# Codex muscle-family icons

Five original anatomical silhouettes made with the built-in image-generation tool, each exported at **1024 × 1024**: `chest.png`, `back.png`, `shoulders.png`, `arms.png`, `legs.png`. Shared treatment: heavy filled masses, rounded anatomical contours, no equipment, no exercise figures, no decorative muscle lines. The exact generation and refinement prompts are recorded in `generation.json`; no particular model version is claimed because the tool does not expose one.

**Background limitation:** transparent generation produced speckled edges and halos, so the final set uses the brief's permitted **white glyph on solid black** fallback. These are opaque RGB PNGs, not ready-to-import alpha template masks. Generated pixels have slight near-white and near-black raster variation rather than mathematically uniform fills. The tool returned 1254 × 1254 images despite the requested size; exports were resampled to 1024 × 1024 without redrawing the shapes. Before app integration, normalize the black/white levels, convert luminance to alpha and use white RGB. The previews demonstrate that treatment only; the five supplied assets retain their black backgrounds.

## Proposed colours and measured contrast

The glyph uses its family colour at 100%; its tile uses that same colour at 14% over the base. All five pass **4.5:1**. None uses the action amber `#FFB45E`; shoulders move to turquoise to avoid the amber/warmup-yellow region. These are fixed family assignments, not a rotating decorative palette.

| Family | Glyph hex | 14% tile over #151A21 | Contrast | Contrast on actual card #171B21 |
|---|---|---|---|---|
| Chest | #FF70B6 | #362636 | 5.55:1 | 5.47:1 |
| Back | #4EB9FF | #1D3040 | 6.25:1 | 6.17:1 |
| Shoulders | #4DE0D4 | #1D363A | 7.91:1 | 7.80:1 |
| Arms | #B891FF | #2C2B40 | 5.61:1 | 5.54:1 |
| Legs | #84D65A | #253429 | 7.32:1 | 7.22:1 |

Measurement: composite each encoded sRGB channel as `tile = 0.14 × glyph + 0.86 × base`; normalize channels to 0–1; linearize with `c/12.92` when `c ≤ 0.04045`, otherwise `((c + 0.055)/1.055)^2.4`; compute `L = 0.2126R + 0.7152G + 0.0722B`; contrast is `(L_glyph + 0.05)/(L_tile + 0.05)`. Ratios use unrounded composited channels; displayed tile hex values are rounded to eight-bit channels. Full precision results are in `contrast.json`. Contrast applies to the fully covered glyph interiors, not partially covered antialiased boundary pixels.

## Five lines of reasoning

1. **Chest:** paired broad pecs and an open sternum gap make the anatomy explicit; vivid pink separates the family from the app's coral-red Danger token.
2. **Back:** lat wings narrow into a waist, making the V-taper the identifying contour; saturated sky blue keeps continuity with the existing back assignment.
3. **Shoulders:** two thick deltoid caps isolate the shoulder muscles with a generous central opening; turquoise distinguishes them from chest and the app's warm status colours.
4. **Arms:** a closed fist, bent forearm and oversized bicep form one compact, immediately familiar silhouette; vivid violet strengthens the existing purple family cue.
5. **Legs:** a convex outer quad and narrow knee stump describe an upper leg without a full figure; fresh green preserves the existing leg cue with greater saturation.

## Preview and inspection

`contact-sheet.png` is one row in Chest, Back, Shoulders, Arms, Legs order on the actual `SurfaceCard` asset colour **#171B21**. It is rendered at **3 pixels per point**: 1200 × 264 pixels represents 400 × 88 pt, each tile is 40 pt, and each visible glyph fits a 23⅓ pt square. View at 400 logical pixels wide for the intended scale. `size-check-24pt.png` uses 24 pt tiles and 14 pt glyph bounds at the same 3× scale. Both were visually inspected: chest and shoulder separations remain open, and the back, flexed arm and quad retain distinct contours. This is a raster size check, not an on-device recognition study.

`compose.py` reproduces the previews with Pillow, using generated image luminance as the compositing mask and preserving aspect ratios. Labels are presentation annotations, not proposed app copy. No app source files were changed; no build or simulator commands were run.
