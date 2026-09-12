Round 1 (T6) of UI-redesign ticket 12 — the muscle-family icons become muscle maps: YOUR round-2
body maps (.scratch/ui-redesign/icons/codex2/) as two-layer template assets in the app. The user
chose them over Claude's on the canvas. Grade against .claude/skills/ios-design/REVIEW.md items
that apply (1, 5, 6, 9, 11, 12) plus the asset pipeline; the ticket is
.scratch/ui-redesign/issues/12-muscle-family-icons.md. Boundary: main..HEAD on branch
ui-redesign-12-muscle-maps (main = 5a10157).

Files: WorkoutTracker/Assets.xcassets/MuscleMaps/ (namespaced; <family>-body / <family>-muscle,
512 px single-scale PNG template images, made from your grey/red renders by a soft luminance and
redness split — the script is inline in the ticket's Build section and in the commit),
Assets.xcassets/Colors/MuscleBody (#5B6472), Features/Design/Theme.swift (muscleBody),
Features/Design/MuscleGroupStyle.swift (colour + map per family; MuscleIcon stacks the two
tinted layers in the 16 % tile, the map at 86 % of the tile), WorkoutTrackerTests/ThemeTests.swift.
Captures .scratch/ui-redesign/screenshots/12/: 04-start-fixture(-axl), 04-template-detail-fixture,
-fixture-axl, -fixture-axl-2, plus 04-start-templates / 04-template-detail (the three-family
fixture) and their AXL pairs. Unit: ThemeTests 2, MuscleFamilyTests 6, TemplateFixtureTests 3 —
11/11. The full UI suite is running now.

Particular attention:
- Item 6: your colours on a 16 % tint (the board's proportion; ticket 11 used 14 %) — remeasure the
  muscle-on-tile pairs, AND the body grey #5B6472 on each tint (it is decoration, not text — say
  whether it needs a floor at all).
- The mask split: open the 512 px assets and your source renders side by side — did the
  luminance/redness thresholds lose the black outline seams between muscle segments, or leave
  red fringe in the body layer? Is the crop rule (body bbox + 8 %) giving the five one visual
  scale, or is the flexed arm smaller than the torsos?
- Single-scale PNG template assets: any reason to prefer 1x/2x/3x or PDF here? The largest render
  is 40 pt × AXL scale ≈ 60 pt × 3 = 180 px, well under 512.
- Item 11: no string or identifier changed (verify).

Do NOT run xcodebuild or simctl (the simulator is running the full suite). Do not modify source
files. Report by severity with file:line, or say "clear" in one paragraph. Write to
.scratch/ui-redesign/codex-review-12.md
