/** Small cryptographic helpers on WebCrypto (the Workers runtime has no Node crypto). */

const encoder = new TextEncoder();

export function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function base64UrlDecode(text: string): Uint8Array {
  if (!/^[A-Za-z0-9_-]*$/.test(text)) throw new Error("not base64url");
  const padded = text.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((text.length + 3) % 4);
  const binary = atob(padded);
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

function base64Decode(text: string): Uint8Array {
  const binary = atob(text.trim());
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

function base64Encode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

export function utf8(text: string): Uint8Array {
  return encoder.encode(text);
}

export async function sha256Hex(text: string): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", utf8(text)));
  return [...digest].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** An opaque bearer token: 32 random bytes, base64url. */
export function newToken(random: (n: number) => Uint8Array): string {
  return base64UrlEncode(random(32));
}

/** A random UUID (v4) from the injected randomness. */
export function newID(random: (n: number) => Uint8Array): string {
  const b = random(16);
  b[6] = (b[6]! & 0x0f) | 0x40;
  b[8] = (b[8]! & 0x3f) | 0x80;
  const hex = [...b].map((x) => x.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

/** Constant-time comparison of two strings. */
export function safeEqual(a: string, b: string): boolean {
  const x = utf8(a);
  const y = utf8(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

async function aesKey(secret: string): Promise<CryptoKey> {
  const raw = base64Decode(secret);
  if (raw.length !== 32) throw new Error("TOKEN_ENC_KEY must be 32 bytes, base64");
  return crypto.subtle.importKey("raw", raw, "AES-GCM", false, ["encrypt", "decrypt"]);
}

/** AES-256-GCM; output is base64(iv ‖ ciphertext). */
export async function encrypt(plain: string, secret: string, random: (n: number) => Uint8Array): Promise<string> {
  const iv = random(12);
  const sealed = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv }, await aesKey(secret), utf8(plain)));
  const out = new Uint8Array(iv.length + sealed.length);
  out.set(iv);
  out.set(sealed, iv.length);
  return base64Encode(out);
}

export async function decrypt(sealed: string, secret: string): Promise<string> {
  const bytes = base64Decode(sealed);
  const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv: bytes.slice(0, 12) }, await aesKey(secret), bytes.slice(12));
  return new TextDecoder().decode(plain);
}

/** Imports a PKCS#8 PEM private key (Apple's .p8) for ES256 signing. */
export async function importES256PrivateKey(pem: string): Promise<CryptoKey> {
  const body = pem.replace(/\\n/g, "\n").replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "").replace(/\s+/g, "");
  return crypto.subtle.importKey("pkcs8", base64Decode(body), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
}
