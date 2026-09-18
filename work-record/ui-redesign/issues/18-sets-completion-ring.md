# 18 — Completed-sets ring matches the count

Type: task
Status: resolved — user confirmed the ring actually works; no app fix required

## Request and scope

The user's real phone capture shows `18/18 sets` with a partially filled neutral ring.
The ring must represent the same fraction as its adjacent count, including a fully closed
ring when all existing sets are complete and an empty ring when no sets exist.
Preserve ticket 16's composition, size, colour, copy, accessibility count and rest timer.
No schema change or phone install is authorized by this ticket.

Branch: `ericlee4992/sets-completion-ring`, base `e51695b`.
Checkout: `/Users/ericlee06/orca/workspaces/Health App/sets-completion-ring`.

## Design contract

In the logging state this screen exists so the user can complete a set in one tap; the eye
lands on the set row. In the resting state the eye lands on the pinned rest countdown.
The header's small neutral sets ring is supporting state, paired with its numeric count.

```
Cancel             Workout                 Finish
Gym                elapsed          ring N/M sets
Heart rate / zone / calories
Exercise card and set rows                   largest block
Add Exercise / Add by Machine
Rest countdown / +15s / Skip                  pinned while resting
```

This is a correctness fix within the accepted design, with no structural alternatives.
Tells: containers deliberate (existing grouped cards); chips deliberate (gym/context);
all-caps deliberate (existing set-table labels); middle-dot metadata deliberate (existing
sensor line); accent density deliberate (accepted completion state and rest actions);
equal-weight blocks deliberate (existing set rows); phone-sized website absent; content
above fold deliberate (existing header and live metrics); picker as primary absent;
default-size-only absent once matching default/AccessibilityL captures pass.

## Diagnosis and verification

Source inspection confirms the text and `ProgressRing` already use the same local completed
and total counts. This does not yet establish why the pixels lag the text. A UI reproduction
must exercise completion, adding a draft row and completing it while capturing the ring.
Do not change counting semantics to compensate for an unproven rendering cause.

Planned gates: focused rendering reproduction at default/AccessibilityL; Debug build;
full local UI suite; independent Claude code and visual review. Shared `ProgressRing` also
serves the draining rest timer and finish summary, so any shared change must verify both.

## Separate cardio discussion (not implementation)

The user wants live gym cardio (timer, heart rate, calories and distance) AND outdoor runs
and rides with GPS routes. They are considering a lifting/cardio start choice and cardio
added during lifting. Proposed direction: one workout containing strength and cardio
segments, with direct lifting/cardio starts and mixed sessions. No final flow or scope is
approved. D15's strength-only restriction is reopened for design discussion; SPEC and the
stored model remain unchanged until the feature's behavior is agreed. Indoor distance
source, pause/resume, per-segment summaries and HealthKit activity representation need design.

## Running reproduction

Initial detached runner PID **87880**, script `work-record/ui-redesign/results/18/run-repro.sh`.
Log `repro.log`, result `repro.xcresult`, actual exit file `repro-exit.txt` in the same
directory. Derived data `/tmp/wt-ticket18-derived`; base product source `e51695b`, with
only diagnostic UI-test additions. The test samples the actual rendered ring at 36 angles
so a correct accessibility count cannot mask an incomplete stroke.

## Reproduction checkpoint

The first diagnostic test build failed because a query was called on an element; fixed the
new test driver only. Retry PID **88419**, `run-repro-2.sh` / `repro-2.log` /
`repro-2.xcresult` / `repro-2-exit.txt`: actual exit **0**, **1 test passed**. It completed
1/1, added a second draft (1/2), completed 2/2 and checked the actual ring pixels at both
complete states. The reported defect did **not** reproduce. No app source has changed.

Next reproduction adds 18 sets with the header offscreen, then scrolls back and minimises /
resumes. User was asked whether the phone's ring stayed incomplete after waiting or revisiting
the header; answer pending. Do not claim a cause or fix from the passing short-session test.

Cardio update: the user explicitly selected **one saved workout with separate lifting and
cardio sections**, and asked to see design screens before implementation. Native throwaway
design branch `ericlee4992/cardio-design-prototype` has its own ticket at
`work-record/cardio-design/issues/01-design-discussion.md`. Gym + outdoor GPS scope remains.

## Answer

The user checked the ring and replied: “it actually works.” Close the report without a
product change. The diagnostic UI run passed 1/1, including pixel checks at 1/1 and 2/2.
The proposed longer-session test was not run; diagnostic test source was removed from the
branch after the user's confirmation. Original logs/results remain locally at the paths
above. No product source, schema, build on the phone or ring behavior changed.

Cardio design remains active independently on `ericlee4992/cardio-design-prototype`.
