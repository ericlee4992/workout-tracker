# Scanner corpus report — Sep 5, 2026 at 3:56 PM

Photos measured: 41 (12 with a catalog row, 29 without). Pipeline: `MachineLabelOCR.read` + `CatalogMatcher.rank` on the shipped catalog.

| Metric | Value |
|---|---|
| Top-1 right (of 12 in catalog) | 7 |
| Preselected right | 6 |
| **Wrong preselections** | **0** |
| Create-new suggested when the row is absent (of 29) | 28 |
| Nothing read at all | 1 |

| Photo | Expected | Read | Top (score) | Pre | Right? | Notes |
|---|---|---|---|---|---|---|
| g010.jpg | — (not in catalog) | (nothing) | — |  | new ✓ | placard small in a whole-machine shot; model not in catalog |
| g018.jpg | — (not in catalog) | SCYBEX / Thisproduct may beproduced under / Made in the U.S.A. / oneor unore of  | — |  | new ✓ | serial plate: brand + model NUMBER only, dense small text |
| g022.jpg | — (not in catalog) | CONVERGING PLATE LOADED OVERHEAD PRESS / Muscles Trained / Load appropriate resi | Life Fitness Plate Loaded Shoulder Press (59%) |  | new ✓ | placard, brand as small logo; model not in catalog |
| g035.jpg | — (not in catalog) | Thisprodact mar bepredored aader / eneormeneofthe folloer laepatents / SCYBEX /  | Cybex VR1 Chest Press (13000) (32%) |  | new ✓ | serial plate beside a PATENT PENDING sticker; model number only |
| g045.jpg | — (not in catalog) | ACAUTION / Arms move in paths / directed by user. / Incorrect path may / cause i | Life Fitness Plate Loaded Pulldown (60%) |  | new ✓ | placard close-up with warning stickers; model not in catalog |
| g058.jpg | — (not in catalog) | CYBEX INTERNATIONAL / THNS PRODUCT MAY BE 5.011-139 / Owatonna, Mn. 55060-1299 / | — |  | new ✓ | red frame, tiny dense serial label; nothing names a model |
| g068.jpg | — (not in catalog) | PLATE LOADED SQUAT PRESS / Load appropriate resistance / 5 Litlower resistance w | PRIME Fitness PLATE LOADED | Leg Press (29%) |  | new ✓ | clean placard, brand as small logo; model not in catalog |
| g069.jpg | — (not in catalog) | SCYBEX | — |  | new ✓ | LOGO ONLY on the frame |
| g072.jpg | — (not in catalog) | OLУBЕN | — |  | new ✓ | LOGO ONLY on the frame (T-bar row) |
| g077.jpg | — (not in catalog) | OCYBEX | — |  | new ✓ | LOGO ONLY on the frame |
| g094.jpg | Cybex VR3 Leg Extension (12050) | L / BENSPARK / INSTÄLLNING / AVSLUT / START / Justera ryggstödet så att knäna år | — |  | ✗ | Swedish placard: BENSPARK; brand logo; expect a miss — the English name is not on the plate |
| h013.jpg | — (not in catalog) | HAMMER / STRENGTH | — |  | new ✓ | badge: brand text only |
| h014.jpg | — (not in catalog) | HAMMER / STRENGTH / GROUND / BASE COMBO / INCLINE / Start 1 Ibs./0.45Kg. | Hammer Strength Ground Base Combo Twist (78%) |  | new ✗ | clean vertical placard; model not in catalog (Combo Twist is) |
| h031.jpg | Hammer Strength Iso-Lateral Bench Press | HAMMER / STRENGTH / ISO-LATERAL / BENCH / PRESS / Start 7 lbs./3.2Kg. / ngth.com | Hammer Strength Iso-Lateral Bench Press (100%) | yes | ✓ | vertical placard with pictograms |
| h032.jpg | — (not in catalog) | LAMMED / STRENGTH | — |  | new ✓ | badge: brand text only, angled |
| h044.jpg | Hammer Strength Iso-Lateral Front Lat Pulldown | HAMMER / STRENGTH / ISO-LATERAL / FRONT LAT / PULLDOWN / Start 1 lb./1.5Kg. / EQ | Hammer Strength Iso-Lateral Front Lat Pulldown (93%) | yes | ✓ | placard at a steep angle, small in frame |
| h045.jpg | — (not in catalog) | WUH / STRENCTH | — |  | new ✓ | badge: brand text only |
| h056.jpg | Hammer Strength Iso-Lateral Low Row | HAMMER / STRENGTH / ISO-LATERAL / LOW ROW / Start 8 Ibs./3.6Kg. / erstrength.com | Hammer Strength Iso-Lateral Low Row (100%) | yes | ✓ | vertical placard, tilted |
| h057.jpg | — (not in catalog) | HAMMER / STRENGTH | — |  | new ✓ | badge: brand text only, with a warning sticker |
| h063.jpg | Hammer Strength Iso-Lateral Row | HAMMER / STRENGTH / ISO-LATERAL / ROW / Start 12 lbs./5.4Kg. | Hammer Strength Iso-Lateral Row (100%) | yes | ✓ | vertical placard, straight on |
| h064.jpg | — (not in catalog) | YAMMER / RENGTH | — |  | new ✓ | embossed metal logo plate on the floor tube |
| h072.jpg | Hammer Strength Iso-Lateral Wide Pulldown | www.hammerstrength.com / P.EUP / HAMMER / STRENGTH / ISO-LATERAL / PULLDOWN / St | Hammer Strength Iso-Lateral Row (67%) |  | ✗ | placard at ~45°, text rotated |
| h083.jpg | — (not in catalog) | HAMMER / STRENCTH | — |  | new ✓ | etched brand on a frosted shroud, low contrast |
| h087.jpg | Hammer Strength Select Assist Dip Chin | HAMMER STRENGTH / www.hammerstrength.com / ASSIST DIPICHIN | Hammer Strength Select Assist Dip Chin (85%) | yes | ✓ | instruction placard: brand small, ASSIST DIP/CHIN large |
| h088.jpg | Hammer Strength Select Assist Dip Chin | HAMMER STRENGTH / ASSIST DIPICHIN / 2.5 / 2,5 | Hammer Strength Select Assist Dip Chin (85%) | yes | ✓ | clean nameplate: brand + name |
| h107.jpg | Hoist Hack Squat/Dead Lift/Shrug RPL-5356 | HOISI / hoistfitness.com / BRACHIT / CAUTION / LEGS I GLUTES / es wootanton / HA | Watson PL Hack Squat (37%) |  | ✗ | HOIST logo + HACK SQUAT instruction sticker with model code |
| h108.jpg | Hoist (ROC-IT) Hack Squat/Dead Lift/Shrug RPL-5356 | HACK SQUAT / SHRUG / HACK SQUAT/DEAD LIF / RPL 0056 / DEAD LIFT / ттм / ROCLT /  | Nautilus Hack Squat (61%) |  | ✗ | ROC-IT sub-brand sticker, no HOIST text, curved |
| h124.jpg | — (not in catalog) | HOS / HOIST / HOISTFITNESS.COM | — |  | new ✓ | LOGO ONLY (bench) |
| h132.jpg | — (not in catalog) | DUAL PULLEY ROW / 1. Sit on seat andposition feet firmly on foot plates with kne | Life Fitness Dual Adjustable Pulley (50%) |  | new ✓ | Pro-series placard; model not in catalog |
| h133.jpg | — (not in catalog) | LiTTes / EC | — |  | new ✓ | LOGO ONLY, script logo |
| h144.jpg | — (not in catalog) | LieFitness / UIP / ASSISTED / DIPICHIN | Life Fitness Chin/Dip/Leg Raise (61%) |  | new ✓ | Pro2 nameplate; nearest catalog row is Insignia Series Assist Dip Chin |
| q1_03.jpg | — (not in catalog) | LifeFiness / Adjust seat height so you are / Triceps / able to comfortably grip  | Life Fitness Back Extension (45%) |  | new ✓ | Pro-series placard; nearest row Insignia Series Triceps Press |
| q1_05.jpg | — (not in catalog) | LifeFilness / Adjust start position to desired range / Gluteus d / Quadriceps /  | PRIME Fitness PLATE LOADED | Leg Press (26%) |  | new ✓ | Pro-series placard; nearest row Insignia Series Seated Leg Press |
| q1_09.jpg | — (not in catalog) | FITNESS / EQUIPMENT / 215-460- / EMPIRE / .COM / FITNES / RRri / EQUIPME / EMPIR | — |  | new ✓ | LOGO ONLY on a yellow frame, dealer signage behind |
| q1_10.jpg | — (not in catalog) | ACAUTION / Moverent / vetrcied in proper / PLATE LOADED ADVANCED PULLDOWN / Load | Life Fitness Plate Loaded Pulldown (61%) |  | new ✓ | placard mid-distance; model not in catalog |
| q1_11.jpg | — (not in catalog) | SCYBEX | — |  | new ✓ | LOGO ONLY, large |
| q1_12.jpg | — (not in catalog) | FRP / FRH | — |  | new ✓ | parts-store serial label, model CODE only, watermarked |
| q1_13.jpg | Precor Vitality Leg Extension (VSL005BP) | Example Model Number / LEG EXTENSION / hwea Yealiny " Serves SetecteofEed Led /  | Life Fitness Insignia Series Leg Extension (40%) |  | ✗ | support-page photo with red annotations over the label |
| q1_15.jpg | — (not in catalog) | BAEHA | — |  | new ✓ | badge, out of focus |
| q1_16.webp | Hammer Strength Plate Loaded Tibia Dorsi-Flexion | HAMMER / STRENGTH / TIBIA / Start 3 Ibs./1.4 Kg. | Hammer Strength Plate Loaded Tibia Dorsi-Flexion (55%) |  | ✓ | plate says TIBIA only; scuffed metal |
| q1_19.png | — (not in catalog) | CAGE: / LufeFitness / OCMY5 / Class: S / Life Fitneas (Afantic) B.V. / 9525 Bryn | — |  | new ✓ | serial label, model code only (not a strength machine) |
