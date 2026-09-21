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
  S0  no actor or interactable is an axis-aligned rectangle (doors exempt)
  S1  pairwise bbox aspect ratios differ by >= 1.25x
  S2  pairwise silhouette fill ratios differ by >= 0.12 (actor classes)
  S3  the two husks SHARE a fill ratio -- same primitive, different proportions

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
    python3 tools/art/legibility_check.py --silhouette          # S0-S3 only
    python3 tools/art/legibility_check.py --contact-sheet o.png # S5 black-on-white sheet

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

# --- the silhouette contract (criteria 6-8) -----------------------------------
# Visual polygons in .tscn units: origin at the element's own anchor, y negative
# is up. COLLISION SHAPES ARE FROZEN -- these are visual-only and a visual that
# overhangs its collider is accepted here (it is one more thing that makes the
# scaffold obviously temporary).
#
# Deliberately crude angular primitives. The approved direction's silhouette
# grammar is "rounded and resonant -- bell curves, horn bells, larynx curvature
# ... never angular"; these are angular on purpose, for the same reason the
# contour is a forbidden motif on purpose. See doc section 6.
SILHOUETTE = {
    # Leaning wrapped column with a one-sided shoulder yoke. The yoke is the
    # asymmetry (S4) and it sits at shoulder height, not head height: art doc
    # section 6 makes "no ears" a rejection criterion, and a protrusion at the
    # crown reads as an ear or a horn before it reads as anything else.
    "player": [(-9, 0), (-9, -40), (9, -40), (9, -30), (15, -30), (15, -20), (9, -20), (9, 0)],
    # One primitive, two proportions (S3). Both taper toward the aperture, so
    # the taper length IS the note length -- art doc section 7.2's "short
    # aperture = short note = short lead; long aperture = long note = long lead"
    # stated as a shape. Both keep the chamber low and the base rooted.
    "reed_husk": [(-16, 0), (-5, -22), (5, -22), (16, 0)],
    "keening_husk": [(-9, 0), (-3, -48), (3, -48), (9, 0)],
    # Flared bell mouth carried on two ribs that protrude past the chamber's
    # widest point, with real negative space beneath the mouth (art doc
    # section 8's two geometric requirements).
    "verse_bearer": [(-20, 0), (-20, -18), (-16, -18), (-8, -38), (8, -38), (16, -18),
                     (20, -18), (20, 0), (15, 0), (15, -18), (-15, -18), (-15, 0)],
    # Tuned tubes of stepped length hanging mouth-down from a yoke (art doc
    # section 9.2). Tube gaps are 8 px so a 2 px contour on each side still
    # leaves 4 px of background visible between them.
    "bell_frame": [(-24, -6), (24, -6), (24, -2), (20, -2), (20, 2), (12, 2), (12, -2),
                   (4, -2), (4, 5), (-4, 5), (-4, -2), (-12, -2), (-12, 8), (-20, 8),
                   (-20, -2), (-24, -2)],
    # Slack skin with the sag off-centre, never at the middle (art doc 9.1).
    "membrane": [(-32, -4), (32, -4), (32, 0), (-10, 6), (-32, 0)],
}

# Doors are exempt from S0: a door is architecture, it is rectangular because it
# is an opening in a wall, and the two constructions in section 4 already carry
# its state distinction structurally.
ACTOR_CLASSES = ["player", "reed_husk", "keening_husk", "verse_bearer"]
KIN_PAIR = {"reed_husk", "keening_husk"}   # S3: same primitive, must SHARE a fill ratio
S1_MIN_RATIO_SEP = 1.25   # pairwise bbox aspect-ratio separation
S2_MIN_FILL_SEP = 0.12    # pairwise silhouette-area / bbox-area separation
S3_MAX_KIN_FILL_SEP = 0.05  # the kin pair must not separate on fill
S0_MAX_FILL = 0.98        # above this the silhouette is an axis-aligned rectangle


def poly_area(pts):
    s = 0.0
    for i in range(len(pts)):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % len(pts)]
        s += x1 * y2 - x2 * y1
    return abs(s) / 2.0


def poly_bbox(pts):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)


def _mirror_symmetric(pts):
    """True if the rasterised shape mirrors about its bounding box's vertical axis."""
    W, H, on = _raster(pts, 1)
    return all((W - 1 - x, y) in on for (x, y) in on)


def silhouette_metrics():
    out = {}
    for k, pts in SILHOUETTE.items():
        _x, _y, w, h = poly_bbox(pts)
        a = poly_area(pts)
        out[k] = {"w": w, "h": h, "ratio": w / float(h), "fill": a / float(w * h), "area": a}
    return out


def silhouette_gate(verbose=True):
    m = silhouette_metrics()
    ok = True
    if verbose:
        print("%-14s %8s %8s %8s %8s" % ("class", "bbox", "ratio", "fill", "verts"))
        for k in SILHOUETTE:
            print("%-14s %8s %8.3f %8.3f %8d"
                  % (k, "%dx%d" % (m[k]["w"], m[k]["h"]), m[k]["ratio"], m[k]["fill"],
                     len(SILHOUETTE[k])))
        print()

    names = list(SILHOUETTE)
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            a, b = names[i], names[j]
            sep = max(m[a]["ratio"], m[b]["ratio"]) / min(m[a]["ratio"], m[b]["ratio"])
            if sep < S1_MIN_RATIO_SEP:
                ok = False
                if verbose:
                    print("S1 FAIL %s/%s aspect separation %.2f < %.2f" % (a, b, sep, S1_MIN_RATIO_SEP))
    for i in range(len(ACTOR_CLASSES)):
        for j in range(i + 1, len(ACTOR_CLASSES)):
            a, b = ACTOR_CLASSES[i], ACTOR_CLASSES[j]
            d = abs(m[a]["fill"] - m[b]["fill"])
            if {a, b} == KIN_PAIR:
                if d > S3_MAX_KIN_FILL_SEP:   # S3 is a floor from the other side
                    ok = False
                    if verbose:
                        print("S3 FAIL kin pair separates on fill by %.3f -- they must share it" % d)
            elif d < S2_MIN_FILL_SEP:
                ok = False
                if verbose:
                    print("S2 FAIL %s/%s fill separation %.3f < %.2f" % (a, b, d, S2_MIN_FILL_SEP))
    # S4: exactly one actor class is asymmetric, and it is the player. The two
    # interactables are asymmetric too, deliberately and by instruction from the
    # art direction (art doc 9.1 requires the membrane's sag off-centre because a
    # centred depression reads as a hole; 9.2 specifies tubes of stepped length).
    # That does not weaken S4, whose job is that the player survives a value-only
    # and a colour-blind read against the other ACTORS -- nothing shares an
    # aspect-ratio band with a 64x10 horizontal strip.
    asym = [k for k in ACTOR_CLASSES if not _mirror_symmetric(SILHOUETTE[k])]
    if asym != ["player"]:
        ok = False
        if verbose:
            print("S4 FAIL asymmetric actor classes are %s, expected exactly ['player']" % asym)
    elif verbose:
        others = [k for k in SILHOUETTE if k not in ACTOR_CLASSES
                  and not _mirror_symmetric(SILHOUETTE[k])]
        print("S4 player is the only asymmetric actor; asymmetric interactables "
              "(art-directed): %s" % (others or "none"))
    for k in SILHOUETTE:
        if m[k]["fill"] > S0_MAX_FILL:
            ok = False
            if verbose:
                print("S0 FAIL %s is an axis-aligned rectangle (fill %.3f)" % (k, m[k]["fill"]))
    if verbose:
        print("S0 not-a-rectangle / S1 proportion / S2 outline / S3 kinship: %s"
              % ("PASS" if ok else "FAIL"))
    return ok


def _raster(pts, scale):
    """Even-odd scanline fill at integer pixel centres. Returns (w, h, set-of-px)."""
    x0, y0, w, h = poly_bbox(pts)
    W, H = int(w * scale), int(h * scale)
    sp = [((px - x0) * scale, (py - y0) * scale) for px, py in pts]
    on = set()
    for y in range(H):
        yc = y + 0.5
        xs = []
        for i in range(len(sp)):
            ax, ay = sp[i]
            bx, by = sp[(i + 1) % len(sp)]
            if (ay <= yc < by) or (by <= yc < ay):
                xs.append(ax + (yc - ay) * (bx - ax) / float(by - ay))
        xs.sort()
        for k in range(0, len(xs) - 1, 2):
            for x in range(max(0, int(xs[k] + 0.5)), min(W, int(xs[k + 1] + 0.5))):
                on.add((x, y))
    return W, H, on


def _write_png(path, w, h, rows):
    def chunk(tag, data):
        c = tag + data
        return (struct.pack(">I", len(data)) + c
                + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF))
    raw = b"".join(b"\x00" + bytes(r) for r in rows)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


def contact_sheet(path):
    """Section 5 of the silhouette contract: every class flattened to solid black
    on white, no colour and no contour, baseline-aligned. Row 1 is slice scale --
    the honest test. Row 2 is the same geometry at 4x, because a human cannot
    judge an 18 px shape on a modern display."""
    groups = [ACTOR_CLASSES, [k for k in SILHOUETTE if k not in ACTOR_CLASSES]]
    PAD, GAP = 12, 16
    bands = []
    for scale in (1, 4):
        for grp in groups:
            rast = [_raster(SILHOUETTE[k], scale) for k in grp]
            bands.append((rast, max(r[1] for r in rast)))
    width = PAD * 2 + max(sum(r[0] for r in rast) + GAP * scale * (len(rast) - 1)
                          for scale, (rast, _bh) in zip((1, 1, 4, 4), bands))
    height = PAD * 2 + sum(bh for _r, bh in bands) + GAP * (len(bands) - 1)
    rows = [bytearray([255] * (width * 3)) for _ in range(height)]

    y = PAD
    for scale, (rast, bh) in zip((1, 1, 4, 4), bands):
        x = PAD
        for W, H, on in rast:
            base = y + bh - H          # baseline-align
            for (px, py) in on:
                i = ((base + py) * width + x + px) * 3
                rows[base + py][(x + px) * 3:(x + px) * 3 + 3] = b"\x00\x00\x00"
            x += W + GAP * scale
        y += bh + GAP
    _write_png(path, width, height, rows)
    order = " | ".join(groups[0]) + "   then   " + " | ".join(groups[1])
    print("wrote %s (%dx%d) -- rows: 1x actors, 1x interactables, 4x actors, 4x interactables"
          % (path, width, height))
    print("left to right: %s" % order)


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

    if "--contact-sheet" in argv:
        i = argv.index("--contact-sheet")
        out = argv[i + 1] if len(argv) > i + 1 else "contact_sheet.png"
        contact_sheet(out)
        return 0

    if "--silhouette" in argv:
        return 0 if silhouette_gate() else 1

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
    print("-- silhouette contract (criteria 6-8) --")
    ok &= silhouette_gate()
    print()
    print("G1 element vs terrain solid  >= %.1f:1   G2 element vs backdrop >= %.1f:1" % (FLOOR, FLOOR))
    print("G3 fill vs its own contour   >= %.1f:1   G4 mutually distinguishable" % FLOOR)
    print()
    print("placeholder legibility gate: %s" % ("PASS" if ok else "FAIL"))
    print("reminder: this gate is throwaway. Deleting it is part of shipping real art.")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
