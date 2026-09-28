#!/usr/bin/env python3
"""Draw the app icon: the dumbbell in the Floodlight palette (D54, Floodlight redesign ticket 11 —
the user kept the dumbbell and moved it from amber to violet).

Usage: render-app-icon.py <appiconset dir>
Writes three 1024 x 1024 PNGs for iOS's icon appearances:
  AppIcon.png        Default: violet #B25CFF plates, deeper violet bar, on ink #060708 (opaque;
                     iOS masks the corners).
  AppIcon-Dark.png   Dark: the same dumbbell on a transparent ground (iOS draws its dark tile).
  AppIcon-Tinted.png Tinted: the dumbbell in greys on a transparent ground (iOS tints it; the
                     bar is darker than the plates so the shape survives the tint).
"""
import os
import sys
from PIL import Image, ImageDraw

SIZE = 1024
INK = (0x06, 0x07, 0x08, 255)
VIOLET = (0xB2, 0x5C, 0xFF, 255)
VIOLET_DEEP = (0x8E, 0x3F, 0xD6, 255)
GREY_PLATE = (0xFF, 0xFF, 0xFF, 255)
GREY_BAR = (0xA0, 0xA0, 0xA0, 255)


def dumbbell(ground, plate, bar):
    scale = 4  # draw big, downsample for smooth edges
    s = SIZE * scale
    img = Image.new("RGBA", (s, s), ground)
    d = ImageDraw.Draw(img)
    # The bar runs under every plate; two plates a side (the shape the user chose, D54).
    cy = s // 2
    bar_h = int(s * 0.085)
    d.rounded_rectangle([int(s * 0.12), cy - bar_h // 2, int(s * 0.88), cy + bar_h // 2],
                        radius=bar_h // 2, fill=bar)
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
            d.rounded_rectangle([x0, cy - h // 2, x1, cy + h // 2], radius=r, fill=plate)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main(out_dir):
    dumbbell(INK, VIOLET, VIOLET_DEEP).convert("RGB").save(os.path.join(out_dir, "AppIcon.png"), "PNG")
    dumbbell((0, 0, 0, 0), VIOLET, VIOLET_DEEP).save(os.path.join(out_dir, "AppIcon-Dark.png"), "PNG")
    dumbbell((0, 0, 0, 0), GREY_PLATE, GREY_BAR).save(os.path.join(out_dir, "AppIcon-Tinted.png"), "PNG")
    print("wrote AppIcon.png, AppIcon-Dark.png, AppIcon-Tinted.png in", out_dir)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
