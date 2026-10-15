import { and, eq, inArray } from "drizzle-orm";
import { getDb } from "../../../../../db/index.ts";
import { authChallenges, caregivers, households, users } from "../../../../../db/schema.ts";
import { requireSession } from "../../auth.ts";
import { verifyOpaqueAppleChallenge } from "../../apple-challenge.ts";
import { createAppleIdentityVerifier } from "../../apple-verifier.ts";
import { createAppleTokenRevoker } from "../../apple-token-revocation.ts";
import { appleAudience, authBucketSecret } from "../../runtime-config.ts";
import { bodyErrorResponse, boundedString, readJsonObject } from "../../validation.ts";

type DeletionProofProvider = {
  challengeSecret: string;
  verifyIdentity(token: string, nonce: string): Promise<{ subject: string }>;
  revokeAuthorization(code: string, subject: string, nonce: string): Promise<void>;
};

function configuredProvider(): DeletionProofProvider | null {
  const audience = appleAudience();
  const challengeSecret = authBucketSecret();
  const teamID = process.env.NIDO_APPLE_TEAM_ID?.trim();
  const keyID = process.env.NIDO_APPLE_KEY_ID?.trim();
  const privateKey = process.env.NIDO_APPLE_PRIVATE_KEY?.trim();
  if (!audience || !challengeSecret || !teamID || !keyID || !privateKey) return null;
  const verifyIdentity = createAppleIdentityVerifier({ audience });
  return { challengeSecret, verifyIdentity, revokeAuthorization: createAppleTokenRevoker({
    clientID: audience, teamID, keyID, privateKey, verifyIdentity,
  }) };
}

export function createAccountDeletionHandler(provider?: DeletionProofProvider) {
  return async (request: Request) => {
  try {
    const authorization = await requireSession(request);
    if (authorization.response) return authorization.response;
    const proofProvider = provider ?? configuredProvider();
    if (!proofProvider) return Response.json({ error: "Apple account deletion is unavailable" }, { status: 503 });
    const body = await readJsonObject(request, 40_000);
    const challengeID = boundedString(body?.challengeID, 1_024);
    const identityToken = boundedString(body?.identityToken, 16_384);
    const authorizationCode = boundedString(body?.authorizationCode, 16_384);
    if (!challengeID || !identityToken || !authorizationCode) {
      return Response.json({ error: "Fresh Apple authorization is required" }, { status: 400 });
    }
    const db = getDb();
    const [user] = await db.select({ subject: users.appleSubject }).from(users)
      .where(eq(users.id, authorization.session.userId)).limit(1);
    if (!user) return Response.json({ error: "Authentication is required" }, { status: 401 });
    let challenge;
    let identity;
    try {
      challenge = await verifyOpaqueAppleChallenge(challengeID, proofProvider.challengeSecret);
      identity = await proofProvider.verifyIdentity(identityToken, challenge.nonceHash);
      if (challenge.expiresAt <= Date.now()) throw new Error();
    } catch {
      return Response.json({ error: "The Apple authorization proof is invalid" }, { status: 401 });
    }
    if (identity.subject !== user.subject) {
      return Response.json({ error: "Authorize with the Apple account being deleted" }, { status: 403 });
    }
    const [consumed] = await db.insert(authChallenges).values({
      id: challenge.id, nonceHash: challenge.nonceHash,
      expiresAt: new Date(challenge.expiresAt), consumedAt: new Date(),
    }).onConflictDoNothing().returning({ id: authChallenges.id });
    if (!consumed) return Response.json({ error: "The Apple authorization proof is already used" }, { status: 401 });
    try {
      await proofProvider.revokeAuthorization(authorizationCode, user.subject, challenge.nonceHash);
    } catch {
      return Response.json({ error: "Unable to revoke Apple authorization; retry with fresh authorization" }, { status: 502 });
    }
    const [caregiver] = await db.select({
      householdId: caregivers.householdId,
      role: caregivers.role,
    }).from(caregivers).where(and(
      eq(caregivers.userId, authorization.session.userId),
      eq(caregivers.status, "active"),
    )).limit(1);
    if (caregiver?.role === "owner") {
      await db.transaction(async tx => {
        const memberRows = await tx.select({ userId: caregivers.userId }).from(caregivers)
          .where(eq(caregivers.householdId, caregiver.householdId)).for("update");
        const userIds = memberRows.map(row => row.userId).filter((id): id is string => Boolean(id));
        await tx.delete(households).where(eq(households.id, caregiver.householdId));
        if (userIds.length > 0) await tx.delete(users).where(inArray(users.id, userIds));
      });
    } else {
      await db.transaction(async tx => {
        await tx.delete(users).where(eq(users.id, authorization.session.userId));
      });
    }
    return Response.json({ deleted: true });
  } catch (error) {
    const bodyResponse = bodyErrorResponse(error);
    if (bodyResponse) return bodyResponse;
    return Response.json({ error: "Unable to delete the account" }, { status: 500 });
  }
  };
}

export const DELETE = createAccountDeletionHandler();
