/** Bindings and settings (wrangler.jsonc `vars`; secrets via `wrangler secret put`). */
export interface Env {
  DB: D1Database;
  /** Sign in with Apple audience: the app's bundle ID. */
  APPLE_CLIENT_ID: string;
  /** The paid Apple Developer team ID (not secret). */
  APPLE_TEAM_ID: string;
  /** Secret: the Sign in with Apple key's ID. */
  APPLE_KEY_ID?: string;
  /** Secret: the Sign in with Apple key (.p8, PKCS#8 PEM). */
  APPLE_PRIVATE_KEY?: string;
  /** Secret: base64 of 32 bytes; encrypts Apple refresh tokens at rest. */
  TOKEN_ENC_KEY?: string;
}

/** What the handler takes from the outside world, so tests can replace it. */
export interface Deps {
  now: () => number;
  fetch: typeof fetch;
  random: (length: number) => Uint8Array;
}

export const liveDeps: Deps = {
  now: () => Date.now(),
  fetch: (input, init) => fetch(input, init),
  random: (length) => crypto.getRandomValues(new Uint8Array(length)),
};
