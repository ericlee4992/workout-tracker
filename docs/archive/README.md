# Historical handoffs

These snapshots preserve prior progress, decisions as understood at the time, and incident
details. They contain superseded instructions and conflicting historical states. Start with
[current STATE](../STATE.md); consult a snapshot when investigating a past change or incident.
Stable decisions remain in [DECISIONS](../DECISIONS.md), detailed ticket records in
[`work-record/`](../../work-record/), and reusable procedures in [DEVELOPMENT](../DEVELOPMENT.md).

| Snapshot | Provenance |
|---|---|
| [STATE before cardio UI refinements](STATE-2026-09-18-before-cardio-ui-refinements.md) | Byte-for-byte copy at `21ef98f`, before the user confirmed indoor distance with AirPods Pro 3 and requested presentation changes |
| [STATE before cardio handoff](STATE-2026-09-18-before-cardio-handoff.md) | Byte-for-byte copy at `b845a3a`, after successful installation and the disconnected launch attempts, before the clean-session checkpoint |
| [STATE before cardio implementation](STATE-2026-09-18-before-cardio-implementation.md) | Byte-for-byte copy at `14982e7`, after direction B was selected and before the optional-device policy and build were authorized |
| [STATE before cardio design](STATE-2026-09-17-before-cardio-design.md) | Byte-for-byte copy at `e51695b`, before the user requested gym/outdoor cardio designs and confirmed the sets ring works |
| [STATE before Graft handoff](STATE-2026-09-17-before-graft-handoff.md) | Byte-for-byte copy at `f89dcde`, after ticket 17 was installed and launched, before the Graft/new-session checkpoint |
| [STATE before Codex setup](STATE-2026-09-17-before-codex-setup.md) | Byte-for-byte copy of `docs/STATE.md` at `9b9feef`, before the 2026-09-17 documentation reorganization; includes handoffs through ticket 16 and historical environment notes |
| [CLAUDE before Codex setup](CLAUDE-2026-09-17-before-codex-setup.md) | Byte-for-byte copy of `CLAUDE.md` at `9b9feef`; the shared guide has moved to root `AGENTS.md` |

Snapshots keep their original text. Backtick paths inside them are relative to the repository
root, as they were before archival. Record new decisions and status in their current source
of truth rather than editing a snapshot to look current. Git retains the earlier revisions too.
