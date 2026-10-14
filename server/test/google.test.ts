import { env } from "cloudflare:test";
import { beforeEach, describe, expect, it } from "vitest";
import { count, GOOGLE_CLIENT_ID, harness, NONCE, type Harness } from "./helpers";

// Public beta ticket 04: Google sign-in — the ID token's checks, the account it makes or finds, the profile's provider,
// no linking with Apple, and deletion of a Google account (nothing of Google's kept, so nothing to revoke).
let h: Harness;
beforeEach(async () => {
  h = await harness();
});

async function signInWith(token: string, nonce = NONCE) {
  return h.call("POST", "/v1/auth/google", { body: { idToken: token, nonce } });
}

describe("Google sign-in — ID token checks", () => {
  it("accepts a good token: one account, a google identity and a session; the profile says Google", async () => {
    const response = await signInWith(await h.googleToken());
    expect(response.status).toBe(200);
    const body = (await response.json()) as { session: string; profile: Record<string, unknown> };
    expect(body.session.length).toBeGreaterThanOrEqual(40);
    expect(body.profile).toMatchObject({ provider: "google", displayName: "Alex Kim", email: "alex@gmail.com" });
    expect([await count("accounts"), await count("identities"), await count("sessions")]).toEqual([1, 1, 1]);
    const identity = await env.DB.prepare("SELECT provider, subject, refresh_token_enc FROM identities").first();
    expect(identity).toEqual({ provider: "google", subject: "109876543210987654321", refresh_token_enc: null });
    const profile = await h.call("GET", "/v1/profile", { token: body.session });
    expect(((await profile.json()) as { provider: string }).provider).toBe("google");
  });

  it("accepts Google's short issuer form", async () => {
    expect((await signInWith(await h.googleToken({ iss: "accounts.google.com" }))).status).toBe(200);
  });

  it("keeps an unverified email out", async () => {
    const body = (await (await signInWith(await h.googleToken({ email_verified: false }))).json()) as { profile: { email: unknown } };
    expect(body.profile.email).toBeNull();
  });

  const rejected: [string, () => Promise<string>, string?, string?][] = [
    ["expired", () => h.googleToken({ exp: Math.floor(h.clock.now / 1000) - 120 }), undefined, "expired_token"],
    ["wrong audience", () => h.googleToken({ aud: "999-other.apps.googleusercontent.com" }), undefined, "invalid_token"],
    ["wrong authorized party", () => h.googleToken({ azp: "999-other.apps.googleusercontent.com" }), undefined, "invalid_token"],
    ["wrong issuer", () => h.googleToken({ iss: "https://evil.example" }), undefined, "invalid_token"],
    ["Apple's issuer", () => h.googleToken({ iss: "https://appleid.apple.com" }), undefined, "invalid_token"],
    ["forged signature", () => h.googleToken({}, NONCE, { forged: true }), undefined, "invalid_token"],
    ["unknown key id", () => h.googleToken({}, NONCE, { kid: "NOPE" }), undefined, "invalid_token"],
    ["alg none", () => h.googleToken({}, NONCE, { alg: "none" }), undefined, "invalid_token"],
    ["no subject", () => h.googleToken({ sub: "" }), undefined, "invalid_token"],
    ["issued in the future", () => h.googleToken({ iat: Math.floor(h.clock.now / 1000) + 3600 }), undefined, "invalid_token"],
    ["wrong nonce", () => h.googleToken(), "another-raw-nonce-xyz", "invalid_nonce"],
    ["short nonce", () => h.googleToken({}, "short"), "short", "invalid_nonce"],
    ["an Apple token", () => h.idToken(), undefined, "invalid_token"],
  ];
  for (const [name, make, nonce, code] of rejected) {
    it(`rejects a token: ${name}`, async () => {
      const response = await signInWith(await make(), nonce ?? NONCE);
      expect(response.status).toBe(401);
      expect(await response.json()).toEqual({ error: code });
      expect(await count("accounts")).toBe(0);
    });
  }

  it("answers 503 when the server has no Google client ID", async () => {
    const { createHandler } = await import("../src/index");
    const unconfigured = await createHandler(h.deps)(new Request("https://stacked.test/v1/auth/google", {
      method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ idToken: await h.googleToken(), nonce: NONCE }),
    }), { ...h.env, GOOGLE_CLIENT_ID: undefined });
    expect(unconfigured.status).toBe(503);
    expect(await unconfigured.json()).toEqual({ error: "server_not_configured" });
    expect(await count("accounts")).toBe(0);
  });

  it("fetches Google's keys once for several sign-ins", async () => {
    await signInWith(await h.googleToken());
    await signInWith(await h.googleToken());
    expect(h.google.keyFetches).toBe(1);
  });
});

describe("Google sign-in — accounts", () => {
  it("signs the same Google person in to the same account", async () => {
    await signInWith(await h.googleToken());
    const again = await signInWith(await h.googleToken({ name: "Someone Else" }));
    expect(again.status).toBe(200);
    expect([await count("accounts"), await count("identities"), await count("sessions")]).toEqual([1, 1, 2]);
    // The name is the first sign-in's (editable on the profile page), not overwritten by a later token.
    expect(((await again.json()) as { profile: { displayName: string } }).profile.displayName).toBe("Alex Kim");
  });

  it("does not link an Apple and a Google sign-in with the same email", async () => {
    await h.signIn();
    await signInWith(await h.googleToken({ email: "relay@privaterelay.appleid.com" }));
    expect(await count("accounts")).toBe(2);
  });

  it("deletes a Google account completely, with nothing for Apple to revoke", async () => {
    const body = (await (await signInWith(await h.googleToken())).json()) as { session: string };
    const response = await h.call("DELETE", "/v1/account", { token: body.session });
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ deleted: true, appleRevocation: "done" });
    expect([await count("accounts"), await count("identities"), await count("sessions"),
            await count("pending_revocations")]).toEqual([0, 0, 0, 0]);
    expect(h.apple.calls).toEqual([]);
  });
});

it("the harness's client ID is the iOS client's shape", () => {
  expect(GOOGLE_CLIENT_ID.endsWith(".apps.googleusercontent.com")).toBe(true);
});
