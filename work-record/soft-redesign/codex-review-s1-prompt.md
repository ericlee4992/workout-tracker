# Codex review — soft-redesign S1 (Soft look app-wide)

You are the independent reviewer; Claude implemented. This is a new ticket series (the Soft redesign, Phase 1 of the
Soft + nutrition plan); please put the earlier design-proposal work in this terminal aside. Checkout
`/Users/ericlee06/orca/workspaces/Health App/UI_design`, branch `ericlee4992/soft-01-look`.

Review: `git diff fc2390c..44043c5` (S1 only; `fc2390c` is `main`).

Read first: `work-record/soft-redesign/issues/01-soft-look.md` (scope, acceptance, progress) and
`work-record/soft-redesign/spec.md`; D67 (new, and its amendment for the icon and greys) and D59 in
`docs/DECISIONS.md`; AGENTS.md. The approved design is the prototype at tag `design/soft-approved-2026-11-07`
(not in `main`): compare with `git show design/soft-approved-2026-11-07:DesignPrototype/Sources/Look/SoftLook.swift`,
`…/Look/Look.swift` (`LookFonts.soft`, near the end), `…/Look/Components/Surfaces.swift` (the Soft branches at the
`origin == .soft` checks), `…/Screens/Live/LiveWorkoutScreen.swift` (`liveLook` for Soft) and
`…/Prototype/ProposalAccent.swift` (`withAccent(.mono, live:)`). The prototype's components are older copies of the
app's plus other study looks; only its Soft-specific parts were ported.

Check in particular:
1. **Fidelity to the approved Soft look**: token values (light and dark), fonts, radii/spacing, lifted cards, the warm
   wash, the live workout's look (Mono, flat, quiet outlines). Anything the prototype's Soft did that the port missed,
   or anything changed beyond it (the deliberate change: deeper text greys for contrast, recorded in D67).
2. **The ink rest slab**: with the Mono action ink in light mode, is every live-colour element on the slab still
   visible (ring, Skip, anything else drawn with `look.live`/`look.action` on `slab`)? Is the `liveOnSlab` override
   applied only where the slab is ink (not on the light glass bars of the `.floodlight` id)?
3. **Leftovers**: any violet, SF Pro Expanded/Black, serif or rounded face still reachable in the app or the widget;
   any place that hard-codes a colour that no longer fits (e.g. text on `action`, which is now ink/flood instead of
   violet — `onAction` pairs, tinted controls via AccentColor, `Menu` labels, toggles).
4. **Behaviour unchanged**: no layout, string, identifier or stored-data change (`StoreFormatGuardTests`), no logic
   touched by the mechanical font edits.
5. **Tests**: `SoftLookContrastTests` — sound measurements (UIColor resolution of opacity colours, the pairs chosen),
   anything important not covered.
6. Icon (`scripts/render-app-icon.py`, the three PNGs) and docs (D67, ticket).

Run yourself on **WT-iPhone27** `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B` (Claude is using WT-Floodlight), with paths
under `/tmp/codex-s1/`: `xcodebuild … build`, and `-only-testing:WorkoutTrackerTests/SoftLookContrastTests
-only-testing:WorkoutTrackerTests/MuscleMapAssetTests -only-testing:WorkoutTrackerTests/StoreFormatGuardTests`; report
exit codes and the xcresult counts. The user deferred the capture suites and core-flow UI classes until more of Phase 1
is built — skip those, but say what you would run. Do not modify files other than the report; do not commit or push.

Write `work-record/soft-redesign/codex-review-s1.md`: findings numbered P1/P2/P3 with file:line, failure scenario and
fix; end with exactly `Verdict: clear` or `Verdict: not clear`.
