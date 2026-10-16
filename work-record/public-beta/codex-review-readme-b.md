# Codex independent review — public README refresh, round 2

Reviewed 2026-10-16 on `ericlee4992/beta-08-testers`, HEAD `ea6edf74fab551d19fdd369505e60a16754b9078`, using `git diff dc778dd..HEAD -- README.md`. The working tree was initially clean. Followed `codex-review-readme-b-prompt.md` and its round-one restrictions, checked all eight prior findings, and reread the whole README. Parallel Standards and Spec audits reused the previously inspected source where unchanged.

No new findings. Each numbered entry below records the earlier finding as resolved; the severity identifies the resolved issue. Only this report was edited. No network requests, builds, app/server tests, wrangler commands, phone/account access or desktop control were performed.

## Standards

1. **P2 — Xcode compatibility: resolved.** `README.md:64–65` identifies Xcode 27 as the verified toolchain and explicitly discloses the Xcode 26 hosted-runner compilation issue, linking STATE. It no longer implies an unqualified successful Xcode 26 build. No further correction requested.

2. **P3 — Simulator selection: resolved.** `README.md:74–80` explains how to list available simulators and uses a simulator-ID placeholder in the test destination. The command no longer depends on the developer's `WT-iPhone` name or its runtime resolution. No further correction requested.

3. **P3 — Generated Graft cache in the public layout: resolved.** The untracked, gitignored `graft/` cache is removed from the table (`README.md:90–101`). The remaining entries describe checked-in repository content. No further correction requested.

4. **P3 — Watch source called a placeholder: resolved.** `README.md:95` describes the companion's workout-session, heart-rate and phone-link implementation, while retaining the distinction that it has never been built/run and is not in the beta. This matches the source and recorded status. No further correction requested.

## Spec

5. **P2 — Prefill fallback and machine scope: resolved.** `README.md:12–16` now limits the machine-anchor statement to machine sets, acknowledges free-weight/bodyweight logging, and separates labeled history/record layers from same-machine prefill. It no longer claims that broader fallback history populates inputs. This agrees with `docs/SPEC.md:40–50`, `PreviousPerformance.swift:103–120` and the existing no-fallback-prefill test. No further correction requested.

6. **P2 — Shipping Apple Watch heart rate: resolved.** `README.md:42–44` describes phone-connected heart-rate sources and explicitly states that the Watch companion is written but not built or shipped. The feature description and folder table now agree with the beta's non-embedded Watch status. No further correction requested.

7. **P2 — Export of “everything”: resolved.** `README.md:45–47` describes workout-data exports, distinguishes fuller JSON with heart-rate series/routes from CSV's sets/cardio table, and removes “everything.” This matches the export implementation and approved policy's format distinction. No further correction requested.

8. **P3 — Absolute server nonreceipt claim: resolved.** `README.md:56–60` now promises no automatic workout upload and expressly includes information deliberately submitted through feedback. The full privacy-policy link remains. It no longer denies that voluntary submissions can contain workout information. No further correction requested.

## Verification

- The read-only README link/anchor check completed with exit **0**: **11 relative targets**, including all six image paths, and no failures. Scoped `git diff --check dc778dd..HEAD -- README.md` passed.
- Confirmed that app/server/Watch/widget source, the six screenshots, AGENTS and SPEC are unchanged since round one. The prior screenshot visual/privacy checks, PNG metadata inspection and catalog count verification therefore remain applicable; no new image or data exposure was introduced.
- Reread the remaining feature, privacy, build, layout, workflow and status text. No additional factual mismatch or newly exposed personal/tester/secret information was identified. No build or test-suite rerun was warranted for this wording-only revision. This clearance does not independently verify a new deployment or change the external-beta release gates recorded in STATE.

Standards: 0 open findings; all 4 prior findings resolved. Spec: 0 open findings; all 4 prior findings resolved.

Verdict: clear
