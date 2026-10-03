import { env } from "cloudflare:test";
import { beforeEach, describe, expect, it } from "vitest";
import { FORCED_REFRESH_COOLDOWN_MS } from "../src/apple";
import { base64UrlEncode, sha256Hex, utf8 } from "../src/crypto";
import { runPendingRevocations } from "../src/index";
import { deleteAccountRevokingApple } from "../src/index";
import { claimDeletion, createAccount, createOrFindAccount, createSession, decryptToken, PENDING_MAX_AGE_MS,
         updateRefreshToken } from "../src/store";
import { CLIENT_ID, count, harness, NONCE, type Harness } from "./helpers";

// codex-review-03: one block per finding.
let h: Harness;
beforeEach(async () => {
  h = await harness();
});

const signInBody = async (subject: string, code: string, nonce = NONCE) =>
  ({ identityToken: await h.idToken({ sub: subject }, nonce), authorizationCode: code, nonce });

describe("#1 the authorization code must belong to the signing-in user", () => {
  it("refuses A's identity token with B's code, creating nothing and storing nothing", async () => {
    const response = await h.call("POST", "/v1/auth/apple", { body: await signInBody("user-A", h.apple.issueCode("user-B")) });
    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: "code_identity_mismatch" });
    expect([await count("accounts"), await count("identities"), await count("sessions")]).toEqual([0, 0, 0]);
  });

  it("refuses a code that was already used", async () => {
    const code = h.apple.issueCode("user-A");
    expect((await h.call("POST", "/v1/auth/apple", { body: await signInBody("user-A", code) })).status).toBe(200);
    const again = await h.call("POST", "/v1/auth/apple", { body: await signInBody("user-A", code) });
    expect(again.status).toBe(502);
    expect(await count("sessions")).toBe(1);
  });

  it("refuses malformed exchange answers: no id_token, an unsigned id_token, an empty refresh token", async () => {
    const answers: ((subject: string) => Promise<unknown>)[] = [
      async () => ({ refresh_token: "r" }),
      async (subject) => ({ refresh_token: "r", id_token: await h.apple.sign({ iss: "https://appleid.apple.com", aud: CLIENT_ID,
        iat: Math.floor(h.clock.now / 1000), exp: Math.floor(h.clock.now / 1000) + 600, sub: subject }, { forged: true }) }),
      async (subject) => ({ refresh_token: "", id_token: await h.apple.sign({ iss: "https://appleid.apple.com", aud: CLIENT_ID,
        iat: Math.floor(h.clock.now / 1000), exp: Math.floor(h.clock.now / 1000) + 600, sub: subject }) }),
      async (subject) => ({ refresh_token: "r", id_token: await h.apple.sign({ iss: "https://appleid.apple.com", aud: "other.app",
        iat: Math.floor(h.clock.now / 1000), exp: Math.floor(h.clock.now / 1000) + 600, sub: subject }) }),
    ];
    for (const answer of answers) {
      h.apple.tokenBody = answer;
      const response = await h.call("POST", "/v1/auth/apple", { body: await signInBody("user-A", h.apple.issueCode("user-A")) });
      expect(response.status).toBe(502);
    }
    expect(await count("accounts")).toBe(0);
  });

  it("rejects identity tokens without iat or exp numbers", async () => {
    for (const overrides of [{ iat: undefined }, { exp: "soon" }, { iat: "now" }]) {
      const token = await h.idToken(overrides);
      const response = await h.call("POST", "/v1/auth/apple", {
        body: { identityToken: token, authorizationCode: h.apple.issueCode("001234.apple-user"), nonce: NONCE } });
      expect(response.status).toBe(401);
    }
  });
});

describe("#2 the body limit counts bytes from the stream", () => {
  it("refuses a body over the limit in bytes even when its characters are under it", async () => {
    const response = await h.call("POST", "/v1/auth/apple", { raw: JSON.stringify({ pad: "é".repeat(40_000) }) });  // 80 KB
    expect(response.status).toBe(413);
  });

  it("stops reading a streamed body without Content-Length as soon as it passes the limit", async () => {
    let pulled = 0;
    const chunk = new Uint8Array(16 * 1024).fill(0x61);
    const stream = new ReadableStream<Uint8Array>({
      pull(controller) { pulled += chunk.byteLength; if (pulled > 1024 * 1024) controller.close(); else controller.enqueue(chunk); },
    });
    const { createHandler } = await import("../src/index");
    const response = await createHandler(h.deps)(new Request("https://stacked.test/v1/auth/apple", {
      method: "POST", body: stream, duplex: "half" } as RequestInit), h.env);
    expect(response.status).toBe(413);
    expect(pulled).toBeLessThanOrEqual(64 * 1024 + 3 * chunk.byteLength);
  });

  it("accepts a body right at the limit (then judges its content)", async () => {
    const base = JSON.stringify({ identityToken: "x", authorizationCode: "y", nonce: "z", pad: "" });
    const raw = JSON.stringify({ identityToken: "x", authorizationCode: "y", nonce: "z", pad: "a".repeat(64 * 1024 - utf8(base).length) });
    expect(utf8(raw).length).toBe(64 * 1024);
    expect((await h.call("POST", "/v1/auth/apple", { raw })).status).toBe(401);
  });
});

describe("#3 unknown key IDs cannot make the server hammer Apple", () => {
  it("refetches the keys for unknown kids at most once per cooldown, and shares concurrent fetches", async () => {
    await h.signIn();  // warms the key cache
    const warm = h.apple.keyFetches;
    for (let i = 0; i < 5; i++) {
      await h.call("POST", "/v1/auth/apple", { body: { identityToken: await h.idToken({}, NONCE, { kid: `BOGUS${i}` }), authorizationCode: "c", nonce: NONCE } });
    }
    await Promise.all([1, 2, 3].map(async (i) => h.call("POST", "/v1/auth/apple", {
      body: { identityToken: await h.idToken({}, NONCE, { kid: `BOGUS-C${i}` }), authorizationCode: "c", nonce: NONCE } })));
    expect(h.apple.keyFetches - warm).toBe(1);
  });

  it("requests waiting for a rotated key all join the one refresh in flight (03b #1)", async () => {
    await h.signIn();
    const warm = h.apple.keyFetches;
    const rotated = await h.apple.rotatedKey();
    h.apple.extraKeys.push(rotated.jwk);
    let release!: () => void;
    h.apple.keysGate = new Promise((resolve) => { release = resolve; });
    const now = Math.floor(h.clock.now / 1000);
    const token = async () => {
      const claims = { iss: "https://appleid.apple.com", aud: CLIENT_ID, iat: now, exp: now + 600, sub: "001234.apple-user",
                       nonce: await sha256Hex(NONCE) };
      const enc = (v: unknown) => base64UrlEncode(utf8(JSON.stringify(v)));
      const input = `${enc({ alg: "RS256", kid: rotated.kid })}.${enc(claims)}`;
      const sig = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", rotated.privateKey, utf8(input)));
      return `${input}.${base64UrlEncode(sig)}`;
    };
    const requests = [1, 2, 3].map(async () => h.call("POST", "/v1/auth/apple", {
      body: { identityToken: await token(), authorizationCode: h.apple.issueCode("001234.apple-user"), nonce: NONCE } }));
    await new Promise((r) => setTimeout(r, 50));
    h.apple.keysGate = undefined;
    release();
    const statuses = (await Promise.all(requests)).map((r) => r.status);
    expect(statuses).toEqual([200, 200, 200]);
    expect(h.apple.keyFetches - warm).toBe(1);
  });

  it("still picks up a rotated Apple key after the cooldown", async () => {
    await h.signIn();
    const rotated = await h.apple.rotatedKey();
    h.apple.extraKeys.push(rotated.jwk);
    h.clock.now += FORCED_REFRESH_COOLDOWN_MS + 1000;
    const now = Math.floor(h.clock.now / 1000);
    const claims = { iss: "https://appleid.apple.com", aud: CLIENT_ID, iat: now, exp: now + 600, sub: "001234.apple-user",
                     nonce: await sha256Hex(NONCE) };
    const enc = (v: unknown) => base64UrlEncode(utf8(JSON.stringify(v)));
    const input = `${enc({ alg: "RS256", kid: rotated.kid })}.${enc(claims)}`;
    const signature = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", rotated.privateKey, utf8(input)));
    const response = await h.call("POST", "/v1/auth/apple", {
      body: { identityToken: `${input}.${base64UrlEncode(signature)}`, authorizationCode: h.apple.issueCode("001234.apple-user"), nonce: NONCE } });
    expect(response.status).toBe(200);
  });
});

describe("#4 simultaneous first sign-ins for one user", () => {
  it("both succeed on one account", async () => {
    const [a, b] = await Promise.all([h.signIn("same-user"), h.signIn("same-user")]);
    expect(a.session).not.toBe(b.session);
    expect([await count("accounts"), await count("identities"), await count("sessions")]).toEqual([1, 1, 2]);
  });

  it("the loser of the insert race (identity already created) joins the winner's account", async () => {
    const winner = await createAccount(h.env, h.deps, "apple", "racer", "Win", null, "refresh-W");
    const loser = await createOrFindAccount(h.env, h.deps, "apple", "racer", "Lose", null, "refresh-L");
    expect(loser.id).toBe(winner.id);
    expect(await count("accounts")).toBe(1);
  });
});

describe("#5 deletion survives Apple being down", () => {
  it("queues the revocation and the hourly job completes it when Apple is back", async () => {
    const { session } = await h.signIn();
    h.apple.revokeThrows = true;
    expect(await (await h.call("DELETE", "/v1/account", { token: session })).json()).toEqual({ deleted: true, appleRevocation: "pending" });
    expect([await count("accounts"), await count("pending_revocations")]).toEqual([0, 1]);
    // Not due yet: nothing happens.
    expect(await runPendingRevocations(h.env, h.deps)).toEqual({ revoked: 0, retried: 0, abandoned: 0 });
    h.clock.now += 61 * 60 * 1000;
    expect(await runPendingRevocations(h.env, h.deps)).toEqual({ revoked: 0, retried: 1, abandoned: 0 });  // still down
    h.apple.revokeThrows = false;
    h.clock.now += 3 * 60 * 60 * 1000;
    expect(await runPendingRevocations(h.env, h.deps)).toEqual({ revoked: 1, retried: 0, abandoned: 0 });
    expect(await count("pending_revocations")).toBe(0);
    expect(h.apple.calls.filter((c) => c.url.endsWith("/auth/revoke")).at(-1)?.body.get("token")).toBe("refresh-1");
  });

  it("queues when the encryption key is unavailable at deletion, and revokes once it is back", async () => {
    const { session } = await h.signIn();
    const key = h.env.TOKEN_ENC_KEY;
    h.env.TOKEN_ENC_KEY = undefined;
    expect(await (await h.call("DELETE", "/v1/account", { token: session })).json()).toEqual({ deleted: true, appleRevocation: "pending" });
    h.env.TOKEN_ENC_KEY = key;
    h.clock.now += 2 * 60 * 60 * 1000;
    expect((await runPendingRevocations(h.env, h.deps)).revoked).toBe(1);
  });

  it("a tampered ciphertext is never revoked, retried until 30 days, then dropped", async () => {
    const { session } = await h.signIn();
    await env.DB.prepare("UPDATE identities SET refresh_token_enc = ?").bind(btoa("x".repeat(40))).run();
    expect(await (await h.call("DELETE", "/v1/account", { token: session })).json()).toEqual({ deleted: true, appleRevocation: "pending" });
    h.clock.now += 2 * 60 * 60 * 1000;
    expect((await runPendingRevocations(h.env, h.deps)).retried).toBe(1);
    h.clock.now += PENDING_MAX_AGE_MS;
    expect((await runPendingRevocations(h.env, h.deps)).abandoned).toBe(1);
    expect(await count("pending_revocations")).toBe(0);
  });

  it("an identity without a kept token reports manual revocation", async () => {
    const { session } = await h.signIn();
    await env.DB.prepare("UPDATE identities SET refresh_token_enc = NULL").run();
    expect(await (await h.call("DELETE", "/v1/account", { token: session })).json()).toEqual({ deleted: true, appleRevocation: "manual" });
  });

  it("two simultaneous deletions: one reports the real outcome, the other never claims success (03b #2)", async () => {
    const { session } = await h.signIn();
    h.apple.revokeStatus = 500;
    const results = await Promise.all([1, 2].map(() => h.call("DELETE", "/v1/account", { token: session })));
    const bodies = await Promise.all(results.map(async (r) => ({ status: r.status, body: await r.json() })));
    const winners = bodies.filter((b) => b.status === 200);
    expect(winners).toEqual([{ status: 200, body: { deleted: true, appleRevocation: "pending" } }]);
    for (const other of bodies.filter((b) => b.status !== 200)) {
      expect([401, 409]).toContain(other.status);
      expect(JSON.stringify(other.body)).not.toContain("done");
    }
    expect([await count("accounts"), await count("identities"), await count("sessions"), await count("pending_revocations")])
      .toEqual([0, 0, 0, 1]);
  });

  it("a deletion that loses the claim reports the race, not success (03b #2, deterministic)", async () => {
    const { profile } = await h.signIn();
    const accountID = (await env.DB.prepare("SELECT id FROM accounts").first<{ id: string }>())!.id;
    expect(profile).toBeTruthy();
    h.apple.revokeStatus = 500;
    expect(await deleteAccountRevokingApple(h.env, h.deps, accountID)).toEqual({ deleted: true, appleRevocation: "pending" });
    expect(await deleteAccountRevokingApple(h.env, h.deps, accountID)).toBeNull();
  });

  it("a newer token stored before the claim is the one queued (03b #3: read T1, write T2, fail)", async () => {
    await h.signIn();
    const accountID = (await env.DB.prepare("SELECT id FROM accounts").first<{ id: string }>())!.id;
    await updateRefreshToken(h.env, h.deps, "apple", "001234.apple-user", "refresh-NEW");
    h.apple.revokeStatus = 500;
    await deleteAccountRevokingApple(h.env, h.deps, accountID);
    const queued = await env.DB.prepare("SELECT token_enc FROM pending_revocations").all<{ token_enc: string }>();
    expect(await Promise.all(queued.results.map((r) => decryptToken(h.env, r.token_enc)))).toEqual(["refresh-NEW"]);
  });

  for (const revokeWorks of [true, false]) {
    it(`a sign-in interrupted by a deletion after storing its token must reauthorize (03c #1, revoke ${revokeWorks ? "ok" : "fails"})`, async () => {
      await h.signIn();
      const accountID = (await env.DB.prepare("SELECT id FROM accounts").first<{ id: string }>())!.id;
      h.apple.nextRefreshToken = "refresh-T2";
      h.apple.revokeStatus = revokeWorks ? 200 : 500;
      let outcome: unknown;
      const { createHandler } = await import("../src/index");
      const paused = createHandler({ ...h.deps, pause: async () => { outcome = await deleteAccountRevokingApple(h.env, h.deps, accountID); } });
      const body = { identityToken: await h.idToken(), authorizationCode: h.apple.issueCode("001234.apple-user"), nonce: NONCE };
      const response = await paused(new Request("https://stacked.test/v1/auth/apple", {
        method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body) }), h.env);
      expect(outcome).toEqual({ deleted: true, appleRevocation: revokeWorks ? "done" : "pending" });
      expect(response.status).toBe(409);
      expect(await response.json()).toEqual({ error: "reauthorize" });
      // No account, identity or session was recreated from the claimed token.
      expect([await count("accounts"), await count("identities"), await count("sessions")]).toEqual([0, 0, 0]);
      const queued = await env.DB.prepare("SELECT token_enc FROM pending_revocations").all<{ token_enc: string }>();
      expect(await Promise.all(queued.results.map((r) => decryptToken(h.env, r.token_enc)))).toEqual(revokeWorks ? [] : ["refresh-T2"]);
      if (revokeWorks) {
        expect(h.apple.calls.filter((c) => c.url.endsWith("/auth/revoke")).map((c) => c.body.get("token"))).toEqual(["refresh-T2"]);
      }
    });
  }

  it("a sign-in after the claim cannot write into the deleted account; it gets a new one (03b #3)", async () => {
    await h.signIn();
    const accountID = (await env.DB.prepare("SELECT id FROM accounts").first<{ id: string }>())!.id;
    expect((await claimDeletion(h.env, h.deps, accountID)).won).toBe(true);
    expect(await updateRefreshToken(h.env, h.deps, "apple", "001234.apple-user", "refresh-LATE")).toBe(false);
    expect(await createSession(h.env, h.deps, accountID)).toBeNull();
    h.apple.nextRefreshToken = "refresh-LATE";
    const again = await h.signIn();
    expect(again.session).toBeTruthy();
    const accounts = await env.DB.prepare("SELECT id FROM accounts").all<{ id: string }>();
    expect(accounts.results.map((a) => a.id)).not.toContain(accountID);
    expect(accounts.results.length).toBe(1);
  });
});
