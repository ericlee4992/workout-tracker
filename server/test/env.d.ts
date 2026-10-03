// The test environment's bindings (wrangler.jsonc plus the migrations the setup applies), for `cloudflare:test`'s env.
declare namespace Cloudflare {
  interface Env {
    DB: D1Database;
    FEEDBACK: R2Bucket;
    APPLE_CLIENT_ID: string;
    APPLE_TEAM_ID: string;
    APPLE_KEY_ID?: string;
    APPLE_PRIVATE_KEY?: string;
    TOKEN_ENC_KEY?: string;
    OPENAI_API_KEY?: string;
    TEST_MIGRATIONS: import("@cloudflare/vitest-pool-workers").D1Migration[];
  }
}
