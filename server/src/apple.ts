import { importES256PrivateKey, sha256Hex } from "./crypto";
import type { Deps, Env } from "./env";
import { decodeJWT, signES256, verifyRS256 } from "./jwt";

export const APPLE_ISSUER = "https://appleid.apple.com";
export const APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys";
export const APPLE_TOKEN_URL = "https://appleid.apple.com/auth/token";
export const APPLE_REVOKE_URL = "https://appleid.apple.com/auth/revoke";

export class AuthError extends Error {
  constructor(readonly code: string, readonly status = 401) {
    super(code);
  }
}

export interface AppleIdentity {
  subject: string;
  email: string | null;
}

/** Every call to Apple gives up after this long, so a slow Apple cannot hold requests open. */
export const APPLE_TIMEOUT_MS = 5000;

/**
 * Apple's signing keys, per isolate: cached for an hour; concurrent fetches share one request; and an unknown `kid`
 * (key rotation — or anyone sending a bogus token) forces a refetch at most once per five minutes
 * (codex-review-03 #3: without the cooldown every junk token cost an outbound fetch).
 */
let keyCache: { keys: JsonWebKey[]; fetchedAt: number } | undefined;
let inflight: Promise<JsonWebKey[]> | undefined;
let lastForcedRefresh = Number.NEGATIVE_INFINITY;
const KEY_CACHE_MS = 60 * 60 * 1000;
export const FORCED_REFRESH_COOLDOWN_MS = 5 * 60 * 1000;

export function resetAppleKeyCache() {
  keyCache = undefined;
  inflight = undefined;
  lastForcedRefresh = Number.NEGATIVE_INFINITY;
}

async function fetchKeys(deps: Deps): Promise<JsonWebKey[]> {
  const response = await deps.fetch(APPLE_KEYS_URL, { signal: AbortSignal.timeout(APPLE_TIMEOUT_MS) });
  if (!response.ok) throw new AuthError("apple_keys_unavailable", 503);
  const body = (await response.json()) as { keys?: JsonWebKey[] };
  if (!Array.isArray(body.keys)) throw new AuthError("apple_keys_unavailable", 503);
  keyCache = { keys: body.keys, fetchedAt: deps.now() };
  return body.keys;
}

async function appleKeys(deps: Deps, forceRefresh = false): Promise<JsonWebKey[]> {
  const fresh = keyCache && deps.now() - keyCache.fetchedAt < KEY_CACHE_MS;
  if (fresh && !forceRefresh) return keyCache!.keys;
  if (fresh && forceRefresh) {
    if (deps.now() - lastForcedRefresh < FORCED_REFRESH_COOLDOWN_MS) return keyCache!.keys;
    lastForcedRefresh = deps.now();
  }
  inflight ??= fetchKeys(deps).finally(() => { inflight = undefined; });
  try {
    return await inflight;
  } catch (error) {
    throw error instanceof AuthError ? error : new AuthError("apple_keys_unavailable", 503);
  }
}

/**
 * Verifies an Apple-issued identity token: Apple's signature (by `kid`), issuer, audience (the bundle ID), expiry
 * (60 s leeway), `iat` present and not in the future, and a subject. Returns its claims.
 */
async function verifyAppleToken(token: string, env: Env, deps: Deps): Promise<Record<string, unknown>> {
  const invalid = "invalid_token";
  let parts;
  try {
    parts = decodeJWT(token);
  } catch {
    throw new AuthError(invalid);
  }
  const kid = parts.header.kid;
  if (parts.header.alg !== "RS256" || typeof kid !== "string") throw new AuthError(invalid);
  let jwk = (await appleKeys(deps)).find((k) => (k as { kid?: string }).kid === kid);
  if (!jwk) jwk = (await appleKeys(deps, true)).find((k) => (k as { kid?: string }).kid === kid);
  if (!jwk || !(await verifyRS256(parts, jwk))) throw new AuthError(invalid);

  const claims = parts.payload;
  const now = Math.floor(deps.now() / 1000);
  if (claims.iss !== APPLE_ISSUER) throw new AuthError(invalid);
  const audience = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
  if (!audience.includes(env.APPLE_CLIENT_ID)) throw new AuthError(invalid);
  if (typeof claims.exp !== "number" || typeof claims.iat !== "number") throw new AuthError(invalid);
  if (claims.exp + 60 < now) throw new AuthError("expired_token");
  if (claims.iat - 60 > now) throw new AuthError(invalid);
  if (typeof claims.sub !== "string" || claims.sub.length === 0) throw new AuthError(invalid);
  return claims;
}

/**
 * The sign-in request's identity token, bound to this sign-in by its nonce: the app sent SHA-256(rawNonce) to Apple
 * and sends rawNonce here, so a token captured elsewhere cannot be replayed with another nonce.
 */
export async function verifyAppleIdentityToken(token: string, rawNonce: string, env: Env, deps: Deps): Promise<AppleIdentity> {
  const claims = await verifyAppleToken(token, env, deps);
  if (typeof rawNonce !== "string" || rawNonce.length < 16 || rawNonce.length > 256) throw new AuthError("invalid_nonce");
  if (claims.nonce !== (await sha256Hex(rawNonce))) throw new AuthError("invalid_nonce");
  const email = typeof claims.email === "string" ? claims.email : null;
  return { subject: claims.sub as string, email };
}

/** The client secret Apple's token and revoke endpoints require: an ES256 JWT signed with the Sign in with Apple key. */
export async function appleClientSecret(env: Env, deps: Deps): Promise<string> {
  if (!env.APPLE_TEAM_ID || !env.APPLE_KEY_ID || !env.APPLE_PRIVATE_KEY) throw new AuthError("apple_not_configured", 503);
  const key = await importES256PrivateKey(env.APPLE_PRIVATE_KEY);
  const now = Math.floor(deps.now() / 1000);
  return signES256({ kid: env.APPLE_KEY_ID, typ: "JWT" },
                   { iss: env.APPLE_TEAM_ID, iat: now, exp: now + 300, aud: APPLE_ISSUER, sub: env.APPLE_CLIENT_ID }, key);
}

function form(fields: Record<string, string>): RequestInit {
  return {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(fields).toString(),
  };
}

/**
 * Exchanges the one-time authorization code for Apple's refresh token, kept only to revoke on account deletion.
 * The identity token Apple returns with it is verified and must name the same user as the sign-in's identity token
 * (codex-review-03 #1): otherwise A's captured identity token plus B's code would sign in as A and store B's token.
 */
export async function exchangeAppleCode(code: string, expectedSubject: string, env: Env, deps: Deps): Promise<string> {
  if (typeof code !== "string" || code.length === 0 || code.length > 2048) throw new AuthError("invalid_code", 400);
  let response: Response;
  try {
    response = await deps.fetch(APPLE_TOKEN_URL, {
      ...form({ client_id: env.APPLE_CLIENT_ID, client_secret: await appleClientSecret(env, deps),
                code, grant_type: "authorization_code" }),
      signal: AbortSignal.timeout(APPLE_TIMEOUT_MS),
    });
  } catch (error) {
    if (error instanceof AuthError) throw error;
    throw new AuthError("apple_exchange_failed", 502);
  }
  if (!response.ok) throw new AuthError("apple_exchange_failed", 502);
  let body: { refresh_token?: unknown; id_token?: unknown };
  try { body = (await response.json()) as typeof body; } catch { throw new AuthError("apple_exchange_failed", 502); }
  if (typeof body.refresh_token !== "string" || body.refresh_token.length === 0 || body.refresh_token.length > 4096) {
    throw new AuthError("apple_exchange_failed", 502);
  }
  if (typeof body.id_token !== "string") throw new AuthError("apple_exchange_failed", 502);
  let claims: Record<string, unknown>;
  try {
    claims = await verifyAppleToken(body.id_token, env, deps);
  } catch (error) {
    if (error instanceof AuthError && error.code === "apple_keys_unavailable") throw error;
    throw new AuthError("apple_exchange_failed", 502);
  }
  if (claims.sub !== expectedSubject) throw new AuthError("code_identity_mismatch", 401);
  return body.refresh_token;
}

/** Revokes Apple's tokens for this app (App Store guideline 5.1.1(v) account deletion). Returns whether Apple accepted. */
export async function revokeAppleToken(refreshToken: string, env: Env, deps: Deps): Promise<boolean> {
  try {
    const response = await deps.fetch(APPLE_REVOKE_URL, {
      ...form({ client_id: env.APPLE_CLIENT_ID, client_secret: await appleClientSecret(env, deps),
                token: refreshToken, token_type_hint: "refresh_token" }),
      signal: AbortSignal.timeout(APPLE_TIMEOUT_MS),
    });
    return response.ok;
  } catch {
    return false;
  }
}
