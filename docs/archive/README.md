# Historical handoffs

These snapshots preserve prior progress, decisions as understood at the time, and incident
details. They contain superseded instructions and conflicting historical states. Start with
[current STATE](../STATE.md); consult a snapshot when investigating a past change or incident.
Stable decisions remain in [DECISIONS](../DECISIONS.md), detailed ticket records in
[`work-record/`](../../work-record/), and reusable procedures in [DEVELOPMENT](../DEVELOPMENT.md).

| Snapshot | Provenance |
|---|---|
| [STATE before whole-app redesign proposal](STATE-2026-09-24-before-redesign-proposal.md) | Byte-for-byte copy at `a0364f2`; signing/device acceptance retained while user requests visuals before a redesign |
| [STATE before September 24 handoff](STATE-2026-09-24-before-session-handoff.md) | Byte-for-byte copy at `40f3f65`; September 22 installation and full prior verification/context |
| [STATE before AI follow-up installation](STATE-2026-09-22-before-followup-install.md) | Byte-for-byte copy at `7e96a82`; verified/merged follow-up awaiting installation |
| [STATE before template visibility/scanning follow-up](STATE-2026-09-22-before-template-followup.md) | Byte-for-byte copy at `5a894da`; September 20 AI installation, verification and still-open device acceptance |
| [STATE before AI gym implementation](STATE-2026-09-20-before-ai-gym.md) | Byte-for-byte copy at `17e42a0`; installed cardio/unit build, prior verification and unresolved physical acceptance |
| [STATE before September 20 session handoff](STATE-2026-09-20-before-session-handoff.md) | Byte-for-byte copy at `6102b5d`, after the installed unit-system update and targeted-verification policy |
| [STATE before app unit systems/indoor cleanup](STATE-2026-09-19-before-cardio-units.md) | Byte-for-byte copy at `e457493`, before Metric/U.S. customary defaults and removal of automatic indoor source details |
| [STATE before arrowless Start/outdoor cleanup](STATE-2026-09-19-before-compact-start-outdoor.md) | Byte-for-byte copy at `0e16a8c`, before the user reopened the stacked Start choice and requested removal of the outdoor GPS section |
| [STATE before Start capsule restoration](STATE-2026-09-19-before-start-capsules.md) | Byte-for-byte copy at `62f9469`, after UI refinements were installed and before the user rejected the text-only start buttons |
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
