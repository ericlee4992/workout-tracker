import { base64UrlDecode, base64UrlEncode, utf8 } from "./crypto";

export interface JWTParts {
  header: { alg?: string; kid?: string; typ?: string };
  payload: Record<string, unknown>;
  signingInput: Uint8Array;
  signature: Uint8Array;
}

/** Splits and decodes a compact JWT without verifying it. Throws on anything malformed. */
export function decodeJWT(token: string): JWTParts {
  if (typeof token !== "string" || token.length > 8192) throw new Error("malformed token");
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("malformed token");
  const [h, p, s] = parts as [string, string, string];
  const json = (segment: string) => JSON.parse(new TextDecoder().decode(base64UrlDecode(segment)));
  const header = json(h);
  const payload = json(p);
  if (typeof header !== "object" || header === null || typeof payload !== "object" || payload === null) {
    throw new Error("malformed token");
  }
  return { header, payload, signingInput: utf8(`${h}.${p}`), signature: base64UrlDecode(s) };
}

/** Verifies an RS256 signature against an RSA public JWK. */
export async function verifyRS256(parts: JWTParts, jwk: JsonWebKey): Promise<boolean> {
  if (parts.header.alg !== "RS256") return false;
  const key = await crypto.subtle.importKey(
    "jwk", { kty: jwk.kty, n: jwk.n, e: jwk.e, alg: "RS256", ext: true },
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
  return crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, parts.signature, parts.signingInput);
}

/** Signs an ES256 JWT (WebCrypto's ECDSA output is already the JOSE r‖s form). */
export async function signES256(header: Record<string, unknown>, payload: Record<string, unknown>,
                                key: CryptoKey): Promise<string> {
  const encode = (value: unknown) => base64UrlEncode(utf8(JSON.stringify(value)));
  const input = `${encode({ ...header, alg: "ES256" })}.${encode(payload)}`;
  const signature = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, utf8(input)));
  return `${input}.${base64UrlEncode(signature)}`;
}
