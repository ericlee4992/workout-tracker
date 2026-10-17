// Ticket 15 (codex-review-15 #1, #2): feedback.mjs's argument parsing and note rule. `npm run test:scripts`; plain
// `node --test`, outside the Workers test pool (the name does not match vitest's *.test.* pattern on purpose).
import assert from "node:assert/strict";
import { test } from "node:test";
import { MAX_NOTE_LENGTH, noteProblem, parseArgs } from "./feedback-args.mjs";

const ID = "11111111-1111-4111-8111-111111111111";

test("--local anywhere is never taken for the command, the ID or a note word", () => {
  for (const argv of [
    ["--local", "done", ID, "fixed", "in", "build", "7"],
    ["done", "--local", ID, "fixed", "in", "build", "7"],
    ["done", ID, "--local", "fixed", "in", "build", "7"],
    ["done", ID, "fixed", "in", "build", "7", "--local"],
    ["done", ID, "fixed", "in", "--local", "build", "7"],
  ]) {
    assert.deepEqual(parseArgs(argv), {
      local: true, command: "done", id: ID, rest: ["done", ID, "fixed", "in", "build", "7"], note: "fixed in build 7",
    }, argv.join(" "));
  }
});

test("without --local it is production, and a missing note is empty", () => {
  assert.deepEqual(parseArgs(["reopen", ID]), { local: false, command: "reopen", id: ID, rest: ["reopen", ID], note: "" });
  assert.equal(parseArgs(["wontfix", ID, "  not planned  "]).note, "not planned");
});

test("a note is one line: CR, LF and the Unicode line and paragraph separators are refused", () => {
  for (const note of ["a\nb", "a\rb", "a\u2028b", "a\u2029b", "a\u0085b", "a\vb", "a\fb"]) {
    assert.ok(noteProblem(note), JSON.stringify(note));
  }
  assert.equal(noteProblem(`fixed in build 7 — it's "quoted"'); DROP TABLE feedback; --`), null);
});

test("a note is at most 200 characters, counted as characters, not bytes", () => {
  assert.equal(noteProblem("é".repeat(MAX_NOTE_LENGTH)), null);
  assert.equal(noteProblem("😀".repeat(MAX_NOTE_LENGTH)), null);
  assert.ok(noteProblem("x".repeat(MAX_NOTE_LENGTH + 1)));
  assert.ok(noteProblem("😀".repeat(MAX_NOTE_LENGTH + 1)));
});
