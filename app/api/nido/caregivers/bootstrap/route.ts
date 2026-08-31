import { eq } from "drizzle-orm";
import { getDb } from "../../../../../db";
import { caregivers, caregiverTokens, households, profiles } from "../../../../../db/schema";
import { createAccessToken, hashAccessToken, publicCaregiverFields } from "../../auth";

export async function POST(request: Request) {
  try {
    const body = await request.json() as { name?: string; babyName?: string; birthDate?: string };
    const name = body.name?.trim() ?? "";
    if (!name) return Response.json({ error: "Indica tu nombre" }, { status: 400 });

    const db = getDb();
    const accessToken = createAccessToken();
    const accessTokenHash = await hashAccessToken(accessToken);
    const legacyHouseholdId = "00000000-0000-4000-8000-000000000001";
    const [existing] = await db.select().from(caregivers).where(eq(caregivers.householdId, legacyHouseholdId)).limit(1);
    if (existing) {
      const [existingToken] = await db.select({ caregiverId: caregiverTokens.caregiverId }).from(caregiverTokens)
        .where(eq(caregiverTokens.caregiverId, existing.id)).limit(1);
      const [profile] = await db.select({ babyName: profiles.babyName, birthDate: profiles.birthDate }).from(profiles)
        .where(eq(profiles.householdId, legacyHouseholdId)).limit(1);
      const ownerMatches = existing.name.localeCompare(name, "es", { sensitivity: "base" }) === 0;
      const babyMatches = Boolean(profile && body.babyName && body.birthDate
        && profile.babyName.localeCompare(body.babyName.trim(), "es", { sensitivity: "base" }) === 0
        && profile.birthDate === body.birthDate);
      if (!existingToken && ownerMatches && babyMatches) {
        await db.insert(caregiverTokens).values({ caregiverId: existing.id, tokenHash: accessTokenHash });
        const [claimed] = await db.select(publicCaregiverFields).from(caregivers).where(eq(caregivers.id, existing.id)).limit(1);
        return Response.json({ caregiver: claimed, accessToken });
      }
    }

    const now = new Date().toISOString();
    const householdId = crypto.randomUUID();
    const caregiverId = crypto.randomUUID();
    const babyName = body.babyName?.trim() ?? "";
    const birthDate = body.birthDate ?? "";
    const householdInsert = db.insert(households).values({ id: householdId });
    const caregiverInsert = db.insert(caregivers).values({
      id: caregiverId,
      householdId,
      name,
      role: "owner",
      status: "active",
      joinedAt: now,
    });
    const tokenInsert = db.insert(caregiverTokens).values({ caregiverId, tokenHash: accessTokenHash });
    if (babyName && /^\d{4}-\d{2}-\d{2}$/.test(birthDate)) {
      await db.batch([
        householdInsert,
        caregiverInsert,
        tokenInsert,
        db.insert(profiles).values({ householdId, caregiverName: name, babyName, birthDate }),
      ]);
    } else {
      await db.batch([householdInsert, caregiverInsert, tokenInsert]);
    }
    const [caregiver] = await db.select(publicCaregiverFields).from(caregivers).where(eq(caregivers.id, caregiverId)).limit(1);
    return Response.json({ caregiver, accessToken }, { status: 201 });
  } catch (error) {
    const message = error instanceof Error ? error.message : "No se pudo crear el cuidador principal";
    return Response.json({ error: message }, { status: 500 });
  }
}
