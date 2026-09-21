#!/usr/bin/env python3
"""Acceptance gate for the PLACEHOLDER legibility layer (docs/art/placeholder-legibility.md).

This file, the layer it measures, and the doc it enforces are all throwaway. They exist
so the vertical slice can be playtested against untextured blockout geometry, and they
are deleted together the moment real assets land. See the doc's "Deletion" section.

What it checks, per gameplay element, in the COLD state:

  G1  the element clears 3.0:1 against the terrain solid
  G2  the element clears 3.0:1 against the room backdrop
  G3  the element's own two values clear 3.0:1 against each other
  G4  elements that must be told apart are told apart

An element here is a two-value construction -- a fill plus a contour -- not a flat fill.
G1/G2 are satisfied when EITHER value clears the floor, which is what makes the element's
boundary perceivable against that ground. That is not a softening of the 3:1 floor; it is
the only construction that can meet it at all. The terrain solid and the backdrop are only
4.35:1 apart in the cold state, and clearing 3:1 against both ends of a band requires 9:1
of band. No flat fill of any colour can do it -- see `python3 tools/art/legibility_check.py
--why` for the bound.

    python3 tools/art/legibility_check.py            # run the table gate
    python3 tools/art/legibility_check.py --why      # print the flat-fill impossibility bound
    python3 tools/art/legibility_check.py --table    # print the ratio table only
    python3 tools/art/legibility_check.py --frame shot.png [more.png ...]   # grade real pixels

The table gate grades the TABLE. That is not the same thing as grading the screen, and
the difference is not academic: the table gate passed on a build whose gated door was
being drawn at 55% opacity by `Door._refresh_visual()`, landing it at 1.78:1 against the
backdrop while this file cheerfully reported 4.07:1. A table gate cannot see a modulate,
a material, a blend mode or a z-order. --frame can.

--frame asserts the invariant that makes this layer checkable at all: in a placeholder
scene of flat opaque fills, EVERY pixel is either a ground colour or a colour from the
table below. Any third colour means something is compositing an element, and the table
has stopped describing what the player sees.

Exit 0 = pass, 1 = fail.
"""
import struct
import sys
import zlib

# --- the cold-derive, mirrored from shaders/cold_warm.gdshader -----------------
# Mirrored, never edited here. If the shader's constants ever change, this copy is
# wrong and the gate is measuring a scene that does not exist. It is duplicated
# rather than imported because this whole file is scheduled for deletion and must
# not become something the shader depends on.
DESAT_DEFAULT, DESAT_BRASS = 0.72, 0.55
TINT_DEFAULT, TINT_BRASS = (0.88, 0.96, 1.08), (0.92, 0.97, 1.03)
COLD_MID = (57 / 255.0, 66 / 255.0, 79 / 255.0)
COLD_MID_AMOUNT = 0.18
BRASS_UNLIT_SCALE = 0.82

FLOOR = 3.0  # WCAG 2.1 SC 1.4.11 non-text contrast

# --- the grounds every element is measured against ----------------------------
# Warm authored values from scripts/levels/room.gd; the cold column is derived here
# exactly as the shader derives it at runtime.
TERRAIN_SOLID_WARM = "cbae8c"   # room.gd SOLID_COLOR  (ST4)
BACKDROP_WARM = "3b2f28"        # room.gd BACKDROP_COLOR (ST0)

# The acceptance gate is the cold state. The warm state is checked too because the
# placeholder layer does not run the derive at all, so its colours are state-independent
# while the terrain underneath them is not: R7/R8 are authored warm-on-first-sight
# (art doc 4.3) and a playtester reaches them in this build.
GROUNDS = [("cold", True), ("warm", False)]

# --- the placeholder layer ----------------------------------------------------
# id, label, fill, contour
# Deliberately saturated, deliberately outside docs/art/palettes/lost-choir-slice.json.
# A colour here that could be mistaken for a palette entry is a bug in this table.
PLACEHOLDER = [
    ("player",       "Player (the Listener)", "ffffff", "000000"),
    ("reed_husk",    "Reed Husk",             "ff4a3a", "000000"),
    ("keening_husk", "Keening Husk",          "35d6ff", "000000"),
    ("verse_bearer", "Verse-bearer (R6)",     "ffe14a", "000000"),
    ("bell_frame",   "Bell-frame",            "b06fff", "000000"),
    ("membrane",     "Membrane",              "3cff7d", "000000"),
    ("door_gated",   "Gated door",            "ff44ab", "000000"),
    ("door_open",    "Open door",             "05060a", "ff44ab"),
]

# Pairs H6 needs a playtester to tell apart (see the doc's "Identity" section).
MUST_DIFFER = [
    ("player", "reed_husk"),
    ("player", "keening_husk"),
    ("reed_husk", "keening_husk"),
    ("door_gated", "door_open"),
]
DIFFER_MIN_RATIO = 1.5   # value separation between the two fills
DIFFER_MIN_HUE = 40.0    # degrees, or achromatic-vs-chromatic


def h2rgb(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def derive_cold(c, brass=False):
    luma = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    s = DESAT_BRASS if brass else DESAT_DEFAULT
    d = [x + (luma - x) * s for x in c]
    t = TINT_BRASS if brass else TINT_DEFAULT
    d = [d[i] * t[i] for i in range(3)]
    if brass:
        return tuple(min(1.0, max(0.0, x * BRASS_UNLIT_SCALE)) for x in d)
    return tuple(min(1.0, max(0.0, d[i] + (COLD_MID[i] - d[i]) * COLD_MID_AMOUNT)) for i in range(3))


def rel_lum(c):
    def lin(u):
        return u / 12.92 if u <= 0.04045 else ((u + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(x) for x in c)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio(a, b):
    la, lb = rel_lum(a), rel_lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def hue_sat(c):
    mx, mn = max(c), min(c)
    d = mx - mn
    if d < 1e-6:
        return None, 0.0
    if mx == c[0]:
        h = 60.0 * (((c[1] - c[2]) / d) % 6)
    elif mx == c[1]:
        h = 60.0 * (((c[2] - c[0]) / d) + 2)
    else:
        h = 60.0 * (((c[0] - c[1]) / d) + 4)
    return h, d / mx


def hue_delta(a, b):
    ha, sa = hue_sat(a)
    hb, sb = hue_sat(b)
    if ha is None or hb is None:
        # achromatic vs chromatic is a separation in its own right
        return 180.0 if (sa > 0.25 or sb > 0.25) else 0.0
    d = abs(ha - hb) % 360.0
    return min(d, 360.0 - d)


def to_hex(c):
    return "#" + "".join("%02x" % max(0, min(255, round(x * 255))) for x in c)


# --- real-pixel grading -------------------------------------------------------
UNKNOWN_AREA_FAIL = 16   # px; below this an odd colour is reported but not fatal
GROUND_TOLERANCE = 2     # per-channel, absorbs the shader's float->byte rounding


def read_png(path):
    """Minimal 8-bit non-interlaced RGB/RGBA reader -- what Godot writes, no Pillow."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("%s: not a PNG" % path)
    pos, idat, hdr = 8, [], None
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        ctype = data[pos + 4:pos + 8]
        if ctype == b"IHDR":
            hdr = struct.unpack(">IIBBBBB", data[pos + 8:pos + 8 + length])
        elif ctype == b"IDAT":
            idat.append(data[pos + 8:pos + 8 + length])
        elif ctype == b"IEND":
            break
        pos += 12 + length
    if hdr is None:
        raise ValueError("%s: no IHDR" % path)
    w, h, depth, color, _c, _f, interlace = hdr
    if depth != 8 or interlace != 0 or color not in (2, 6):
        raise ValueError("%s: need 8-bit non-interlaced RGB or RGBA" % path)
    n = 3 if color == 2 else 4
    raw = zlib.decompress(b"".join(idat))
    stride, out, prev, p = w * n, bytearray(w * n * h), bytearray(w * n), 0
    for y in range(h):
        ft = raw[p]
        p += 1
        line = bytearray(raw[p:p + stride])
        p += stride
        if ft == 1:
            for i in range(n, stride):
                line[i] = (line[i] + line[i - n]) & 0xFF
        elif ft == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif ft == 3:
            for i in range(stride):
                a = line[i - n] if i >= n else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif ft == 4:
            for i in range(stride):
                a = line[i - n] if i >= n else 0
                c = prev[i - n] if i >= n else 0
                b = prev[i]
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        elif ft != 0:
            raise ValueError("%s: bad PNG filter %d" % (path, ft))
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return w, h, n, bytes(out)


def _near(a, b):
    return all(abs(a[i] - b[i]) <= GROUND_TOLERANCE for i in range(3))


def grade_frame(path):
    """True if every pixel is a ground colour or a table colour."""
    w, h, n, px = read_png(path)
    counts = {}
    for i in range(0, len(px), n):
        key = (px[i], px[i + 1], px[i + 2])
        counts[key] = counts.get(key, 0) + 1

    grounds = []
    for state, cold in GROUNDS:
        for role, warm_hex in (("terrain solid", TERRAIN_SOLID_WARM), ("backdrop", BACKDROP_WARM)):
            c = derive_cold(h2rgb(warm_hex)) if cold else h2rgb(warm_hex)
            grounds.append(("%s %s" % (state, role), tuple(round(x * 255) for x in c)))
    # One colour can serve several roles -- the black contour serves seven -- so
    # collect every owner rather than letting the first entry claim it.
    table = {}
    for eid, label, fill_hex, cont_hex in PLACEHOLDER:
        for hx, kind in ((fill_hex, "fill"), (cont_hex, "contour")):
            table.setdefault(tuple(int(hx[i:i + 2], 16) for i in (0, 2, 4)), []).append(
                "%s %s" % (label, kind))

    cold_solid = derive_cold(h2rgb(TERRAIN_SOLID_WARM))
    cold_back = derive_cold(h2rgb(BACKDROP_WARM))

    print("%s -- %dx%d, %d distinct colours" % (path, w, h, len(counts)))
    unknown, ok = [], True
    for col, cnt in sorted(counts.items(), key=lambda kv: -kv[1]):
        known_as = None
        for gname, gcol in grounds:
            if _near(col, gcol):
                known_as = gname
                break
        if known_as is None:
            for tcol, owners in table.items():
                if _near(col, tcol):
                    known_as = (owners[0] if len(owners) == 1
                                else "%s (+%d more)" % (owners[0], len(owners) - 1))
                    break
        hexs = "#%02x%02x%02x" % col
        if known_as is None:
            rgb = tuple(x / 255.0 for x in col)
            print("   %s %7d px  UNACCOUNTED -- vs cold solid %.2f:1, vs cold backdrop %.2f:1"
                  % (hexs, cnt, ratio(rgb, cold_solid), ratio(rgb, cold_back)))
            unknown.append((hexs, cnt))
            if cnt >= UNKNOWN_AREA_FAIL:
                ok = False
        else:
            print("   %s %7d px  %s" % (hexs, cnt, known_as))
    if unknown and not ok:
        print("   -> an unaccounted colour means an element is being composited (modulate,")
        print("      alpha, blend mode) and the table no longer describes the screen.")
    print("   frame verdict: %s" % ("PASS" if ok else "FAIL"))
    print()
    return ok


def why():
    solid = derive_cold(h2rgb(TERRAIN_SOLID_WARM))
    back = derive_cold(h2rgb(BACKDROP_WARM))
    ls, lb = rel_lum(solid), rel_lum(back)
    print("cold terrain solid %s  relative luminance %.4f" % (to_hex(solid), ls))
    print("cold backdrop      %s  relative luminance %.4f" % (to_hex(back), lb))
    print("band between them: %.2f:1" % ratio(solid, back))
    print()
    print("A single flat fill clearing %.1f:1 against BOTH ends of that band needs" % FLOOR)
    print("%.0f:1 of band. There is %.2f:1. The three candidate windows are all empty:" % (FLOOR * FLOOR, ratio(solid, back)))
    print("  lighter than the solid:  L >= %.4f   (the brightest colour that exists is 1.0000)"
          % (FLOOR * (ls + 0.05) - 0.05))
    print("  darker than the backdrop: L <= %+.4f  (the darkest colour that exists is 0.0000)"
          % ((lb + 0.05) / FLOOR - 0.05))
    print("  between the two:          L >= %.4f AND L <= %.4f   (empty interval)"
          % (FLOOR * (lb + 0.05) - 0.05, (ls + 0.05) / FLOOR - 0.05))
    print()
    print("Pure white -- the best a flat fill can possibly do -- reaches %.2f:1 against the"
          % ratio((1.0, 1.0, 1.0), solid))
    print("solid. Hence the two-value construction. See docs/art/placeholder-legibility.md.")


def main(argv):
    if "--why" in argv:
        why()
        return 0

    if "--frame" in argv:
        paths = argv[argv.index("--frame") + 1:]
        if not paths:
            print("error: --frame needs at least one PNG")
            return 1
        ok = True
        for p in paths:
            try:
                ok &= grade_frame(p)
            except (OSError, ValueError) as exc:
                print("error: %s" % exc)
                return 1
        print("rendered-frame gate: %s" % ("PASS" if ok else "FAIL"))
        return 0 if ok else 1

    table_only = "--table" in argv
    rows, ok = {}, True

    for state, cold in GROUNDS:
        solid = derive_cold(h2rgb(TERRAIN_SOLID_WARM)) if cold else h2rgb(TERRAIN_SOLID_WARM)
        back = derive_cold(h2rgb(BACKDROP_WARM)) if cold else h2rgb(BACKDROP_WARM)
        print("%s state -- terrain solid %s   backdrop %s   band %.2f:1"
              % (state, to_hex(solid), to_hex(back), ratio(solid, back)))
        print("%-22s %-9s %-9s %10s %11s %10s"
              % ("element", "fill", "contour", "vs solid", "vs backdrop", "fill/cont"))
        for eid, label, fill_hex, cont_hex in PLACEHOLDER:
            fill, cont = h2rgb(fill_hex), h2rgb(cont_hex)
            g1 = max(ratio(fill, solid), ratio(cont, solid))
            g2 = max(ratio(fill, back), ratio(cont, back))
            g3 = ratio(fill, cont)
            rows[eid] = fill
            print("%-22s #%-8s #%-8s %9.2f %11.2f %10.2f"
                  % (label, fill_hex, cont_hex, g1, g2, g3))
            if not table_only:
                ok &= g1 >= FLOOR and g2 >= FLOOR and g3 >= FLOOR
        print()

    print("%-22s %-22s %10s %8s" % ("must be told apart", "", "value", "hue deg"))
    for a, b in MUST_DIFFER:
        r = ratio(rows[a], rows[b])
        hd = hue_delta(rows[a], rows[b])
        passed = r >= DIFFER_MIN_RATIO or hd >= DIFFER_MIN_HUE
        print("%-22s %-22s %10.2f %8.0f   %s" % (a, b, r, hd, "ok" if passed else "FAIL"))
        if not table_only:
            ok &= passed

    if table_only:
        return 0
    print()
    print("G1 element vs terrain solid  >= %.1f:1   G2 element vs backdrop >= %.1f:1" % (FLOOR, FLOOR))
    print("G3 fill vs its own contour   >= %.1f:1   G4 mutually distinguishable" % FLOOR)
    print()
    print("placeholder legibility gate: %s" % ("PASS" if ok else "FAIL"))
    print("reminder: this gate is throwaway. Deleting it is part of shipping real art.")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
