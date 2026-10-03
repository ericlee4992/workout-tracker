import { AuthError } from "./apple";

/** The JSON routes' body limit. The feedback route has its own (a screenshot), passed to `readBodyBytes`. */
export const MAX_BODY_BYTES = 64 * 1024;

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status, headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
}

export function failure(code: string, status: number): Response {
  return json({ error: code }, status);
}

/**
 * Reads at most `limit` **bytes** from the stream, cancelling it as soon as the limit is passed
 * (codex-review-03 #2: `request.text()` buffered a chunked body of any size first, and measured UTF-16 units).
 */
export async function readBodyBytes(request: Request, limit: number): Promise<Uint8Array> {
  const declared = Number(request.headers.get("content-length") ?? "0");
  if (declared > limit) throw new AuthError("body_too_large", 413);
  if (!request.body) return new Uint8Array(0);
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > limit) {
      await reader.cancel();
      throw new AuthError("body_too_large", 413);
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  return bytes;
}

export async function readJSON(request: Request): Promise<Record<string, unknown>> {
  const text = new TextDecoder().decode(await readBodyBytes(request, MAX_BODY_BYTES));
  let body: unknown;
  try { body = JSON.parse(text); } catch { throw new AuthError("malformed_json", 400); }
  if (typeof body !== "object" || body === null || Array.isArray(body)) throw new AuthError("malformed_json", 400);
  return body as Record<string, unknown>;
}

export function bearer(request: Request): string | null {
  const header = request.headers.get("authorization") ?? "";
  const match = /^Bearer ([A-Za-z0-9_-]+)$/.exec(header);
  return match ? match[1]! : null;
}

