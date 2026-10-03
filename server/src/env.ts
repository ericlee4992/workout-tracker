/** Bindings and settings (wrangler.jsonc `vars`; secrets via `wrangler secret put`). */
export interface Env {
  DB: D1Database;
  /** Feedback screenshots (R2). */
  FEEDBACK: R2Bucket;
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
  /** Secret: the developer's OpenAI key (ticket 06). Never sent to the app; without it the AI routes answer 503. */
  OPENAI_API_KEY?: string;
}

/** What the handler takes from the outside world, so tests can replace it. */
export interface Deps {
  now: () => number;
  fetch: typeof fetch;
  random: (length: number) => Uint8Array;
  /** Test seam only (absent in production): awaited at named points so a test can interleave another request. */
  pause?: (point: "before-session") => Promise<void>;
  /** Test seam only: the OpenAI deadline (default OPENAI_TIMEOUT_MS). */
  openAITimeoutMs?: number;
}

export const liveDeps: Deps = {
  now: () => Date.now(),
  fetch: (input, init) => fetch(input, init),
  random: (length) => crypto.getRandomValues(new Uint8Array(length)),
};
