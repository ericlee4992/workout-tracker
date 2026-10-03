#!/usr/bin/env node
// Public beta ticket 06: the AI off switch and a look at today's use. Writes to the production D1 (`--local` for
// `wrangler dev`'s copy); a pause applies to the next request — no app build, no deploy.
//
//   node scripts/ai.mjs status [--local]                 # global switch, paused accounts, today's use per account
//   node scripts/ai.mjs pause [--account <id>] [--local]  # everyone, or one account
//   node scripts/ai.mjs resume [--account <id>] [--local]
import { execFileSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const serverDir = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const args = process.argv.slice(2);
const command = args[0];
const where = args.includes("--local") ? "--local" : "--remote";
const accountIndex = args.indexOf("--account");
const account = accountIndex >= 0 ? args[accountIndex + 1] : null;
const ID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

if (accountIndex >= 0 && !(account && ID.test(account))) {
  console.error("--account takes an account ID (a UUID, as `status` shows it).");
  process.exit(2);
}

function query(sql) {
  const out = execFileSync("npx", ["wrangler", "d1", "execute", "stacked", where, "--json", "--command", sql],
    { cwd: serverDir, encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] });
  return JSON.parse(out)[0]?.results ?? [];
}

const day = new Intl.DateTimeFormat("en-CA", { timeZone: "America/New_York", year: "numeric", month: "2-digit", day: "2-digit" })
  .format(new Date());

switch (command) {
  case "pause":
    query(account
      ? `INSERT OR IGNORE INTO ai_account_pauses (account_id, created_at) SELECT id, ${Date.now()} FROM accounts WHERE id = '${account}'`
      : "INSERT INTO ai_settings (key, value) VALUES ('paused', '1') ON CONFLICT(key) DO UPDATE SET value = '1'");
    console.log(account ? `AI paused for ${account}.` : "AI paused for everyone.");
    break;
  case "resume":
    query(account
      ? `DELETE FROM ai_account_pauses WHERE account_id = '${account}'`
      : "INSERT INTO ai_settings (key, value) VALUES ('paused', '0') ON CONFLICT(key) DO UPDATE SET value = '0'");
    console.log(account ? `AI resumed for ${account} (the global switch still applies).` : "AI resumed for everyone (per-account pauses stay).");
    break;
  case "status": {
    const paused = query("SELECT value FROM ai_settings WHERE key = 'paused'")[0]?.value === "1";
    console.log(`Global: ${paused ? "PAUSED" : "on"}`);
    for (const row of query("SELECT account_id FROM ai_account_pauses")) console.log(`Paused account: ${row.account_id}`);
    console.log(`Today (${day}, New York):`);
    for (const row of query(`SELECT account_id, flow, successes, attempts FROM ai_usage WHERE day = '${day}' ORDER BY account_id, flow`)) {
      console.log(`  ${row.account_id}  ${row.flow.padEnd(16)} ${row.successes} done, ${row.attempts} attempts`);
    }
    break;
  }
  default:
    console.error("Usage: node scripts/ai.mjs status | pause [--account <id>] | resume [--account <id>]  [--local]");
    process.exit(2);
}
