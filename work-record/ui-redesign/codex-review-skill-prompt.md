Review (T6) of a new agent skill, not app code: .claude/skills/ios-design/ — SKILL.md,
REFERENCE.md, REVIEW.md — plus the pointer added to CLAUDE.md. Branch ios-design-skill (main..HEAD).

Context: the UI redesign (tickets 01–09, `work-record/ui-redesign/`, D54) shipped and the user said
"the design is not there" and the Start screen "seems a bit off". This skill is meant to make the
NEXT pass compose screens instead of styling them. You built the design system it describes.

Scope:
1. Accuracy: every number and token in REFERENCE.md against the HIG (as you know it) and
   `Features/Design/Theme.swift` / `Assets.xcassets/Colors`; every component and haptic name
   exists as written; the reference-app descriptions are flagged as from memory — is anything in
   them wrong?
2. The rules in SKILL.md: are any of them wrong for iOS 26 / SwiftUI, contradictory with D54 or
   the copy policy, or unenforceable (no way to tell whether a screen passes)?
3. The process: does each step end on a checkable completion criterion? Is anything missing that
   would have caught the first pass's failures (three equal blocks on Start, a picker styled as
   a button, AXL truncation found only by capture)?
4. The tells list: fair, and is anything on it actually a good pattern here?
5. REVIEW.md: could you grade a screen with it, by inspection, and disagree with the author only
   about facts? Any item that is taste rather than a check?
6. Length: anything that is a no-op an agent would do anyway, or exposition that should be cut?

Do NOT run xcodebuild or simctl. Report by severity with file:line, or say "clear" in one paragraph.
Do not modify files. Write to work-record/ui-redesign/codex-review-skill.md
