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
}

export const NONCE = "raw-nonce-0123456789abcdef";

export async function harness(): Promise<Harness> {
  resetAppleKeyCache();
  // The pool keeps one D1 per test file: start every test from empty tables (children first).
  await env.DB.batch(["pending_revocations", "sessions", "identities", "accounts"].map((t) => env.DB.prepare(`DELETE FROM ${t}`)));
  const clock = { now: Date.UTC(2026, 9, 2, 12) };
  const { apple, fetch: fakeFetch, privateKeyPEM } = await makeFakeApple(clock);
  let counter = 0;
  const deps: Deps = {
    now: () => clock.now,
    fetch: fakeFetch,
    random: (n) => { const bytes = crypto.getRandomValues(new Uint8Array(n)); bytes[0] = counter++ % 256; return bytes; },
  };
  const testEnv: Env = {
    ...env,
    APPLE_CLIENT_ID: CLIENT_ID,
    APPLE_TEAM_ID: "TEAMID1234",
    APPLE_KEY_ID: "KEYID12345",
    APPLE_PRIVATE_KEY: privateKeyPEM,
    TOKEN_ENC_KEY: btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32)))),
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
  return { apple, env: testEnv, clock, call, idToken, signIn, deps };
}

export async function count(table: string): Promise<number> {
  const row = await env.DB.prepare(`SELECT COUNT(*) AS n FROM ${table}`).first<{ n: number }>();
  return row?.n ?? 0;
}
