"""Compose the requested preview; does not modify the five generated glyph assets."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).parent
ROWS = json.loads((ROOT / 'contrast.json').read_text())
SCALE = 3
CARD = '#171B21'
FONT = '/System/Library/Fonts/SFNS.ttf'

def render(tile_side, glyph_side, filename):
    canvas = Image.new('RGB', (400 * SCALE, 88 * SCALE), CARD)
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(FONT, 11 * SCALE)
    for i, row in enumerate(ROWS):
        center = (40 + i * 80) * SCALE
        top = 12 * SCALE
        side = tile_side * SCALE
        left = center - side // 2
        draw.rounded_rectangle((left, top, left+side-1, top+side-1),
                               radius=(14 if tile_side == 40 else 8)*SCALE,
                               fill=row[CARD]['tileHex'])
        # White-on-black fallback: use luminance as coverage for this preview only.
        mask = Image.open(ROOT / (row['family']+'.png')).convert('L')
        bounds = mask.point(lambda p: 255 if p > 128 else 0).getbbox()
        mask = mask.crop(bounds)
        mask.thumbnail((round(glyph_side*SCALE), round(glyph_side*SCALE)), Image.Resampling.LANCZOS)
        canvas.paste(row['hex'], (center-mask.width//2, top+(side-mask.height)//2), mask)
        draw.text((center, top+side+8*SCALE), row['family'].title(),
                  fill='#F6F3EC', font=font, anchor='mt')
    canvas.save(ROOT / filename)

render(40, 40*14/24, 'contact-sheet.png')
render(24, 14, 'size-check-24pt.png')
