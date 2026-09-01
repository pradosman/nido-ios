import { eq } from "drizzle-orm";
import { getDb } from "../../../../../db/index.ts";
import { caregivers, households, profiles, users } from "../../../../../db/schema.ts";
import { publicCaregiverFields, requireSession } from "../../auth.ts";
import { bodyErrorResponse, boundedString, readJsonObject, recentBirthDate } from "../../validation.ts";

export async function POST(request: Request) {
  try {
    const authorization = await requireSession(request);
    if (authorization.response) return authorization.response;
    const db = getDb();
    const body = await readJsonObject(request, 2_048);
    const name = boundedString(body?.name, 80);
    const babyName = boundedString(body?.babyName, 80);
    const birthDate = recentBirthDate(body?.birthDate);
    if (!name || !babyName || !birthDate) {
      return Response.json({ error: "Invalid household profile" }, { status: 400 });
    }

    const householdId = crypto.randomUUID();
    const caregiverId = crypto.randomUUID();
    const caregiver = await db.transaction(async tx => {
      const [lockedUser] = await tx.select({ id: users.id }).from(users)
        .where(eq(users.id, authorization.session.userId)).limit(1).for("update");
      if (!lockedUser) throw new Error("Authenticated user no longer exists");
      const [membership] = await tx.select({ id: caregivers.id }).from(caregivers)
        .where(eq(caregivers.userId, authorization.session.userId)).limit(1).for("update");
      if (membership) return null;
      await tx.insert(households).values({ id: householdId });
      await tx.insert(caregivers).values({
        id: caregiverId,
        householdId,
        userId: authorization.session.userId,
        name,
        role: "owner",
        status: "active",
        joinedAt: new Date(),
      });
      await tx.insert(profiles).values({ householdId, caregiverName: name, babyName, birthDate });
      const [created] = await tx.select(publicCaregiverFields).from(caregivers)
        .where(eq(caregivers.id, caregiverId)).limit(1);
      return created;
    });
    if (!caregiver) return Response.json({ error: "The account already belongs to a household" }, { status: 409 });
    return Response.json({ caregiver }, { status: 201 });
  } catch (error) {
    const bodyResponse = bodyErrorResponse(error);
    if (bodyResponse) return bodyResponse;
    return Response.json({ error: "Unable to create the household" }, { status: 500 });
  }
}
