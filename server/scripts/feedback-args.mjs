// Ticket 15: feedback.mjs's argument parsing and note rule, kept apart so `node --test` can run them without wrangler
// (scripts/feedback-args.node-test.mjs; codex-review-15 #1, #2).

export const MAX_NOTE_LENGTH = 200;

/**
 * `--local` may stand anywhere; it is removed before the command, ID and note are read, so it is never taken for one of
 * them (codex-review-15 #1). The note is every word after the ID.
 */
export function parseArgs(argv) {
  const local = argv.includes("--local");
  const rest = argv.filter((a) => a !== "--local");
  return { local, command: rest[0], id: rest[1], rest, note: rest.slice(2).join(" ").trim() };
}

/** Line breaks of any kind, including the Unicode line and paragraph separators (codex-review-15 #2). */
const LINE_BREAK = /[\r\n\v\f\u0085\u2028\u2029]/;

/** The note's problem, or null when it is fine: one line of at most MAX_NOTE_LENGTH characters (code points). */
export function noteProblem(note) {
  return LINE_BREAK.test(note) || [...note].length > MAX_NOTE_LENGTH
    ? `A note is one line of at most ${MAX_NOTE_LENGTH} characters.`
    : null;
}
