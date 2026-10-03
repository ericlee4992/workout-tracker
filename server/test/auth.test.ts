import { env } from "cloudflare:test";
import { beforeEach, describe, expect, it } from "vitest";
import { base64UrlDecode, decrypt, utf8 } from "../src/crypto";
import { decodeJWT } from "../src/jwt";
import { SESSION_LIFETIME_MS } from "../src/store";
import { CLIENT_ID, count, harness, NONCE, type Harness } from "./helpers";

let h: Harness;
beforeEach(async () => {
  h = await harness();
});

async function signInWith(token: string, nonce = NONCE, code?: string) {
  const authorizationCode = code ?? h.apple.issueCode("001234.apple-user");
  return h.call("POST", "/v1/auth/apple", { body: { identityToken: token, authorizationCode, nonce } });
}

describe("Sign in with Apple — identity token checks", () => {
  it("accepts a good token and creates one account, identity and session", async () => {
    const response = await signInWith(await h.idToken(), NONCE);
    expect(response.status).toBe(200);
    const body = (await response.json()) as { session: string; expiresAt: number; profile: { email: string } };
    expect(body.session.length).toBeGreaterThanOrEqual(40);
    expect(body.expiresAt).toBe(h.clock.now + SESSION_LIFETIME_MS);
    expect(body.profile.email).toBe("relay@privaterelay.appleid.com");
    expect([await count("accounts"), await count("identities"), await count("sessions")]).toEqual([1, 1, 1]);
  });

  it("stores only a hash of the session token", async () => {
    const { session } = await h.signIn();
    const stored = await env.DB.prepare("SELECT token_hash FROM sessions").first<{ token_hash: string }>();
    expect(stored?.token_hash).not.toBe(session);
    expect(stored?.token_hash).toMatch(/^[0-9a-f]{64}$/);
  });

  const rejected: [string, () => Promise<string>, string?, string?][] = [
    ["expired", () => h.idToken({ exp: Math.floor(h.clock.now / 1000) - 120 }), undefined, "expired_token"],
    ["wrong audience", () => h.idToken({ aud: "com.someone.else" }), undefined, "invalid_token"],
    ["wrong issuer", () => h.idToken({ iss: "https://evil.example" }), undefined, "invalid_token"],
    ["forged signature", () => h.idToken({}, NONCE, { forged: true }), undefined, "invalid_token"],
    ["unknown key id", () => h.idToken({}, NONCE, { kid: "NOPE" }), undefined, "invalid_token"],
    ["alg none", () => h.idToken({}, NONCE, { alg: "none" }), undefined, "invalid_token"],
    ["no subject", () => h.idToken({ sub: "" }), undefined, "invalid_token"],
    ["issued in the future", () => h.idToken({ iat: Math.floor(h.clock.now / 1000) + 3600 }), undefined, "invalid_token"],
  ];
  for (const [name, make, nonce, code] of rejected) {
    it(`rejects a token: ${name}`, async () => {
      const response = await signInWith(await make(), nonce ?? NONCE);
      expect(response.status).toBe(401);
      expect(await response.json()).toEqual({ error: code });
      expect(await count("accounts")).toBe(0);
    });
  }

  it("rejects a wrong nonce (a token captured for another sign-in)", async () => {
    const response = await signInWith(await h.idToken(), "another-raw-nonce-xyz");
    expect(await response.json()).toEqual({ error: "invalid_nonce" });
    expect(await count("accounts")).toBe(0);
  });

  it("rejects garbage tokens and bodies", async () => {
    for (const token of ["", "a.b", "a.b.c", "x".repeat(9000)]) {
      expect((await signInWith(token)).status).toBe(401);
    }
    expect((await h.call("POST", "/v1/auth/apple", { raw: "{not json" })).status).toBe(400);
    expect((await h.call("POST", "/v1/auth/apple", { raw: "[1,2]" })).status).toBe(400);
    expect((await h.call("POST", "/v1/auth/apple", { raw: JSON.stringify({ pad: "x".repeat(70_000) }) })).status).toBe(413);
    expect(await count("accounts")).toBe(0);
  });
});

describe("Sign in with Apple — the code exchange and the account", () => {
  it("exchanges the code with a valid ES256 client secret and keeps the refresh token encrypted", async () => {
    await h.signIn();
    const exchange = h.apple.calls.find((c) => c.url.endsWith("/auth/token"));
    expect(exchange?.body.get("grant_type")).toBe("authorization_code");
    expect(exchange?.body.get("client_id")).toBe(CLIENT_ID);
    const secret = decodeJWT(exchange!.body.get("client_secret")!);
    expect(secret.header).toMatchObject({ alg: "ES256", kid: "KEYID12345" });
    expect(secret.payload).toMatchObject({ iss: "TEAMID1234", aud: "https://appleid.apple.com", sub: CLIENT_ID });
    const valid = await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, h.apple.esPublicKey,
                                             secret.signature, secret.signingInput);
    expect(valid).toBe(true);
    const row = await env.DB.prepare("SELECT refresh_token_enc FROM identities").first<{ refresh_token_enc: string }>();
    expect(row?.refresh_token_enc).not.toContain("refresh-1");
    expect(await decrypt(row!.refresh_token_enc, h.env.TOKEN_ENC_KEY!)).toBe("refresh-1");
  });

  it("creates no account when Apple refuses the code (an unrevokable account is never made)", async () => {
    h.apple.tokenStatus = 400;
    const response = await signInWith(await h.idToken());
    expect(response.status).toBe(502);
    expect(await count("accounts")).toBe(0);
  });

  it("refuses to sign in when the server cannot keep refresh tokens", async () => {
    h.env.TOKEN_ENC_KEY = undefined;
    const response = await signInWith(await h.idToken());
    expect(response.status).toBe(503);
    expect(await count("accounts")).toBe(0);
  });

  it("keeps the first-sign-in name, cleaned, and finds the same account next time", async () => {
    const first = await h.signIn(undefined, { givenName: "  Ada ", familyName: "Lovelace\n" });
    expect(first.profile.displayName).toBe("Ada Lovelace");
    h.apple.nextRefreshToken = "refresh-2";
    const second = await h.signIn(undefined, { givenName: "Someone", familyName: "Else" });
    expect(second.profile.displayName).toBe("Ada Lovelace");
    expect(await count("accounts")).toBe(1);
    expect(await count("sessions")).toBe(2);
    const row = await env.DB.prepare("SELECT refresh_token_enc FROM identities").first<{ refresh_token_enc: string }>();
    expect(await decrypt(row!.refresh_token_enc, h.env.TOKEN_ENC_KEY!)).toBe("refresh-2");
  });

  it("keeps different Apple users apart", async () => {
    await h.signIn("user-a");
    await h.signIn("user-b");
    expect(await count("accounts")).toBe(2);
  });
});

describe("Sessions, profile, sign-out", () => {
  it("reads and renames the profile with the session", async () => {
    const { session } = await h.signIn();
    const read = await h.call("GET", "/v1/profile", { token: session });
    expect(read.status).toBe(200);
    expect(await read.json()).toMatchObject({ email: "relay@privaterelay.appleid.com", provider: "apple" });
    const renamed = await h.call("PUT", "/v1/profile", { token: session, body: { displayName: " New  Name " } });
    expect(await renamed.json()).toMatchObject({ displayName: "New Name" });
    for (const bad of ["", "   ", "x".repeat(51), "bad\u0007name", 42]) {
      expect((await h.call("PUT", "/v1/profile", { token: session, body: { displayName: bad } })).status).toBe(400);
    }
  });

  it("refuses missing, malformed and unknown tokens", async () => {
    expect((await h.call("GET", "/v1/profile")).status).toBe(401);
    expect((await h.call("GET", "/v1/profile", { token: "short" })).status).toBe(401);
    expect((await h.call("GET", "/v1/profile", { token: "A".repeat(43) })).status).toBe(401);
  });

  it("expires a session after 90 days without use, and renews it by use", async () => {
    const { session } = await h.signIn();
    h.clock.now += 80 * 86_400_000;
    expect((await h.call("GET", "/v1/profile", { token: session })).status).toBe(200);  // renewed here
    h.clock.now += 80 * 86_400_000;  // 160 days after sign-in, 80 after last use
    expect((await h.call("GET", "/v1/profile", { token: session })).status).toBe(200);
    h.clock.now += 91 * 86_400_000;
    expect((await h.call("GET", "/v1/profile", { token: session })).status).toBe(401);
    expect(await count("sessions")).toBe(0);
  });

  it("signs out one session only", async () => {
    const one = await h.signIn();
    const two = await h.signIn();
    expect((await h.call("POST", "/v1/auth/signout", { token: one.session })).status).toBe(200);
    expect((await h.call("GET", "/v1/profile", { token: one.session })).status).toBe(401);
    expect((await h.call("GET", "/v1/profile", { token: two.session })).status).toBe(200);
  });
});

describe("Account deletion", () => {
  it("revokes Apple's token and deletes every row of the account, and only that account", async () => {
    const mine = await h.signIn("user-a");
    await h.signIn("user-a");
    await h.signIn("user-b");
    const response = await h.call("DELETE", "/v1/account", { token: mine.session });
    expect(await response.json()).toEqual({ deleted: true, appleRevocation: "done" });
    const revoke = h.apple.calls.find((c) => c.url.endsWith("/auth/revoke"));
    expect(revoke?.body.get("token")).toBe("refresh-1");
    expect(revoke?.body.get("token_type_hint")).toBe("refresh_token");
    expect([await count("accounts"), await count("identities"), await count("sessions")]).toEqual([1, 1, 1]);
    expect((await h.call("GET", "/v1/profile", { token: mine.session })).status).toBe(401);
    // A second deletion with the dead session changes nothing.
    expect((await h.call("DELETE", "/v1/account", { token: mine.session })).status).toBe(401);
    expect(await count("accounts")).toBe(1);
  });

  it("deletes the rows even when Apple refuses the revocation, and queues it", async () => {
    const { session } = await h.signIn();
    h.apple.revokeStatus = 500;
    const response = await h.call("DELETE", "/v1/account", { token: session });
    expect(await response.json()).toEqual({ deleted: true, appleRevocation: "pending" });
    expect([await count("accounts"), await count("identities"), await count("sessions")]).toEqual([0, 0, 0]);
    expect(await count("pending_revocations")).toBe(1);
  });

  it("signing in again after deletion makes a new, empty account", async () => {
    const first = await h.signIn(undefined, { givenName: "Ada" });
    await h.call("DELETE", "/v1/account", { token: first.session });
    const again = await h.signIn();
    expect(again.profile.displayName).toBeNull();
    expect(await count("accounts")).toBe(1);
  });
});

describe("Pages and routing", () => {
  it("serves the stub privacy and support pages and 404s the rest", async () => {
    for (const path of ["/privacy", "/support"]) {
      const response = await h.call("GET", path);
      expect(response.status).toBe(200);
      expect(response.headers.get("content-type")).toContain("text/html");
    }
    expect((await h.call("GET", "/nope")).status).toBe(404);
    expect((await h.call("GET", "/v1/auth/apple")).status).toBe(404);
  });

  it("never echoes a token or key in an error", async () => {
    const response = await signInWith(await h.idToken({}, NONCE, { forged: true }));
    const text = await response.text();
    expect(text).not.toContain("refresh");
    expect(text).not.toContain("PRIVATE");
    expect(utf8(text).length).toBeLessThan(100);
    expect(base64UrlDecode("").length).toBe(0);
  });
});
