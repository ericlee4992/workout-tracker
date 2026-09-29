Round 2 of the independent review of ticket 12 (Cardio, plain Floodlight) on `ericlee4992/redesign-floodlight-cardio`
in `/tmp/wt-floodlight/cardio`. Your round-1 report is `work-record/redesign-floodlight/codex-review-12.md`; Claude's
response is the section "Codex review 12 — response (round 1)" in `work-record/redesign-floodlight/issues/12-cardio.md`,
with the round-2 verification under "Verification". The fixes are in the range `0fddd52..HEAD`.

Check that each of the eight findings is resolved without a regression, and review the fix code itself (the bound on
splits / markers / the ring, `CardioFormat.parse` / `isInvalidEntry` and the Distance sheet's typing cap, the live
distance figure's separate edit button on the Distance figure and on the ring, `CardioFormat.distance(0)`, the
snapshot key and cancellation, the stat-number figures, the split tail, the spoken split speed), the new tests
(`CardioReadoutTests`, the added `FloodlightCardioUITests` / `CardioUITests` assertions — could any pass vacuously?),
the splits fixture's second segment, and two changes found while looking at the retaken captures: the finished cards'
figure labels may wrap to two lines ("Entered distance"), and History hides "Workout details" when a cardio-only
workout has no tile left. Retaken captures: `work-record/redesign-floodlight/captures/12/`.

Same rules as round 1: do NOT run xcodebuild or simctl; modify nothing but the report. Report by severity with
file:line and a concrete failure case, or say "clear". Write the report to
`work-record/redesign-floodlight/codex-review-12b.md`.
