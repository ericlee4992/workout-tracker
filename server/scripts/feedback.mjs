#!/usr/bin/env node
// Public beta ticket 07: read testers' feedback. Runs wrangler against the production D1/R2 (`--local` for
// `wrangler dev`'s local copies). Nothing is written anywhere except a screenshot you ask for, always into
// server/.feedback (git-ignored).
//
//   node scripts/feedback.mjs list [--limit 20] [--local]
//   node scripts/feedback.mjs show <id> [--local]
//   node scripts/feedback.mjs screenshot <id> [--local]
//   node scripts/feedback.mjs delete <id> [--local]      (a tester's request; asks nothing, so check the ID first)
//   node scripts/feedback.mjs prune [--local]            (only the download clean-up)
//
// Every run first deletes downloaded screenshots 15 days old or more and, in production, those whose feedback no longer
// exists (deleted on request, with its account, or after the server's one-year retention). The privacy policy promises
// copies are gone within 30 days (ticket 08): keep downloads in server/.feedback (--local: .feedback-local), never
// elsewhere, keep this clean-up, and run `prune` at least every 15 days while any download exists (README).
//
// Feedback is tester data: do not paste it into the repository, an issue, or a chat.
import { execFileSync } from "node:child_process";
import { mkdirSync, readdirSync, rmSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const serverDir = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const args = process.argv.slice(2);
const command = args[0];
const flag = (name) => args.includes(name);
const option = (name, fallback) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};
const where = flag("--local") ? "--local" : "--remote";
// Separate folders, so a production run never prunes local downloads and a local key never touches a production copy.
const downloads = path.join(serverDir, where === "--remote" ? ".feedback" : ".feedback-local");
/** Half the policy's 30 days, inclusive: with `prune` run at least every 15 days, no copy outlives 30 (08e #1). */
const DOWNLOAD_PRUNE_AGE_MS = 15 * 24 * 60 * 60 * 1000;
const ID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

function wrangler(...rest) {
  return execFileSync("npx", ["wrangler", ...rest], { cwd: serverDir, encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] });
}

function query(sql) {
  const out = JSON.parse(wrangler("d1", "execute", "stacked", where, "--json", "--command", sql));
  return out[0]?.results ?? [];
}

function idArgument() {
  const id = args[1];
  if (!id || !ID.test(id)) {
    console.error("Give the feedback ID shown by `list` (a UUID).");
    process.exit(2);
  }
  return id;
}

const SELECT = "SELECT f.id, f.created_at, f.category, f.message, f.app_version, f.build, f.system_version, f.model, " +
  "f.screenshot_key, f.screenshot_bytes, a.display_name, a.email " +
  "FROM feedback f LEFT JOIN accounts a ON a.id = f.account_id";

function who(row) {
  return row.email ? `${row.display_name ?? "(no name)"} <${row.email}>` : "signed out";
}

/**
 * Downloaded screenshots 15 days old or more — always, even when the database cannot be reached — and then, in production,
 * those whose feedback row is gone. If that query fails, the unexpired files are kept (nothing proves them deleted).
 */
function pruneDownloads() {
  let files;
  try { files = readdirSync(downloads); } catch { return; }
  const cutoff = Date.now() - DOWNLOAD_PRUNE_AGE_MS;
  const remove = (name, why) => {
    rmSync(path.join(downloads, name), { force: true });
    console.error(`Deleted the downloaded copy ${name} (${why})`);
  };
  const kept = [];
  for (const name of files) {
    if (statSync(path.join(downloads, name)).mtimeMs <= cutoff) remove(name, "15 days"); else kept.push(name);
  }
  if (kept.length === 0 || where !== "--remote") return;
  let live;
  try {
    live = new Set(query("SELECT screenshot_key FROM feedback WHERE screenshot_key IS NOT NULL")
      .map((r) => path.basename(r.screenshot_key)));
  } catch {
    console.error("Could not check downloaded copies against the database; kept them for the next run.");
    return;
  }
  for (const name of kept) if (!live.has(name)) remove(name, "its feedback is gone");
}

if (["list", "show", "screenshot", "delete", "prune"].includes(command)) pruneDownloads();

switch (command) {
  case "list": {
    const limit = Number.parseInt(option("--limit", "20"), 10);
    if (!Number.isInteger(limit) || limit < 1 || limit > 500) { console.error("--limit is 1–500"); process.exit(2); }
    for (const row of query(`${SELECT} ORDER BY f.created_at DESC LIMIT ${limit}`)) {
      const when = new Date(row.created_at).toLocaleString("en-US", { timeZone: "America/New_York" });
      const first = row.message.split("\n")[0];
      console.log(`${row.id}  ${when}  ${row.category.padEnd(5)}  ${row.screenshot_key ? "📎" : "  "}  ${who(row)}`);
      console.log(`    ${first.length > 100 ? `${first.slice(0, 100)}…` : first}`);
    }
    break;
  }
  case "show": {
    const id = idArgument();
    const [row] = query(`${SELECT} WHERE f.id = '${id}'`);
    if (!row) { console.error("No such feedback."); process.exit(1); }
    console.log(`${row.category} · ${new Date(row.created_at).toLocaleString("en-US", { timeZone: "America/New_York" })} (New York)`);
    console.log(`From: ${who(row)}`);
    console.log(`App ${row.app_version} (${row.build}) · iOS ${row.system_version} · ${row.model}`);
    console.log(row.screenshot_key ? `Screenshot: ${row.screenshot_bytes} bytes — fetch it with \`screenshot ${row.id}\`` : "No screenshot");
    console.log("");
    console.log(row.message);
    break;
  }
  case "screenshot": {
    const id = idArgument();
    const [row] = query(`SELECT screenshot_key FROM feedback WHERE id = '${id}'`);
    if (!row?.screenshot_key) { console.error("That feedback has no screenshot."); process.exit(1); }
    mkdirSync(downloads, { recursive: true, mode: 0o700 });
    const file = path.join(downloads, path.basename(row.screenshot_key));
    wrangler("r2", "object", "get", `stacked-feedback/${row.screenshot_key}`, where, "--file", file);
    console.log(file);
    break;
  }
  case "delete": {
    // The screenshot first: if that fails the row stays, so running this again finishes the job.
    const id = idArgument();
    const [row] = query(`SELECT screenshot_key FROM feedback WHERE id = '${id}'`);
    if (!row) { console.error("No such feedback."); process.exit(1); }
    if (row.screenshot_key) {
      wrangler("r2", "object", "delete", `stacked-feedback/${row.screenshot_key}`, where);
      rmSync(path.join(downloads, path.basename(row.screenshot_key)), { force: true });
    }
    query(`DELETE FROM feedback WHERE id = '${id}'`);
    console.log(`Deleted feedback ${id}${row.screenshot_key ? " and its screenshot" : ""}.`);
    break;
  }
  case "prune":
    break;
  default:
    console.error("Usage: node scripts/feedback.mjs list [--limit N] | show <id> | screenshot <id> | delete <id> | prune  [--local]");
    process.exit(2);
}
