Round 3 of the CI/T6 review, same checkout, branch ericlee4992/ci-and-t6. Round 2 (codex-review-ci-b.md) was clear,
but the branch CI run you flagged as pending, 43590959069 on b228c97c, **failed**: 2 of 1370 tests —
`WorkoutActivityContentTests.aColdPlusFifteenAttachesTheRuntimeAndReachesTheWatch` (`feed.sent.last == .some(nil)`,
:342) and `WorkoutActivityProviderTests.aRestSentBeforeAProviderRunsReachesItOnceStarted` (`feeds.last?.sent.last == end`,
:107), each after ~338 s. Read the run yourself (`gh run view 43590959069 --log`).

Author's diagnosis: wall-clock, not an app bug. On the runner each test waited minutes for the main actor; their rests
were 90 s (startRest default; provider test `now + 90`). The app correctly ignores Skip on a rest that has run out
(`WorkoutActivityCommands.swift:105-110`, `end > .now`) and replays only a running rest to a new phase's provider
(`WorkoutActivityProvider.swift:125`, `restEndsAt > .now`) — exactly the two failing assertions. Fix f6d76f08 (tests only):
startRest's default is 3600 s and the provider test's rest ends at now + 3600, with comments. I checked that no assertion
in these files depends on the 90 s length (RestTimerService.add does not clamp; heart-rate cap 240 is not read by those
tests) and that WatchLinkTests' rest broadcast uses a fixed date with no expiry check.

Evidence: WT-Floodlight, build/dd-ci: build-for-testing exit 0 (build/results/r3-build.log); WorkoutActivityContentTests +
WorkoutActivityProviderTests on the Unit plan 21/21 passed (build/results/r3-activity.xcresult). New branch CI run
43592530127 on f6d76f08 dispatched (in progress when written).

Review `git diff 6f8a9d52..HEAD`. Check the diagnosis against the code (is any failure a real ordering bug rather than
expiry?), whether other tests in the Unit plan share the same short-rest/expiry dependence and would flake on the runner
the same way (name them), and that nothing else regressed. Build and rerun the two classes yourself on WT-Redesign-2
(EB4328A1-87BD-4850-A3B2-A6E604701F1C), derived data /tmp/wt-ci-codex; no UI run. Read run 43592530127's result if it has
finished. Do not push or trigger workflows. Modify nothing but work-record/dev-speed/codex-review-ci-c.md, ending with
exactly "Verdict: clear" or "Verdict: not clear".
