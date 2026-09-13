"""Ticket 12 — the muscle-map assets, reproducibly (codex-review-12, P3).

Reads Codex's round-2 renders (grey body + red muscle on black, 1024 px) and writes the app's
two template layers per family into Assets.xcassets/MuscleMaps/<family>-{body,muscle}.imageset:
  body   alpha = clamp((max(r,g,b) - 18) / (70 - 18))            — anything that is not black
  muscle alpha = clamp((r - max(g,b) - 25) / (90 - 25)) * body   — redness, inside the body
Crop: the body's bounding box where body alpha > 0.5, padded to a square of 1.08 × the longer
side, centred on the bbox; then LANCZOS to 512 × 512. RGB is white (template rendering replaces
it). Run from the repo root: python3 work-record/ui-redesign/icons/make-muscle-map-assets.py
"""
from PIL import Image
import numpy as np, json, os
SRC = "work-record/ui-redesign/icons/codex2"
OUT = "WorkoutTracker/Assets.xcassets/MuscleMaps"
FAMILIES = ["chest", "back", "shoulders", "arms", "legs"]
BODY_LO, BODY_HI, RED_LO, RED_HI, BBOX_ALPHA, PAD, SIZE = 18, 70, 25, 90, 0.5, 1.08, 512

def soft(v, lo, hi):
    return np.clip((v - lo) / (hi - lo), 0, 1)

os.makedirs(OUT, exist_ok=True)
json.dump({"info": {"author": "xcode", "version": 1}, "properties": {"provides-namespace": True}},
          open(f"{OUT}/Contents.json", "w"), indent=2)
for fam in FAMILIES:
    im = np.asarray(Image.open(f"{SRC}/{fam}.png").convert("RGB")).astype(float)
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    body_a = soft(im.max(axis=2), BODY_LO, BODY_HI)
    muscle_a = soft(r - np.maximum(g, b), RED_LO, RED_HI) * body_a
    ys, xs = np.where(body_a > BBOX_ALPHA)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    side = int(max(x1 - x0 + 1, y1 - y0 + 1) * PAD)
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    sy0, sx0 = cy - side // 2, cx - side // 2
    for name, a in (("body", body_a), ("muscle", muscle_a)):
        canvas = np.zeros((side, side), float)
        ya, yb = max(0, sy0), min(a.shape[0], sy0 + side)
        xa, xb = max(0, sx0), min(a.shape[1], sx0 + side)
        canvas[ya - sy0:yb - sy0, xa - sx0:xb - sx0] = a[ya:yb, xa:xb]
        img = Image.new("RGBA", (side, side), (255, 255, 255, 0))
        img.putalpha(Image.fromarray((canvas * 255).astype("uint8")))
        d = f"{OUT}/{fam}-{name}.imageset"; os.makedirs(d, exist_ok=True)
        img.resize((SIZE, SIZE), Image.LANCZOS).save(f"{d}/{fam}-{name}.png")
        json.dump({"images": [{"filename": f"{fam}-{name}.png", "idiom": "universal"}],
                   "info": {"author": "xcode", "version": 1},
                   "properties": {"template-rendering-intent": "template"}},
                  open(f"{d}/Contents.json", "w"), indent=2)
    print(fam, "bbox", (int(x0), int(y0), int(x1), int(y1)), "side", side)
