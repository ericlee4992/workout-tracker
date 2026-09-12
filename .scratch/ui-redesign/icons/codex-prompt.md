Design task (not a review). Read .scratch/ui-redesign/icons/brief.md first — five muscle-family
icons (Chest, Back, Shoulders, Arms, Legs) for this iPhone app's template tiles; the user found the
current SF Symbols "inaccurate and mild" and asked for YOUR design, made with your image generation
model (the user calls it "Image 2.5" — use whatever image-generation tool you have), alongside
Claude's. Read .claude/skills/ios-design/SKILL.md and REFERENCE.md for the palette and rules, and
WorkoutTracker/Features/Design/MuscleGroupStyle.swift for what exists.

Produce, in .scratch/ui-redesign/icons/codex/: chest.png, back.png, shoulders.png, arms.png,
legs.png — each 1024 × 1024, transparent background, a single flat white silhouette of the body
part (pecs; lats / V-taper; deltoid caps; a flexed bicep; a thigh/quad) that survives at 24 pt,
consistent in weight and style across the five — plus README.md with your five proposed colours
(hex, one per family, ≥ 4.5:1 on a 14 % tint of themselves over #151A21 — measure) and five lines
of reasoning. If your image tool cannot output transparency, output white glyph on solid black and
say so in the README. Also write .scratch/ui-redesign/icons/codex/contact-sheet.png: the five on
one row over the app's card colour at 40 pt-equivalent scale, if you can compose it (skip if not).
Do NOT modify app source files; do not run xcodebuild or simctl. When finished, write
.scratch/ui-redesign/icons/codex/DONE.md with one paragraph on what you made and any limitation.
