import assert from "node:assert/strict";
import { generateKeyPairSync, sign } from "node:crypto";
import test from "node:test";

const audience = "com.example.Nido";
const issuer = "https://appleid.apple.com";
const secret = "test-only-source-bucket-secret-32-bytes";
const baseNow = new Date("2026-09-01T12:00:00.000Z");
const { privateKey, publicKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
const jwk = publicKey.export({ format: "jwk" });
jwk.alg = "RS256";
jwk.kid = "route-test-key";
jwk.use = "sig";

function encode(value) {
  return Buffer.from(JSON.stringify(value)).toString("base64url");
}

function signedToken(nonce) {
  const nowSeconds = Math.floor(baseNow.getTime() / 1000);
  const header = { alg: "RS256", kid: jwk.kid, typ: "JWT" };
  const payload = {
    iss: issuer,
    aud: audience,
    sub: "route-level-apple-subject",
    nonce,
    iat: nowSeconds - 10,
    exp: nowSeconds + 300,
  };
  const signingInput = `${encode(header)}.${encode(payload)}`;
  return `${signingInput}.${sign("RSA-SHA256", Buffer.from(signingInput), privateKey).toString("base64url")}`;
}

function memoryStore() {
  const challenges = new Map();
  const sessions = [];
  return {
    challenges,
    sessions,
    async exchange(input) {
      await new Promise(resolve => setTimeout(resolve, 5));
      if (challenges.has(input.challenge.id)) throw new Error("challenge replay");
      challenges.set(input.challenge.id, { ...input.challenge, consumedAt: input.now });
      sessions.push({ id: input.session.id, userSubject: input.subject });
      return { membership: null };
    },
  };
}

test("injected Apple session route accepts local RS256 and rejects concurrent replay", async () => {
  const [challengeModule, handlerModule, verifierModule] = await Promise.all([
    import("../app/api/nido/apple-challenge.ts"),
    import("../app/api/nido/apple-session-handler.ts"),
    import("../app/api/nido/apple-verifier.ts"),
  ]);
  const challenge = await challengeModule.createOpaqueAppleChallenge(secret, baseNow.getTime());
  const verifyIdentity = verifierModule.createAppleIdentityVerifier({
    jwks: { keys: [jwk] }, audience, now: () => baseNow,
  });
  const store = memoryStore();
  const handler = handlerModule.createAppleSessionHandler({
    audience,
    challengeSecret: secret,
    verifyIdentity,
    store,
    now: () => baseNow.getTime(),
  });
  const requestBody = JSON.stringify({
    challengeID: challenge.challengeID,
    identityToken: signedToken(challenge.nonceHash),
  });
  const responses = await Promise.all([
    handler(new Request("https://nido.test/api/nido/auth/apple/session", {
      method: "POST", headers: { "content-type": "application/json" }, body: requestBody,
    })),
    handler(new Request("https://nido.test/api/nido/auth/apple/session", {
      method: "POST", headers: { "content-type": "application/json" }, body: requestBody,
    })),
  ]);
  assert.deepEqual(responses.map(response => response.status).sort(), [201, 401]);
  assert.equal(store.challenges.size, 1);
  assert.equal(store.sessions.length, 1);
});

test("Apple session route recomputes time after verification and rejects an expired challenge", async () => {
  const [challengeModule, handlerModule, verifierModule] = await Promise.all([
    import("../app/api/nido/apple-challenge.ts"),
    import("../app/api/nido/apple-session-handler.ts"),
    import("../app/api/nido/apple-verifier.ts"),
  ]);
  const challenge = await challengeModule.createOpaqueAppleChallenge(secret, baseNow.getTime(), 100);
  const verifyIdentity = verifierModule.createAppleIdentityVerifier({
    jwks: { keys: [jwk] }, audience, now: () => baseNow,
  });
  const store = memoryStore();
  let clockReads = 0;
  const handler = handlerModule.createAppleSessionHandler({
    audience,
    challengeSecret: secret,
    verifyIdentity: async (...arguments_) => {
      const result = await verifyIdentity(...arguments_);
      return result;
    },
    store,
    now: () => clockReads++ === 0 ? baseNow.getTime() : baseNow.getTime() + 101,
  });
  const response = await handler(new Request("https://nido.test/api/nido/auth/apple/session", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ challengeID: challenge.challengeID, identityToken: signedToken(challenge.nonceHash) }),
  }));
  assert.equal(response.status, 401);
  assert.equal(store.sessions.length, 0);
});
