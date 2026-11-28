"""Add print bleed to a rendered tarp PNG by mirroring its edges.

    python make_bleed.py <in.png> <out-basename> [--bleed-in 0.5] [--dpi 300]

Writes <out-basename>.png and <out-basename>.pdf, each (24 + 2*bleed) x (36 + 2*bleed) in.
The printer trims the extra back off, so the artwork still ends exactly at 24 x 36 in.
"""
import argparse
from PIL import Image, ImageOps

Image.MAX_IMAGE_PIXELS = None

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("out")
ap.add_argument("--bleed-in", type=float, default=0.5)
ap.add_argument("--dpi", type=int, default=300)
a = ap.parse_args()

im = Image.open(a.src).convert("RGB")
b = round(a.bleed_in * a.dpi)
w, h = im.size
out = Image.new("RGB", (w + 2 * b, h + 2 * b))
out.paste(im, (b, b))
# Edges: mirror the outermost b pixels outward; corners: mirror both ways.
out.paste(ImageOps.mirror(im.crop((0, 0, b, h))), (0, b))
out.paste(ImageOps.mirror(im.crop((w - b, 0, w, h))), (w + b, b))
out.paste(ImageOps.flip(im.crop((0, 0, w, b))), (b, 0))
out.paste(ImageOps.flip(im.crop((0, h - b, w, h))), (b, h + b))
for (x0, y0, dx, dy) in [(0, 0, 0, 0), (w - b, 0, w + b, 0), (0, h - b, 0, h + b), (w - b, h - b, w + b, h + b)]:
    out.paste(ImageOps.flip(ImageOps.mirror(im.crop((x0, y0, x0 + b, y0 + b)))), (dx, dy))

out.save(a.out + ".png", dpi=(a.dpi, a.dpi))
out.save(a.out + ".pdf", resolution=a.dpi)
print(f"{a.out}: {out.size[0]}x{out.size[1]} px = {out.size[0]/a.dpi:.2f} x {out.size[1]/a.dpi:.2f} in @ {a.dpi} dpi")
