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

/** Apple rotates its signing keys rarely; one fetch per isolate per hour is plenty. */
let keyCache: { keys: JsonWebKey[]; fetchedAt: number } | undefined;
const KEY_CACHE_MS = 60 * 60 * 1000;

export function resetAppleKeyCache() {
  keyCache = undefined;
}

async function appleKeys(deps: Deps, refresh = false): Promise<JsonWebKey[]> {
  if (!refresh && keyCache && deps.now() - keyCache.fetchedAt < KEY_CACHE_MS) return keyCache.keys;
  const response = await deps.fetch(APPLE_KEYS_URL);
  if (!response.ok) throw new AuthError("apple_keys_unavailable", 503);
  const body = (await response.json()) as { keys?: JsonWebKey[] };
  if (!Array.isArray(body.keys)) throw new AuthError("apple_keys_unavailable", 503);
  keyCache = { keys: body.keys, fetchedAt: deps.now() };
  return body.keys;
}

/**
 * Verifies a Sign in with Apple identity token: Apple's signature (by `kid`, refetching the keys once for a new
 * kid), issuer, audience (the bundle ID), expiry (60 s leeway), and the nonce — the app sent SHA-256(rawNonce) to
 * Apple and sends rawNonce here, so a token captured elsewhere cannot be replayed.
 */
export async function verifyAppleIdentityToken(token: string, rawNonce: string, env: Env, deps: Deps): Promise<AppleIdentity> {
  let parts;
  try {
    parts = decodeJWT(token);
  } catch {
    throw new AuthError("invalid_token");
  }
  const kid = parts.header.kid;
  if (parts.header.alg !== "RS256" || typeof kid !== "string") throw new AuthError("invalid_token");
  let jwk = (await appleKeys(deps)).find((k) => (k as { kid?: string }).kid === kid);
  if (!jwk) jwk = (await appleKeys(deps, true)).find((k) => (k as { kid?: string }).kid === kid);
  if (!jwk || !(await verifyRS256(parts, jwk))) throw new AuthError("invalid_token");

  const claims = parts.payload;
  const now = Math.floor(deps.now() / 1000);
  if (claims.iss !== APPLE_ISSUER) throw new AuthError("invalid_token");
  const audience = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
  if (!audience.includes(env.APPLE_CLIENT_ID)) throw new AuthError("invalid_token");
  if (typeof claims.exp !== "number" || claims.exp + 60 < now) throw new AuthError("expired_token");
  if (typeof claims.iat === "number" && claims.iat - 60 > now) throw new AuthError("invalid_token");
  if (typeof rawNonce !== "string" || rawNonce.length < 16 || rawNonce.length > 256) throw new AuthError("invalid_nonce");
  if (claims.nonce !== (await sha256Hex(rawNonce))) throw new AuthError("invalid_nonce");
  if (typeof claims.sub !== "string" || claims.sub.length === 0) throw new AuthError("invalid_token");
  const email = typeof claims.email === "string" ? claims.email : null;
  return { subject: claims.sub, email };
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

/** Exchanges the one-time authorization code for Apple's refresh token, kept only to revoke on account deletion. */
export async function exchangeAppleCode(code: string, env: Env, deps: Deps): Promise<string> {
  if (typeof code !== "string" || code.length === 0 || code.length > 2048) throw new AuthError("invalid_code", 400);
  const response = await deps.fetch(APPLE_TOKEN_URL, form({
    client_id: env.APPLE_CLIENT_ID, client_secret: await appleClientSecret(env, deps),
    code, grant_type: "authorization_code",
  }));
  if (!response.ok) throw new AuthError("apple_exchange_failed", 502);
  const body = (await response.json()) as { refresh_token?: unknown };
  if (typeof body.refresh_token !== "string") throw new AuthError("apple_exchange_failed", 502);
  return body.refresh_token;
}

/** Revokes Apple's tokens for this app (App Store guideline 5.1.1(v) account deletion). Returns whether Apple accepted. */
export async function revokeAppleToken(refreshToken: string, env: Env, deps: Deps): Promise<boolean> {
  try {
    const response = await deps.fetch(APPLE_REVOKE_URL, form({
      client_id: env.APPLE_CLIENT_ID, client_secret: await appleClientSecret(env, deps),
      token: refreshToken, token_type_hint: "refresh_token",
    }));
    return response.ok;
  } catch {
    return false;
  }
}
