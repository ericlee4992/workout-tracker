import { AuthError } from "./apple";
import { newID } from "./crypto";
import type { Deps, Env } from "./env";
import { readBodyBytes } from "./http";

// Public beta ticket 07: POST /v1/feedback. Multipart form fields: category, message, appVersion, build,
// systemVersion, model, and an optional `screenshot` file (JPEG or PNG, at most 5 MB). Signed in (a bearer session)
// or out. Limits per New York day: 10 signed out per address, 30 per account, 500 in all.

export const MAX_MESSAGE_LENGTH = 4_000;
export const MAX_SCREENSHOT_BYTES = 5 * 1024 * 1024;
/** The screenshot plus the text fields and the multipart framing; anything larger is refused while streaming. */
export const MAX_FEEDBACK_BODY_BYTES = MAX_SCREENSHOT_BYTES + 64 * 1024;
export const SIGNED_OUT_DAILY_LIMIT = 10;
export const ACCOUNT_DAILY_LIMIT = 30;
/** Everyone together: bounds what a spread-out flood can store in a day (R2's free tier is 10 GB). */
export const GLOBAL_DAILY_LIMIT = 500;
/** An upload's key is queued for deletion this far ahead; its row insert removes it (far past any request's life). */
export const UPLOAD_GRACE_MS = 60 * 60 * 1000;
/** R2's most keys per delete call (Workers API), and so the sweep's batch. */
export const R2_DELETE_BATCH = 1_000;

const CATEGORIES = new Set(["bug", "idea", "other"]);
const DETAIL_PATTERNS: Record<string, RegExp> = {
  appVersion: /^[0-9A-Za-z.\-]{1,32}$/,
  build: /^[0-9A-Za-z.\-]{1,32}$/,
  systemVersion: /^[0-9.]{1,16}$/,
  model: /^[A-Za-z0-9,._\- ]{1,40}$/,
};

/** The calendar day in America/New_York (the app's day for every daily limit, D60). */
export function newYorkDay(ms: number): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "America/New_York", year: "numeric", month: "2-digit", day: "2-digit" })
    .format(new Date(ms));
}

/** User-perceived characters, as the app counts them (Swift `String.count`). */
export function characterCount(text: string): number {
  let n = 0;
  for (const _ of new Intl.Segmenter("en", { granularity: "grapheme" }).segment(text)) n++;
  return n;
}

/** The message as stored: trimmed; 1–4,000 characters; no control characters other than tab and line breaks. */
export function cleanMessage(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const message = value.trim();
  if (message.length === 0 || /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(message)) return null;
  return characterCount(message) <= MAX_MESSAGE_LENGTH ? message : null;
}

/** The image type from the file's own first bytes (never the declared type); null for anything else. */
export function sniffImage(bytes: Uint8Array): "image/jpeg" | "image/png" | null {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "image/jpeg";
  const png = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes.length >= 8 && png.every((b, i) => bytes[i] === b)) return "image/png";
  return null;
}

/**
 * The signed-out limit's key: an HMAC of the day and the address under a key derived from TOKEN_ENC_KEY. IPv4 is
 * small enough to hash exhaustively, so a plain hash would be reversible; with the key it is not, and with the day in
 * it one day's key cannot be linked to the next. Null when the server has no key (signed-out feedback then fails).
 */
async function addressKey(env: Env, address: string, day: string): Promise<string | null> {
  if (!env.TOKEN_ENC_KEY) return null;
  const secret = new TextEncoder().encode(`feedback-ip-v1:${env.TOKEN_ENC_KEY}`);
  const key = await crypto.subtle.importKey("raw", secret, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${day}|${address}`)));
  return `ip:${[...mac].map((b) => b.toString(16).padStart(2, "0")).join("")}`;
}

const UPSERT_COUNT = "ON CONFLICT(key) DO UPDATE SET count = CASE WHEN day = excluded.day THEN count + 1 ELSE 1 END, " +
  "day = excluded.day RETURNING count";

/** Counts one submission attempt against `key` for `day`; returns the count including this one. */
async function bump(env: Env, key: string, day: string): Promise<number> {
  const row = await env.DB.prepare(`INSERT INTO feedback_limits (key, day, count) VALUES (?, ?, 1) ${UPSERT_COUNT}`)
    .bind(key, day).first<{ count: number }>();
  return row?.count ?? Number.MAX_SAFE_INTEGER;
}

/**
 * The account's counter, written only while the account exists (codex-review-07 #4): a request authenticated just
 * before its account's deletion must not recreate a row naming the deleted account. Null when the account is gone.
 */
async function bumpAccount(env: Env, accountID: string, day: string): Promise<number | null> {
  const row = await env.DB.prepare(
    `INSERT INTO feedback_limits (key, day, count) SELECT ?, ?, 1 WHERE EXISTS (SELECT 1 FROM accounts WHERE id = ?) ${UPSERT_COUNT}`)
    .bind(`account:${accountID}`, day, accountID).first<{ count: number }>();
  return row ? row.count : null;
}

interface Parsed {
  category: string;
  message: string;
  details: { appVersion: string; build: string; systemVersion: string; model: string };
  screenshot: { bytes: Uint8Array; type: "image/jpeg" | "image/png" } | null;
}

async function parse(request: Request): Promise<Parsed> {
  const contentType = request.headers.get("content-type") ?? "";
  if (!/^multipart\/form-data;\s*boundary=/i.test(contentType)) throw new AuthError("unsupported_media_type", 415);
  const bytes = await readBodyBytes(request, MAX_FEEDBACK_BODY_BYTES);
  let form: FormData;
  try {
    form = await new Request("https://feedback.invalid/", { method: "POST", headers: { "content-type": contentType }, body: bytes })
      .formData();
  } catch {
    throw new AuthError("malformed_form", 400);
  }
  const category = form.get("category");
  if (typeof category !== "string" || !CATEGORIES.has(category)) throw new AuthError("invalid_category", 400);
  const message = cleanMessage(form.get("message"));
  if (!message) throw new AuthError("invalid_message", 400);
  const details = {} as Parsed["details"];
  for (const [name, pattern] of Object.entries(DETAIL_PATTERNS)) {
    const value = form.get(name);
    if (typeof value !== "string" || !pattern.test(value)) throw new AuthError("invalid_details", 400);
    details[name as keyof Parsed["details"]] = value;
  }
  const file = form.get("screenshot");
  let screenshot: Parsed["screenshot"] = null;
  if (file !== null) {
    if (typeof file === "string") throw new AuthError("invalid_screenshot", 400);
    if (file.size > MAX_SCREENSHOT_BYTES) throw new AuthError("screenshot_too_large", 413);
    const data = new Uint8Array(await file.arrayBuffer());
    const type = sniffImage(data);
    if (!type) throw new AuthError("invalid_screenshot", 400);
    screenshot = { bytes: data, type };
  }
  if (form.getAll("screenshot").length > 1) throw new AuthError("invalid_screenshot", 400);
  return { category, message, details, screenshot };
}

/**
 * Stores one submission. Validation first (a malformed request costs no quota), then the limits, then the screenshot
 * to R2, then the row — inserted only while its account still exists, so a submission racing the account's deletion
 * leaves nothing behind (its object is removed at once, or by the sweep).
 */
export async function submitFeedback(request: Request, env: Env, deps: Deps, accountID: string | null) {
  const input = await parse(request);
  const now = deps.now();
  const day = newYorkDay(now);
  // Counted per attempt that passes validation (README): a refusal by the global limit still counts for the sender.
  if (accountID) {
    const used = await bumpAccount(env, accountID, day);
    if (used === null) throw new AuthError("unauthorized", 401);
    if (used > ACCOUNT_DAILY_LIMIT) throw new AuthError("rate_limited", 429);
  } else {
    const key = await addressKey(env, request.headers.get("cf-connecting-ip") ?? "unknown", day);
    if (!key) throw new AuthError("server_not_configured", 503);
    if ((await bump(env, key, day)) > SIGNED_OUT_DAILY_LIMIT) throw new AuthError("rate_limited", 429);
  }
  // Its own code, so the app does not tell one tester they sent too many when everyone did.
  if ((await bump(env, "global", day)) > GLOBAL_DAILY_LIMIT) throw new AuthError("feedback_full", 429);

  const id = newID(deps.random);
  let key: string | null = null;
  if (input.screenshot) {
    key = `feedback/${id}.${input.screenshot.type === "image/png" ? "png" : "jpg"}`;
    // Queued before the put, so an object whose row never lands (a crash, a failed insert) is still deleted.
    await env.DB.prepare("INSERT INTO screenshot_deletions (key, due_at) VALUES (?, ?)").bind(key, now + UPLOAD_GRACE_MS).run();
    await env.FEEDBACK.put(key, input.screenshot.bytes, { httpMetadata: { contentType: input.screenshot.type } });
  }
  const values = [
    id, accountID, input.category, input.message, input.details.appVersion, input.details.build,
    input.details.systemVersion, input.details.model, key, input.screenshot?.type ?? null,
    input.screenshot?.bytes.byteLength ?? null, now,
  ];
  const columns = "id, account_id, category, message, app_version, build, system_version, model, " +
    "screenshot_key, screenshot_type, screenshot_bytes, created_at";
  // Signed in: only while the account exists (a deletion may have committed since authentication).
  const insert = accountID
    ? env.DB.prepare(`INSERT INTO feedback (${columns}) SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? ` +
        "WHERE EXISTS (SELECT 1 FROM accounts WHERE id = ?)").bind(...values, accountID)
    : env.DB.prepare(`INSERT INTO feedback (${columns}) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`).bind(...values);
  // One transaction: the row and the un-queueing of its key land together or not at all.
  const [inserted] = await env.DB.batch(key
    ? [insert, env.DB.prepare(
        "DELETE FROM screenshot_deletions WHERE key = ? AND EXISTS (SELECT 1 FROM feedback WHERE screenshot_key = ?)")
        .bind(key, key)]
    : [insert]);
  if ((inserted!.meta.changes ?? 0) === 0) {
    if (key) {
      await env.FEEDBACK.delete(key);
      await env.DB.prepare("DELETE FROM screenshot_deletions WHERE key = ?").bind(key).run();
    }
    throw new AuthError("unauthorized", 401);
  }
  return { id };
}

/** Deletes `keys` from R2 in batches the API accepts; false when any batch failed (the queue keeps them). */
async function deleteObjects(env: Env, keys: string[]): Promise<boolean> {
  let ok = true;
  for (let i = 0; i < keys.length; i += R2_DELETE_BATCH) {
    try {
      await env.FEEDBACK.delete(keys.slice(i, i + R2_DELETE_BATCH));
    } catch {
      ok = false;
    }
  }
  return ok;
}

/**
 * Right after an account deletion: deletes the screenshots that deletion queued. Only when every batch succeeded are
 * the queue entries removed; otherwise the hourly sweep retries them (R2 deletes are idempotent).
 */
export async function deleteClaimedScreenshots(env: Env, claim: string) {
  const rows = await env.DB.prepare("SELECT key FROM screenshot_deletions WHERE claim = ?").bind(claim).all<{ key: string }>();
  const keys = rows.results.map((r) => r.key);
  if (keys.length === 0) return;
  if (await deleteObjects(env, keys)) {
    await env.DB.prepare("DELETE FROM screenshot_deletions WHERE claim = ?").bind(claim).run();
  } else {
    console.error("feedback screenshots left for the sweep", { count: keys.length });
  }
}

/**
 * The hourly clean-up, bounded whatever the bucket holds (codex-review-07 #3): at most one batch of due keys — those
 * a deletion queued and uploads whose row never landed — in one R2 call and three D1 queries; the rest wait for the
 * next run, oldest first. Old rate-limit counters are removed separately, so one failing never blocks the other.
 */
export async function sweepFeedback(env: Env, deps: Deps) {
  const now = deps.now();
  let removed = 0;
  try {
    // A key whose row exists is never deleted from R2 (defence in depth: the insert un-queues it atomically).
    const due = (await env.DB.prepare(
      "SELECT d.rowid AS rid, d.key, d.due_at, EXISTS (SELECT 1 FROM feedback f WHERE f.screenshot_key = d.key) AS live " +
      "FROM screenshot_deletions d WHERE d.due_at <= ? ORDER BY d.due_at, d.key LIMIT ?")
      .bind(now, R2_DELETE_BATCH).all<{ rid: number; key: string; due_at: number; live: number }>()).results;
    if (due.length > 0) {
      const doomed = due.filter((r) => !r.live).map((r) => r.key);
      if (await deleteObjects(env, doomed)) {
        // Exactly the rows read (D1 binds at most 100 parameters, so not by key list): up to the last in the read order,
        // and no row inserted since the read — a new row's rowid is above every existing one.
        const last = due[due.length - 1]!;
        const maxRowID = Math.max(...due.map((r) => r.rid));
        await env.DB.prepare(
          "DELETE FROM screenshot_deletions WHERE rowid <= ? AND (due_at < ? OR (due_at = ? AND key <= ?))")
          .bind(maxRowID, last.due_at, last.due_at, last.key).run();
        removed = doomed.length;
      }
    }
  } catch (error) {
    console.error("feedback screenshot sweep failed", error instanceof Error ? error.name : "unknown");
  }
  try {
    await env.DB.prepare("DELETE FROM feedback_limits WHERE day < ?").bind(newYorkDay(now)).run();
  } catch (error) {
    console.error("feedback counter clean-up failed", error instanceof Error ? error.name : "unknown");
  }
  if (removed > 0) console.log("feedback sweep", { removed });
  return { removed };
}
