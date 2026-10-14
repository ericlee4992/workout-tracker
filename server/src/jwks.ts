import type { Deps } from "./env";

class KeySetError extends Error {}

/**
 * A provider's published signing keys (Apple's, Google's), per isolate: cached for an hour; concurrent fetches share one
 * request; and an unknown `kid` (key rotation — or anyone sending a bogus token) forces a refetch at most once per five
 * minutes (codex-review-03 #3: without the cooldown every junk token cost an outbound fetch). A refresh already running
 * answers everyone waiting for a new key (codex-review-03b #1). Moved from apple.ts for ticket 04 (Google).
 */
export const KEY_CACHE_MS = 60 * 60 * 1000;
export const FORCED_REFRESH_COOLDOWN_MS = 5 * 60 * 1000;

export function keySet(url: string, timeoutMs: number, unavailable: () => Error) {
  let cache: { keys: JsonWebKey[]; fetchedAt: number } | undefined;
  let inflight: Promise<JsonWebKey[]> | undefined;
  let lastForcedRefresh = Number.NEGATIVE_INFINITY;

  async function fetchKeys(deps: Deps): Promise<JsonWebKey[]> {
    const response = await deps.fetch(url, { signal: AbortSignal.timeout(timeoutMs) });
    if (!response.ok) throw new KeySetError();
    const body = (await response.json()) as { keys?: JsonWebKey[] };
    if (!Array.isArray(body.keys)) throw new KeySetError();
    cache = { keys: body.keys, fetchedAt: deps.now() };
    return body.keys;
  }

  async function keys(deps: Deps, forceRefresh = false): Promise<JsonWebKey[]> {
    const fresh = cache && deps.now() - cache.fetchedAt < KEY_CACHE_MS;
    if (fresh && !forceRefresh) return cache!.keys;
    if (forceRefresh && inflight) return inflight;
    if (fresh && forceRefresh) {
      if (deps.now() - lastForcedRefresh < FORCED_REFRESH_COOLDOWN_MS) return cache!.keys;
      lastForcedRefresh = deps.now();
    }
    inflight ??= fetchKeys(deps).finally(() => { inflight = undefined; });
    try {
      return await inflight;
    } catch {
      throw unavailable();
    }
  }

  return {
    /** The key with this `kid`, refetching once (within the cooldown) when it is not in the cached set. */
    async find(deps: Deps, kid: string): Promise<JsonWebKey | undefined> {
      const match = (set: JsonWebKey[]) => set.find((k) => (k as { kid?: string }).kid === kid);
      return match(await keys(deps)) ?? match(await keys(deps, true));
    },
    reset() {
      cache = undefined;
      inflight = undefined;
      lastForcedRefresh = Number.NEGATIVE_INFINITY;
    },
  };
}
