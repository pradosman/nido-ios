import { verifyOpaqueAppleChallenge } from "./apple-challenge.ts";
import { randomSecret, sha256 } from "./crypto.ts";
import { bodyErrorResponse, boundedString, readJsonObject } from "./validation.ts";

const SESSION_BODY_LIMIT_BYTES = 20_000;
const SESSION_LIFETIME_MS = 30 * 24 * 60 * 60 * 1_000;

type VerifiedIdentity = { subject: string };
type MembershipState = { caregiverID: string; householdID: string; role: "owner" | "caregiver" } | null;

export type AppleSessionExchange = {
  subject: string;
  challenge: { id: string; nonceHash: string; expiresAt: number };
  session: { id: string; tokenHash: string; expiresAt: number };
  now: number;
};

export type AppleSessionStore = {
  exchange(input: AppleSessionExchange): Promise<{ membership: MembershipState }>;
};

type AppleSessionHandlerOptions = {
  challengeSecret: string;
  verifyIdentity(identityToken: string, expectedNonce: string): Promise<VerifiedIdentity>;
  store: AppleSessionStore;
  now?: () => number;
};

export class AppleSessionRateLimitError extends Error {}

export function createAppleSessionHandler(options: AppleSessionHandlerOptions) {
  const now = options.now ?? Date.now;
  return async (request: Request) => {
    try {
      const body = await readJsonObject(request, SESSION_BODY_LIMIT_BYTES);
      const challengeID = boundedString(body?.challengeID, 1_024);
      const identityToken = boundedString(body?.identityToken, 16_384);
      if (!challengeID || !identityToken) {
        return Response.json({ error: "Invalid authentication request" }, { status: 400 });
      }
      const challenge = await verifyOpaqueAppleChallenge(challengeID, options.challengeSecret, now());
      const identity = await options.verifyIdentity(identityToken, challenge.nonceHash);

      // Token/JWKS verification may suspend on the network. Expiry decisions and
      // persisted timestamps must use a fresh clock reading after it completes.
      const exchangeTime = now();
      if (challenge.expiresAt <= exchangeTime) {
        return Response.json({ error: "The authentication challenge is invalid" }, { status: 401 });
      }
      const token = randomSecret(32);
      const expiresAt = exchangeTime + SESSION_LIFETIME_MS;
      const result = await options.store.exchange({
        subject: identity.subject,
        challenge,
        session: {
          id: crypto.randomUUID(),
          tokenHash: await sha256(token),
          expiresAt,
        },
        now: exchangeTime,
      });
      return Response.json({
        token,
        expiresAt: new Date(expiresAt).toISOString(),
        membership: result.membership,
      }, { status: 201 });
    } catch (error) {
      const bodyResponse = bodyErrorResponse(error);
      if (bodyResponse) return bodyResponse;
      if (error instanceof AppleSessionRateLimitError) {
        return Response.json({ error: "Too many authentication attempts" }, { status: 429 });
      }
      return Response.json({ error: "Apple authentication failed" }, { status: 401 });
    }
  };
}
