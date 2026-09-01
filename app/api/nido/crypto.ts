export function randomSecret(byteLength: number) {
  const bytes = crypto.getRandomValues(new Uint8Array(byteLength));
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

export async function sha256(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, "0")).join("");
}

async function hmacKey(secret: string) {
  return crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

export async function hmacSha256(secret: string, value: string) {
  const signature = await crypto.subtle.sign("HMAC", await hmacKey(secret), new TextEncoder().encode(value));
  return new Uint8Array(signature);
}

export async function verifyHmacSha256(secret: string, value: string, signature: Uint8Array<ArrayBuffer>) {
  return crypto.subtle.verify("HMAC", await hmacKey(secret), signature, new TextEncoder().encode(value));
}

export async function hmacSha256Hex(secret: string, value: string) {
  return Array.from(await hmacSha256(secret, value), byte => byte.toString(16).padStart(2, "0")).join("");
}

export function encodeBase64Url(bytes: Uint8Array) {
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

export function decodeBase64Url(value: string) {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) return null;
  try {
    const padding = "=".repeat((4 - value.length % 4) % 4);
    const decoded = atob(value.replaceAll("-", "+").replaceAll("_", "/") + padding);
    return Uint8Array.from(decoded, character => character.charCodeAt(0));
  } catch {
    return null;
  }
}
