import { AuthError, exchangeAppleCode, revokeAppleToken, verifyAppleIdentityToken } from "./apple";
import { liveDeps, type Deps, type Env } from "./env";
import { privacyPage, supportPage } from "./pages";
import {
  accountForToken, claimDeletion, createOrFindAccount, createSession, decryptToken, deleteSession,
  duePendingRevocations, finishPendingRevocation, findAccountByIdentity, PENDING_MAX_AGE_MS,
  retryPendingRevocationLater, setDisplayName, updateRefreshToken, type Account,
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

/**
 * Reads at most MAX_BODY_BYTES **bytes** from the stream, cancelling it as soon as the limit is passed
 * (codex-review-03 #2: `request.text()` buffered a chunked body of any size first, and measured UTF-16 units).
 */
async function readBodyText(request: Request): Promise<string> {
  const declared = Number(request.headers.get("content-length") ?? "0");
  if (declared > MAX_BODY_BYTES) throw new AuthError("body_too_large", 413);
  if (!request.body) return "";
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > MAX_BODY_BYTES) {
      await reader.cancel();
      throw new AuthError("body_too_large", 413);
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  return new TextDecoder().decode(bytes);
}

async function readJSON(request: Request): Promise<Record<string, unknown>> {
  const text = await readBodyText(request);
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
  const refreshToken = await exchangeAppleCode(String(body.authorizationCode ?? ""), identity.subject, env, deps);
  // Apple gives the name only on the first authorization, to the app; the app forwards it.
  const name = cleanName([body.givenName, body.familyName].filter((p) => typeof p === "string").join(" "));
  // Store this sign-in's token on the user's identity. If the identity is already gone (deleted before this point), the
  // token was never stored or claimed, so a new account may hold it.
  let account = await findAccountByIdentity(env, "apple", identity.subject);
  if (!account || !(await updateRefreshToken(env, deps, "apple", identity.subject, refreshToken))) {
    account = await createOrFindAccount(env, deps, "apple", identity.subject, name, identity.email, refreshToken);
  }
  await deps.pause?.("before-session");
  const session = await createSession(env, deps, account.id);
  // From here the token is stored; if a deletion claimed the account meanwhile, it also claimed this token for
  // revocation. Never reuse it for another account (codex-review-03c #1): the app must ask Apple again.
  if (!session) throw new AuthError("reauthorize", 409);
  return json({ session: session.token, expiresAt: session.expiresAt, profile: profile(account) });
}

async function authenticated(request: Request, env: Env, deps: Deps) {
  const token = bearer(request);
  const found = token ? await accountForToken(env, deps, token) : null;
  if (!found) throw new AuthError("unauthorized", 401);
  return found;
}

/**
 * Account deletion (guideline 5.1.1(v); codex-review-03 #5, 03b #2–#4). One transaction claims it: every current Apple
 * token moves to the revocation queue and every account row is deleted. Then each queued token is revoked now; a
 * success leaves the queue, a failure stays for the hourly retry. `appleRevocation`:
 * - "done": Apple accepted every token;
 * - "pending": at least one is queued. The app tells the user deletion is complete and Apple's access is being removed,
 *   and — because a retry can still fail for good — how to stop it themselves at once: iOS Settings → Apple Account →
 *   Sign in with Apple → Stacked (Apple TN3194);
 * - "manual": an identity never kept a token; only that iOS Settings route remains.
 * Returns null when another request deleted the account first.
 */
export async function deleteAccountRevokingApple(env: Env, deps: Deps, accountID: string) {
  const claim = await claimDeletion(env, deps, accountID);
  if (!claim.won) return null;
  let pending = 0;
  for (const sealed of claim.queued) {
    const plain = await decryptToken(env, sealed);
    if (plain !== null && (await revokeAppleToken(plain, env, deps))) await finishPendingRevocation(env, sealed);
    else pending++;
  }
  const appleRevocation = claim.missing > 0 ? "manual" : pending > 0 ? "pending" : "done";
  return { deleted: true, appleRevocation };
}

/** The hourly retry of queued revocations (wrangler.jsonc `triggers.crons`). */
export async function runPendingRevocations(env: Env, deps: Deps) {
  const now = deps.now();
  let revoked = 0, retried = 0, abandoned = 0;
  for (const row of await duePendingRevocations(env, now)) {
    const plain = await decryptToken(env, row.token_enc);
    if (plain !== null && (await revokeAppleToken(plain, env, deps))) {
      await finishPendingRevocation(env, row.token_enc);
      revoked++;
    } else if (now - row.created_at >= PENDING_MAX_AGE_MS) {
      // Bounded retention: Apple refresh tokens stay valid until revoked, so this one may still be live. The user was
      // told at deletion ("pending") how to stop Sign in with Apple in iOS Settings (TN3194); that is the remedy now.
      await finishPendingRevocation(env, row.token_enc);
      abandoned++;
    } else {
      await retryPendingRevocationLater(env, now, row);
      retried++;
    }
  }
  if (revoked + retried + abandoned > 0) console.log("pending revocations", { revoked, retried, abandoned });
  return { revoked, retried, abandoned };
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
          const outcome = await deleteAccountRevokingApple(env, deps, account.id);
          // Lost a race with another deletion of the same account: that request reports the real outcome.
          return outcome ? json(outcome) : failure("deletion_in_progress", 409);
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
  scheduled: async (_controller: ScheduledController, env: Env, ctx: ExecutionContext) => {
    ctx.waitUntil(runPendingRevocations(env, liveDeps));
  },
} satisfies ExportedHandler<Env>;
