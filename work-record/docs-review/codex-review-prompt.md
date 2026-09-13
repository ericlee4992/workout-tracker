You are cross-reviewing work written by a different agent (Claude), per this repo's T6 rule in
CLAUDE.md: every change is reviewed by an agent that did not write it. Read CLAUDE.md first.

SCOPE: two docs-only commits on `main`.

  0cdcd19  Docs: milestone 4 shipped; correct the plan of record
  43ee775  Docs: the 7-day profile expiry, and how it actually presents

Start with `git show 0cdcd19` and `git show 43ee775`.

Claude's claim in 0cdcd19 is that docs/STATE.md was FALSE: its "what to do next" list called
progress charts "the next unbuilt milestone", when charts actually shipped inside milestone 8
(ticket 01, 2026-08-26) and the as-entered tooltip landed in 4eb5486 (2026-08-29).

WHAT I NEED FROM YOU, in priority order:

1. VERIFY THE CLAIMS ARE TRUE, against code and git history rather than against other docs.
   - Are progress charts really implemented? Where?
     (Claude cites WorkoutTracker/Features/History/ExerciseProgressView.swift.)
   - Does SPEC milestone 4 say "Swift Charts; normalized axes, as-entered tooltips" -- and is
     EACH of those three things actually built? Normalized axes are D25. If any part of
     milestone 4 is NOT built, the new text ("Nothing in milestone 4 remains") is itself false
     and that is the most important thing you can find.
   - Is the 7-day profile expiry story in 43ee775 accurate and reproducible from the evidence?

2. DID THE EDIT INTRODUCE NEW FALSE STATEMENTS? Check every factual assertion added in the
   diffs, including dates, commit hashes, file paths and test counts.

3. FIND WHAT CLAUDE MISSED. Sweep docs/STATE.md and docs/SPEC.md for OTHER stale or false
   claims. STATE.md is the file a cold agent session is told to read FIRST, so a wrong sentence
   there costs real hours. Known-suspicious areas worth checking:
   - the "561 unit + 25 UI green" figure (nobody re-ran the suite today)
   - the Status section's description of which branches/commits are current
   - anything describing milestone 5 (dropped 2026-08-29) or milestone 6 (half done)
   - claims about what is installed on the phone
   Verify counts by looking at the test target rather than trusting the number.

4. JUDGEMENT: is the rewritten milestone-4 entry actually CLEARER for a cold agent, or does it
   bury the lede? Say so plainly if the prose is worse.

CONSTRAINTS:
- Do NOT modify any file. This is a read-only review; report only.
- Be adversarial. A review that finds nothing is a review that failed.
- Rank findings most severe first. For each: file, what is claimed, what is actually true, and
  the evidence (command or file:line) that settles it.
