#!/usr/bin/env python3
"""Draw the app icon: an ink tile with an amber dumbbell (D54, Ink / Amber).
Usage: render-app-icon.py <out.png> — 1024 x 1024, opaque (iOS masks the corners)."""
import sys
from PIL import Image, ImageDraw

SIZE = 1024
INK = (0x0A, 0x0A, 0x0C)
AMBER = (0xFF, 0xB4, 0x5E)
AMBER_DEEP = (0xE0, 0x93, 0x3D)

def main(out):
    scale = 4  # draw big, downsample for smooth edges
    s = SIZE * scale
    img = Image.new("RGB", (s, s), INK)
    d = ImageDraw.Draw(img)
    # The dumbbell: a bar, two inner plates, two outer plates, per side.
    cy = s // 2
    bar_h = int(s * 0.085)
    d.rounded_rectangle([int(s * 0.25), cy - bar_h // 2, int(s * 0.75), cy + bar_h // 2],
                        radius=bar_h // 2, fill=AMBER_DEEP)
    plate_w = int(s * 0.085)
    inner_h = int(s * 0.44)
    outer_h = int(s * 0.32)
    gap = int(s * 0.018)
    r = int(s * 0.025)
    for side in (-1, 1):
        x_inner = s // 2 + side * int(s * 0.21)
        x_outer = x_inner + side * (plate_w + gap)
        for x, h in ((x_inner, inner_h), (x_outer, outer_h)):
            x0, x1 = sorted((x, x + side * plate_w))
            d.rounded_rectangle([x0, cy - h // 2, x1, cy + h // 2], radius=r, fill=AMBER)
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    img.save(out, "PNG")
    print("wrote", out)

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "AppIcon.png")
