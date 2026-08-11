# Strength Equipment Model Names — Group 2

Manufacturers: Technogym, Matrix Fitness, Gym80, Panatta, Watson Gym Equipment, Eleiko, BH Fitness.

**Method note:** Every model below was read from a manufacturer product listing (usually the
structured product data embedded in the manufacturer's own category page), a manufacturer
country-site range page, or — for Panatta only — an authorised dealer's line-by-line catalogue
carrying Panatta's own SKU codes. Nothing here was extrapolated from a naming pattern. Where a
line exists but I could not enumerate its members, it is listed under Notes rather than guessed at.

Cardio products were dropped even where they appeared in the same listing (e.g. Artis Run/Bike/Climb).

---

## Technogym

Source(s):
- https://www.technogym.com/en-US/category/selection-900/
- https://www.technogym.com/en-US/category/selection-700/
- https://www.technogym.com/en-US/category/selectorized-strength-machines/
- https://www.technogym.com/en-US/category/plate-loaded/
- https://www.technogym.com/en-US/category/artis/
- https://www.technogym.com/en-US/product/kinesis-one_M5800.html
- https://www.technogym.com/en-US/product/kinesis-personal_MD05.html

All Selection / Artis / Pure Strength names below were taken from the `"name"` fields of the
structured product data embedded in Technogym's own category pages, and cross-checked against the
product-URL slugs on the same pages.

### Selection 900 (selectorized)
- Selection 900 Chest Press — chest press
- Selection 900 Pectoral — pec deck / chest fly
- Selection 900 Shoulder Press — shoulder press
- Selection 900 Delts Machine — lateral raise / deltoid
- Selection 900 Lat Machine — lat pulldown
- Selection 900 Vertical Traction — vertical pulldown (chest-supported)
- Selection 900 Pulldown — lat pulldown
- Selection 900 Low Row — seated row
- Selection 900 Pulley — cable pulley / seated row
- Selection 900 Arm Curl — biceps curl
- Selection 900 Arm Extension — triceps extension
- Selection 900 Leg Press — leg press
- Selection 900 Leg Extension — leg extension
- Selection 900 Leg Curl — leg curl (seated)
- Selection 900 Prone Leg Curl — lying / prone leg curl
- Selection 900 Adductor — leg adduction
- Selection 900 Standing Calf — standing calf raise
- Selection 900 Glute Press — glute kickback / hip extension
- Selection 900 Hip Thrust — hip thrust
- Selection 900 Multi Flight — multi-exercise (see note)
- Selection 900 Abdominal Crunch — abdominal crunch
- Selection 900 Total Abdominal — abdominal crunch (multi-position)
- Selection 900 Rotary Torso — torso rotation
- Selection 900 Lower Back — back extension

**Multi-exercise station:** `Selection 900 Multi Flight` is a multi-movement station (Technogym
markets it as a multi-flight/standing multi-exercise unit). Flag it as multi-exercise; I did not
find an authoritative enumeration of its individual movements.

### Selection 700 (selectorized; several are dual-function)
- Selection 700 Chest Press — chest press
- Selection 700 Shoulder Press — shoulder press
- Selection 700 Delts Machine — lateral raise / deltoid
- Selection 700 Lat Machine — lat pulldown
- Selection 700 Vertical Traction — vertical pulldown (chest-supported)
- Selection 700 Low Row — seated row
- Selection 700 Leg Press — leg press
- Selection 700 Leg Extension — leg extension
- Selection 700 Leg Curl — leg curl
- Selection 700 Multi Hip — multi-hip (hip flexion/extension/abduction)
- Selection 700 Abdominal Crunch — abdominal crunch
- Selection 700 Lower Back — back extension
- **Selection 700 Dual Leg Curl / Extension** — leg extension + leg curl (MULTI-EXERCISE, dual)
- **Selection 700 Dual Abductor / Adductor** — leg abduction + leg adduction (MULTI-EXERCISE, dual)
- **Selection 700 Dual Pectoral / Reverse Fly** — chest fly + reverse fly (MULTI-EXERCISE, dual)

Note the "/" is part of Technogym's own product name for the three Dual machines.

### Artis (selectorized)
- Artis Chest Press — chest press
- Artis Pectoral — pec deck / chest fly
- Artis Shoulder Press — shoulder press
- Artis Lat Machine — lat pulldown
- Artis Vertical Traction — vertical pulldown (chest-supported)
- Artis Low Row — seated row
- Artis Rear Delt Row — rear delt row
- Artis Arm Curl — biceps curl
- Artis Arm Extension — triceps extension
- Artis Leg Press — leg press
- Artis Leg Extension — leg extension
- Artis Leg Curl — leg curl
- Artis Squat — squat machine
- Artis Abductor — leg abduction
- Artis Adductor — leg adduction
- Artis Multi Hip — multi-hip (MULTI-EXERCISE)
- Artis Total Abdominal — abdominal crunch
- Artis Rotary Torso — torso rotation
- Artis Lower Back — back extension

### Pure Strength (plate-loaded)
- Pure Strength Chest Press — chest press
- Pure Strength Wide Chest Press — chest press (wide grip)
- Pure Strength Incline Chest Press — incline chest press
- Pure Strength Shoulder Press — shoulder press
- Pure Strength Pulldown — lat pulldown
- Pure Strength Row — row
- Pure Strength Low Row — seated low row
- Pure Strength Pullover — pullover
- Pure Strength Biceps — biceps curl
- Pure Strength Seated Dip — triceps dip
- Pure Strength Leg Press — leg press
- Pure Strength Linear Leg Press — linear leg press
- Pure Strength Leg Extension — leg extension
- Pure Strength Standing Leg Curl — standing leg curl
- Pure Strength Hack Squat — hack squat
- Pure Strength Belt Squat — belt squat
- Pure Strength Deadlift — deadlift
- Pure Strength Hip Thrust — hip thrust
- Pure Strength Rear Kick — glute kickback
- Pure Strength Standing Abductor — standing leg abduction
- Pure Strength Calf — calf raise
- Pure Strength Seated Calf — seated calf raise

### Kinesis (cable / functional)
- Kinesis One — cable functional trainer (MULTI-EXERCISE)
- Kinesis Personal — wall-mounted cable functional trainer (MULTI-EXERCISE)

Notes:
- Technogym's site returns HTTP 403 to plain fetchers; I retrieved pages with a browser user-agent
  and read the embedded structured product data, so these names are Technogym's canonical strings.
- **"Selection 900 Abductor" does NOT appear** as a product. Selection 900 lists an Adductor only.
  The word "abductor" appears in page prose but there is no product entry or product URL for it.
  Do not add a Selection 900 Abductor by symmetry with the Adductor.
- **"Artis Triceps" appears in marketing prose but is NOT a product entry.** The Artis triceps
  machine is `Artis Arm Extension`. Omitted deliberately.
- Technogym also markets a "Selection Pro" line — this is the previous generation, now superseded
  on the site by Selection 900 / Selection 700. Second-hand dealers list e.g. "Selection Pro Chest
  Press", "Selection Pro Leg Extension", "Selection Pro Shoulder Press", "Selection Pro Seated Leg
  Press". Because I could only confirm these on resellers and not on a current Technogym listing, I
  have not enumerated the Selection Pro line here. It is real and still common in gyms — worth
  covering, but needs its own verification pass against an archived Technogym catalogue.
- The Pure Strength category page also carries benches (Olympic Flat/Incline/Decline/Military
  Bench, Adjustable Bench, Flat Bench, Lower Back Bench, T-Bar Row). Excluded as benches, except
  T-Bar Row which is a machine but which I could not confirm carries the "Pure Strength" prefix.

---

## Matrix Fitness

Source(s):
- https://us.matrixfitness.com/sitemap.xml (complete product URL set)
- https://us.matrixfitness.com/eng/strength/single-station/g7-s78-glute
- https://us.matrixfitness.com/eng/strength/single-station/g3-s30-lat-pulldown
- https://us.matrixfitness.com/eng/strength/multi-station/mg-921-lat-pulldown

Matrix's site is a JavaScript app, but its sitemap enumerates every product with a slug of the form
`<model-code>-<product-name>`. The series↔prefix mapping below was confirmed against live product
page titles (which render as "Glute | Ultra | Single-Station", "Lat Pulldown | Aura | Single-Station",
"Lat Pulldown | Magnum | Multi-Station").

| Prefix | Series |
|---|---|
| G3 | Aura |
| G7 | Ultra |
| VS | Versa |
| MG | Magnum |
| GO | Go |
| VY | Varsity |

### Ultra Series — G7 (selectorized)
- G7-S13 Converging Chest Press — chest press
- G7-S22 Pectoral Fly — pec deck / chest fly
- G7-S23 Converging Shoulder Press — shoulder press
- G7-S21 Lateral Raise — lateral raise
- G7-S33 Diverging Lat Pulldown — lat pulldown
- G7-S34 Diverging Seated Row — seated row
- G7-S40 Independent Biceps Curl — biceps curl
- G7-S41 Dependent Arm Curl — biceps curl
- G7-S42 Triceps Press — triceps press
- G7-S45 Triceps Extension — triceps extension
- G7-S51 Abdominal Crunch — abdominal crunch
- G7-S52 Back Extension — back extension
- G7-S55 Rotary Torso — torso rotation
- G7-S70 Leg Press — leg press
- G7-S71 Leg Extension — leg extension
- G7-S72 Seated Leg Curl — seated leg curl
- G7-S73 Prone Leg Curl — lying / prone leg curl
- G7-S74 Hip Adduction — leg adduction
- G7-S75 Hip Abduction — leg abduction
- G7-S77 Calf Extension — calf raise
- G7-S78 Glute — glute kickback / hip extension
- G7-S79 Hip Thrust — hip thrust

**Trim variant caveat:** every G7 model above also exists with a `B` suffix (G7-S13B, G7-S79B, …),
sold as "Ultra Base Trim". Same machine, same exercise, different upholstery/trim package. Treat the
B variants as the same catalog entry unless you want trim-level granularity.

### Aura Series — G3 (selectorized)
- G3-S10 Chest Press — chest press
- G3-S13 Converging Chest Press — chest press
- G3-S12 Pectoral Fly — pec deck / chest fly
- G3-S20 Shoulder Press — shoulder press
- G3-S23 Converging Shoulder Press — shoulder press
- G3-S21 Lateral Raise — lateral raise
- G3-S22 Rear Delt Fly — rear delt fly
- G3-S30 Lat Pulldown — lat pulldown
- G3-S33 Diverging Lat Pulldown — lat pulldown
- G3-S31 Seated Row — seated row
- G3-S34 Diverging Seated Row — seated row
- G3-S40 Arm Curl — biceps curl
- G3-S42 Triceps Press — triceps press
- G3-S45 Triceps Extension — triceps extension
- G3-S51 Abdominal Crunch — abdominal crunch
- G3-S52 Back Extension — back extension
- G3-S55 Rotary Torso — torso rotation
- G3-S60 Dip/Chin Assist — assisted dip & pull-up (MULTI-EXERCISE)
- G3-S70 Leg Press — leg press
- G3-S71 Leg Extension — leg extension
- G3-S72 Seated Leg Curl — seated leg curl
- G3-S73 Prone Leg Curl — lying / prone leg curl
- G3-S74 Hip Adductor — leg adduction
- G3-S75 Hip Abductor — leg abduction
- G3-S76 Rotary Hip — multi-hip (MULTI-EXERCISE)
- G3-S77 Calf Press — calf raise

### Versa Series — VS (selectorized; many are dual-function)
- VS-S13 Converging Chest Press — chest press
- VS-S22 Pectoral Fly / Rear Delt — chest fly + rear delt fly (MULTI-EXERCISE)
- VS-S23 Converging Shoulder Press — shoulder press
- VS-S33 Diverging Lat Pulldown — lat pulldown
- VS-S34 Diverging Seated Row — seated row
- VS-S40 Biceps Curl — biceps curl
- VS-S42 Triceps Press — triceps press
- VS-S52 Back Extension — back extension
- VS-S53 Abdominal — abdominal crunch
- VS-S71 Leg Extension — leg extension
- VS-S72 Seated Leg Curl — seated leg curl
- VS-S78 Glute — glute kickback / hip extension
- VS-S131 Multi-Press — chest press + shoulder press (MULTI-EXERCISE)
- VS-S331 Lat Pulldown / Seated Row — lat pulldown + seated row (MULTI-EXERCISE)
- VS-S401 Bicep / Tricep — biceps curl + triceps (MULTI-EXERCISE)
- VS-S531 Abdominal / Back Extension — abdominal crunch + back extension (MULTI-EXERCISE)
- VS-S601 Chin/Dip Assist — assisted dip & pull-up (MULTI-EXERCISE)
- VS-S70 Leg Press / Calf Press — leg press + calf raise (MULTI-EXERCISE)
- VS-S711 Leg Extension / Seated Leg Curl — leg extension + leg curl (MULTI-EXERCISE)
- VS-S74 Hip Abductor / Adductor — leg abduction + leg adduction (MULTI-EXERCISE)
- VS-VFT Functional Trainer 18 — cable functional trainer (MULTI-EXERCISE)
- VS-VFT Functional Trainer 30 — cable functional trainer (MULTI-EXERCISE)

### Go Series — GO (selectorized)
- GO-S13 Chest Press — chest press
- GO-S23 Shoulder Press — shoulder press
- GO-S33 Lat Pulldown — lat pulldown
- GO-S34 Seated Row — seated row
- GO-S40 Biceps Curl — biceps curl
- GO-S42 Seated Triceps Press — triceps press
- GO-S53 Abdominal — abdominal crunch
- GO-S70 Leg Press — leg press
- GO-S71 Leg Extension — leg extension
- GO-S72 Seated Leg Curl — seated leg curl
- GO-FT Functional Trainer — cable functional trainer (MULTI-EXERCISE)

### Magnum Series — MG, plate-loaded
- MG-PL12 Vertical Bench Press — chest press (vertical)
- MG-PL13 Supine Bench Press — bench press
- MG-PL14 Incline Bench Press — incline chest press
- MG-PL15 Vertical Decline Bench Press — decline chest press
- MG-PL23 Shoulder Press — shoulder press
- MG-PL33 Lat Pulldown — lat pulldown
- MG-PL34 Seated Row — seated row
- MG-PL35 T-Bar Row — T-bar row
- MG-PL36 Lever Row — row
- MG-PL37 High Row — high row
- MG-PL38 Low Row — low row
- MG-PL41 Elevated Biceps Curl — biceps curl
- MG-PL50 Ab Crunch Bench — abdominal crunch
- MG-PL62 Smith Machine — Smith machine
- MG-PL70 45 Degree Leg Press — leg press
- MG-PL71 Hack Squat — hack squat
- MG-PL72 Kneeling Leg Curl — kneeling leg curl
- MG-PL73 Reclining Leg Extension — leg extension
- MG-PL76 Standing Calf — standing calf raise
- MG-PL77 Seated Calf — seated calf raise
- MG-PL78 Glute Trainer — glute kickback / hip extension
- MG-PL79 Squat Lunge — squat / lunge
- MG-PL80 Pendulum Squat — pendulum squat
- MG-PL81 Belt Squat — belt squat
- MG-PL82 Standing Hip Thrust — hip thrust (standing)
- MG-405 Reverse Back Extension — reverse hyperextension

### Magnum Series — MG, multi-station / cable
- MG-921 Lat Pulldown — lat pulldown
- MG-923 Adjustable Pulley — adjustable cable pulley (MULTI-EXERCISE)
- MG-924 Adjustable Crossover — cable crossover (MULTI-EXERCISE)
- MG-926 Low Row — low row
- MG-942 Triceps Pushdown — triceps pushdown
- MG-946 Lat Pulldown / Low Row — lat pulldown + low row (MULTI-EXERCISE)

### Magnum Series — MG, racks & Smith
- MG-MX47 Power Rack — power rack
- MG-MX690 Half Rack — half rack
- MG-MX691 Double Half Rack — half rack (double)
- MG-MX47691 Combo Power Half Rack — combo rack
- MG-PRO47 Pro Power Rack — power rack
- MG-PRO47C Pro Conf Power Rack — power rack (configurable)
- MG-PRO690 Pro Half Rack — half rack
- MG-PRO690EX Pro XL Half Rack — half rack
- MG-PRO691 Pro Double Half Rack — half rack (double)
- MG-PRO691C Pro Conf Double Half Rack — half rack (configurable)

### Varsity Series — VY (plate-loaded)
- VY-400 Perfect Squat — squat machine
- VY-401 Leg Extension — leg extension
- VY-402 Prone Leg Curl — lying / prone leg curl
- VY-431 Biceps Curl — biceps curl
- VY-432 Triceps Extension — triceps extension
- VY-M49-02 Angled Smith Machine — Smith machine
- G1-FW161 Smith Machine (Varsity) — Smith machine

### Other multi-station / functional (selectorized cable)
- G1-MG30 3-Stack Multi-Gym — multi-station gym (MULTI-EXERCISE)
- G3-MS20 Adjustable Cable Crossover — cable crossover (MULTI-EXERCISE)
- G3-MS40P 4-Stack — multi-station gym (MULTI-EXERCISE)
- G3-MS50P 5-Stack — multi-station gym (MULTI-EXERCISE)
- G3-MS80P 8-Stack — multi-station gym (MULTI-EXERCISE)
- G3-MSFT3 Functional Trainer — cable functional trainer (MULTI-EXERCISE)

Notes:
- There is also a small `MD-` prefixed group (MD-S70 Leg Press, MD-S711 Leg Extension/Leg Curl,
  MD-AP Adjustable Pulley, MD-FW52 MI Back Trainer). **I could not confirm which Matrix series the
  MD prefix denotes**, so I have not filed them under a line. The model codes themselves are real
  (they come straight from Matrix's sitemap); only the series label is uncertain.
- Matrix's `xult` / `MX-` items in Free Weights are racks and storage (XULT line), not exercise
  machines — excluded.
- Matrix formats these on its own site as "Chest Press | Aura | Single-Station" — i.e. exercise
  name and series are separate fields. I have rendered them as `<code> <exercise>` which matches how
  dealers and gym floors label them; adjust to `Aura G3-S10 Chest Press` if you prefer series-first.

---

## Gym80

Source(s):
- https://www.gym80.co.uk/product-ranges/sygnum
- https://www.gym80.co.uk/product-ranges/sygnum-dual
- https://www.gym80.co.uk/product-ranges/sygnum-combo
- https://www.gym80.co.uk/product-ranges/sygnum-cable-art
- https://www.gym80.co.uk/product-ranges/sygnum-stations
- https://www.gym80.co.uk/product-ranges/sygnum-basic
- https://www.gym80.co.uk/product-ranges/pure-kraft
- https://gym80.us/products/pure-kraft/pure-kraft-strong/

Gym80 identifies every machine by a 4-digit part number plus a descriptive name. Both are given.

### Sygnum (selectorized / pin-loaded)
- 3016 Seated Chest Press — chest press
- 3023 Incline Chest Press — incline chest press
- 3097 Inner Chest Press — chest press (inner)
- 3022 Butterfly — pec deck / chest fly
- 3021 Butterfly with Pads — pec deck / chest fly
- 3025 Butterfly Reverse — reverse fly / rear delt
- 3014 Chest Crossover Machine — cable crossover
- 3121 Standing Chest Crossover Machine — standing cable crossover
- 3032 Shoulder Press — shoulder press
- 3050 Shoulder Lateral Raise with Grips — lateral raise
- 3099 Standing Shoulder Lateral Raise — lateral raise (standing)
- 3096 Neck Press — neck / shoulder press
- 3020 Lat Pulldown Machine — lat pulldown
- 3047 ISO Lat — lat pulldown (independent)
- 3040 Seated Row Machine — seated row
- 3039 Seated Row Without Chest Support — seated row
- 3012 Pull Over Machine — pullover
- 3012N Pull Over Machine — pullover
- 3010 Biceps Machine — biceps curl
- 3098 Biceps Horizontal — biceps curl (horizontal)
- 3071 Forearms Machine — forearm / wrist curl
- 3011 Triceps Extension — triceps extension
- 3095 Triceps Overhead — overhead triceps extension
- 3036 Dip Machine — triceps dip
- 3017 Kneeling/Chinning-Dipping Machine — assisted pull-up & dip (MULTI-EXERCISE)
- 3001 Leg Extension — leg extension
- 3123 Lying Leg Extension with Adjustable Backrest — leg extension (lying)
- 3002 Lying Leg Curl — lying leg curl
- 3003 Seated Leg Curl — seated leg curl
- 3013 Standing Leg Curl — standing leg curl
- 3030 Seated Leg Press — leg press
- 3031 Lying Leg Press — leg press (lying)
- 3028 Abduction Machine — leg abduction
- 3029 Adduction Machine — leg adduction
- 3069 Standing Abduction — leg abduction (standing)
- 3006 Total Hip Machine — multi-hip (MULTI-EXERCISE)
- 3004 Kneeling Glutes Kick — glute kickback
- 3005 Radial Glutes Kick — glute kickback
- 4416 Bootymizer — glute / hip thrust
- 3018 Standing Calf Raise Machine — standing calf raise
- 3027 Seated Calf Press — seated calf raise
- 3094 Donkey Calf Raise — donkey calf raise
- 3008 Abdominal Machine — abdominal crunch
- 3034 Lying Abdominal Machine — abdominal crunch (lying)
- 3037 Special Abdominal Machine — abdominal crunch
- 3124 Crunch Machine — abdominal crunch
- 3225 Twister Machine — torso rotation
- 3007 Lower Back Machine — back extension
- 4900 Incline Row Combo — incline row
- 4116 Lat Pull Station — lat pulldown
- 4016 Rowing Station — seated row

### Sygnum Innovation (selectorized sub-line)
- 5001 Innovation Leg Press — leg press
- 5002 Innovation Glutes Machine — glute / hip extension
- 5003 Innovation Rower Machine — seated row
- 5004 Innovation Curler Machine — biceps curl
- 5006 Innovation Multi Extension Machine — multi-exercise extension (MULTI-EXERCISE)

### Sygnum Dual (selectorized, dual/independent arms)
- 3041 Dual Chest Press — chest press
- 3042 Dual Incline Chest Press — incline chest press
- 3043 Dual Incline Shoulder Press — shoulder press
- 3044 Dual Lat Pulldown — lat pulldown
- 3045 Dual Seated Row — seated row
- 3046 Dual Leg Press — leg press
- 4401 Deadlift Machine — deadlift
- 4402 Shoulder & Chest Press — shoulder press + chest press (MULTI-EXERCISE)
- 4403 Push & Pull Machine — press + row (MULTI-EXERCISE)

### Sygnum Combo (selectorized, two exercises per machine — ALL MULTI-EXERCISE)
- 5011 Abduction and Adduction Combo — leg abduction + leg adduction
- 5012 Abdominal and Back Combo — abdominal crunch + back extension
- 5013 Leg Curl and Leg Extension Combo — leg curl + leg extension
- 5014 Butterfly and Butterfly Reverse Combo — chest fly + reverse fly
- 5015 Shoulder and Lat Pull Combo — shoulder press + lat pulldown

### Sygnum Cable Art (cable — ALL MULTI-EXERCISE)
- 5101 Cable Art No. 1 – Shoulder & Back
- 5102 Cable Art No. 2 – Latisimus & Trapecius *(Gym80's own spelling)*
- 5103 Cable Art No. 3 – Chest & Shoulder
- 5104 Cable Art No. 4 – Biceps & Triceps
- 5105 Cable Art No. 5 – Upper Body
- 5106 Cable Art No. 6 – Legs

### Sygnum Stations (cable / multi-station)
- 4004 Crossover Cable Station — cable crossover (MULTI-EXERCISE)
- 4012 Adjustable Cable Crossover Station — cable crossover (MULTI-EXERCISE)
- 4034 Dual Adjustable Pulley — cable pulley (MULTI-EXERCISE)
- 4042 Adjustable V-Station — cable station (MULTI-EXERCISE)
- 4033 Duplex Station — cable station (MULTI-EXERCISE)
- 4032 Beltpulley 4-Station Tower — multi-station gym (MULTI-EXERCISE)
- 4044 5-Station Tower — multi-station gym (MULTI-EXERCISE)
- 4117 5 Station Tower — multi-station gym (MULTI-EXERCISE)
- 4170 8-Station Tower — multi-station gym (MULTI-EXERCISE)
- 4036 Multipress Station — Smith / multi-press
- 4125 Pulley Explosive — cable pulley
- 4134 Pulley Universal — cable pulley
- 5201 Multi-Power Station — Smith / power station (MULTI-EXERCISE)
- 5242 Multi-Power Station Privategym — Smith / power station (MULTI-EXERCISE)

### Sygnum Basic (racks, benches, bodyweight stations)
- 4002 Basic Multi Press Station — Smith / multi-press
- 4019 Standing Scott Curl — preacher curl (standing)
- 4093 Basic Seated Scott Curl — preacher curl (seated)
- 4021 Basic Dip Station — dip
- 4031 Basic Abdominal Flexor with Chinning Bar — abdominal / chin-up (MULTI-EXERCISE)
- 4046 Basic Abdominal Flexor — abdominal
- 4119 Basic 45-Back Extension — back extension
- 4165 Basic Roman Chair Adjustable — back extension
- 4040 Basic Max Rack — rack
- 4094 Basic Squat Rack — squat rack
- 4156 Multi Rack Station with Chin-Up Bar — rack (MULTI-EXERCISE)
- 5221 Half Rack — half rack
- 5226 Half Rack Platform — half rack
- 5233 Homerack — rack
- 4680 Basic One Leg Stand — single-leg stand
- 4922 Basic Step — step

### Pure Kraft (plate-loaded)
- 4328 Seated Chest Press Dual — chest press
- 4331 Bench Press Dual — bench press
- 4329N Incline Chest Press Dual — incline chest press
- 4346 Decline Chest Press Dual — decline chest press
- 4376 Lying Inner Chest Dual — chest fly (lying)
- 4341 Chest Butterfly Dual — pec deck / chest fly
- 4344 Butterfly Reverse Dual — reverse fly / rear delt
- 4326 Chest Crossover Dual — cable crossover
- 4320 Shoulder Press Dual — shoulder press
- 4325 Shoulder Lateral Raise Dual — lateral raise
- 4385 Standing Shoulder Lateral Raise — lateral raise (standing)
- 4388 Viking Press — viking / neutral-grip press
- 4371 Neck Press — neck / shoulder press
- 4311 Lat Pulldown Dual — lat pulldown
- 4322 Seated Row Dual — seated row
- 4340 High Row Dual — high row
- 4319 Low Row — low row
- 4327 Power Row Dual — row
- 4318 Bent Over Row — bent-over row
- 4383 55 Degree Rowing Machine — chest-supported row
- 4018 T-Bar Row — T-bar row
- 4350 Pullover — pullover
- 4338 Biceps Curl — biceps curl
- 4355 Biceps Curl Dual — biceps curl
- 4366 Biceps Overhead — overhead biceps curl
- 4339 Triceps Extension — triceps extension
- 4379 Overhead Triceps — overhead triceps extension
- 4335 Triceps Dip Dual — triceps dip
- 4372 Standing Multi-Joint — multi-joint press (MULTI-EXERCISE)
- 4336 Leg Extension — leg extension
- 4337 Lying Leg Curl — lying leg curl
- 4373 Standing Leg Curl — standing leg curl
- 4375 Inverse Leg Curl — inverse / nordic leg curl
- 4314 Seated Leg Press Dual — leg press
- 4023 45 Degrees Linear Leg Press — leg press
- 4324 45 Degrees Pivot Leg Press — leg press
- 4354 Vertical Leg Press — leg press (vertical)
- 4038 Squat Machine — squat machine
- 4159 Hack Squat — hack squat
- 4353N Pendulum Squat — pendulum squat
- 4360 Belt Squat — belt squat
- 4332 Deadlift Rotating Grips Dual — deadlift
- 4333 Deadlift Double Handle Grips Dual — deadlift
- 4384 Abduction 3D — leg abduction
- 4374 Standing Abduction — leg abduction (standing)
- 4321 Gluteus Kick Machine — glute kickback
- 4352 Booty Booster — hip thrust / glute
- 4386 Booty Booster Special — hip thrust / glute
- 4345 55 Degrees Standing Calf Raise — standing calf raise
- 4026 Seated Calf Raise — seated calf raise
- 4380 Donkey Calf — donkey calf raise
- 4348 Tibia Dorsi Flexion — tibialis / dorsiflexion
- 4343 Abdominal Crunch — abdominal crunch
- 4342N Rotating Ab Crunch — abdominal crunch (rotating)
- 4317 Ab Swing — abdominal
- 4307 Lying Abdominal — abdominal crunch (lying)

### Pure Kraft STRONG (plate-loaded, with Load Drop mechanism)
- 4361 Pure Kraft STRONG Leg Press — leg press
- 4362 Pure Kraft STRONG Decline Chest Press Dual — decline chest press
- 4363 Pure Kraft STRONG Shoulder Press Dual — shoulder press
- 4364 Pure Kraft STRONG Bench Press Dual — bench press
- 4365 Pure Kraft STRONG Incline Chest Press Dual — incline chest press

Notes:
- Gym80 markets **80Classics** (weight-stack), **80Athletics** (functional/performance), **Outdoor**
  and **Specialty Machines** as further ranges. **I did not enumerate these** — they are real lines
  (listed on gym80.us and gym80.co.uk) but I did not get a member-level listing I trust. 80Classics
  in particular is likely to be present on gym floors and deserves a follow-up pass.
- Gym80's number suffixes matter: `3012` and `3012N` are both listed as "Pull Over Machine", and
  `4329N` / `4342N` / `4353N` carry an N. These are real distinct SKUs on Gym80's own range pages,
  not typos, but for a user-facing picker you may want to collapse N-variants into one entry.
- Casing on Gym80's pages is inconsistent (some names ALL CAPS, some Title Case). I have normalised
  to Title Case; the words themselves are unchanged.

---

## Panatta

Source(s):
- https://www.apexmotionusa.com/equipment/strength/monolith
- https://www.apexmotionusa.com/equipment/strength/fit-evo
- https://www.apexmotionusa.com/equipment/strength/freeweight-special
- https://www.apexmotionusa.com/equipment/strength/freeweight-one
- https://www.apexmotionusa.com/equipment/strength/freeweight-hp
- https://www.panattasport.com/en/monolith/ , /en/freeweight-one/ , /en/free-weight-special/ (line
  existence + individual product names confirmed via search index; see caveat)

**Source caveat:** panattasport.com sits behind Cloudflare and refused every fetch I attempted. The
lists below come from Apex Motion USA, an authorised Panatta dealer, whose listings carry Panatta's
own SKU codes (1MTH…, 1FE…, 1FW…, 1FO…, 1SC…, 1HP…). The SKU codes are the strongest evidence these
are genuine catalogue entries — they match the codes visible in panattasport.com URLs and titles that
did surface in search results (e.g. Monolith Horizontal Adjustable Leg Press 1MTH085, Freeweight One
Rowing Machine 1FO004, Freeweight Special Alternate Triceps Machine 1FW252). Panatta's English names
are often non-idiomatic ("Leg curling", "Iperextension", "Peck back", "Dorsy Bar") — **these are
Panatta's own spellings and should be preserved verbatim**, not corrected.

### Monolith (selectorized, premium/compact)
Upper body: 1MTH001 Lat pulldown — lat pulldown · 1MTH002 Lat pulldown circular — lat pulldown ·
1MTH007 Lat pulldown convergent — lat pulldown · 1MTH006 High row convergent — high row ·
1MTH003 Pulley row — seated row · 1MTH004A Rowing machine circular — seated row ·
1MTH005 Lower back — back extension · 1MTH024 Deltoid press circular — shoulder press ·
1MTH026 Lateral deltoid — lateral raise · 1MTH028 Standing multi flight — standing cable (MULTI-EXERCISE) ·
1MTH033 Vertical chest press circular — chest press · 1MTH034 Inclined chest press circular — incline chest press ·
1MTH035 Pectoral machine — pec deck / chest fly · 1MTH117 Peck back — reverse fly / rear delt ·
1MTH039 Pullover machine — pullover · 1MTH138 Dips press — triceps dip ·
1MTH053 Triceps machine — triceps extension · 1MTH153 French press machine — overhead triceps extension ·
1MTH056 Alternate arm curl — biceps curl · 1MTH057 Alternate arm extension — triceps extension

Core: 1MTH067 Abdominal crunch — abdominal crunch

Lower body: 1MTH081 Leg extension — leg extension · 1MTH082 Leg curling — leg curl ·
1MTH083 Seated leg curling — seated leg curl · 1MTH085 Horizontal Adjustable leg press — leg press ·
1MTH086 Abductor machine — leg abduction · 1MTH087 Adductor machine — leg adduction ·
1MTH093 Dual Adductor Abductor machine — leg adduction + abduction (MULTI-EXERCISE) ·
1MTH088 Gluteus machine — glute kickback · 1MTH090 Multi hip — multi-hip (MULTI-EXERCISE) ·
1MTH092 Calf hack machine — calf raise + hack squat (MULTI-EXERCISE) · 1MTH097 Hip thrust — hip thrust

Total body (cable/multi-station, ALL MULTI-EXERCISE): 1MTH111 Cable crossover ·
1MTH125 Adjustable cable crossover · 1MTH114 Adjustable cable station · 1MTH126 Cable station ·
1MTH112 4-station multi gym · 1MTH127 2-Station Multi Gym · 1MTH115 Jungle machine

### Fit Evo (selectorized)
Back/pull: 1FE001 Lat pulldown · 1FE101 Lat pulldown double Stack · 1FE002 Lat pulldown circular ·
1FE007 Lat pulldown convergent — all lat pulldown · 1FE006 High row convergent — high row ·
1FE003 Pulley row · 1FE103 Pulley row double Stack · 1FE004A Rowing machine circular — seated row ·
1FE008 Total Back — back (MULTI-EXERCISE) · 1FE005 Lower back — back extension

Chest/shoulder: 1FE036 Vertical chest press · 1FE033 Vertical chest press circular — chest press ·
1FE037 Inclined chest press · 1FE034 Inclined chest press circular — incline chest press ·
1FE035 Pectoral machine — pec deck / chest fly · 1FE117 Peck back — reverse fly / rear delt ·
1FE039 Pullover machine — pullover · 1FE025 Deltoid press · 1FE024 Deltoid press circular — shoulder press ·
1FE026 Lateral deltoids — lateral raise · 1FE027 Rotary cuff — rotator cuff ·
1FE032 Total Press — press (MULTI-EXERCISE) · 1FE028 Standing multi flight — standing cable (MULTI-EXERCISE)

Arms: 1FE051 Curling machine · 1FE056 Alternate arm curl · 1FE356 Alternate arm curl 120 ·
1FE456 Alternate arm curl -45 — all biceps curl · 1FE052 Alternate preacher curl machine — preacher curl ·
1FE053 Triceps machine · 1FE057 Alternate arm extension · 1FE357 Alternate arm extension 90 — triceps extension ·
1FE153 French press machine — overhead triceps extension · 1FE038 Dips press — triceps dip ·
1FE155 Alternate standing total arms — arms (MULTI-EXERCISE)

Core: 1FE065 Upper abdominal · 1FE067 Abdominal crunch — abdominal crunch ·
1FE066 Torsion machine — torso rotation

Legs: 1FE081 Leg extension · 1FE082 Leg curling · 1FE083 Seated leg curling ·
1FE084 Standing leg curling · 1FE085 Horizontal leg press ·
1FE095 Dual system horizontal leg press — leg press · 1FE086 Abductor machine — leg abduction ·
1FE087 Adductor machine — leg adduction ·
1FE093 Adductor/ abductor machine — abduction + adduction (MULTI-EXERCISE) ·
1FE088 Gluteus machine · 1FE094A Master gluteus plus — glute · 1FE097 Hip thrust — hip thrust ·
1FE089 Calf machine — calf raise · 1FE090 Multi hip — multi-hip (MULTI-EXERCISE) ·
1FE098 Power runner — sled / running press

Cable & stations (MULTI-EXERCISE): 1FE111 Cable crossover · 1FE125 Adjustable cable crossover ·
1FE114B High low pulley · 1FE112 4-station multi gym · 1FE112F 4-Station Four HLP ·
1FE115 Jungle machine · 1FE120 Jungle machine hlp · 1FE120D Jungle machine double hlp ·
1FE118A Multipurpose press · 1FE113B Smith machine linear bearings — Smith machine ·
1FE121 Chin and dip counterbalanced · 1FE211 Chin and dip — assisted pull-up & dip

### Freeweight Special (plate-loaded, "Super" heavy-duty)
Chest: 1FW036 Super vertical chest press · 1FW035 Super inclined chest press ·
1FW041 Super declined chest press · 1FW037 Super Horizontal Bench Press · 1FW033 Super inclined bench press ·
1FW043 Super middle chest flight machine · 1FW038 Super upper chest flight machine — chest fly ·
1FW040 Dips press dual system · 1FW140 Dips press — triceps dip

Back: 1FW001 Super lat machine convergent · 1FW101 Super lat pulldown circular — lat pulldown ·
1FW003 Super high row — high row · 1FW102 Super power row · 1FW002 Super low row ·
1FW104 Super Rowing — row · 1FW005 Super dorsy bar — row · 1FW010 Super Shrug Machine — shrug ·
1FW039 Super pullover machine · 1FW139 Pullover machine — pullover

Shoulders: 1FW025 Super deltoid press — shoulder press · 1FW027 Lateral deltoids — lateral raise ·
1FW026 Back deltoids — rear delt

Arms: 1FW551 Four Angle Biceps Machines · 1FW056 Alternate Arm Curl – 45 · 1FW055 Alternate Arm Curl 120 ·
1FW251 Alternate curling machine · 1FW351 Curling machine — biceps curl ·
1FW054 Alternate Preacher Curl Machine — preacher curl ·
1FW252 Alternate triceps machine · 1FW352 Triceps machine — triceps extension

Legs: 1FW085 Super leg press bridge · 1FW100 Super Horizontal Leg Press Dual System ·
1FW086 Super leg press 45° · 1FW090 Super leg press 45° dual system · 1FW093 Super vertical leg press ·
1FW193 Vertical leg press — leg press · 1FW091 Super squat machine · 1FW084 Super power squat ·
1FW080 Super pendulum squat — pendulum squat · 1FW095 Belt squat — belt squat ·
1FW087 Super hack squat — hack squat · 1FW079 Super Lunge Machine — lunge ·
1FW181 Leg extension · 1FW281 Alternate leg extension — leg extension ·
1FW082 Alternate leg curling · 1FW182 Leg curling · 1FW183 Seated leg curling ·
1FW094 Kneeling leg curling — leg curl · 1FW092 Super calf hack — calf raise + hack squat (MULTI-EXERCISE) ·
1FW088 Super seated calf — seated calf raise · 1FW089 Donkey calf — donkey calf raise ·
1FW097 Hip thrust — hip thrust · 1FW099 Standing abductor — leg abduction ·
1FW096 Reverse hyperextension — reverse hyperextension · 1FW098 Power runner — sled / running press

Racks & Smith: 1FW520 Olympic smith machine counterbalanced — Smith machine ·
1FW534 Olympic half rack · 1FW531 Olympic power rack — rack ·
1FW533 Military bench · 1FW518 Seal row bench — bench

### Freeweight One (plate-loaded, compact/value)
1FO001 Lat machine convergent — lat pulldown · 1FO101 Lat pulldown circular — lat pulldown ·
1FO002 Low row · 1FO003 High row · 1FO004 Rowing machine · 1FO102 Power row — row ·
1FO005 Dorsy Bar — row · 1FO010 Shrug Machine — shrug · 1FO039 Pullover machine — pullover ·
1FO036 Vertical chest press · 1FO035 Inclined chest press — chest press ·
1FO038 Upper Chest Flight Machine · 1FO043 Middle chest flight machine — chest fly ·
1FO140 Dips Press — triceps dip · 1FO025 Deltoid press — shoulder press ·
1FO027 Lateral deltoids — lateral raise · 1FO026 Back deltoids — rear delt ·
1FO029 Viking Press — viking press · 1FO151 Curling machine — biceps curl ·
1FO053 French press machine — overhead triceps extension · 1FO086 Leg press 45° ·
1FO085 Leg press bridge — leg press · 1FO080 Pendulum squat — pendulum squat ·
1FO087 Hack Squat — hack squat · 1FO091 Squat and Calf Machine — squat + calf raise (MULTI-EXERCISE) ·
1FO181 Leg extension — leg extension · 1FO183 Seated leg curling · 1FO094 Kneeling leg curling — leg curl ·
1FO088 Seated Calf — seated calf raise · 1FO097 Hip thrust · 1FO197 Standing Hip Thrust — hip thrust ·
1FO304 Adjustable Row 45° — chest-supported row · 1FO120 Power Smith Machine Multi Angles — Smith machine

### SEC (selectorized, space-efficient)
1SC001 Lat pulldown — lat pulldown · 1SC003 Pulley row · 1SC004 Rowing machine — seated row ·
1SC005 Lower back — back extension · 1SC034 Vertical chest convergent · 1SC037 Inclined chest press — chest press ·
1SC035 Pectoral machine — pec deck / chest fly · 1SC117 Peck back — reverse fly / rear delt ·
1SC024 Deltoid press convergent — shoulder press · 1SC051 Curling machine — biceps curl ·
1SC053 Triceps machine — triceps extension · 1SC065 Upper abdominal — abdominal crunch ·
1SC081 Leg extension — leg extension · 1SC082 Leg curling · 1SC083 Seated leg curling — leg curl ·
1SC085 Horizontal leg press · 1SC085M Horizontal leg press medical — leg press ·
1SC086 Abductor machine — leg abduction · 1SC087 Adductor machine — leg adduction ·
1SC093 Adductor/abductor machine — abduction + adduction (MULTI-EXERCISE) ·
1SC089 Calf machine — calf raise · 1SC090 Multi hip — multi-hip (MULTI-EXERCISE)

SEC cable/stations (MULTI-EXERCISE): 1SC111 Cable crossover · 1SC120 Adjustable cable crossover ·
1SC114 High low pulley · 1SC112 4-station multi gym · 1SC115 Jungle machine ·
1SC110 Smith machine selectorized · 1SC113A Smith machine linear bearings — Smith machine ·
1SC211 Chin and dip (chin optional) — assisted pull-up & dip

SEC Dual (two exercises per machine — ALL MULTI-EXERCISE):
1SCD010 Dual lat machine | pulley row — lat pulldown + seated row ·
1SCD050 Dual curling | triceps machine — biceps curl + triceps ·
1SCD030 Multi press — chest press + shoulder press ·
1SCD060 Dual abdominal | lower back — abdominal crunch + back extension ·
1SCD080 Dual leg extension | seated leg curling — leg extension + leg curl

### Freeweight HP (benches, racks and multifunctional)
- 1HP534 Jammer — jammer press (MULTI-EXERCISE)
- 1HP506 Combo twist — torso rotation
- 1HP590 Squat lunge — squat / lunge
- 1HP233 Power tower — bodyweight station (MULTI-EXERCISE)
- 1HP232 Power platform — lifting platform
- 1HP201 Fully adjustable bench, 1HP201A Fully adjustable bench kit for 1hp234a,
  1HP216 Multipurpose sit up bench, 1HP206 Olympic multi bench, 1HP203 Super olympic flat bench,
  1HP203B Olympic flat bench, 1HP205 Super olympic inclined bench, 1HP205B Olympic inclined bench,
  1HP217 Multimotion bench, 1HP207 Super olympic shoulder bench, 1HP207B Olympic shoulder bench,
  1HP214 Triceps bench, 1HP215 Standing curl bench, 1HP213 Adjustable standing curl bench — benches

Notes:
- Freeweight HP is predominantly a **bench and rack** line, not an isotonic-machine line. If your app
  only catalogues machines, most of Freeweight HP can be skipped except Jammer, Combo twist, Squat
  lunge and Power tower.
- Panatta also markets an **HP Line** of heavy-duty machines distinct from the Freeweight HP benches
  in some markets. **I could not verify a member list for it** and have not included one.
- Several exercise names repeat across lines with different prefixes (e.g. "Leg extension" exists as
  1MTH081, 1FE081, 1FW181, 1FO181, 1SC081). The SKU prefix is what disambiguates the line — keep it.

---

## Watson Gym Equipment

Source(s):
- https://watsongym.co.uk/product-category/machines/plate-loaded-machines/feed/
- https://watsongym.co.uk/product-category/machines/single-stack-machines/feed/
- https://watsongym.co.uk/product-category/machines/dual-stack/feed/
- https://watsongym.co.uk/product-category/machines/multi-gyms/feed/
- https://watsongym.co.uk/product-sitemap.xml , https://watsongym.co.uk/range-sitemap.xml

These are Watson's own product titles, read from the WooCommerce category feeds on watsongym.co.uk
(the HTML category pages are JS-rendered and 403 to fetchers; the feeds return the same catalogue).
Watson uses a strict prefix convention: **PL** = plate loaded, **SS** = single stack (selectorized),
**DS** = dual stack (selectorized). Watson's declared ranges are **Animal**, **Original**,
**Total Access** and **Westside**; the Animal and Westside range names appear inside product names.

### PL — Plate Loaded
- PL Chest Press — chest press
- PL Standing Chest Press — chest press (standing)
- PL Decline Chest Press — decline chest press
- PL Super Incline Chest Press — incline chest press
- PL Bench Press — bench press
- PL Free Motion Chest Press — chest press (free motion)
- PL Pec Fly — pec deck / chest fly
- PL Arched Incline Pec Fly — incline chest fly
- PL Shoulder Press — shoulder press
- PL Incline Shoulder Press — incline shoulder press
- PL Free Motion Shoulder Press — shoulder press (free motion)
- PL Standing Lateral Raise — lateral raise
- PL Delt Builder — deltoid
- PL Front Pulldown — lat pulldown
- PL Lateral Row — row
- PL Low Row — low row
- PL Perfect Row — row
- PL T-Bar Row — T-bar row
- PL Independent Pullover — pullover
- PL Tru Pull — pulldown/row
- PL Bicep Curl — biceps curl
- PL Seated Dip — triceps dip
- PL Standing ISO Dip — triceps dip (standing)
- PL Jammer — jammer press (MULTI-EXERCISE)
- PL Multi-Trainer — multi-exercise station (MULTI-EXERCISE)
- PL Total Torso — torso (MULTI-EXERCISE)
- PL Leg Extension — leg extension
- PL Standing Leg Curl — standing leg curl
- PL 45° Leg Press — leg press
- PL Pivot Leg Press — leg press
- PL Rear Pivot Leg Press — leg press
- PL Vertical Leg Press — leg press (vertical)
- PL Hack Squat — hack squat
- PL 30 Degree Hack Squat — hack squat
- PL Linear Hack Squat — hack squat (linear)
- PL Pendulum Squat — pendulum squat
- PL Power Squat — squat machine
- PL Tru Squat — squat machine
- PL Leverage Squat — squat machine
- PL Hip Belt Squat — belt squat
- PL Lunge Machine — lunge
- PL Deadlift — deadlift
- PL Standing Hip Thrust — hip thrust
- PL Glute Blaster — glute
- PL Hip Abductor — leg abduction
- PL Hip Adductor — leg adduction
- PL 45º Calf Raise — calf raise
- PL Seated Calf Raise — seated calf raise
- PL Seated Calf / Tibia Raise — calf + tibialis (MULTI-EXERCISE)
- PL Total Calf / Tibialis Developer — calf + tibialis (MULTI-EXERCISE)
- PL Donkey Calf Raise — donkey calf raise
- PL Tibialis Trainer — tibialis
- PL Seated / Standing Shrug Machine — shrug (MULTI-EXERCISE)
- PL Power Runner — sled / running press
- PL Viking Press — viking press
- PL Seated Hand Gripper — grip
- PL Standing Hand Gripper — grip
- PL Deluxe Reverse Hyper Extension — reverse hyperextension
- PL Plyo Swing — plyometric swing
- PL Pakulski Leg Package — leg package (MULTI-EXERCISE)
- PL Smith Machine with 4 x Weight Storage — Smith machine
- PL Counter-Balanced Smith Machine with 4 x Weight Storage — Smith machine
- PL Four-Way Smith Machine with Horizontal & Vertical Stops — Smith machine

Animal range (plate loaded):
- PL Animal Converging Standing Chest Press — chest press
- PL Animal ISO Linear Row — row
- PL Animal Lateral Row — row
- PL Animal Chest Supported T-Bar Row — T-bar row
- PL Animal Leg Press — leg press
- PL Animal Horizontal Leg Press — leg press
- PL Animal Vertical Leg Press — leg press (vertical)
- PL Animal Adjustable Hack Squat — hack squat
- PL Animal Viking Press — viking press
- PL Animal Half Rack / Four Way Smith — rack + Smith machine (MULTI-EXERCISE)

Westside range (plate loaded):
- PL Westside MR-19 — reverse hyper / posterior chain
- PL Westside Reverse Hyper with Bent Pendulum — reverse hyperextension
- PL Westside Ultra Pro Reverse Hyper — reverse hyperextension
- PL Westside Ultra Supreme Reverse Hyper — reverse hyperextension
- PL Westside Inverse Curl Pro — inverse / nordic leg curl
- PL Westside Hip & Quad Developer Pro — hip & quad

### SS — Single Stack (selectorized)
- SS Chest Press — chest press
- SS Pec Fly / Rear Delt — chest fly + rear delt (MULTI-EXERCISE)
- SS Multi Pec / Delt — chest + delt (MULTI-EXERCISE)
- SS Shoulder Press — shoulder press
- SS Multi-Press — press (MULTI-EXERCISE)
- SS Seated Lateral Raise — lateral raise
- SS Seated Incline Lateral Raise — lateral raise
- SS Standing Lateral Raise — lateral raise
- SS Lat Pulldown — lat pulldown
- SS Dual Cable Lat Pulldown — lat pulldown
- SS Seated Row — seated row
- SS Low Pulley Row — low row
- SS Dual Cable Low Pulley Row — low row
- SS Lat Pulldown / Low Pulley Row — lat pulldown + low row (MULTI-EXERCISE)
- SS Pullover — pullover
- SS Bicep Curl — biceps curl
- SS Tricep Extension — triceps extension
- SS Overhead Tricep Extension — overhead triceps extension
- SS Tricep Dip — triceps dip
- SS Bicep Tricep Machine — biceps + triceps (MULTI-EXERCISE)
- SS Abdominal Crunch — abdominal crunch
- SS Torso Twist — torso rotation
- SS Back Extension — back extension
- SS Hyper Extension — hyperextension
- SS Rotator Cuff — rotator cuff
- SS Assisted Chin / Dip — assisted pull-up & dip (MULTI-EXERCISE)
- SS Adjustable Pulley — cable pulley (MULTI-EXERCISE)
- SS Dual Cable Adjustable Pulley — cable pulley (MULTI-EXERCISE)
- SS Leg Press — leg press
- SS Leg Extension — leg extension
- SS Seated Leg Curl — seated leg curl
- SS Lying Leg Curl — lying leg curl
- SS Standing Leg Curl — standing leg curl
- SS Leg Extension / Seated Leg Curl — leg extension + leg curl (MULTI-EXERCISE)
- SS Leg Extension / Lying Leg Curl — leg extension + leg curl (MULTI-EXERCISE)
- SS Hip Abductor — leg abduction
- SS Standing Hip Abductor — leg abduction (standing)
- SS Hip Adductor — leg adduction
- SS Dual Hip Adductor / Abductor — adduction + abduction (MULTI-EXERCISE)
- SS Glute Machine — glute
- SS Multi-Hip — multi-hip (MULTI-EXERCISE)
- SS Calf Raise — calf raise
- Total Access Tricep Dip — triceps dip (Total Access range)

### DS — Dual Stack (selectorized / cable)
- DS Animal Chest Press — chest press
- DS Animal Decline Chest Press — decline chest press
- DS Animal Shoulder Press — shoulder press
- DS Animal Lat Pulldown — lat pulldown
- DS Animal Front Pulldown — lat pulldown
- DS Animal High Pulley Row — high row
- DS Animal Mid to Low Row — low row
- DS Animal Bicep Curl — biceps curl
- DS Animal Low Pulley — cable pulley (MULTI-EXERCISE)
- DS Animal Leg Extension — leg extension
- DS Animal Functional Trainer — cable functional trainer (MULTI-EXERCISE)
- DS Cable Crossover — cable crossover (MULTI-EXERCISE)
- DS Dual Adjustable Pulley — cable pulley (MULTI-EXERCISE)
- DS Seated Dual Cables — cable (MULTI-EXERCISE)
- DS Smith Machine — Smith machine

### Multi-Gyms (ALL MULTI-EXERCISE)
- Animal 10 Stack Multi-Gym
- Animal Dual Stack Multi-Gym
- Animal Dual Stack Cable Column
- Single Stack Multi-Gym
- Six Station Multi-Gym
- Eight Station Multi-Gym
- Power Gym
- Power Gym with Floor Pulley Platform
- Total Fit Gym
- Home Gym Package

Notes:
- Watson's declared ranges are **Animal**, **Original**, **Total Access**, **Westside**. The Animal,
  Westside and Total Access names are embedded in product names; **"Original" is not** — most
  unprefixed PL/SS/DS products presumably belong to Original, but Watson does not label them that
  way and I did not confirm the mapping, so I have not tagged them.
- Watson also sells a large accessory/attachment/specialty-bar catalogue (grapplers, thick-grip bars,
  Poliquin handles, etc.) and benches. Excluded — not trackable machines.
- The feeds are paginated; I read pages 1–5 of each category and the lists converged, so these should
  be complete for the four machine categories.

---

## Eleiko

Source(s):
- https://eleiko.com/sitemap.xml (full product URL set)
- https://eleiko.com/en/equipment/strengthmachines/ (cables / selectorized / plate-loaded subtrees)
- https://eleiko.com/en/prestera , https://eleiko.com/en/equipment/racksandrigs

**Important finding — read before seeding anything Eleiko:** Eleiko is a barbell, plate and rack
manufacturer, not a machine manufacturer. Its `/equipment/strengthmachines/` category is **almost
entirely Precor-branded** — the `selectorized` and `plateloaded` subtrees contain Precor Resolute,
Precor Discovery and Precor Glute Builder machines that Eleiko resells (e.g. "Precor Resolute
Converging Chest Press RSL0414", "Precor Discovery Plate Loaded Hack Squat DPL603", "Precor Glute
Builder Hip Thrust Elite GPL612"). **Do not file these under Eleiko** — a user standing in front of
one is standing in front of a Precor. They belong in a Precor entry if the catalogue has one.

The genuinely Eleiko-branded strength equipment is:

### Eleiko cable machines (selectorized cable)
- Eleiko Dual Adjustable Pulley — cable pulley (MULTI-EXERCISE); 90 kg and 120 kg stack options
- Eleiko Cable Cross — cable crossover (MULTI-EXERCISE); 90 kg and 120 kg
- Eleiko Cable Cross Multi Station — cable crossover (MULTI-EXERCISE); 90 kg and 120 kg
- Eleiko Single Adjustable Pulley Multi Station — cable pulley (MULTI-EXERCISE); 90/120 kg
- Eleiko Single Adjustable Pulley Wall Mounted — cable pulley (MULTI-EXERCISE); 90/120 kg
- Eleiko Lat Pull Down — lat pulldown; Free Standing / Multi Station / Wall Mounted, 120 or 150 kg
- Eleiko Low Row — low row; Free Standing / Multi Station / Wall Mounted, 120 or 150 kg

### Prestera (racks / smith-or-rack)
- Eleiko Prestera Power Rack — power rack
- Eleiko Prestera Half Rack — half rack
- Eleiko Prestera Double Half Rack — half rack (double)
- Eleiko Prestera Fitness Half Rack — half rack
- Eleiko Prestera Squat Rack — squat rack
- Eleiko Prestera Half Rack w/ Smith Attachment — half rack + Smith machine (MULTI-EXERCISE)
- Eleiko Prestera Double Half Rack w/ Smith Attachment — half rack + Smith machine (MULTI-EXERCISE)

### Other Eleiko racks/stands
- Eleiko Classic Squat Stand — squat stand
- Eleiko Light Squat Stand — squat stand
- Eleiko Powerlifting Training Station — combo rack
- Eleiko Training Combo Rack — combo rack
- Eleiko IPF Competition Combo Rack — combo rack
- Eleiko XF Flat Bench — bench

Notes:
- Prestera rack SKUs are sold in many finish/height permutations (Black / Stainless / Short / Tall /
  Charcoal uprights). For a user-facing picker, collapse to the base names above — a lifter will not
  know whether their half rack is the "stainless tall" SKU.
- **XF 80** is a real Eleiko racks-and-rigs line (https://eleiko.com/equipment/racksandrigs/xf80),
  including galvanized outdoor variants. **I could not enumerate its individual members** from the
  sitemap subtree and have not guessed at them. Report the line; add members after a dedicated pass.
- Eleiko has no leg press, no chest press, no lat machine of its own beyond the cable Lat Pull Down.
  If your seed data suggests otherwise, it is almost certainly a rebadged Precor.

---

## BH Fitness

Source(s):
- https://bh.fitness/en/equipments/strength/
- https://bh.fitness/en/equipments/strength/movemia-strength/
- https://bh.fitness/en/equipments/strength/pl-series/
- https://bh.fitness/en/equipments/strength/inertia-strength/

BH labels every machine `<code> <name>` on its own range pages; both are reproduced. BH's own
capitalisation is inconsistent (some names ALL CAPS on the page); normalised to Title Case here.

### Movemia (selectorized) — BH's flagship commercial strength line
- M070 Chest Press — chest press
- M270 Butterfly — pec deck / chest fly
- M420 Pec Fly / Rear Delt — chest fly + rear delt (MULTI-EXERCISE)
- M090 Shoulder Press — shoulder press
- M490 Deltoid Raise — lateral raise
- M550 Lat Pulldown — lat pulldown
- M290 Low Row — seated low row
- M450 Assisted Chin and Dip — assisted pull-up & dip (MULTI-EXERCISE)
- M130 Biceps — biceps curl
- M160 Triceps — triceps extension
- M010 Leg Extension — leg extension
- M030 Lying Leg Curl — lying leg curl
- M170 Prone Leg Curl — prone leg curl
- M050 Leg Press — leg press
- M250 Abductor/Adductor — leg abduction + adduction (MULTI-EXERCISE)
- M330 Gluteous — glute *(BH's own spelling)*
- M230 Calf Raise — calf raise
- M310 Abdominal — abdominal crunch
- M510 Lower Back — back extension
- M370 Dual Adjustable Pulley — cable pulley (MULTI-EXERCISE)

### PL Series (plate-loaded)
- PL070B Chest Press — chest press
- PL075B Incline Chest Press — incline chest press
- PL080 Multi-Position Press — press (MULTI-EXERCISE)
- PL090B Shoulder Press — shoulder press
- PL490 Standing Lateral Raises — lateral raise
- PL110B Lat Pulley — lat pulldown
- PL290B T-Bar Row — T-bar row
- PL300B Seated Row — seated row
- PL130B Biceps — biceps curl
- PL150B Seated Triceps — triceps extension
- PL155B Seated Triceps — triceps extension
- PL010B Leg Extension — leg extension
- PL170B Femoral — leg curl *(BH's term for hamstring curl)*
- PL700B Leg Press — leg press
- PL200B Hack Squat — hack squat
- PL845B Super Squat — squat machine
- PL320B Belt Squat — belt squat
- PL250B Squat Lunge — squat / lunge
- PL255B Standing Abductor — leg abduction (standing)
- PL330B Rear Kick — glute kickback
- PL340B Hip Thrust — hip thrust
- PL210B Seated Calf — seated calf raise
- PL310B Rotational Abdominal Crunch — abdominal crunch / torso rotation
- PL350B Half Rack — half rack
- PL400B Full Rack — power rack

### Inertia / L Series (selectorized)
- L070B Chest Press — chest press
- L270B Butterfly — pec deck / chest fly
- L410B Rear Deltoid / Peck Deck — chest fly + rear delt (MULTI-EXERCISE)
- L090B Shoulder Press — shoulder press
- L080B Chest/Shoulder Press — chest press + shoulder press (MULTI-EXERCISE)
- L490B Deltoid Raise — lateral raise
- L110B Lat Pulley — lat pulldown
- L290B Seated Row — seated row
- L550B Lat Pull/Rower (Dual) — lat pulldown + row (MULTI-EXERCISE)
- L450B Assisted Kneeling Chin and Dip — assisted pull-up & dip (MULTI-EXERCISE)
- L130B Biceps — biceps curl
- L150B Seated Triceps — triceps extension
- L160B Horizontal Triceps — triceps extension
- L140B Biceps/Triceps — biceps + triceps (MULTI-EXERCISE)
- L010B Leg Extension — leg extension
- L020B Leg Extensión/Curl — leg extension + leg curl (MULTI-EXERCISE) *(BH's own accented spelling)*
- L030B Lying Leg Curl — lying leg curl
- L170B Seated Leg Curl — seated leg curl
- L050B Leg Press — leg press
- L250B Abduction/Adduction — leg abduction + adduction (MULTI-EXERCISE)
- L330B Gluteous — glute
- L335 Hip Thrust — hip thrust
- L340B Total Hip — multi-hip (MULTI-EXERCISE)
- L210B Seated Calf — seated calf raise
- L310B Abdominal — abdominal crunch
- L510B Lower Back — back extension
- L610B Abdominal/Lower Back — abdominal crunch + back extension (MULTI-EXERCISE)
- L430B Twister — torso rotation

### TR Series (benches, racks, multifunctional stations)
Mostly benches and racks — L800/L835/L900 Abdominal Bench, L885 Abdominal Flexor, L810 Flat Bench,
L805 Inclined Bench, L815 Horizontal Olympic Bench, L820 Inclined Press Bench, L855 Declined Press
Bench, L850 Shoulder Press Bench, L830 Scott Bank (preacher curl), L840 Roman Chair, L825 /
L826BB Multiposition Bench, L300 Streching Bench, L350/L845/LD400 Racks. Machines/stations worth
cataloguing:
- L360 Multifunctional Station — cable station (MULTI-EXERCISE)
- L365 Multifunctional Station — cable station (MULTI-EXERCISE)
- L480B Multifunctional Station — cable station (MULTI-EXERCISE)
- L485 Multifunctional Station — cable station (MULTI-EXERCISE)
- L480X2 Multi (TR) — cable station (MULTI-EXERCISE)
- L535B Multi (TR) — cable station (MULTI-EXERCISE)
- L540B Multi (TR) — cable station (MULTI-EXERCISE)

Notes:
- **PL150B and PL155B are both named "Seated Triceps"** on BH's own page. That is what the page says;
  it is not a transcription error. They will need disambiguation in a picker.
- BH's strength index has a page 2 I did not exhaust, plus a `plr-studio-en` range. The four ranges
  above (Movemia, PL Series, Inertia, TR Series) are the commercial strength lines and I read each
  range page in full.
- Keep BH's spellings ("Gluteous", "Femoral", "Streching", "Extensión") — they are how the machines
  are labelled.

---

## Confidence

### Covered well — safe to ship
- **Technogym** — Selection 900, Selection 700, Artis and Pure Strength all read from the structured
  product data in Technogym's own category pages, then cross-checked against product-URL slugs. Two
  traps flagged and avoided (no Selection 900 Abductor; no "Artis Triceps").
- **Matrix Fitness** — model codes come from Matrix's own sitemap, which enumerates every product;
  series↔prefix mapping confirmed against live product page titles. Very high confidence in the codes
  and exercises. The only soft spot is presentation format (`G7-S13 Converging Chest Press` vs
  `Ultra Converging Chest Press`) — pick one.
- **Gym80** — Sygnum (incl. Dual, Combo, Cable Art, Stations, Basic, Innovation) and Pure Kraft /
  Pure Kraft STRONG all read from Gym80's own UK and US range pages, with part numbers.
- **Watson Gym Equipment** — read from Watson's own WooCommerce category feeds. Prefix convention
  (PL / SS / DS) is Watson's own and is reliable.
- **BH Fitness** — Movemia, PL Series and Inertia read from BH's own range pages with model codes.

### Covered, with a source caveat
- **Panatta** — large and detailed, but sourced from Apex Motion USA (authorised dealer) because
  panattasport.com is behind Cloudflare and refused every fetch. Confidence is high because every
  entry carries a Panatta SKU code (1MTH/1FE/1FW/1FO/1SC/1HP) and the codes match the ones visible in
  panattasport.com URLs that surfaced in search. **If you want belt-and-braces, spot-check ~10 SKUs
  against panattasport.com from a browser before shipping.**

### Thin
- **Eleiko** — thin *because there is little to find*, not because research fell short. Eleiko does
  not make a machine range; its "strength machines" category is largely resold Precor. What is
  genuinely Eleiko (cable machines, Prestera racks) is listed and is accurate. Expect ~20 entries,
  not 100. If your seed data currently attributes leg presses or chest presses to Eleiko, that is a
  bug.

### Could not verify — deliberately omitted
- **Technogym Selection Pro** — the previous-generation selectorized line, still very common on gym
  floors. Confirmed to exist via multiple resellers (Chest Press, Leg Extension, Shoulder Press,
  Seated Leg Press) but not enumerable from a current Technogym listing. Needs an archived-catalogue
  pass. Omitting it means real machines will be unrepresented; adding it unverified means invented
  entries. I chose to omit.
- **Technogym Selection 900 Multi Flight** individual movements — flagged as multi-exercise, movements
  not enumerated.
- **Gym80 80Classics, 80Athletics, Specialty Machines, Outdoor** — real lines, no member list obtained.
- **Panatta "HP Line"** (distinct from the Freeweight HP bench line) — real line referenced in some
  markets, no member list obtained.
- **Eleiko XF 80** — real racks-and-rigs line, members not enumerated.
- **Matrix `MD-` prefix** (MD-S70 Leg Press, MD-S711 Leg Extension/Leg Curl, MD-AP Adjustable Pulley,
  MD-FW52 MI Back Trainer) — codes are real (from Matrix's sitemap) but I could not determine which
  series the prefix denotes, so they are unfiled.
- **Watson "Original" range membership** — the range exists but Watson does not mark which products
  belong to it.
- **BH `plr-studio` range** and page 2 of BH's strength index — not exhausted.

### Known duplicate/variant traps for the seeding step
- Matrix G7 `B`-suffix models are "Ultra Base Trim" — same machine, different upholstery. Collapse
  unless you want trim granularity.
- Gym80 `N`-suffix part numbers (3012/3012N, 4329N, 4342N, 4353N) are distinct SKUs of the same machine.
- Eleiko Prestera racks and cable machines exist in many finish/weight-stack permutations.
- Panatta repeats the same exercise name across lines; the SKU prefix is the only disambiguator.
- BH PL150B and PL155B share the name "Seated Triceps" on BH's own page.
