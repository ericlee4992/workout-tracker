import { env } from "cloudflare:test";
import { beforeEach, describe, expect, it } from "vitest";
import {
  ACCOUNT_DAILY_LIMIT, characterCount, GLOBAL_DAILY_LIMIT, MAX_FEEDBACK_BODY_BYTES, MAX_MESSAGE_LENGTH,
  MAX_SCREENSHOT_BYTES, newYorkDay, R2_DELETE_BATCH, SIGNED_OUT_DAILY_LIMIT, sweepFeedback, UPLOAD_GRACE_MS,
} from "../src/feedback";
import { count, harness, JPEG, PNG, type Harness } from "./helpers";

// Public beta ticket 07: POST /v1/feedback.
let h: Harness;
beforeEach(async () => {
  h = await harness();
});

interface Row {
  id: string; account_id: string | null; category: string; message: string; app_version: string; build: string;
  system_version: string; model: string; screenshot_key: string | null; screenshot_type: string | null;
  screenshot_bytes: number | null; created_at: number;
}
const rows = async () => (await env.DB.prepare("SELECT * FROM feedback ORDER BY created_at, id").all<Row>()).results;
const objects = async () => (await env.FEEDBACK.list()).objects.map((o) => o.key);
const errorOf = async (response: Response) => ((await response.json()) as { error: string }).error;

/** A JPEG-headed buffer of `size` bytes. */
function jpegOfSize(size: number): Uint8Array {
  const bytes = new Uint8Array(size);
  bytes.set(JPEG.subarray(0, 4));
  return bytes;
}

describe("storing feedback", () => {
  it("stores a signed-out submission with its details and no account", async () => {
    const response = await h.feedback({ fields: { category: "idea", message: "  Add supersets.\n" } });
    expect(response.status).toBe(201);
    const { id } = (await response.json()) as { id: string };
    const [row] = await rows();
    expect(row).toMatchObject({
      id, account_id: null, category: "idea", message: "Add supersets.", app_version: "0.1.0", build: "1",
      system_version: "27.0", model: "iPhone16,2", screenshot_key: null, created_at: h.clock.now,
    });
    expect(await objects()).toEqual([]);
  });

  it("stores the account of a signed-in submission", async () => {
    const { session } = await h.signIn();
    const account = await env.DB.prepare("SELECT id FROM accounts").first<{ id: string }>();
    expect((await h.feedback({ token: session })).status).toBe(201);
    expect((await rows())[0]!.account_id).toBe(account!.id);
  });

  it("keeps the IP address nowhere: not in the row, not readable in the counter", async () => {
    await h.feedback({ ip: "198.51.100.23" });
    const stored = JSON.stringify([await rows(), (await env.DB.prepare("SELECT * FROM feedback_limits").all()).results]);
    expect(stored).not.toContain("198.51.100.23");
    expect(stored).toMatch(/"ip:[0-9a-f]{64}"/);
  });

  it("stores a JPEG or PNG screenshot in R2 under the row's key, typed by its own bytes", async () => {
    expect((await h.feedback({ screenshot: { bytes: JPEG } })).status).toBe(201);
    expect((await h.feedback({ screenshot: { bytes: PNG, type: "image/jpeg", name: "x.jpg" } })).status).toBe(201);
    const [jpeg, png] = (await rows()).sort((a, b) => (a.screenshot_type! < b.screenshot_type! ? -1 : 1));
    expect(jpeg).toMatchObject({ screenshot_type: "image/jpeg", screenshot_bytes: JPEG.byteLength });
    expect(jpeg!.screenshot_key).toBe(`feedback/${jpeg!.id}.jpg`);
    expect(png).toMatchObject({ screenshot_type: "image/png", screenshot_key: `feedback/${png!.id}.png` });
    const object = await env.FEEDBACK.get(jpeg!.screenshot_key!);
    expect(new Uint8Array(await object!.arrayBuffer())).toEqual(JPEG);
    expect(object!.httpMetadata?.contentType).toBe("image/jpeg");
  });
});

describe("validation", () => {
  const invalid: [string, Parameters<Harness["feedback"]>[0], number, string][] = [
    ["an unknown category", { fields: { category: "praise" } }, 400, "invalid_category"],
    ["no category", { fields: { category: null } }, 400, "invalid_category"],
    ["no message", { fields: { message: null } }, 400, "invalid_message"],
    ["a blank message", { fields: { message: " \n\t " } }, 400, "invalid_message"],
    ["a message with a control character", { fields: { message: "hi\u0000there" } }, 400, "invalid_message"],
    ["a message over 4,000 characters", { fields: { message: "a".repeat(MAX_MESSAGE_LENGTH + 1) } }, 400, "invalid_message"],
    ["no app version", { fields: { appVersion: null } }, 400, "invalid_details"],
    ["a model with markup", { fields: { model: "<script>" } }, 400, "invalid_details"],
    ["a too-long build", { fields: { build: "1".repeat(33) } }, 400, "invalid_details"],
    ["a screenshot sent as text", { screenshot: "not a file" }, 400, "invalid_screenshot"],
    ["a GIF", { screenshot: { bytes: new TextEncoder().encode("GIF89a....."), type: "image/gif" } }, 400, "invalid_screenshot"],
    ["a 'JPEG' that is HTML", { screenshot: { bytes: new TextEncoder().encode("<html></html>"), type: "image/jpeg" } }, 400, "invalid_screenshot"],
  ];
  for (const [name, options, status, code] of invalid) {
    it(`refuses ${name}, storing nothing and spending no quota`, async () => {
      const response = await h.feedback(options);
      expect([response.status, await errorOf(response)]).toEqual([status, code]);
      expect([await count("feedback"), await count("feedback_limits"), (await objects()).length]).toEqual([0, 0, 0]);
    });
  }

  it("accepts exactly 4,000 characters, counted as the app counts them (an emoji is one)", async () => {
    const message = "💪🏽".repeat(MAX_MESSAGE_LENGTH);
    expect(characterCount(message)).toBe(MAX_MESSAGE_LENGTH);
    expect((await h.feedback({ fields: { message } })).status).toBe(201);
  });

  it("refuses a body that is not multipart", async () => {
    const response = await h.call("POST", "/v1/feedback", { body: { category: "bug", message: "hi" } });
    expect([response.status, await errorOf(response)]).toEqual([415, "unsupported_media_type"]);
  });

  it("refuses two screenshots", async () => {
    const form = new FormData();
    for (const [k, v] of Object.entries({ category: "bug", message: "m", appVersion: "1", build: "1", systemVersion: "27.0", model: "x" })) form.append(k, v);
    form.append("screenshot", new File([JPEG], "a.jpg"));
    form.append("screenshot", new File([JPEG], "b.jpg"));
    const { createHandler } = await import("../src/index");
    const response = await createHandler(h.deps)(new Request("https://stacked.test/v1/feedback", { method: "POST", body: form }), h.env);
    expect([response.status, await errorOf(response)]).toEqual([400, "invalid_screenshot"]);
    expect(await objects()).toEqual([]);
  });

  it("refuses an invalid or expired session instead of filing it as signed out", async () => {
    const bad = await h.feedback({ token: "x".repeat(43) });
    expect([bad.status, await errorOf(bad)]).toEqual([401, "unauthorized"]);
    const malformed = await h.feedback({ authorization: "Basic abc" });
    expect(malformed.status).toBe(401);
    expect(await count("feedback")).toBe(0);
  });
});

describe("size limits", () => {
  it("accepts a screenshot of exactly 5 MB", async () => {
    expect((await h.feedback({ screenshot: { bytes: jpegOfSize(MAX_SCREENSHOT_BYTES) } })).status).toBe(201);
    expect((await rows())[0]!.screenshot_bytes).toBe(MAX_SCREENSHOT_BYTES);
  });

  it("refuses a screenshot one byte over 5 MB", async () => {
    const response = await h.feedback({ screenshot: { bytes: jpegOfSize(MAX_SCREENSHOT_BYTES + 1) } });
    expect([response.status, await errorOf(response)]).toEqual([413, "screenshot_too_large"]);
    expect([await count("feedback"), (await objects()).length]).toEqual([0, 0]);
  });

  it("stops reading a body past the route's limit, declared or streamed", async () => {
    const big = jpegOfSize(MAX_FEEDBACK_BODY_BYTES + 1);
    const declared = await h.feedback({ screenshot: { bytes: big } });
    expect([declared.status, await errorOf(declared)]).toEqual([413, "body_too_large"]);
    let sent = 0;
    const stream = new ReadableStream<Uint8Array>({
      pull(controller) {
        if (sent > MAX_FEEDBACK_BODY_BYTES * 3) { controller.close(); return; }
        controller.enqueue(new Uint8Array(256 * 1024));
        sent += 256 * 1024;
      },
    });
    const { createHandler } = await import("../src/index");
    const streamed = await createHandler(h.deps)(new Request("https://stacked.test/v1/feedback", {
      method: "POST", headers: { "content-type": "multipart/form-data; boundary=x" }, body: stream,
      // @ts-expect-error -- workerd needs this for a streamed request body
      duplex: "half",
    }), h.env);
    expect(streamed.status).toBe(413);
    expect(sent).toBeLessThan(MAX_FEEDBACK_BODY_BYTES * 2);
  });

  it("the JSON routes keep their 64 KB limit", async () => {
    const { session } = await h.signIn();
    const response = await h.call("PUT", "/v1/profile", { token: session, raw: JSON.stringify({ displayName: "a".repeat(70 * 1024) }) });
    expect(response.status).toBe(413);
  });
});

describe("rate limits", () => {
  it(`allows ${SIGNED_OUT_DAILY_LIMIT} signed-out submissions a day per address, then refuses; another address is separate`, async () => {
    for (let i = 0; i < SIGNED_OUT_DAILY_LIMIT; i++) expect((await h.feedback({ ip: "203.0.113.9" })).status).toBe(201);
    const over = await h.feedback({ ip: "203.0.113.9" });
    expect([over.status, await errorOf(over)]).toEqual([429, "rate_limited"]);
    expect((await h.feedback({ ip: "203.0.113.10" })).status).toBe(201);
    expect(await count("feedback")).toBe(SIGNED_OUT_DAILY_LIMIT + 1);
  });

  it("resets at midnight in New York, not UTC", async () => {
    h.clock.now = Date.UTC(2026, 9, 3, 3, 30);  // 23:30 EDT on Oct 2
    expect(newYorkDay(h.clock.now)).toBe("2026-10-02");
    for (let i = 0; i < SIGNED_OUT_DAILY_LIMIT; i++) await h.feedback();
    expect((await h.feedback()).status).toBe(429);
    h.clock.now = Date.UTC(2026, 9, 3, 3, 59);  // still Oct 2 in New York, although Oct 3 in UTC
    expect((await h.feedback()).status).toBe(429);
    h.clock.now = Date.UTC(2026, 9, 3, 4, 1);   // 00:01 EDT on Oct 3
    expect((await h.feedback()).status).toBe(201);
  });

  it(`limits a signed-in account to ${ACCOUNT_DAILY_LIMIT} a day, whatever the address`, async () => {
    const { session } = await h.signIn();
    for (let i = 0; i < ACCOUNT_DAILY_LIMIT; i++) {
      expect((await h.feedback({ token: session, ip: `198.51.100.${i}` })).status).toBe(201);
    }
    expect((await h.feedback({ token: session, ip: "198.51.100.200" })).status).toBe(429);
    // Signed-out sending from the same address is its own budget.
    expect((await h.feedback({ ip: "198.51.100.0" })).status).toBe(201);
  });

  it(`stops everyone after ${GLOBAL_DAILY_LIMIT} submissions in a day`, async () => {
    await env.DB.prepare("INSERT INTO feedback_limits (key, day, count) VALUES ('global', ?, ?)")
      .bind(newYorkDay(h.clock.now), GLOBAL_DAILY_LIMIT).run();
    const response = await h.feedback({ ip: "192.0.2.1" });
    expect([response.status, await errorOf(response)]).toEqual([429, "feedback_full"]);
    expect(await objects()).toEqual([]);
  });

  it("signed-out feedback fails closed without the server key (no reversible address hash is ever stored)", async () => {
    const { createHandler } = await import("../src/index");
    const keyless = { ...h.env, TOKEN_ENC_KEY: undefined };
    const form = new FormData();
    for (const [k, v] of Object.entries({ category: "bug", message: "m", appVersion: "1", build: "1", systemVersion: "27.0", model: "x" })) form.append(k, v);
    const refused = await createHandler(h.deps)(new Request("https://stacked.test/v1/feedback", { method: "POST", body: form }), keyless);
    expect([refused.status, await errorOf(refused)]).toEqual([503, "server_not_configured"]);
  });
});


const FIELDS = { category: "bug", message: "m", appVersion: "1", build: "1", systemVersion: "27.0", model: "x" };
function form(withScreenshot = false): FormData {
  const data = new FormData();
  for (const [k, v] of Object.entries(FIELDS)) data.append(k, v);
  if (withScreenshot) data.append("screenshot", new File([JPEG], "a.jpg"));
  return data;
}

/** An R2 stand-in that enforces the production limit of 1,000 keys per delete and records every call. */
function fakeBucket(options: { failDeletes?: boolean } = {}) {
  const deletes: string[][] = [];
  const bucket = {
    async delete(keys: string | string[]) {
      const list = Array.isArray(keys) ? keys : [keys];
      if (list.length > R2_DELETE_BATCH) throw new Error(`R2 refuses ${list.length} keys`);
      if (options.failDeletes) throw new Error("R2 down");
      deletes.push(list);
    },
  } as unknown as R2Bucket;
  return { bucket, deletes };
}

/** Counts the D1 statements prepared (each is a query against Workers Free's 50 per invocation). */
function countingDB(db: D1Database) {
  const counter = { statements: 0 };
  const proxy = new Proxy(db, {
    get(target, prop) {
      if (prop === "prepare") return (sql: string) => { counter.statements++; return target.prepare(sql); };
      const value = Reflect.get(target, prop);
      return typeof value === "function" ? value.bind(target) : value;
    },
  });
  return { db: proxy as D1Database, counter };
}

const queued = async () => (await env.DB.prepare("SELECT key FROM screenshot_deletions ORDER BY key").all<{ key: string }>())
  .results.map((r) => r.key);

describe("account deletion covers feedback", () => {
  it("deletes the account's rows, screenshots and counter; signed-out feedback and other accounts' stay", async () => {
    const mine = await h.signIn("001234.apple-user");
    const theirs = await h.signIn("009999.other-user");
    await h.feedback({ token: mine.session, screenshot: { bytes: JPEG } });
    await h.feedback({ token: mine.session });
    await h.feedback({ token: theirs.session, screenshot: { bytes: PNG } });
    await h.feedback({ screenshot: { bytes: JPEG } });
    expect([await count("feedback"), (await objects()).length]).toEqual([4, 3]);
    expect(await queued()).toEqual([]);  // every landed upload un-queued its key

    const response = await h.call("DELETE", "/v1/account", { token: mine.session });
    expect(response.status).toBe(200);
    const left = await rows();
    expect(left).toHaveLength(2);
    const counters = await env.DB.prepare("SELECT COUNT(*) AS n FROM feedback_limits WHERE key LIKE 'account:%'").first<{ n: number }>();
    expect(counters!.n).toBe(1);  // only the other account's counter
    expect((await objects()).sort()).toEqual(left.map((r) => r.screenshot_key!).sort());
    expect(await queued()).toEqual([]);
  });

  it("a submission racing the deletion stores nothing — no row, no object, no counter naming the account (07 #4)", async () => {
    const { session } = await h.signIn();
    const account = await env.DB.prepare("SELECT id FROM accounts").first<{ id: string }>();
    // The deletion commits between the request's authentication and its writes.
    const { submitFeedback } = await import("../src/feedback");
    await h.call("DELETE", "/v1/account", { token: session });
    await expect(submitFeedback(new Request("https://stacked.test/v1/feedback", { method: "POST", body: form(true) }), h.env, h.deps, account!.id))
      .rejects.toMatchObject({ code: "unauthorized" });
    expect([await count("feedback"), (await objects()).length, (await queued()).length]).toEqual([0, 0, 0]);
    const named = await env.DB.prepare("SELECT COUNT(*) AS n FROM feedback_limits WHERE key = ?").bind(`account:${account!.id}`).first<{ n: number }>();
    expect(named!.n).toBe(0);
  });

  it("the insert racing the deletion (after the counter) removes its object at once", async () => {
    const { session } = await h.signIn();
    const account = await env.DB.prepare("SELECT id FROM accounts").first<{ id: string }>();
    const { submitFeedback } = await import("../src/feedback");
    // The account disappears after the counter was taken: drop it when the upload starts.
    const racing = { ...h.env, FEEDBACK: new Proxy(h.env.FEEDBACK, {
      get(target, prop) {
        if (prop === "put") return async (...args: Parameters<R2Bucket["put"]>) => {
          await h.call("DELETE", "/v1/account", { token: session });
          return target.put(...args);
        };
        const value = Reflect.get(target, prop);
        return typeof value === "function" ? value.bind(target) : value;
      },
    }) };
    await expect(submitFeedback(new Request("https://stacked.test/v1/feedback", { method: "POST", body: form(true) }), racing, h.deps, account!.id))
      .rejects.toMatchObject({ code: "unauthorized" });
    expect([await count("feedback"), (await objects()).length, (await queued()).length]).toEqual([0, 0, 0]);
  });

  it("deletes more than R2's 1,000 keys per call in batches (07 #5)", async () => {
    const { session } = await h.signIn();
    const account = await env.DB.prepare("SELECT id FROM accounts").first<{ id: string }>();
    await env.DB.prepare(
      "WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 1001) " +
      "INSERT INTO feedback (id, account_id, category, message, app_version, build, system_version, model, " +
      "screenshot_key, screenshot_type, screenshot_bytes, created_at) " +
      "SELECT 'f' || i, ?, 'bug', 'm', '1', '1', '27.0', 'x', 'feedback/f' || i || '.jpg', 'image/jpeg', 4, 0 FROM n")
      .bind(account!.id).run();
    const fake = fakeBucket();
    const { createHandler } = await import("../src/index");
    const response = await createHandler(h.deps)(new Request("https://stacked.test/v1/account",
      { method: "DELETE", headers: { authorization: `Bearer ${session}` } }), { ...h.env, FEEDBACK: fake.bucket });
    expect(response.status).toBe(200);
    expect(fake.deletes.map((d) => d.length)).toEqual([1000, 1]);
    expect(new Set(fake.deletes.flat()).size).toBe(1001);
    expect([await count("feedback"), (await queued()).length]).toEqual([0, 0]);
  });

  it("screenshots whose R2 delete fails at deletion stay queued and the sweep deletes them", async () => {
    const { session } = await h.signIn();
    await h.feedback({ token: session, screenshot: { bytes: JPEG } });
    const { createHandler } = await import("../src/index");
    const response = await createHandler(h.deps)(new Request("https://stacked.test/v1/account",
      { method: "DELETE", headers: { authorization: `Bearer ${session}` } }), { ...h.env, FEEDBACK: fakeBucket({ failDeletes: true }).bucket });
    expect(response.status).toBe(200);
    expect(await count("feedback")).toBe(0);
    expect([(await objects()).length, (await queued()).length]).toEqual([1, 1]);
    expect(await sweepFeedback(h.env, h.deps)).toEqual({ removed: 1 });
    expect([(await objects()).length, (await queued()).length]).toEqual([0, 0]);
  });
});

describe("the hourly sweep", () => {
  it("an upload whose row never landed is deleted once its grace has passed, not before", async () => {
    const failing = { ...h.env, DB: new Proxy(h.env.DB, {
      get(target, prop) {
        if (prop === "batch") return async () => { throw new Error("D1 unavailable"); };
        const value = Reflect.get(target, prop);
        return typeof value === "function" ? value.bind(target) : value;
      },
    }) };
    const { createHandler } = await import("../src/index");
    const response = await createHandler(h.deps)(new Request("https://stacked.test/v1/feedback",
      { method: "POST", headers: { "cf-connecting-ip": "203.0.113.1" }, body: form(true) }), failing);
    expect(response.status).toBe(500);
    expect([await count("feedback"), (await objects()).length, (await queued()).length]).toEqual([0, 1, 1]);
    h.clock.now += UPLOAD_GRACE_MS - 1000;
    expect(await sweepFeedback(h.env, h.deps)).toEqual({ removed: 0 });
    h.clock.now += 2000;
    expect(await sweepFeedback(h.env, h.deps)).toEqual({ removed: 1 });
    expect([(await objects()).length, (await queued()).length]).toEqual([0, 0]);
  });

  it("never deletes an object whose row exists, even if its key is queued", async () => {
    await h.feedback({ screenshot: { bytes: JPEG } });
    const key = (await rows())[0]!.screenshot_key!;
    await env.DB.prepare("INSERT INTO screenshot_deletions (key, due_at) VALUES (?, 0)").bind(key).run();
    expect(await sweepFeedback(h.env, h.deps)).toEqual({ removed: 0 });
    expect(await objects()).toEqual([key]);
    expect(await queued()).toEqual([]);
  });

  it("is bounded: at most 12 statements and one R2 call per run, continuing where it stopped (07 #3)", async () => {
    await env.DB.prepare(
      "WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 2501) " +
      "INSERT INTO screenshot_deletions (key, due_at) SELECT 'feedback/k' || printf('%05d', i) || '.jpg', i FROM n").run();
    const fake = fakeBucket();
    const { db, counter } = countingDB(h.env.DB);
    const bounded = { ...h.env, DB: db, FEEDBACK: fake.bucket };
    const perRun: number[] = [];
    for (let run = 0; run < 3; run++) {
      const before = counter.statements;
      await sweepFeedback(bounded, h.deps);
      perRun.push(counter.statements - before);
    }
    expect(Math.max(...perRun)).toBeLessThanOrEqual(12);  // read + ≤ 10 deletes + counters; revocations stay ≤ 21
    expect(fake.deletes.map((d) => d.length)).toEqual([1000, 1000, 501]);
    expect(fake.deletes.flat()).toContain("feedback/k02501.jpg");  // the last, beyond two runs' budgets
    expect(await queued()).toEqual([]);
  });

  it("a job queued while the sweep runs survives it, even on a reused-looking position (07b #2)", async () => {
    // Codex's interleaving: the sweep reads A; A's own clean-up empties the queue; another deletion queues B, due at the
    // same time and ordered before A; B's immediate delete failed. The sweep must clear A's job only.
    await env.DB.prepare("INSERT INTO screenshot_deletions (key, due_at, claim) VALUES ('feedback/a.jpg', 5, 'c1')").run();
    const interleaved = { ...h.env, FEEDBACK: { async delete() {
      await env.DB.prepare("DELETE FROM screenshot_deletions WHERE claim = 'c1'").run();
      await env.DB.prepare("INSERT OR REPLACE INTO screenshot_deletions (key, due_at, claim) VALUES ('feedback/0.jpg', 5, 'c2')").run();
    } } as unknown as R2Bucket };
    await sweepFeedback(interleaved, h.deps);
    expect(await queued()).toEqual(["feedback/0.jpg"]);
    const fake = fakeBucket();
    await sweepFeedback({ ...h.env, FEEDBACK: fake.bucket }, h.deps);
    expect(fake.deletes.flat()).toEqual(["feedback/0.jpg"]);
    expect(await queued()).toEqual([]);
  });

  it("a key re-queued by a deletion while the sweep held its old job is kept for the next run", async () => {
    // Read while its row was live (so not deleted from R2); then the account is deleted and the key re-queued, as
    // claimDeletion does (INSERT OR REPLACE: a new id).
    await h.feedback({ screenshot: { bytes: JPEG } });
    const key = (await rows())[0]!.screenshot_key!;
    await env.DB.prepare("INSERT INTO screenshot_deletions (key, due_at) VALUES (?, 0)").bind(key).run();
    await env.DB.prepare("INSERT INTO screenshot_deletions (key, due_at) VALUES ('feedback/orphan.jpg', 0)").run();
    const requeue = { ...h.env, FEEDBACK: { async delete(keys: string[]) {
      expect(keys).toEqual(["feedback/orphan.jpg"]);  // the live key is not deleted
      await env.DB.prepare("DELETE FROM feedback").run();
      await env.DB.prepare("INSERT OR REPLACE INTO screenshot_deletions (key, due_at, claim) VALUES (?, 1, 'c3')").bind(key).run();
    } } as unknown as R2Bucket };
    await sweepFeedback(requeue, h.deps);
    expect(await queued()).toEqual([key]);
    expect(await sweepFeedback(h.env, h.deps)).toEqual({ removed: 1 });
    expect(await objects()).toEqual([]);
  });

  it("removes counters from earlier days, even when the screenshot sweep fails", async () => {
    await h.feedback();
    expect(await count("feedback_limits")).toBe(2);  // the address and the global counter
    await env.DB.prepare("INSERT INTO screenshot_deletions (key, due_at) VALUES ('feedback/x.jpg', 0)").run();
    h.clock.now += 24 * 60 * 60 * 1000;
    await sweepFeedback({ ...h.env, FEEDBACK: fakeBucket({ failDeletes: true }).bucket }, h.deps);
    expect(await count("feedback_limits")).toBe(0);
    expect(await queued()).toEqual(["feedback/x.jpg"]);
  });
});
