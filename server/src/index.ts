import { isFlow, proxyAI, pruneAI, usage } from "./ai";
import { AuthError, exchangeAppleCode, revokeAppleToken, verifyAppleIdentityToken } from "./apple";
import { liveDeps, type Deps, type Env } from "./env";
import { deleteClaimedScreenshots, submitFeedback, sweepFeedback } from "./feedback";
import { bearer, failure, json, readJSON } from "./http";
import { cleanTraining, readTraining, trainingStatement } from "./training";
import { privacyPage, supportPage } from "./pages";
import {
  accountForToken, claimDeletion, createOrFindAccount, createSession, decryptToken, deleteSession,
  duePendingRevocations, finishPendingRevocation, findAccountByIdentity, PENDING_MAX_AGE_MS,
  retryPendingRevocationLater, updateRefreshToken, type Account,
} from "./store";

const MAX_NAME_LENGTH = 50;

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

/** The profile with its training profile (ticket 05). */
async function fullProfile(env: Env, account: Account) {
  return { ...profile(account), training: await readTraining(env, account.id) };
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
  await deleteClaimedScreenshots(env, claim.claim);
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
          return json(await fullProfile(env, account));
        }
        case "PUT /v1/profile": {
          // Either or both: `displayName`; `training` (an object to save, null to remove). Both are checked before
          // either is written, so a refused request changes nothing.
          const { account } = await authenticated(request, env, deps);
          const body = await readJSON(request);
          const hasName = "displayName" in body, hasTraining = "training" in body;
          if (!hasName && !hasTraining) return failure("invalid_display_name", 400);
          const name = hasName ? cleanName(body.displayName) : null;
          if (hasName && !name) return failure("invalid_display_name", 400);
          const training = hasTraining && body.training !== null ? cleanTraining(body.training) : null;
          // One batch (a transaction): a failure in either write leaves both unchanged (codex-review-05 #1).
          const statements: D1PreparedStatement[] = [];
          if (name) statements.push(env.DB.prepare("UPDATE accounts SET display_name = ? WHERE id = ?").bind(name, account.id));
          if (hasTraining) statements.push(trainingStatement(env, deps, account.id, training));
          const results = await env.DB.batch(statements);
          // A save that found no account (deleted meanwhile) wrote nothing.
          if (training !== null && hasTraining && (results[results.length - 1]!.meta.changes ?? 0) === 0) {
            return failure("unauthorized", 401);
          }
          return json(await fullProfile(env, name ? { ...account, display_name: name } : account));
        }
        case "GET /v1/ai/usage": {
          const { account } = await authenticated(request, env, deps);
          return json(await usage(env, deps, account.id));
        }
        case "POST /v1/feedback": {
          // Works signed out; a bearer that is sent must be valid (the app then knows its session ended).
          const accountID = bearer(request) || request.headers.has("authorization")
            ? (await authenticated(request, env, deps)).account.id : null;
          return json(await submitFeedback(request, env, deps, accountID), 201);
        }
        case "DELETE /v1/account": {
          const { account } = await authenticated(request, env, deps);
          const outcome = await deleteAccountRevokingApple(env, deps, account.id);
          // Lost a race with another deletion of the same account: that request reports the real outcome.
          return outcome ? json(outcome) : failure("deletion_in_progress", 409);
        }
        default: {
          const flow = /^POST \/v1\/ai\/([a-z-]+)$/.exec(route)?.[1];
          if (flow && isFlow(flow)) {
            const { account } = await authenticated(request, env, deps);
            return json(await proxyAI(request, env, deps, account.id, flow));
          }
          return failure("not_found", 404);
        }
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
    ctx.waitUntil(sweepFeedback(env, liveDeps));
    ctx.waitUntil(pruneAI(env, liveDeps));
  },
} satisfies ExportedHandler<Env>;
