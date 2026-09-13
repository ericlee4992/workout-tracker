"""Compose two-layer previews with Pillow; keep generated source colours intact."""
from collections import Counter
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).parent
FAMILIES = {'chest': '#FF70B6', 'back': '#4EB9FF', 'shoulders': '#4DE0D4',
            'arms': '#B891FF', 'legs': '#84D65A'}
PALETTE = ((0, 0, 0), (128, 128, 128), (255, 0, 0))
SCALE = 3

def layers(im):
    # Approximate generated colours are classified only for the tinted preview.
    labels = []
    for r, g, b in im.getdata():
        distances = [(r-pr)**2 + (g-pg)**2 + (b-pb)**2 for pr, pg, pb in PALETTE]
        labels.append(min(range(3), key=distances.__getitem__))
    masks = []
    for label in (1, 2):
        mask = Image.new('L', im.size)
        mask.putdata([255 if v == label else 0 for v in labels])
        masks.append(mask)
    return masks

def render(size, filename):
    canvas = Image.new('RGB', (400*SCALE, 104*SCALE), '#171B21')
    draw = ImageDraw.Draw(canvas)
    small = ImageFont.truetype('/System/Library/Fonts/SFNS.ttf', 9*SCALE)
    label = ImageFont.truetype('/System/Library/Fonts/SFNS.ttf', 11*SCALE)
    draw.text((200*SCALE, 8*SCALE), f'MUSCLE MAPS  /  {size} PT  /  3×',
              font=small, fill='#A0A8B5', anchor='mt')
    for i, family in enumerate(FAMILIES):
        center = (40+i*80)*SCALE
        side = size*SCALE
        top = 29*SCALE + (40*SCALE-side)//2
        for mask, colour in zip(MASKS[family], ('#5B6472', FAMILIES[family])):
            mask = mask.resize((side, side), Image.Resampling.LANCZOS)
            canvas.paste(colour, (center-side//2, top), mask)
        draw.text((center, 77*SCALE), family.title(), font=label,
                  fill='#F6F3EC', anchor='mt')
    canvas.save(ROOT / filename)

MASKS = {}
report = {}
for family in FAMILIES:
    im = Image.open(ROOT / f'{family}.png').convert('RGB')
    assert im.size == (1024, 1024), (family, im.size)
    counts = Counter(im.getdata())
    MASKS[family] = layers(im)
    body, muscle = MASKS[family]
    union = Image.frombytes('L', im.size, bytes(max(a, b) for a, b in zip(body.tobytes(), muscle.tobytes())))
    report[family] = {'size': im.size, 'uniqueColours': len(counts),
                      'exactPalettePercent': round(100*sum(counts[c] for c in PALETTE)/(1024*1024), 2),
                      'mostCommon': counts.most_common(5), 'bodyBounds': union.getbbox(),
                      'previewMuscleColour': FAMILIES[family]}
render(40, 'contact-sheet.png')
render(24, 'size-check-24pt.png')
(ROOT / 'validation.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report, indent=2))
