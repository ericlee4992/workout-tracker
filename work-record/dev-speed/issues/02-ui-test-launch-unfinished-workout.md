# 02 — UI tests: an unfinished Outdoor Run at launch blocks the scan button

Type: task
Status: needs-triage
Found in: N12 review (2026-11-12/13), `work-record/nutrition/codex-review-n12.md` rounds 1–4.

## What happens

On WT-iPhone27 (`47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`), `BarcodeSearchUITests.testABarcodeNotFoundOffersTheLabelScanAndManualAdd`
and `KoreanFoodUITests.testAKoreanBarcodeOffersIsThisItAndTheLoggedFoodOpensNextTime` sometimes never reach the camera:
the app, launched with `-uiTestReset -uiTestDesignSample -uiTestFoodSample -uiTestTerra`, shows an **active "Outdoor
Run +1" workout** (Today's "Resume workout") within ~5 s of launch, before any tap; the scan button is then not hittable
(XCTest: "Computed hit point {-1, -1}"), and after the tap **Choose Cardio** is on screen. Seen in parallel and serial
runs (Codex: serial and a warm single run failed; the author's serial pair passed), never on WT-Floodlight.

Evidence: author `/tmp/n12data/ui-r4-004412.xcresult` (13/14) and `/tmp/n12data/ui-r4s-005159.xcresult` (2/2);
Codex `/tmp/codex-n12-r4/` (`ui.xcresult`, `ui-serial.xcresult`, `ui-warm.xcresult`, timeline frames
`author-before-5.png` … `author-after-22.png`). Local `/tmp` paths do not survive a reboot.

## To find out

Where the active Outdoor Run comes from although `-uiTestReset` removes the store directory: launch arguments, the
design-sample/fixture seeding (time of day — the failures were around midnight), restored presentation or workout
state kept outside the store (UserDefaults, app group, Live Activity), or the simulator itself. Use the recording's
timeline, not only the final hierarchy. Not caused by N12 (it changes no Today, workout, cardio, launch or reset code).

## Comments
