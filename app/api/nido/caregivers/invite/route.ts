import { and, eq } from "drizzle-orm";
import { getDb } from "../../../../../db/index.ts";
import { caregivers, invitations, users } from "../../../../../db/schema.ts";
import { requireMembership } from "../../auth.ts";
import { randomInvitationCode, sha256 } from "../../crypto.ts";
import { bodyErrorResponse, boundedString, readJsonObject } from "../../validation.ts";

const INVITATION_LIFETIME_MS = 7 * 24 * 60 * 60 * 1_000;

export async function POST(request: Request) {
  try {
    const authorization = await requireMembership(request, true);
    if (authorization.response) return authorization.response;
    const body = await readJsonObject(request, 1_024);
    const name = boundedString(body?.name, 80);
    if (!name) return Response.json({ error: "Invalid family member name" }, { status: 400 });
    const db = getDb();
    const caregiverId = crypto.randomUUID();
    const canonicalCode = randomInvitationCode();
    const code = `${canonicalCode.slice(0, 4)}-${canonicalCode.slice(4, 8)}-${canonicalCode.slice(8, 12)}`;
    const now = new Date();
    const expiresAt = new Date(now.getTime() + INVITATION_LIFETIME_MS);
    const caregiver = await db.transaction(async tx => {
      await tx.insert(caregivers).values({
        id: caregiverId,
        householdId: authorization.caregiver.householdId,
        name,
        role: "caregiver",
        status: "pending",
      });
      await tx.insert(invitations).values({
        id: crypto.randomUUID(),
        caregiverId,
        codeHash: await sha256(canonicalCode),
        expiresAt,
        createdAt: now,
      });
      const [created] = await tx.select({
      id: caregivers.id,
      name: caregivers.name,
      role: caregivers.role,
      status: caregivers.status,
      createdAt: caregivers.createdAt,
      joinedAt: caregivers.joinedAt,
      }).from(caregivers).where(eq(caregivers.id, caregiverId)).limit(1);
      return created;
    });
    return Response.json({
      caregiver: { ...caregiver, inviteCode: code },
      invitation: { code, expiresAt: expiresAt.toISOString() },
    }, { status: 201 });
  } catch (error) {
    const bodyResponse = bodyErrorResponse(error);
    if (bodyResponse) return bodyResponse;
    return Response.json({ error: "Unable to create the invitation" }, { status: 500 });
  }
}

export async function DELETE(request: Request) {
  try {
    const authorization = await requireMembership(request, true);
    if (authorization.response) return authorization.response;
    const id = new URL(request.url).searchParams.get("id")?.trim() ?? "";
    if (!id || id.length > 64) return Response.json({ error: "Invalid family member" }, { status: 400 });
    if (id === authorization.caregiver.id) {
      return Response.json({ error: "The owner cannot remove their own membership" }, { status: 400 });
    }
    const db = getDb();
    const target = await db.transaction(async tx => {
      const [row] = await tx.select({ userId: caregivers.userId }).from(caregivers).where(and(
        eq(caregivers.id, id),
        eq(caregivers.householdId, authorization.caregiver.householdId),
      )).limit(1).for("update");
      if (!row) return null;
      if (row.userId) await tx.delete(users).where(eq(users.id, row.userId));
      else await tx.delete(caregivers).where(eq(caregivers.id, id));
      return row;
    });
    if (!target) return Response.json({ error: "The family member does not exist" }, { status: 404 });
    return Response.json({ deleted: id });
  } catch {
    return Response.json({ error: "Unable to remove the family member" }, { status: 500 });
  }
}
