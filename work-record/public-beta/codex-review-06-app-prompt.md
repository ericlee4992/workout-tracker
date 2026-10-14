Review public-beta ticket 06's **app half** in /Users/ericlee06/orca/workspaces/Health App/public-beta, branch
ericlee4992/beta-06-ai-proxy-app: `git diff main..HEAD` (main = 0998e40). The ticket is
work-record/public-beta/issues/06-ai-proxy.md — read *Scope*, *Acceptance*, *App half — UI-first stage*, *App half —
wiring* and *Deployed checks*. Spec: work-record/public-beta/spec.md → *AI through the server*; decisions D60 (and the
D53/D56/D58 rules it keeps: consent flags, editable proposals, confirmation, catalog rules). The server half was cleared
in codex-review-06d and is unchanged; its contract is server/README.md → *Endpoints* / *AI* and server/src/ai.ts.

What changed: the three AI flows (Scan Machine, Ask AI for Templates, New Model's "Suggest exercises with AI") now call
`POST /v1/ai/{flow}` with the signed-in session through `Domain/AIServerClient.swift` instead of OpenAI with a device
key; every entry point reads the account (`TerraAccess.ready/client`); the Settings key field, `AskAIKeyStore`,
`TerraClient`, `AskAIKeyHint` and the app's copies of the instructions/schemas are removed; a launch-time purge deletes
an older build's keychain key; the user-approved screens and strings (the ticket's table) are in place.

Check, against the code, its callers and the server's actual behaviour:
1. **Request contract:** each flow's body matches what server/src/ai.ts accepts (field names, UUID case, `loadType`
   values, `muscleGroup` omission/empty, the routine request as `JSONEncoder` writes it — `heightCm`/`weightKg`
   optional), nothing else is sent (no model, instructions, schema or key), the 75 s timeout vs the server's 60 s,
   `{result}` read back into the unchanged decoders and validation (`EquipmentIdentification.validated`,
   `AIRoutine.validated`, `ExerciseProposalAPI.parse`) — the app must still trust nothing from the server.
2. **Errors and copy:** every server status/code maps to the approved line (ticket table); the over-limit line's
   extra `GET /v1/ai/usage`; cancellation stays cancellation (no error shown after Cancel/dismissal); the routine error
   step's split and the scan error step's "continue manually" rewrite still read correctly with the new lines.
3. **Session lifecycle:** a 401 from any flow signs the phone out only if that session is still current
   (`invalidate(token:)`), and the UI then shows Sign In; signing in from the scan sheet / routine / New Model / Ask AI
   sheet lands back in a usable state; no stale request can write after sign-out or dismissal.
4. **Key removal:** no OpenAI key path left in the app (production or tests), the purge's keychain query matches the
   item older builds wrote (`AskAIKeyStore` in `git show main:WorkoutTracker/Features/Gyms/AskAIKeyStore.swift`), and
   it never runs under UI tests; the legacy Anthropic client is test-fixture-only and reads no key.
5. **Fixtures/isolation:** the `-uiTestTerra` fixture still answers signed out (no sample account) and the sample
   account decides when present; UI tests never reach the network or keychain.
6. **Standards and spec:** comments vs callers, approved strings used exactly, accessibility identifiers the tests
   read, AGENTS/DEVELOPMENT conventions, the verification scope chosen (ticket) — is it enough for the change?
   Acceptance items still open (the phone's live smoke) are stated as open, not claimed.

Claude's evidence (read the artifacts yourself; root /tmp/wt-floodlight/results/06app/): `build2.log`/`build3.log`;
`unit2.xcresult` + `unit2.log` (986/986, WT-iPhone27); `cap-ld.xcresult` (light/Default captures) and
`cap-rest.xcresult` (dark/Default passed; the two AX runs failed only at the New Model step, since split out);
`ui1.xcresult` + `ui1.log` + `ui1.status` — the targeted UI run (AskAI, FloodlightAIAccess, FloodlightAIRoutine,
FloodlightScan, FloodlightSettings, FloodlightProfile, FloodlightGyms, ScanMachineLabel), which may still be running
when you start: read `ui1.status` (`exit N`) when present. The deployed checks' figures are in the ticket.

Do not run builds, simulators or devices, and do not call the deployed server; modify nothing but your report. Write
the report to work-record/public-beta/codex-review-06-app.md with separate Standards and Spec sections, findings ranked
P1–P3 with file:line, ending with exactly "Verdict: clear" or "Verdict: not clear".
