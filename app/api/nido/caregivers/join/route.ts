import { and, eq, gt, isNull, lt, sql } from "drizzle-orm";
import { getDb } from "../../../../../db/index.ts";
import { caregivers, invitationClaims, invitations } from "../../../../../db/schema.ts";
import { requireSession } from "../../auth.ts";
import { sha256 } from "../../crypto.ts";
import { consumeRateLimit } from "../../rate-limit.ts";
import { bodyErrorResponse, boundedString, readJsonObject } from "../../validation.ts";

const RATE_WINDOW_MS = 10 * 60 * 1_000;
const MAX_FAILED_ATTEMPTS = 5;
const NEW_INVITATION_CODE = /^[A-HJ-NP-Z2-9]{12}$/i;
const GROUPED_NEW_INVITATION_CODE = /^([A-HJ-NP-Z2-9]{4})-([A-HJ-NP-Z2-9]{4})-([A-HJ-NP-Z2-9]{4})$/i;

function normalizeInvitationCode(code: string) {
  if (GROUPED_NEW_INVITATION_CODE.test(code)) return code.replaceAll("-", "").toUpperCase();
  if (NEW_INVITATION_CODE.test(code)) return code.toUpperCase();
  return code;
}

export async function POST(request: Request) {
  try {
    const authorization = await requireSession(request);
    if (authorization.response) return authorization.response;
    const body = await readJsonObject(request, 1_024);
    const code = boundedString(body?.code, 128);
    if (!code) return Response.json({ error: "Invalid invitation" }, { status: 400 });
    const now = new Date();
    if (!await consumeRateLimit(`join:${authorization.session.userId}`, now, RATE_WINDOW_MS, 20)) {
      return Response.json({ error: "Too many invitation attempts" }, { status: 429 });
    }
    const db = getDb();
    const codeHash = await sha256(normalizeInvitationCode(code));
    const result = await db.transaction(async tx => {
      const [existingMembership] = await tx.select({ id: caregivers.id }).from(caregivers)
        .where(eq(caregivers.userId, authorization.session.userId)).limit(1).for("update");
      if (existingMembership) return { status: "membership" as const };
      const [invitation] = await tx.select({
        id: invitations.id,
        caregiverId: invitations.caregiverId,
        expiresAt: invitations.expiresAt,
        consumedAt: invitations.consumedAt,
        failedAttempts: invitations.failedAttempts,
      }).from(invitations).where(eq(invitations.codeHash, codeHash)).limit(1).for("update");
      if (!invitation || invitation.consumedAt || invitation.expiresAt <= now || invitation.failedAttempts >= MAX_FAILED_ATTEMPTS) {
        if (invitation && invitation.failedAttempts < MAX_FAILED_ATTEMPTS) {
          await tx.update(invitations).set({
            failedAttempts: sql`least(${invitations.failedAttempts} + 1, ${MAX_FAILED_ATTEMPTS})`,
          }).where(eq(invitations.id, invitation.id));
        }
        return { status: "invalid" as const };
      }
      const [claimedInvitation] = await tx.update(invitations).set({ consumedAt: now }).where(and(
        eq(invitations.id, invitation.id),
        isNull(invitations.consumedAt),
        gt(invitations.expiresAt, now),
        lt(invitations.failedAttempts, MAX_FAILED_ATTEMPTS),
      )).returning({ id: invitations.id });
      if (!claimedInvitation) return { status: "invalid" as const };
      const [caregiver] = await tx.update(caregivers).set({
        userId: authorization.session.userId,
        status: "active",
        joinedAt: now,
      }).where(and(eq(caregivers.id, invitation.caregiverId), eq(caregivers.status, "pending"))).returning({
        id: caregivers.id,
        name: caregivers.name,
        role: caregivers.role,
        status: caregivers.status,
        createdAt: caregivers.createdAt,
        joinedAt: caregivers.joinedAt,
      });
      if (!caregiver) throw new Error("Invitation membership update failed");
      await tx.insert(invitationClaims).values({
        invitationId: invitation.id,
        userId: authorization.session.userId,
        claimedAt: now,
      });
      return { status: "joined" as const, caregiver };
    });
    if (result.status === "membership") {
      return Response.json({ error: "The account already belongs to a household" }, { status: 409 });
    }
    if (result.status === "invalid") {
      return Response.json({ error: "The invitation is invalid or expired" }, { status: 404 });
    }
    return Response.json({ caregiver: result.caregiver });
  } catch (error) {
    const bodyResponse = bodyErrorResponse(error);
    if (bodyResponse) return bodyResponse;
    return Response.json({ error: "Unable to accept the invitation" }, { status: 409 });
  }
}
