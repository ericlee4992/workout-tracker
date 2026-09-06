# Scanner corpus report — Sep 6, 2026 at 1:50 AM — LLM READINGS (Claude) through the app's matcher

Photos measured: 41 (12 with a catalog row, 29 without). Pipeline: Claude transcription (corpus/llm-readings.json) + `CatalogMatcher.rank` on the shipped catalog.

| Metric | Value |
|---|---|
| Top-1 right (of 12 in catalog) | 10 |
| Preselected right | 6 |
| **Wrong preselections** | **0** |
| Create-new suggested when the row is absent (of 29) | 24 |
| Nothing read at all | 1 |

| Photo | Expected | Read | Top (score) | Pre | Right? | Notes |
|---|---|---|---|---|---|---|
| g010.jpg | — (not in catalog) | (nothing) | — |  | new ✓ | placard small in a whole-machine shot; model not in catalog |
| g018.jpg | — (not in catalog) | CYBEX / MODEL # 5222-90 | — |  | new ✓ | serial plate: brand + model NUMBER only, dense small text |
| g022.jpg | — (not in catalog) | Converging Plate Loaded Overhead Press / Cybex | Cybex Eagle NX Overhead Press (52%) |  | new ✓ | placard, brand as small logo; model not in catalog |
| g035.jpg | — (not in catalog) | CYBEX / MODEL # 11000-90 | Cybex VR1 Chest Press (13000) (43%) |  | new ✓ | serial plate beside a PATENT PENDING sticker; model number only |
| g045.jpg | — (not in catalog) | PLATE LOADED ADVANCED PULLDOWN / CYBEX International | Life Fitness Plate Loaded Pulldown (42%) |  | new ✓ | placard close-up with warning stickers; model not in catalog |
| g058.jpg | — (not in catalog) | CYBEX INTERNATIONAL | — |  | new ✓ | red frame, tiny dense serial label; nothing names a model |
| g068.jpg | — (not in catalog) | PLATE LOADED SQUAT PRESS / CYBEX | Hammer Strength Plate Loaded Super Squat Press (40%) |  | new ✓ | clean placard, brand as small logo; model not in catalog |
| g069.jpg | — (not in catalog) | CYBEX | — |  | new ✓ | LOGO ONLY on the frame |
| g072.jpg | — (not in catalog) | CYBEX | — |  | new ✓ | LOGO ONLY on the frame (T-bar row) |
| g077.jpg | — (not in catalog) | CYBEX | — |  | new ✓ | LOGO ONLY on the frame |
| g094.jpg | Cybex VR3 Leg Extension (12050) | CYBEX / BENSPARK | — |  | ✗ | Swedish placard: BENSPARK; brand logo; expect a miss — the English name is not on the plate |
| h013.jpg | — (not in catalog) | HAMMER / STRENGTH | — |  | new ✓ | badge: brand text only |
| h014.jpg | — (not in catalog) | HAMMER STRENGTH / GROUND BASE COMBO INCLINE | Hammer Strength Ground Base Combo Twist (78%) |  | new ✗ | clean vertical placard; model not in catalog (Combo Twist is) |
| h031.jpg | Hammer Strength Iso-Lateral Bench Press | HAMMER STRENGTH / ISO-LATERAL BENCH PRESS | Hammer Strength Iso-Lateral Bench Press (100%) | yes | ✓ | vertical placard with pictograms |
| h032.jpg | — (not in catalog) | HAMMER STRENGTH | — |  | new ✓ | badge: brand text only, angled |
| h044.jpg | Hammer Strength Iso-Lateral Front Lat Pulldown | Hammer Strength / Iso-Lateral Front Lat Pulldown | Hammer Strength Iso-Lateral Front Lat Pulldown (100%) | yes | ✓ | placard at a steep angle, small in frame |
| h045.jpg | — (not in catalog) | HAMMER STRENGTH | — |  | new ✓ | badge: brand text only |
| h056.jpg | Hammer Strength Iso-Lateral Low Row | Hammer Strength / Iso-Lateral Low Row | Hammer Strength Iso-Lateral Low Row (100%) |  | ✓ | vertical placard, tilted |
| h057.jpg | — (not in catalog) | HAMMER STRENGTH | — |  | new ✓ | badge: brand text only, with a warning sticker |
| h063.jpg | Hammer Strength Iso-Lateral Row | HAMMER STRENGTH / ISO-LATERAL ROW | Hammer Strength Iso-Lateral Row (100%) | yes | ✓ | vertical placard, straight on |
| h064.jpg | — (not in catalog) | HAMMER / STRENGTH | — |  | new ✓ | embossed metal logo plate on the floor tube |
| h072.jpg | Hammer Strength Iso-Lateral Wide Pulldown | Hammer Strength / Iso-Lateral Wide Pulldown | Hammer Strength Iso-Lateral Wide Pulldown (100%) | yes | ✓ | placard at ~45°, text rotated |
| h083.jpg | — (not in catalog) | HAMMER STRENGTH | — |  | new ✓ | etched brand on a frosted shroud, low contrast |
| h087.jpg | Hammer Strength Select Assist Dip Chin | HAMMER STRENGTH / ASSIST DIP/CHIN | Hammer Strength Select Assist Dip Chin (85%) | yes | ✓ | instruction placard: brand small, ASSIST DIP/CHIN large |
| h088.jpg | Hammer Strength Select Assist Dip Chin | HAMMER STRENGTH / ASSIST DIP/CHIN | Hammer Strength Select Assist Dip Chin (85%) | yes | ✓ | clean nameplate: brand + name |
| h107.jpg | Hoist Hack Squat/Dead Lift/Shrug RPL-5356 | HOIST / HACK SQUAT / RPL-5356 | Hoist Hack Squat/Dead Lift/Shrug RPL-5356 (70%) |  | ✓ | HOIST logo + HACK SQUAT instruction sticker with model code |
| h108.jpg | Hoist (ROC-IT) Hack Squat/Dead Lift/Shrug RPL-5356 | ROC-IT PLATE LOADED / HACK SQUAT/DEAD LIFT | Hammer Strength Plate Loaded Hack Squat (70%) |  | ✗ | ROC-IT sub-brand sticker, no HOIST text, curved |
| h124.jpg | — (not in catalog) | HOIST / HOISTFITNESS.COM | — |  | new ✓ | LOGO ONLY (bench) |
| h132.jpg | — (not in catalog) | DUAL PULLEY ROW / Life Fitness | Life Fitness Dual Adjustable Pulley (73%) |  | new ✗ | Pro-series placard; model not in catalog |
| h133.jpg | — (not in catalog) | Life Fitness | — |  | new ✓ | LOGO ONLY, script logo |
| h144.jpg | — (not in catalog) | Life Fitness / Assisted Dip/Chin | Life Fitness Chin/Dip/Leg Raise (67%) |  | new ✓ | Pro2 nameplate; nearest catalog row is Insignia Series Assist Dip Chin |
| q1_03.jpg | — (not in catalog) | Life Fitness / Triceps Press | Life Fitness Insignia Series Triceps Press (66%) |  | new ✗ | Pro-series placard; nearest row Insignia Series Triceps Press |
| q1_05.jpg | — (not in catalog) | Life Fitness / Seated Leg Press | Life Fitness Insignia Series Seated Leg Press (69%) |  | new ✗ | Pro-series placard; nearest row Insignia Series Seated Leg Press |
| q1_09.jpg | — (not in catalog) | CYBEX | — |  | new ✓ | LOGO ONLY on a yellow frame, dealer signage behind |
| q1_10.jpg | — (not in catalog) | PLATE LOADED ADVANCED PULLDOWN / CYBEX International | Life Fitness Plate Loaded Pulldown (42%) |  | new ✓ | placard mid-distance; model not in catalog |
| q1_11.jpg | — (not in catalog) | CYBEX | — |  | new ✓ | LOGO ONLY, large |
| q1_12.jpg | — (not in catalog) | HAMMER STRENGTH / Model: PLSM | — |  | new ✓ | parts-store serial label, model CODE only, watermarked |
| q1_13.jpg | Precor Vitality Leg Extension (VSL005BP) | LEG EXTENSION / Precor Vitality™ Series Selectorized Line | Precor Vitality Leg Extension (VSL005BP) (58%) |  | ✓ | support-page photo with red annotations over the label |
| q1_15.jpg | — (not in catalog) | STRENGTH | Technogym Pure Strength Row (44%) |  | new ✗ | badge, out of focus |
| q1_16.webp | Hammer Strength Plate Loaded Tibia Dorsi-Flexion | HAMMER STRENGTH / TIBIA | Hammer Strength Plate Loaded Tibia Dorsi-Flexion (55%) |  | ✓ | plate says TIBIA only; scuffed metal |
| q1_19.png | — (not in catalog) | Life Fitness / Model: / LCM-CC.WHT.ENG.LB.NON | — |  | new ✓ | serial label, model code only (not a strength machine) |
