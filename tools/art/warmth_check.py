#!/usr/bin/env python3
"""Acceptance checker for the cold -> warm contract (vertical-slice spec section 8).

Section 8 asks for "a measurable rise in scene warmth and contrast" and for a
side-by-side that is unmistakable to someone who has not played. This script is the
measurable half. It does not replace the human side-by-side read -- it catches the
case where the transition looks like a graphics setting instead of a consequence,
before it reaches a playtester.

    python3 tools/art/warmth_check.py cold.png warm.png

Both images must be the same room, same camera, same frame, one before restoration and
one after. Exit code 0 = pass, 1 = fail, 2 = could not read an input.

Thresholds are art-direction contracts, not tuning knobs -- see section 4.4 of
docs/art/vertical-slice-art-direction.md.
"""
import struct
import sys
import zlib

# --- thresholds (section 4.4) -------------------------------------------------
COLD_MAX_MEAN_W = 0.02    # cold scene must not be warm on average
COLD_MAX_WARM_SHARE = 0.06  # at most 6% of pixels may sit above the chroma floor (dormant brass)
MIN_DELTA_MEAN_W = 0.12   # warmth must rise by this much
MIN_DELTA_CONTRAST = 0.02  # value contrast (stdev of luma) must rise by this much
WARM_FLOOR = 0.06         # a pixel is "warm" when (R-B)/255 exceeds this


def read_png(path):
    """Minimal 8-bit non-interlaced RGB/RGBA PNG reader -- what Godot screenshots are.
    Avoids a Pillow dependency so the gate runs anywhere, including bare CI."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("%s: not a PNG" % path)
    pos, idat, hdr = 8, [], None
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        ctype = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if ctype == b"IHDR":
            hdr = struct.unpack(">IIBBBBB", body)
        elif ctype == b"IDAT":
            idat.append(body)
        elif ctype == b"IEND":
            break
        pos += 12 + length
    if hdr is None:
        raise ValueError("%s: no IHDR" % path)
    w, h, depth, color, _comp, _filt, interlace = hdr
    if depth != 8 or interlace != 0 or color not in (2, 6):
        raise ValueError("%s: need 8-bit non-interlaced RGB or RGBA" % path)
    nch = 3 if color == 2 else 4
    raw = zlib.decompress(b"".join(idat))
    stride = w * nch
    out = bytearray(stride * h)
    prev = bytearray(stride)
    p = 0
    for y in range(h):
        ft = raw[p]
        p += 1
        line = bytearray(raw[p:p + stride])
        p += stride
        if ft == 1:
            for i in range(nch, stride):
                line[i] = (line[i] + line[i - nch]) & 0xFF
        elif ft == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif ft == 3:
            for i in range(stride):
                a = line[i - nch] if i >= nch else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif ft == 4:
            for i in range(stride):
                a = line[i - nch] if i >= nch else 0
                c = prev[i - nch] if i >= nch else 0
                b = prev[i]
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        elif ft != 0:
            raise ValueError("%s: bad filter %d" % (path, ft))
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return w, h, nch, bytes(out)


def measure(path):
    w, h, nch, px = read_png(path)
    n = w * h
    sw = sl = sl2 = 0.0
    warm_px = 0
    for i in range(0, len(px), nch):
        r, g, b = px[i], px[i + 1], px[i + 2]
        warmth = (r - b) / 255.0
        lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
        sw += warmth
        sl += lum
        sl2 += lum * lum
        if warmth > WARM_FLOOR:
            warm_px += 1
    mean_w = sw / n
    mean_l = sl / n
    contrast = max(0.0, sl2 / n - mean_l * mean_l) ** 0.5
    return {"px": n, "mean_w": mean_w, "warm_share": warm_px / n,
            "mean_lum": mean_l, "contrast": contrast}


def main(argv):
    if len(argv) != 3:
        print(__doc__)
        return 2
    try:
        cold, warm = measure(argv[1]), measure(argv[2])
    except (OSError, ValueError) as exc:
        print("error: %s" % exc)
        return 2
    if cold["px"] != warm["px"]:
        print("error: images differ in size -- shoot the same camera framing")
        return 2

    d_w = warm["mean_w"] - cold["mean_w"]
    d_c = warm["contrast"] - cold["contrast"]
    checks = [
        ("cold scene is not warm on average", cold["mean_w"] <= COLD_MAX_MEAN_W,
         "mean warmth %+.3f (max %+.3f)" % (cold["mean_w"], COLD_MAX_MEAN_W)),
        ("cold has only dormant brass above the chroma floor",
         cold["warm_share"] <= COLD_MAX_WARM_SHARE,
         "%.1f%% of pixels warm (max %.1f%%)" % (cold["warm_share"] * 100, COLD_MAX_WARM_SHARE * 100)),
        ("cold has some dormant brass at all", cold["warm_share"] > 0.001,
         "%.2f%% of pixels warm -- absent metal, not dormant metal" % (cold["warm_share"] * 100)),
        ("warmth rises", d_w >= MIN_DELTA_MEAN_W,
         "delta mean warmth %+.3f (min %+.3f)" % (d_w, MIN_DELTA_MEAN_W)),
        ("contrast rises", d_c >= MIN_DELTA_CONTRAST,
         "delta contrast %+.3f (min %+.3f)" % (d_c, MIN_DELTA_CONTRAST)),
    ]
    print("cold: mean_w %+.3f  warm_share %.1f%%  lum %.3f  contrast %.3f"
          % (cold["mean_w"], cold["warm_share"] * 100, cold["mean_lum"], cold["contrast"]))
    print("warm: mean_w %+.3f  warm_share %.1f%%  lum %.3f  contrast %.3f"
          % (warm["mean_w"], warm["warm_share"] * 100, warm["mean_lum"], warm["contrast"]))
    print()
    ok = True
    for label, passed, detail in checks:
        print("%s %-52s %s" % ("PASS" if passed else "FAIL", label, detail))
        ok &= passed
    print()
    print("section 8 numeric gate: %s" % ("PASS" if ok else "FAIL"))
    print("reminder: the human side-by-side read is a separate, non-negotiable gate.")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
