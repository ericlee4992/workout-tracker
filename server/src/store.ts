import { decrypt, encrypt, newID, newToken, sha256Hex } from "./crypto";
import type { Deps, Env } from "./env";

export const SESSION_LIFETIME_MS = 90 * 24 * 60 * 60 * 1000;
/** A session's expiry moves forward at most once a day, so reads are not writes on every request. */
export const SESSION_RENEW_AFTER_MS = 24 * 60 * 60 * 1000;

export interface Account {
  id: string;
  display_name: string | null;
  email: string | null;
  created_at: number;
}

export async function findAccountByIdentity(env: Env, provider: string, subject: string): Promise<Account | null> {
  return env.DB.prepare(
    "SELECT a.* FROM accounts a JOIN identities i ON i.account_id = a.id WHERE i.provider = ? AND i.subject = ?")
    .bind(provider, subject).first<Account>();
}

/** Creates the account and its identity in one batch (both or neither). */
export async function createAccount(env: Env, deps: Deps, provider: string, subject: string,
                                    displayName: string | null, email: string | null,
                                    refreshToken: string | null): Promise<Account> {
  const now = deps.now();
  const account: Account = { id: newID(deps.random), display_name: displayName, email, created_at: now };
  const sealed = refreshToken && env.TOKEN_ENC_KEY ? await encrypt(refreshToken, env.TOKEN_ENC_KEY, deps.random) : null;
  await env.DB.batch([
    env.DB.prepare("INSERT INTO accounts (id, display_name, email, created_at) VALUES (?, ?, ?, ?)")
      .bind(account.id, displayName, email, now),
    env.DB.prepare("INSERT INTO identities (provider, subject, account_id, refresh_token_enc, created_at) VALUES (?, ?, ?, ?, ?)")
      .bind(provider, subject, account.id, sealed, now),
  ]);
  return account;
}

/**
 * Create-or-find for a first sign-in (codex-review-03 #4): two first sign-ins for the same user can both find no
 * account; the loser's identity insert hits the primary key after its single-use code is already exchanged. Instead
 * of failing, it signs in to the winner's account and keeps its own (newer) refresh token. If the winner's account
 * was deleted in between, the lookup finds nothing and a fresh account is created — the deletion stays complete.
 */
export async function createOrFindAccount(env: Env, deps: Deps, provider: string, subject: string,
                                          displayName: string | null, email: string | null,
                                          refreshToken: string): Promise<Account> {
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      return await createAccount(env, deps, provider, subject, displayName, email, refreshToken);
    } catch (error) {
      if (!/UNIQUE|PRIMARY KEY|constraint/i.test(error instanceof Error ? error.message : "")) throw error;
      const existing = await findAccountByIdentity(env, provider, subject);
      if (existing && (await updateRefreshToken(env, deps, provider, subject, refreshToken))) return existing;
    }
  }
  throw new Error("account creation kept conflicting");
}

/** Keeps the newest refresh token (each authorization code exchange issues one) so deletion revokes a live one. */
/** Stores the newer token; false when the identity is gone (the account was deleted meanwhile). */
export async function updateRefreshToken(env: Env, deps: Deps, provider: string, subject: string, refreshToken: string): Promise<boolean> {
  if (!env.TOKEN_ENC_KEY) return false;
  const sealed = await encrypt(refreshToken, env.TOKEN_ENC_KEY, deps.random);
  const result = await env.DB.prepare("UPDATE identities SET refresh_token_enc = ? WHERE provider = ? AND subject = ?")
    .bind(sealed, provider, subject).run();
  return (result.meta.changes ?? 0) > 0;
}

/** A session for the account — or null when the account no longer exists (deleted meanwhile; codex-review-03b #3). */
export async function createSession(env: Env, deps: Deps, accountID: string): Promise<{ token: string; expiresAt: number } | null> {
  const token = newToken(deps.random);
  const now = deps.now();
  const expiresAt = now + SESSION_LIFETIME_MS;
  const result = await env.DB.prepare(
    "INSERT INTO sessions (token_hash, account_id, created_at, expires_at, last_used_at) " +
    "SELECT ?, ?, ?, ?, ? WHERE EXISTS (SELECT 1 FROM accounts WHERE id = ?)")
    .bind(await sha256Hex(token), accountID, now, expiresAt, now, accountID).run();
  return (result.meta.changes ?? 0) > 0 ? { token, expiresAt } : null;
}

/** The account behind a bearer token, renewing the session's expiry by use; null if unknown or expired. */
export async function accountForToken(env: Env, deps: Deps, token: string): Promise<{ account: Account; tokenHash: string } | null> {
  if (token.length < 16 || token.length > 128) return null;
  const tokenHash = await sha256Hex(token);
  const row = await env.DB.prepare(
    "SELECT s.expires_at, s.last_used_at, a.* FROM sessions s JOIN accounts a ON a.id = s.account_id WHERE s.token_hash = ?")
    .bind(tokenHash).first<Account & { expires_at: number; last_used_at: number }>();
  const now = deps.now();
  if (!row) return null;
  if (row.expires_at <= now) {
    await env.DB.prepare("DELETE FROM sessions WHERE token_hash = ?").bind(tokenHash).run();
    return null;
  }
  if (now - row.last_used_at >= SESSION_RENEW_AFTER_MS) {
    await env.DB.prepare("UPDATE sessions SET expires_at = ?, last_used_at = ? WHERE token_hash = ?")
      .bind(now + SESSION_LIFETIME_MS, now, tokenHash).run();
  }
  const { expires_at: _e, last_used_at: _l, ...account } = row;
  return { account, tokenHash };
}

export async function deleteSession(env: Env, tokenHash: string) {
  await env.DB.prepare("DELETE FROM sessions WHERE token_hash = ?").bind(tokenHash).run();
}

export async function setDisplayName(env: Env, accountID: string, name: string) {
  await env.DB.prepare("UPDATE accounts SET display_name = ? WHERE id = ?").bind(name, accountID).run();
}

export async function decryptToken(env: Env, sealed: string): Promise<string | null> {
  if (!env.TOKEN_ENC_KEY) return null;
  try { return await decrypt(sealed, env.TOKEN_ENC_KEY); } catch { return null; }
}

/** First retry an hour after the failure, doubling up to a day; given up after 30 days. */
export const PENDING_MAX_AGE_MS = 30 * 24 * 60 * 60 * 1000;
export function backoff(attempts: number): number {
  return Math.min(60 * 60 * 1000 * 2 ** Math.max(0, attempts - 1), 24 * 60 * 60 * 1000);
}

export interface DeletionClaim {
  /** False when another request deleted the account first (a race: report it, do not invent an outcome). */
  won: boolean;
  /** The encrypted tokens this deletion moved to the queue, to revoke now. */
  queued: string[];
  /** Apple identities that never kept a token: manual revocation only. */
  missing: number;
}

/**
 * Claims the deletion in ONE transaction (codex-review-03b #2, #3): reads the account's current Apple tokens, moves
 * them to `pending_revocations` (due after the first backoff, so the cron does not race the immediate attempt), and
 * deletes sessions, identities and the account. A sign-in that stored a newer token before this point is captured;
 * one after it finds no account and makes a new one; a second deletion finds nothing to delete and loses.
 */
export async function claimDeletion(env: Env, deps: Deps, accountID: string): Promise<DeletionClaim> {
  const now = deps.now();
  const results = await env.DB.batch([
    env.DB.prepare("SELECT refresh_token_enc FROM identities WHERE account_id = ? AND provider = 'apple'").bind(accountID),
    env.DB.prepare(
      "INSERT OR IGNORE INTO pending_revocations (token_enc, created_at, attempts, next_attempt_at) " +
      "SELECT refresh_token_enc, ?, 1, ? FROM identities WHERE account_id = ? AND provider = 'apple' AND refresh_token_enc IS NOT NULL")
      .bind(now, now + backoff(1), accountID),
    env.DB.prepare("DELETE FROM sessions WHERE account_id = ?").bind(accountID),
    env.DB.prepare("DELETE FROM identities WHERE account_id = ?").bind(accountID),
    env.DB.prepare("DELETE FROM accounts WHERE id = ?").bind(accountID),
  ]);
  const tokens = (results[0]!.results as { refresh_token_enc: string | null }[]).map((r) => r.refresh_token_enc);
  const won = (results[4]!.meta.changes ?? 0) > 0;
  return { won, queued: tokens.filter((t): t is string => t !== null), missing: tokens.filter((t) => t === null).length };
}

export interface PendingRevocation { token_enc: string; created_at: number; attempts: number }

export async function duePendingRevocations(env: Env, now: number, limit = 50): Promise<PendingRevocation[]> {
  const rows = await env.DB.prepare(
    "SELECT token_enc, created_at, attempts FROM pending_revocations WHERE next_attempt_at <= ? ORDER BY next_attempt_at LIMIT ?")
    .bind(now, limit).all<PendingRevocation>();
  return rows.results;
}

export async function finishPendingRevocation(env: Env, tokenEnc: string) {
  await env.DB.prepare("DELETE FROM pending_revocations WHERE token_enc = ?").bind(tokenEnc).run();
}

export async function retryPendingRevocationLater(env: Env, now: number, row: PendingRevocation) {
  await env.DB.prepare("UPDATE pending_revocations SET attempts = ?, next_attempt_at = ? WHERE token_enc = ?")
    .bind(row.attempts + 1, now + backoff(row.attempts + 1), row.token_enc).run();
}
