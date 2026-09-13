# Codex review — scanner accuracy 05 round 3 + ticket 06 (T6)

Boundary: `6242324...HEAD` (`e5ef77c`). Verdict: **do not merge yet**.

## Medium

- `WorkoutTracker/Domain/LabelCrop.swift:38` still admits a crop that is the frame for practical purposes. For a 2000×800 image, `CGRect(x: 0.0725, y: 0.04, width: 0.9, height: 0.92)` expands and clamps to `(1, 0, 1999, 800)`: all but one pixel column, or 99.95% of the photo. The guard at lines 41–42 requires only one edge to differ from the frame, so it closes exact equality but not ticket 05's privacy invariant in substance. The replacement fixture itself is sound: `ScanFixture.plateRegion` is exactly the rendered 1600×500 plate on its 2000×800 canvas, its margin leaves canvas out, and `ScanMachineLabelSheet.swift:257` passes that same region to Vision.

- The durable disclosure is still not exact. `docs/SPEC.md:28` and `docs/DECISIONS.md:62` say ticket 05 sends only the plate *inside* the framing box, but `WorkoutTracker/Domain/LabelCrop.swift:31` deliberately adds an 8% margin outside it. D53 at `docs/DECISIONS.md:62` also says ticket 06 sends the plate's lines, while the wire body at `WorkoutTracker/Domain/ExerciseProposal.swift:70` sends three separate plate fields—brand, model, and lines—before the full exercise id/name/muscle-group list. The opt-in timing is now stated correctly, but what leaves the phone is not yet described exactly for either ticket.

## Low

- `docs/STATE.md:5` introduces “Codex round 2 verdict: CODEX-VERDICT-PLACEHOLDER” even though the round-2 verdict is known and lines 27–31 summarize it. This conflicts with `CLAUDE.md:3`, which makes STATE the cold-start source of truth, and is new in this fix commit.

The other requested closures are sound by inspection: Cancel, Add, and `onDisappear` cancel and release `proposalTask`, and its post-await cancellation guard prevents a cancelled task from touching sheet state; the fixture ledger asserts 0 for a preselected plate and 0-before/1-after for the happy path; the timeout fixture produces the plain timeout note; and the keyboard wait plus exact field-value assertion only harden the gym helper. No `xcodebuild` or `simctl` command was run; the recorded 697/697, 7/7, and 2/2 verification was accepted as supplied.
