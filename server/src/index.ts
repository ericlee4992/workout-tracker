import { AuthError, exchangeAppleCode, revokeAppleToken, verifyAppleIdentityToken } from "./apple";
import { liveDeps, type Deps, type Env } from "./env";
import { privacyPage, supportPage } from "./pages";
import {
  accountForToken, appleRefreshTokens, createAccount, createSession, deleteAccount, deleteSession,
  findAccountByIdentity, setDisplayName, updateRefreshToken, type Account,
} from "./store";

const MAX_BODY_BYTES = 64 * 1024;
const MAX_NAME_LENGTH = 50;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status, headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
}

function failure(code: string, status: number): Response {
  return json({ error: code }, status);
}

async function readJSON(request: Request): Promise<Record<string, unknown>> {
  const length = Number(request.headers.get("content-length") ?? "0");
  if (length > MAX_BODY_BYTES) throw new AuthError("body_too_large", 413);
  const text = await request.text();
  if (text.length > MAX_BODY_BYTES) throw new AuthError("body_too_large", 413);
  let body: unknown;
  try { body = JSON.parse(text); } catch { throw new AuthError("malformed_json", 400); }
  if (typeof body !== "object" || body === null || Array.isArray(body)) throw new AuthError("malformed_json", 400);
  return body as Record<string, unknown>;
}

function bearer(request: Request): string | null {
  const header = request.headers.get("authorization") ?? "";
  const match = /^Bearer ([A-Za-z0-9_-]+)$/.exec(header);
  return match ? match[1]! : null;
}

/** A display name as given: trimmed, 1–50 characters, no control characters; null when absent or unusable. */
export function cleanName(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const name = value.replace(/\s+/g, " ").trim();
  if (name.length === 0 || name.length > MAX_NAME_LENGTH || /[\u0000-\u001f\u007f]/.test(name)) return null;
  return name;
}

function profile(account: Account, provider = "apple") {
  return { displayName: account.display_name, email: account.email, provider, memberSince: account.created_at };
}

async function signInWithApple(request: Request, env: Env, deps: Deps): Promise<Response> {
  // Without the encryption key the refresh token could not be kept, so the account could not be revoked later.
  if (!env.TOKEN_ENC_KEY) throw new AuthError("server_not_configured", 503);
  const body = await readJSON(request);
  const identity = await verifyAppleIdentityToken(String(body.identityToken ?? ""), String(body.nonce ?? ""), env, deps);
  // Fail closed: an account whose Apple tokens cannot be revoked at deletion must not be created (guideline 5.1.1(v)).
  const refreshToken = await exchangeAppleCode(String(body.authorizationCode ?? ""), env, deps);
  let account = await findAccountByIdentity(env, "apple", identity.subject);
  if (account) {
    await updateRefreshToken(env, deps, "apple", identity.subject, refreshToken);
  } else {
    // Apple gives the name only on the first authorization, to the app; the app forwards it.
    const name = cleanName([body.givenName, body.familyName].filter((p) => typeof p === "string").join(" "));
    account = await createAccount(env, deps, "apple", identity.subject, name, identity.email, refreshToken);
  }
  const session = await createSession(env, deps, account.id);
  return json({ session: session.token, expiresAt: session.expiresAt, profile: profile(account) });
}

async function authenticated(request: Request, env: Env, deps: Deps) {
  const token = bearer(request);
  const found = token ? await accountForToken(env, deps, token) : null;
  if (!found) throw new AuthError("unauthorized", 401);
  return found;
}

export function createHandler(deps: Deps) {
  return async (request: Request, env: Env): Promise<Response> => {
    const url = new URL(request.url);
    const route = `${request.method} ${url.pathname}`;
    try {
      switch (route) {
        case "GET /privacy": return privacyPage();
        case "GET /support": return supportPage();
        case "GET /v1/health": return json({ ok: true });
        case "POST /v1/auth/apple": return await signInWithApple(request, env, deps);
        case "POST /v1/auth/signout": {
          const { tokenHash } = await authenticated(request, env, deps);
          await deleteSession(env, tokenHash);
          return json({ ok: true });
        }
        case "GET /v1/profile": {
          const { account } = await authenticated(request, env, deps);
          return json(profile(account));
        }
        case "PUT /v1/profile": {
          const { account } = await authenticated(request, env, deps);
          const body = await readJSON(request);
          const name = cleanName(body.displayName);
          if (!name) return failure("invalid_display_name", 400);
          await setDisplayName(env, account.id, name);
          return json(profile({ ...account, display_name: name }));
        }
        case "DELETE /v1/account": {
          const { account } = await authenticated(request, env, deps);
          // Revoke first (Apple requires it), then delete every row whatever Apple answered: the user's deletion
          // request is honoured even if Apple is unreachable; the answer is reported, not hidden.
          const tokens = await appleRefreshTokens(env, account.id);
          const results = await Promise.all(tokens.map((t) => revokeAppleToken(t, env, deps)));
          await deleteAccount(env, account.id);
          return json({ deleted: true, appleRevoked: results.length > 0 && results.every(Boolean) });
        }
        default:
          return failure("not_found", 404);
      }
    } catch (error) {
      if (error instanceof AuthError) return failure(error.code, error.status);
      // Never echo internals (tokens, keys) to the client; the request body is not logged either.
      console.error("unhandled", route, error instanceof Error ? error.name : "unknown");
      return failure("server_error", 500);
    }
  };
}

const handle = createHandler(liveDeps);

export default {
  fetch: (request: Request, env: Env) => handle(request, env),
} satisfies ExportedHandler<Env>;
