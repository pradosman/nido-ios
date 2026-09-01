import {
  decodeBase64Url,
  encodeBase64Url,
  hmacSha256,
  randomSecret,
  sha256,
  verifyHmacSha256,
} from "./crypto.ts";

const DEFAULT_CHALLENGE_LIFETIME_MS = 5 * 60 * 1_000;
const MAXIMUM_CHALLENGE_LENGTH = 1_024;

type ChallengePayload = {
  version: 1;
  id: string;
  nonceHash: string;
  expiresAt: number;
};

function encodePayload(payload: ChallengePayload) {
  return encodeBase64Url(new TextEncoder().encode(JSON.stringify(payload)));
}

export async function createOpaqueAppleChallenge(
  secret: string,
  now = Date.now(),
  lifetimeMs = DEFAULT_CHALLENGE_LIFETIME_MS,
) {
  if (!secret || lifetimeMs < 1 || lifetimeMs > DEFAULT_CHALLENGE_LIFETIME_MS) {
    throw new Error("Invalid challenge configuration");
  }
  const nonce = randomSecret(32);
  const nonceHash = await sha256(nonce);
  const expiresAt = now + lifetimeMs;
  const payload = encodePayload({ version: 1, id: crypto.randomUUID(), nonceHash, expiresAt });
  const signature = encodeBase64Url(await hmacSha256(secret, payload));
  return { challengeID: `${payload}.${signature}`, nonce, nonceHash, expiresAt };
}

export async function verifyOpaqueAppleChallenge(challengeID: string, secret: string, now = Date.now()) {
  if (!challengeID || challengeID.length > MAXIMUM_CHALLENGE_LENGTH) throw new Error("Invalid challenge");
  const parts = challengeID.split(".");
  if (parts.length !== 2) throw new Error("Invalid challenge");
  const [encodedPayload, encodedSignature] = parts;
  const payloadBytes = decodeBase64Url(encodedPayload);
  const signature = decodeBase64Url(encodedSignature);
  if (!payloadBytes || !signature || !await verifyHmacSha256(secret, encodedPayload, signature)) {
    throw new Error("Invalid challenge signature");
  }
  let payload: unknown;
  try {
    payload = JSON.parse(new TextDecoder().decode(payloadBytes));
  } catch {
    throw new Error("Invalid challenge payload");
  }
  if (
    !payload
    || typeof payload !== "object"
    || (payload as Partial<ChallengePayload>).version !== 1
    || typeof (payload as Partial<ChallengePayload>).id !== "string"
    || !/^[0-9a-f-]{36}$/i.test((payload as Partial<ChallengePayload>).id ?? "")
    || typeof (payload as Partial<ChallengePayload>).nonceHash !== "string"
    || !/^[a-f0-9]{64}$/i.test((payload as Partial<ChallengePayload>).nonceHash ?? "")
    || !Number.isInteger((payload as Partial<ChallengePayload>).expiresAt)
  ) {
    throw new Error("Invalid challenge payload");
  }
  const verified = payload as ChallengePayload;
  if (verified.expiresAt <= now || verified.expiresAt > now + DEFAULT_CHALLENGE_LIFETIME_MS) {
    throw new Error("Expired challenge");
  }
  return verified;
}
