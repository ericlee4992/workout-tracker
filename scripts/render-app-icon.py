#!/usr/bin/env python3
"""Draw the app icon: the dumbbell in Soft's Mono palette (D67; the user, 2026-11-07: "for icon make a
mono version"). The dumbbell shape is unchanged since D54 (amber) and D59 (violet).

Usage: render-app-icon.py <appiconset dir>
Writes three 1024 x 1024 PNGs for iOS's icon appearances:
  AppIcon.png        Default: ink #111114 plates, a grey #4A4A50 bar, on white (opaque; iOS masks
                     the corners) — the Mono action of Soft Light.
  AppIcon-Dark.png   Dark: flood #F5F5F7 plates, a grey #A1A1A8 bar, on a transparent ground (iOS
                     draws its dark tile) — the Mono action of Soft dark.
  AppIcon-Tinted.png Tinted: the dumbbell in greys on a transparent ground (iOS tints it; the
                     bar is darker than the plates so the shape survives the tint).
"""
import os
import sys
from PIL import Image, ImageDraw

SIZE = 1024
WHITE = (0xFF, 0xFF, 0xFF, 255)
INK = (0x11, 0x11, 0x14, 255)
INK_BAR = (0x4A, 0x4A, 0x50, 255)
FLOOD = (0xF5, 0xF5, 0xF7, 255)
FLOOD_BAR = (0xA1, 0xA1, 0xA8, 255)
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
    dumbbell(WHITE, INK, INK_BAR).convert("RGB").save(os.path.join(out_dir, "AppIcon.png"), "PNG")
    dumbbell((0, 0, 0, 0), FLOOD, FLOOD_BAR).save(os.path.join(out_dir, "AppIcon-Dark.png"), "PNG")
    dumbbell((0, 0, 0, 0), GREY_PLATE, GREY_BAR).save(os.path.join(out_dir, "AppIcon-Tinted.png"), "PNG")
    print("wrote AppIcon.png, AppIcon-Dark.png, AppIcon-Tinted.png in", out_dir)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
