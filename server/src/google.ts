import { AuthError } from "./apple";
import { sha256Hex } from "./crypto";
import type { Deps, Env } from "./env";
import { keySet } from "./jwks";
import { decodeJWT, verifyRS256 } from "./jwt";

/**
 * Public beta ticket 04: Google sign-in without a Google SDK. The app runs Google's OAuth 2.0 authorization-code flow
 * with PKCE for an iOS client (`ASWebAuthenticationSession`), exchanges the code itself and sends the ID token here.
 * The server keeps no Google token (an iOS client has no secret, and there is nothing of Google's to revoke at
 * deletion); it verifies the ID token and signs the person in.
 */
export const GOOGLE_ISSUERS = ["https://accounts.google.com", "accounts.google.com"];
export const GOOGLE_KEYS_URL = "https://www.googleapis.com/oauth2/v3/certs";
export const GOOGLE_TIMEOUT_MS = 5000;

const googleKeys = keySet(GOOGLE_KEYS_URL, GOOGLE_TIMEOUT_MS, () => new AuthError("google_keys_unavailable", 503));

export function resetGoogleKeyCache() {
  googleKeys.reset();
}

export interface GoogleIdentity {
  subject: string;
  /** Only an address Google has verified. */
  email: string | null;
  name: string | null;
}

/**
 * Verifies a Google ID token: Google's signature (by `kid`), issuer, audience = the iOS client ID (and `azp`, when
 * present), expiry (60 s leeway), `iat` present and not in the future, a subject, and the nonce — the app put
 * SHA-256(rawNonce) in the authorization request and sends rawNonce here, so a token captured elsewhere cannot be
 * replayed with another nonce (as for Apple).
 */
export async function verifyGoogleIdentityToken(token: string, rawNonce: string, env: Env, deps: Deps): Promise<GoogleIdentity> {
  const invalid = "invalid_token";
  if (!env.GOOGLE_CLIENT_ID) throw new AuthError("server_not_configured", 503);
  let parts;
  try {
    parts = decodeJWT(token);
  } catch {
    throw new AuthError(invalid);
  }
  const kid = parts.header.kid;
  if (parts.header.alg !== "RS256" || typeof kid !== "string") throw new AuthError(invalid);
  const jwk = await googleKeys.find(deps, kid);
  if (!jwk || !(await verifyRS256(parts, jwk))) throw new AuthError(invalid);

  const claims = parts.payload;
  const now = Math.floor(deps.now() / 1000);
  if (typeof claims.iss !== "string" || !GOOGLE_ISSUERS.includes(claims.iss)) throw new AuthError(invalid);
  const audience = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
  if (!audience.includes(env.GOOGLE_CLIENT_ID)) throw new AuthError(invalid);
  if (claims.azp !== undefined && claims.azp !== env.GOOGLE_CLIENT_ID) throw new AuthError(invalid);
  if (typeof claims.exp !== "number" || typeof claims.iat !== "number") throw new AuthError(invalid);
  if (claims.exp + 60 < now) throw new AuthError("expired_token");
  if (claims.iat - 60 > now) throw new AuthError(invalid);
  if (typeof claims.sub !== "string" || claims.sub.length === 0 || claims.sub.length > 255) throw new AuthError(invalid);
  if (typeof rawNonce !== "string" || rawNonce.length < 16 || rawNonce.length > 256) throw new AuthError("invalid_nonce");
  if (claims.nonce !== (await sha256Hex(rawNonce))) throw new AuthError("invalid_nonce");
  const email = claims.email_verified === true && typeof claims.email === "string" ? claims.email : null;
  const name = typeof claims.name === "string" ? claims.name : null;
  return { subject: claims.sub, email, name };
}
