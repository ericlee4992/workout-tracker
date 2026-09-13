Round 4 (T6) of scanner-accuracy tickets 05 "Ask AI" + 06 "Suggest exercises with AI".
Round-3 review: work-record/scanner-accuracy/codex-review-05c.md. The response is in
issues/05-ask-ai-escalation.md under "Codex review 05c — response". Boundary of the fixes:
e5ef77c..HEAD on branch ask-ai (one commit).

Scope: are the three round-3 findings closed exactly —
1. `LabelCrop.maximumAreaShare` (a crop may cover at most 90 % of the photo's area). Is 90 %
   the right line — can a real portrait-phone box ever exceed it (LabelFramingBox: 94 % of the
   view width at 2:1, the preview aspect-fills a 3:4 photo)? Does the fixture plate still crop?
   The pinned cases in `PlateTranscriptionTests.noBoxMeansNothingToSend` and
   `LabelCropRenderingTests`.
2. The disclosures: SPEC line 28, D53, the scan sheet's Ask AI footer, `AskAISettingsSheet`'s
   footer, the New Model sheet's footer — do they now say exactly what leaves the phone for both
   tickets (box + 8 % margin, ≤ 9/10 of the photo; brand, model, lines + the exercise list)?
3. STATE's placeholder is gone and every round's verdict is named.
Also: the happy-path UI test no longer scrolls to the accept button before tapping Ask AI
(a tap on an off-screen row flaked once) — is the "nothing preselected" claim still proven
somewhere? And whether the fixes introduced anything new.

Do NOT run xcodebuild or simctl (the simulator is in use); review by inspection. Verification
at this head is in the ticket (full UI suite 44/44 on e5ef77c; AskAIUITests 7/7 and the unit
suite green here).

If closed, say "clear" in one paragraph. Otherwise report by severity with file:line. Do not
modify source files. Write to work-record/scanner-accuracy/codex-review-05d.md
