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

    python3 tools/art/legibility_check.py            # run the gate
    python3 tools/art/legibility_check.py --why      # print the flat-fill impossibility bound
    python3 tools/art/legibility_check.py --table    # print the ratio table only

Exit 0 = pass, 1 = fail.
"""
import sys

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
