import assert from "node:assert/strict";
import { generateKeyPairSync, sign } from "node:crypto";
import test from "node:test";

const audience = "com.example.Nido";
const issuer = "https://appleid.apple.com";
const nonce = "f".repeat(64);
const now = new Date("2026-09-01T12:00:00.000Z");
const { privateKey, publicKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
const jwk = publicKey.export({ format: "jwk" });
jwk.alg = "RS256";
jwk.kid = "test-key";
jwk.use = "sig";

function encode(value) {
  return Buffer.from(JSON.stringify(value)).toString("base64url");
}

function appleToken(overrides = {}, headerOverrides = {}) {
  const header = { alg: "RS256", kid: jwk.kid, typ: "JWT", ...headerOverrides };
  const payload = {
    iss: issuer,
    aud: audience,
    sub: "001234.stable-apple-subject",
    nonce,
    iat: Math.floor(now.getTime() / 1000) - 30,
    exp: Math.floor(now.getTime() / 1000) + 300,
    ...overrides,
  };
  const signingInput = `${encode(header)}.${encode(payload)}`;
  return `${signingInput}.${sign("RSA-SHA256", Buffer.from(signingInput), privateKey).toString("base64url")}`;
}

async function verifier() {
  const { createAppleIdentityVerifier } = await import("../app/api/nido/apple-verifier.ts");
  return createAppleIdentityVerifier({ jwks: { keys: [jwk] }, audience, now: () => now });
}

test("Apple verifier accepts a locally signed token with the exact identity contract", async () => {
  const verify = await verifier();
  assert.deepEqual(await verify(appleToken(), nonce), { subject: "001234.stable-apple-subject" });
});

test("Apple verifier accepts a fresh signed token with provider-controlled future expiration", async () => {
  const verify = await verifier();
  const expiration = Math.floor(now.getTime() / 1000) + 3_600;
  assert.deepEqual(
    await verify(appleToken({ exp: expiration }), nonce),
    { subject: "001234.stable-apple-subject" },
  );
});

test("Apple verifier rejects untrusted identity, algorithm, nonce, and token age", async () => {
  const verify = await verifier();
  const invalidTokens = [
    appleToken({ iss: "https://attacker.example" }),
    appleToken({ aud: "com.example.Other" }),
    appleToken({ aud: [audience, "com.example.Attacker"] }),
    appleToken({ sub: "" }),
    appleToken({ nonce: "0".repeat(64) }),
    appleToken({ iat: Math.floor(now.getTime() / 1000) - 601 }),
    appleToken({}, { alg: "HS256" }),
  ];
  for (const token of invalidTokens) {
    await assert.rejects(() => verify(token, nonce));
  }
});
