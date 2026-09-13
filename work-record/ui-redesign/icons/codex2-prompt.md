Design task, round 2 (not a review). Your first set is in work-record/ui-redesign/icons/codex/ and
the brief in work-record/ui-redesign/icons/brief.md. The user has now given a DIRECTION with two
reference images — read them: work-record/ui-redesign/icons/ref/muscle-map-lines.png (a line-drawn
body with the working muscle filled orange) and ref/muscle-map-flat.png (flat stylised torsos with
muscle segments, the target muscle in red). The user: "how about making it more realistic like
this and highlighting the muscle, like these. I think it will be easier to see this way."

So: a MUSCLE MAP per family — a neutral body silhouette with the family's muscle highlighted.
Chest: a front torso, pecs highlighted. Back: a back-view torso, lats (+ traps) highlighted.
Shoulders: a front torso, both deltoid caps highlighted. Arms: a flexed arm, the bicep
highlighted. Legs: a pair of legs from the front, the quads highlighted. Realistic-simplified
anatomy (the flat reference's level of detail, NOT the line drawing's thin strokes — it must
survive at 24 pt), the same crop and scale across the five.

Output format, so the app can tint the two layers separately: each image 1024 × 1024 on SOLID
BLACK, the body in EXACTLY mid-grey #808080 (flat, no shading) and the highlighted muscle in
EXACTLY pure red #FF0000 (flat), nothing else — I split the layers by colour into two masks. If
your image tool cannot hold exact flat colours, get as close as you can and say so. Files:
work-record/ui-redesign/icons/codex2/{chest,back,shoulders,arms,legs}.png, a contact-sheet.png of
the five on the app's card colour #171B21 at 40 pt-equivalent with the body in #5B6472 and the
muscle in your family colours from round 1 (compose it with Pillow like last time), and README.md
(five lines: what each shows and any limitation). Do NOT modify app source; do not run xcodebuild
or simctl. When finished write work-record/ui-redesign/icons/codex2/DONE.md (one paragraph).
