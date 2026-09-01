import { and, eq, isNull } from "drizzle-orm";
import { getDb } from "../../../../../../db/index.ts";
import { authChallenges, authSessions, caregivers, users } from "../../../../../../db/schema.ts";
import { createAppleIdentityVerifier } from "../../../apple-verifier.ts";
import {
  AppleSessionRateLimitError,
  createAppleSessionHandler,
  type AppleSessionExchange,
  type AppleSessionStore,
} from "../../../apple-session-handler.ts";
import { hmacSha256Hex } from "../../../crypto.ts";
import { consumeRateLimit } from "../../../rate-limit.ts";
import { appleAudience, authBucketSecret } from "../../../runtime-config.ts";

const RATE_WINDOW_MS = 10 * 60 * 1_000;

export function createProductionAppleSessionStore(secret: string): AppleSessionStore {
  return {
    async exchange(input: AppleSessionExchange) {
      const db = getDb();
      const rateKey = await hmacSha256Hex(secret, `apple-session:${input.subject}`);
      const exchangeTime = new Date(input.now);
      if (!await consumeRateLimit(`apple-session:${rateKey}`, exchangeTime, RATE_WINDOW_MS, 10)) {
        throw new AppleSessionRateLimitError();
      }
      return db.transaction(async tx => {
        await tx.insert(users).values({ id: crypto.randomUUID(), appleSubject: input.subject }).onConflictDoNothing();
        const [user] = await tx.select({ id: users.id }).from(users)
          .where(eq(users.appleSubject, input.subject)).limit(1).for("update");
        if (!user) throw new Error("User mapping failed");
        await tx.insert(authChallenges).values({
          id: input.challenge.id,
          nonceHash: input.challenge.nonceHash,
          expiresAt: new Date(input.challenge.expiresAt),
          consumedAt: exchangeTime,
          createdAt: exchangeTime,
        });
        await tx.update(authSessions).set({ revokedAt: exchangeTime }).where(and(
          eq(authSessions.userId, user.id),
          isNull(authSessions.revokedAt),
        ));
        await tx.insert(authSessions).values({
          id: input.session.id,
          userId: user.id,
          challengeId: input.challenge.id,
          tokenHash: input.session.tokenHash,
          expiresAt: new Date(input.session.expiresAt),
          createdAt: exchangeTime,
        });
        const [membership] = await tx.select({
          caregiverID: caregivers.id,
          householdID: caregivers.householdId,
          role: caregivers.role,
        }).from(caregivers).where(and(
          eq(caregivers.userId, user.id),
          eq(caregivers.status, "active"),
        )).limit(1);
        return { membership: membership ?? null };
      });
    },
  };
}

export async function POST(request: Request) {
  const audience = appleAudience();
  const secret = authBucketSecret();
  if (!audience || !secret) {
    return Response.json({ error: "Apple authentication is unavailable" }, { status: 503 });
  }
  return createAppleSessionHandler({
    challengeSecret: secret,
    verifyIdentity: createAppleIdentityVerifier({ audience }),
    store: createProductionAppleSessionStore(secret),
  })(request);
}
