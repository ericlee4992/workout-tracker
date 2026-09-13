Round 2 (T6) of machine-deletion ticket 01. Round-1 review:
work-record/machine-deletion/codex-review-01.md. The response is in
issues/01-delete-machines.md under "Codex review 01 — response". Boundary of the fixes:
d35e725..HEAD on branch delete-machines (one commit).

Scope: are the round-1 items closed exactly — `DeleteMachineMenuItem` shared by both context
menus; the restore unit test asserting defaultUnit, defaultPresetID, label, model, the live
relationship and the three snapshot fields after the round trip; the mid-workout UI test logging
a set on the machine (a catalog-model machine now), deleting it, asserting the entry and its
80 × 8 survive on the workout screen, finishing, and finding the exercise in History; the alert
Cancel scoped to app.alerts. And whether the fixes introduced anything new.

Do NOT run xcodebuild or simctl; review by inspection. Verification at this head is in the
ticket (698 unit, MachineDeletionUITests 2/2, full UI suite 46/46 on d35e725).

If closed, say "clear" in one paragraph. Otherwise report by severity with file:line. Do not
modify source files. Write to work-record/machine-deletion/codex-review-01b.md
