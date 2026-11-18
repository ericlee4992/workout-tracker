---
name: review-round
description: Run one round of this project's independent Codex review (T6) — a ticket's first review, a fix round after findings, or a release review — from the self-check through the verdict and its record.
---

# Review round

One round = one brief, one report, one verdict. The rules live in AGENTS.md (*Workflow and verification*: T6, the
self-check, "What the reviewer reruns", one Codex session) and the agent mechanics in
[tools-paseo](../../../docs/agents/tools-paseo.md); this is the order of work.

## 1. Self-check

Reread your whole diff as a hostile reviewer against **every** defect class in AGENTS.md's self-check list; fix what
you find, each fix with its regression test. Rerun the affected scope.

Done when: every class has been looked at, and the ticket's evidence ends in the Verified / Not verified / Known flaky
block with real counts, exit codes and xcresult paths.

## 2. Checkpoint

Commit and push the branch; the ticket's progress notes say what is in this round.

Done when: `git status` is clean and the remote branch has the tip you will name in the brief.

## 3. Brief

Write the brief as a file — the Write tool, or a heredoc with a quoted delimiter so backticks stay literal:

| Round | Brief | Report |
|---|---|---|
| A ticket's first | `work-record/<feature>/codex-review-<NN>-prompt.md` | `…/codex-review-<NN>.md` |
| Fix rounds | `…/codex-review-<NN>b-prompt.md`, then `c`, `d` … | `…/codex-review-<NN>b.md` … |
| A release | `work-record/release/codex-review-<version>-build-<build>-prompt.md` | `…/codex-review-<version>-build-<build>.md` |

**A first brief** carries:

- who implemented, the repository path, the branch, and the **exact diff range** (`<base commit>..HEAD`);
- *Read first*: AGENTS.md, the ticket, the decisions (D-numbers) and SPEC sections the change touches;
- **numbered review questions specific to this change**, each naming its files and the failure scenarios you fear
  most — data safety, stored format and privacy first when they apply;
- what to run, by AGENTS.md's "What the reviewer reruns"; the reviewer's simulator — **WT-Redesign-2**
  (`EB4328A1-87BD-4850-A3B2-A6E604701F1C`) with `-derivedDataPath /tmp/wt-<ticket>-codex` — while yours (WT-Floodlight,
  WT-iPhone27) stay untouched; your xcresult paths, to inspect;
- the rules: modify nothing but the report; no phone, Apple account, backups, deploys or desktop control;
- the report path and format: numbered findings with severity P0–P3, file:line, the failure scenario and a suggested
  fix; what it ran, with counts and exit codes; a last line that is exactly `Verdict: clear` or `Verdict: not clear`.

**A fix-round brief** is short: "same rules as `<round-1 brief>`", the previous report, the diff since the reviewed
commit, each finding → its fix → its regression test, and which runs are due (UI tests only when the fix changed UI
behaviour or UI test code). A finding you disagree with stays in the brief with your reasoning; the reviewer decides.

Done when: the brief names a diff range that matches the pushed tip, and every question points at real files.

## 4. Send

Find the one Codex agent (tools-paseo: `list_agents`; create one only when it is gone, stuck, near its limit or in
another workspace, and record a new one's id in STATE). Send one line: "Read and follow `<brief>`. Branch `<branch>` at
`<sha>`. Write `<report>` ending with the exact Verdict line."

Done when: the send is queued and the agent is running.

## 5. Wait

The verdict line in the report file is the signal; a finish notification is a hint. Watch the file with a background
until-loop on `^Verdict: (clear|not clear)$`. While Codex builds and tests, run no builds or tests of your own — the
Mac throttles under two heavy runs. Read and answer any permission request (`respond_to_permission`).

Done when: the report's last line is a verdict.

## 6. Read and record

Read the whole report yourself, including what it ran: counts and exit codes that look like real runs. Then add
`### Codex round <N> — <clear | not clear (findings)>` to the ticket (the release record for a release): a link to
the report, each finding with its fix and regression test, and the verification of the fixes. Commit and push.

- **Not clear:** fix every finding, rerun the affected scope, and start the next round at step 1 with the next letter.
- **Clear:** the round is over; next is the merge (AGENTS.md) or the release's next step.

Done when: the ticket records this round's verdict and the branch is pushed.
