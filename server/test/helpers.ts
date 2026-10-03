import { env } from "cloudflare:test";
import { resetAppleKeyCache } from "../src/apple";
import { base64UrlEncode, sha256Hex, utf8 } from "../src/crypto";
import type { Deps, Env } from "../src/env";
import { createHandler } from "../src/index";

/** A fake Apple: its own RSA signing key (and a second, unpublished one for forged tokens), a fake token and revoke
 *  endpoint, and the calls they received. Nothing in these tests reaches the network. */
export interface FakeApple {
  kid: string;
  sign: (claims: Record<string, unknown>, options?: { forged?: boolean; kid?: string; alg?: string }) => Promise<string>;
  calls: { url: string; body: URLSearchParams }[];
  /** Fetches of Apple's key set. */
  keyFetches: number;
  /** Keys served besides the original (a rotation). */
  extraKeys: JsonWebKey[];
  /** While set, the key-set response waits for this promise (a slow Apple). */
  keysGate?: Promise<void>;
  tokenStatus: number;
  revokeStatus: number;
  /** Throw from the revoke endpoint (a network failure / timeout). */
  revokeThrows: boolean;
  nextRefreshToken: string;
  /** Replaces the token endpoint's JSON answer (malformed-answer tests). */
  tokenBody?: (subject: string) => Promise<unknown>;
  esPublicKey: CryptoKey;
  /** A single-use authorization code for `subject`, as Apple issues one per authorization. */
  issueCode: (subject: string) => string;
  /** An Apple key pair outside the published set, with its public JWK (for rotation tests). */
  rotatedKey: () => Promise<{ kid: string; privateKey: CryptoKey; jwk: JsonWebKey }>;
}

async function rsaPair() {
  return crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true, ["sign", "verify"]) as Promise<CryptoKeyPair>;
}

export async function makeFakeApple(clock: { now: number } = { now: Date.now() }): Promise<{ apple: FakeApple; fetch: typeof fetch; privateKeyPEM: string }> {
  const published = await rsaPair();
  const forged = await rsaPair();
  const jwk = (await crypto.subtle.exportKey("jwk", published.publicKey)) as JsonWebKey;
  const kid = "TESTKID1";
  const es = (await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"])) as CryptoKeyPair;
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", es.privateKey) as ArrayBuffer);
  let b64 = "";
  for (const byte of pkcs8) b64 += String.fromCharCode(byte);
  const privateKeyPEM = `-----BEGIN PRIVATE KEY-----\n${btoa(b64)}\n-----END PRIVATE KEY-----`;

  const codes = new Map<string, { subject: string; used: boolean }>();
  let codeCounter = 0;
  const apple: FakeApple = {
    kid, calls: [], keyFetches: 0, extraKeys: [], tokenStatus: 200, revokeStatus: 200, revokeThrows: false,
    nextRefreshToken: "refresh-1", esPublicKey: es.publicKey,
    issueCode(subject) {
      const code = `code-${++codeCounter}`;
      codes.set(code, { subject, used: false });
      return code;
    },
    async rotatedKey() {
      const pair = await rsaPair();
      const jwkOut = (await crypto.subtle.exportKey("jwk", pair.publicKey)) as JsonWebKey;
      return { kid: "ROTATED2", privateKey: pair.privateKey, jwk: { ...jwkOut, kid: "ROTATED2", alg: "RS256", use: "sig" } as JsonWebKey };
    },
    async sign(claims, options = {}) {
      const header = { alg: options.alg ?? "RS256", kid: options.kid ?? kid };
      const enc = (v: unknown) => base64UrlEncode(utf8(JSON.stringify(v)));
      const input = `${enc(header)}.${enc(claims)}`;
      const key = options.forged ? forged.privateKey : published.privateKey;
      const signature = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, utf8(input)));
      return `${input}.${base64UrlEncode(signature)}`;
    },
  };
  const fakeFetch: typeof fetch = async (input, init) => {
    const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url;
    if (url === "https://appleid.apple.com/auth/keys") {
      apple.keyFetches++;
      if (apple.keysGate) await apple.keysGate;
      return Response.json({ keys: [{ ...jwk, kid, alg: "RS256", use: "sig" }, ...apple.extraKeys] });
    }
    const body = new URLSearchParams(String(init?.body ?? ""));
    apple.calls.push({ url, body });
    if (url === "https://appleid.apple.com/auth/token") {
      if (apple.tokenStatus !== 200) return new Response("{}", { status: apple.tokenStatus });
      const grant = codes.get(body.get("code") ?? "");
      if (!grant || grant.used) return Response.json({ error: "invalid_grant" }, { status: 400 });  // single-use
      grant.used = true;
      if (apple.tokenBody) return Response.json(await apple.tokenBody(grant.subject));
      const now = Math.floor(clock.now / 1000);
      const idToken = await apple.sign({ iss: "https://appleid.apple.com", aud: CLIENT_ID, iat: now, exp: now + 600, sub: grant.subject });
      return Response.json({ access_token: "a", refresh_token: apple.nextRefreshToken, id_token: idToken, token_type: "Bearer" });
    }
    if (url === "https://appleid.apple.com/auth/revoke") {
      if (apple.revokeThrows) throw new Error("network down");
      return new Response(null, { status: apple.revokeStatus });
    }
    throw new Error(`unexpected fetch ${url}`);
  };
  return { apple, fetch: fakeFetch, privateKeyPEM };
}

export const CLIENT_ID = "com.ericlee4992.workouttracker";

export interface Harness {
  apple: FakeApple;
  env: Env;
  clock: { now: number };
  call: (method: string, path: string, options?: { body?: unknown; token?: string; raw?: string }) => Promise<Response>;
  idToken: (overrides?: Record<string, unknown>, nonce?: string, options?: Parameters<FakeApple["sign"]>[1]) => Promise<string>;
  signIn: (subject?: string, extra?: Record<string, unknown>) => Promise<{ session: string; profile: Record<string, unknown> }>;
  /** The router's `deps` (for calling exported functions like the scheduled retry directly). */
  deps: Deps;
  /** POST /v1/feedback as multipart: the given fields over valid defaults (null drops a field). */
  feedback: (options?: FeedbackOptions) => Promise<Response>;
  /** A fake OpenAI Responses endpoint (ticket 06). */
  openai: FakeOpenAI;
}

export interface FakeOpenAI {
  calls: { body: Record<string, unknown>; authorization: string | null }[];
  /** The answer to the next calls; the default is a completed reply carrying `result`. */
  respond: (body: Record<string, unknown>) => Promise<Response> | Response;
  /** While set, each call waits for it (requests in flight). */
  gate?: Promise<void>;
}

export const OPENAI_KEY = "fake-key";

/** A completed Responses API reply whose single output_text is `result` as JSON. */
export function openAIReply(result: unknown, usage = { input_tokens: 1200, output_tokens: 300, output_tokens_details: { reasoning_tokens: 200 } }) {
  return Response.json({
    status: "completed", usage,
    output: [{ type: "reasoning", content: [] }, { type: "message", content: [{ type: "output_text", text: JSON.stringify(result) }] }],
  });
}

export interface FeedbackOptions {
  fields?: Record<string, string | null>;
  screenshot?: { bytes: Uint8Array; type?: string; name?: string } | string;
  token?: string;
  /** Sent as an Authorization header verbatim. */
  authorization?: string;
  ip?: string;
}

export const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01, 0xff, 0xd9]);
export const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d]);

export const NONCE = "raw-nonce-0123456789abcdef";

export async function harness(): Promise<Harness> {
  resetAppleKeyCache();
  // The pool keeps one D1 per test file: start every test from empty tables (children first).
  await env.DB.batch(["training_profiles", "ai_usage", "ai_requests", "ai_settings", "ai_account_pauses",
    "feedback", "feedback_limits", "screenshot_deletions", "pending_revocations", "sessions", "identities", "accounts"]
    .map((t) => env.DB.prepare(`DELETE FROM ${t}`)));
  const stored = await env.FEEDBACK.list();
  if (stored.objects.length > 0) await env.FEEDBACK.delete(stored.objects.map((o) => o.key));
  const clock = { now: Date.UTC(2026, 9, 2, 12) };
  const { apple, fetch: fakeFetch, privateKeyPEM } = await makeFakeApple(clock);
  let counter = 0;
  const openai: FakeOpenAI = { calls: [], respond: () => openAIReply({ ok: true }) };
  const deps: Deps = {
    now: () => clock.now,
    fetch: async (input, init) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url;
      if (url !== "https://api.openai.com/v1/responses") return fakeFetch(input, init);
      const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
      openai.calls.push({ body, authorization: new Headers(init?.headers).get("authorization") });
      // Honours the abort signal, as fetch does, for headers that are slow to come.
      const aborted = new Promise<never>((_, reject) => {
        const signal = init?.signal;
        if (signal?.aborted) reject(signal.reason);
        signal?.addEventListener("abort", () => reject(signal.reason));
      });
      if (openai.gate) await Promise.race([openai.gate, aborted]);
      const response = await Promise.race([Promise.resolve(openai.respond(body)), aborted]);
      if (!response.body || !init?.signal) return response;
      // …and for a body still streaming in when the deadline passes.
      const signal = init.signal;
      const reader = response.body.getReader();
      const guarded = new ReadableStream<Uint8Array>({
        async pull(controller) {
          try {
            const { done, value } = await Promise.race([reader.read(), aborted]);
            if (done) controller.close(); else controller.enqueue(value);
          } catch (error) {
            controller.error(signal.aborted ? signal.reason : error);
          }
        },
      });
      return new Response(guarded, { status: response.status, headers: response.headers });
    },
    random: (n) => { const bytes = crypto.getRandomValues(new Uint8Array(n)); bytes[0] = counter++ % 256; return bytes; },
  };
  const testEnv: Env = {
    ...env,
    APPLE_CLIENT_ID: CLIENT_ID,
    APPLE_TEAM_ID: "TEAMID1234",
    APPLE_KEY_ID: "KEYID12345",
    APPLE_PRIVATE_KEY: privateKeyPEM,
    TOKEN_ENC_KEY: btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32)))),
    OPENAI_API_KEY: OPENAI_KEY,
  };
  const handle = createHandler(deps);
  const call: Harness["call"] = (method, path, options = {}) => {
    const headers: Record<string, string> = {};
    if (options.token) headers.authorization = `Bearer ${options.token}`;
    const body = options.raw ?? (options.body === undefined ? undefined : JSON.stringify(options.body));
    if (body !== undefined) headers["content-type"] = "application/json";
    return handle(new Request(`https://stacked.test${path}`, { method, headers, body }), testEnv);
  };
  const idToken: Harness["idToken"] = async (overrides = {}, nonce = NONCE, options) => {
    const now = Math.floor(clock.now / 1000);
    return apple.sign({
      iss: "https://appleid.apple.com", aud: CLIENT_ID, iat: now, exp: now + 600, sub: "001234.apple-user",
      email: "relay@privaterelay.appleid.com", nonce: await sha256Hex(nonce), ...overrides,
    }, options);
  };
  const signIn: Harness["signIn"] = async (subject = "001234.apple-user", extra = {}) => {
    const response = await call("POST", "/v1/auth/apple", {
      body: { identityToken: await idToken({ sub: subject }), authorizationCode: apple.issueCode(subject), nonce: NONCE, ...extra },
    });
    if (response.status !== 200) throw new Error(`sign-in failed ${response.status} ${await response.text()}`);
    return response.json() as Promise<{ session: string; profile: Record<string, unknown> }>;
  };
  const feedback: Harness["feedback"] = (options = {}) => {
    const form = new FormData();
    const fields: Record<string, string | null> = {
      category: "bug", message: "The rest timer kept counting.", appVersion: "0.1.0", build: "1",
      systemVersion: "27.0", model: "iPhone16,2", ...options.fields,
    };
    for (const [name, value] of Object.entries(fields)) if (value !== null) form.append(name, value);
    if (typeof options.screenshot === "string") form.append("screenshot", options.screenshot);
    else if (options.screenshot) {
      form.append("screenshot", new File([options.screenshot.bytes], options.screenshot.name ?? "shot.jpg",
        { type: options.screenshot.type ?? "image/jpeg" }));
    }
    const headers: Record<string, string> = { "cf-connecting-ip": options.ip ?? "203.0.113.7" };
    if (options.token) headers.authorization = `Bearer ${options.token}`;
    if (options.authorization !== undefined) headers.authorization = options.authorization;
    return handle(new Request("https://stacked.test/v1/feedback", { method: "POST", headers, body: form }), testEnv);
  };
  return { apple, env: testEnv, clock, call, idToken, signIn, deps, feedback, openai };
}

export async function count(table: string): Promise<number> {
  const row = await env.DB.prepare(`SELECT COUNT(*) AS n FROM ${table}`).first<{ n: number }>();
  return row?.n ?? 0;
}
