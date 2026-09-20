#!/usr/bin/env python3
"""Compose a §14-compliant review sheet: full render + shipping-size resample + black-fill silhouette."""
import sys
from PIL import Image, ImageDraw

def make_sheet(src_path, out_path, canvas_w, canvas_h, bg_sample_xy=(4, 4), bg_thresh=28):
    src = Image.open(src_path).convert("RGB")
    bg = src.getpixel(bg_sample_xy)

    # shipping-size resample (nearest, no smoothing — this is a preview of pixel art, not a photo downscale)
    small = src.resize((canvas_w, canvas_h), Image.NEAREST)

    # black-fill silhouette from the full-res render: mask by distance from sampled background color
    mask = Image.new("L", src.size, 0)
    px = src.load()
    mpx = mask.load()
    for y in range(src.size[1]):
        for x in range(src.size[0]):
            r, g, b = px[x, y]
            dr, dg, db = r - bg[0], g - bg[1], b - bg[2]
            dist = (dr * dr + dg * dg + db * db) ** 0.5
            mpx[x, y] = 255 if dist > bg_thresh else 0
    silhouette_full = Image.new("RGB", src.size, (255, 255, 255))
    silhouette_full.paste((0, 0, 0), mask=mask)
    silhouette_small = silhouette_full.resize((canvas_w, canvas_h), Image.NEAREST)
    # upscale the shipping-size panels back up (nearest) so they're inspectable in the sheet
    up = 6
    small_up = small.resize((canvas_w * up, canvas_h * up), Image.NEAREST)
    silhouette_up = silhouette_small.resize((canvas_w * up, canvas_h * up), Image.NEAREST)

    pad = 24
    row_h = max(src.size[1], small_up.size[1], silhouette_up.size[1])
    total_w = src.size[0] + pad + small_up.size[0] + pad + silhouette_up.size[0] + pad * 2
    total_h = row_h + 60
    sheet = Image.new("RGB", (total_w, total_h), (40, 40, 44))
    d = ImageDraw.Draw(sheet)
    x = pad
    sheet.paste(src, (x, 50))
    d.text((x, 15), "full render", fill=(230, 230, 230))
    x += src.size[0] + pad
    sheet.paste(small_up, (x, 50))
    d.text((x, 15), f"shipping {canvas_w}x{canvas_h} (nearest, x{up})", fill=(230, 230, 230))
    x += small_up.size[0] + pad
    sheet.paste(silhouette_up, (x, 50))
    d.text((x, 15), "black-fill silhouette test", fill=(230, 230, 230))
    sheet.save(out_path, quality=92)
    print(f"wrote {out_path}")

if __name__ == "__main__":
    src, out, w, h = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    bx = int(sys.argv[5]) if len(sys.argv) > 5 else 4
    by = int(sys.argv[6]) if len(sys.argv) > 6 else 4
    make_sheet(src, out, w, h, (bx, by))
