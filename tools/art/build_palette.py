#!/usr/bin/env python3
"""Generate the slice palette files from the single warm source of truth.

The warm column is authored by hand. The cold column is DERIVED, never authored --
see docs/art/vertical-slice-art-direction.md section 4. Re-run this script after any
warm-palette edit; do not hand-edit the generated .gpl / .json files.

    python3 tools/art/build_palette.py
"""
import json
import os

# id, warm hex, family, role
WARM = [
    ("ST0", "3b2f28", "stone",   "deepest crevice"),
    ("ST1", "5a4638", "stone",   "shadow"),
    ("ST2", "806450", "stone",   "body"),
    ("ST3", "a8876b", "stone",   "lit face"),
    ("ST4", "cbae8c", "stone",   "rim / chipped edge"),
    ("WX0", "8d7a5e", "wax",     "shadow"),
    ("WX1", "bda880", "wax",     "body"),
    ("WX2", "ded0a8", "wax",     "lit"),
    ("WX3", "f4ecd0", "wax",     "highest value in the kit"),
    ("TC0", "5c2b1f", "terra",   "shadow"),
    ("TC1", "8c3f2a", "terra",   "body"),
    ("TC2", "b85a35", "terra",   "lit"),
    ("TC3", "d98149", "terra",   "rim"),
    ("BZ0", "2f3a33", "bronze",  "shadow"),
    ("BZ1", "4d6152", "bronze",  "body"),
    ("BZ2", "6f8f74", "bronze",  "verdigris bloom"),
    ("BZ3", "9dbfa2", "bronze",  "verdigris lit crust"),
    ("HK0", "2b2621", "husk",    "frame shadow"),
    ("HK1", "4f453a", "husk",    "frame body"),
    ("HK2", "7c6d5a", "husk",    "membrane dried"),
    ("HK3", "b2a288", "husk",    "membrane lit / taut"),
    ("VD0", "14161c", "void",    "interior black"),
    ("VD1", "23262f", "void",    "near-black"),
    ("VD2", "333a47", "void",    "ambient floor"),
    ("BR0", "4a3312", "brass",   "deep seat"),
    ("BR1", "7d5a1d", "brass",   "shadow"),
    ("BR2", "b98c2c", "brass",   "body"),
    ("BR3", "e0b849", "brass",   "lit face"),
    ("BR4", "ffe9a3", "brass",   "specular -- legal only where w > 0"),
    ("SM0", "ff9a3c", "seam",    "outer bleed"),
    ("SM1", "ffc75e", "seam",    "body"),
    ("SM2", "fff2c4", "seam",    "core"),
]

# Cold transform constants. Any change here is an art-direction change, not a tweak.
DESAT_STD, DESAT_METAL = 0.72, 0.55
TINT_STD, TINT_METAL = (0.88, 0.96, 1.08), (0.92, 0.97, 1.03)
COLD_MID = "39424f"
MID_PULL = 0.18
METAL_UNLIT_SCALE = 0.82


def h2r(h):
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def r2h(c):
    return "".join("%02x" % max(0, min(255, round(x))) for x in c)


def luma(rgb):
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]


def cold(hex_warm, family):
    """sRGB-space transform. The shader MUST run this in sRGB, not linear, so that
    what Aseprite shows the artist is what the game shows the player."""
    c = h2r(hex_warm)
    metal = family == "brass"
    s = DESAT_METAL if metal else DESAT_STD
    tint = TINT_METAL if metal else TINT_STD
    L = luma(c)
    c = [x + (L - x) * s for x in c]
    c = [c[i] * tint[i] for i in range(3)]
    if metal:
        # Dormant metal: keeps its value structure, loses its light.
        c = [x * METAL_UNLIT_SCALE for x in c]
    else:
        m = h2r(COLD_MID)
        c = [c[i] + (m[i] - c[i]) * MID_PULL for i in range(3)]
    return r2h(c)


def gpl(path, name, entries):
    with open(path, "w", encoding="utf-8") as f:
        f.write("GIMP Palette\nName: %s\nColumns: 8\n#\n" % name)
        for pid, hx, _fam, role in entries:
            r, g, b = h2r(hx)
            f.write("%3d %3d %3d\t%s %s\n" % (r, g, b, pid, role))


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
    out = os.path.join(root, "docs", "art", "palettes")
    warm_entries, cold_entries, pairs = [], [], []
    for pid, hx, fam, role in WARM:
        warm_entries.append((pid, hx, fam, role))
        if fam == "seam":
            # The seam does not exist in the cold state -- the crack is dark.
            pairs.append({"id": pid, "family": fam, "role": role,
                          "warm": "#" + hx, "cold": None})
            continue
        ch = cold(hx, fam)
        cold_entries.append((pid, ch, fam, role))
        pairs.append({"id": pid, "family": fam, "role": role,
                      "warm": "#" + hx, "cold": "#" + ch})

    gpl(os.path.join(out, "lost-choir-slice.gpl"), "Lost Choir Slice (warm)", warm_entries)
    gpl(os.path.join(out, "lost-choir-slice-cold.gpl"), "Lost Choir Slice (cold, derived)", cold_entries)
    with open(os.path.join(out, "lost-choir-slice.json"), "w", encoding="utf-8") as f:
        json.dump({
            "name": "Lost Choir -- vertical slice",
            "scope": "slice-scoped; see docs/art/vertical-slice-art-direction.md",
            "generated_by": "tools/art/build_palette.py",
            "cold_transform": {
                "space": "sRGB 8-bit",
                "desaturate_toward_luma": {"default": DESAT_STD, "brass": DESAT_METAL},
                "channel_tint": {"default": list(TINT_STD), "brass": list(TINT_METAL)},
                "pull_to_cold_mid": {"color": "#" + COLD_MID, "amount": MID_PULL,
                                     "applies_to": "everything except brass"},
                "brass_unlit_value_scale": METAL_UNLIT_SCALE,
            },
            "colors": pairs,
        }, f, indent=2)
        f.write("\n")
    print("wrote %d colors" % len(pairs))


if __name__ == "__main__":
    main()
