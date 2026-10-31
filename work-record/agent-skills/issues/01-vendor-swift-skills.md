# 01 — Add the SwiftUI Pro and SwiftData Pro agent skills

Type: tooling (agent instructions only; no app code)
Status: **Codex round 1: 1 finding (P2), fixed; round 2 pending** (2026-10-31)
Implementer: Claude; Reviewer: Codex.
Branch: `ericlee4992/swift-pro-skills` (off `main` `57a5764`), checkout `…/Health App/swift-pro-skills`.

## Request (the user, 2026-10-31)

"Are there any skills particularly useful for building our current app? Can you search" →
"yes add the swiftdata pro and swiftui pro. How could we actually start using it or applying it to our project"

## Acceptance criteria

- [x] `swiftui-pro` and `swiftdata-pro` copied unchanged from upstream into `.claude/skills/`, each with its
      MIT `LICENSE`; every file read before copying (Markdown, an icon, Codex `agents/openai.yaml`; no scripts or hooks).
- [x] `.agents/skills/` symlinks to both, like `ios-design`, so Codex reads the same files.
- [x] AGENTS overrides for the conflicts below, in Task-specific guides.
- [x] DEVELOPMENT records the source, pinned commits and the update procedure.
- [ ] Codex review clear.
- [ ] Merged to `main` (the user's go-ahead).

## Conflicts found and how AGENTS resolves them

| Skill text | Project rule | Override |
|---|---|---|
| SwiftUI Pro: "Target Swift 6.4"; strict concurrency; "never use GCD". SwiftData Pro: "Target Swift 6.2" | `SWIFT_VERSION = 5.0` | Keep Swift 5 mode and existing concurrency style |
| SwiftUI Pro `resizability.md`: iPhone Duo, iPad windows, size classes | iPhone portrait (AGENTS) | Only when a ticket asks |
| SwiftData Pro `core-rules.md`: explicit delete rules, "most commonly `.cascade`" | Frozen history; `Models.swift` uses `.nullify` toward `ExerciseEntry`/`Workout` | Keep each relationship's existing rule: catalog/context links into history `.nullify`; owned rows `.cascade` (D47) |
| SwiftData Pro: "nearly always … a specific migration schema" | DEVELOPMENT migration/backup checks | Schema changes follow DEVELOPMENT |
| SwiftUI Pro `design.md`: shared constants, avoid `.caption`, hard-coded padding | `ios-design` skill | `ios-design` decides fonts, spacing, colour |
| SwiftUI Pro `views.md`: one type per file, extract every `some View` helper | Targeted diffs per ticket | Report as separate findings, outside the ticket's diff |

SwiftData Pro's CloudKit rules (no `@Attribute(.unique)`/`#Unique`, defaults or optionals, optional relationships)
match AGENTS exactly.

## Survey (2026-10-31): what else was considered

- **rshankras/claude-code-apple-skills** (164 skills): current, but several examples use `@Attribute(.unique)`;
  its CloudKit generator bridges `CKRecord` by hand instead of SwiftData's CloudKit store; overlaps our ios-design,
  ticket and review workflows; the plugin install tracks `main` unpinned. Useful later as reference only:
  `security/privacy-manifests`, `ios/accessibility-audit`, `release-review`, App Store skills.
- **expo/skills**: React Native/Expo only; `expo-data-fetching` claims "ANY network request". Not applicable.
- **twostraws/Swift-Testing-Agent-Skill**: good fit (97 Swift Testing files); not added yet — the user chose two.
- **dadederk/iOS-Accessibility-Agent-Skill**: deep VoiceOver/Dynamic Type guidance; large (~5,700 lines); optional.
- **AvdLee SwiftUI Expert**: overlaps SwiftUI Pro, 10k+ lines plus Python Instruments scripts.
- **Swift concurrency skills** (Hudson, AvdLee): push Swift 6 migration; skipped.
- **Simulator/xcodebuild skills**: DEVELOPMENT already holds this project's build/test procedures.

## Verification

Docs/agent-instructions only → DEVELOPMENT verification scope: links and consistency, no app build or tests.
Results recorded under Comments.

## Comments

### Codex round 1 (2026-10-31) — [report](../codex-review-01.md)

One P2: the AGENTS delete-rule override ("`.nullify` toward logged workouts and sets") was too broad — `Workout.entries`,
`ExerciseEntry.sets` and the other owned rows deliberately `.cascade` (D47). Fixed: AGENTS now says to keep each
relationship's rule in `Domain/Models.swift`, naming the `.nullify` catalog/context links and the `.cascade` owned rows
(checked against every `deleteRule` in `Models.swift`). Codex otherwise confirmed: 27/27 vendored files byte-identical to
the pinned upstream commits, no scripts/hooks, symlinks/links/anchors resolve, `git diff --check` exit 0.
