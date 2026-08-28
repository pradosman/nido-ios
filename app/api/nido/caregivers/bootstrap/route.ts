import { eq } from "drizzle-orm";
import { getDb } from "../../../../../db";
import { caregivers, caregiverTokens, profiles } from "../../../../../db/schema";
import { createAccessToken, hashAccessToken, publicCaregiverFields } from "../../auth";

export async function POST(request: Request) {
  try {
    const body = await request.json() as { name?: string; babyName?: string; birthDate?: string };
    const name = body.name?.trim() ?? "";
    if (!name) return Response.json({ error: "Indica tu nombre" }, { status: 400 });

    const db = getDb();
    const [existing] = await db.select().from(caregivers).where(eq(caregivers.status, "active")).limit(1);
    const accessToken = createAccessToken();
    const accessTokenHash = await hashAccessToken(accessToken);
    if (existing) {
      const [existingToken] = await db.select({ caregiverId: caregiverTokens.caregiverId }).from(caregiverTokens)
        .where(eq(caregiverTokens.caregiverId, existing.id)).limit(1);
      if (existingToken) return Response.json({ error: "Este espacio ya tiene un cuidador" }, { status: 409 });
      const [profile] = await db.select({ babyName: profiles.babyName, birthDate: profiles.birthDate }).from(profiles).limit(1);
      const ownerMatches = existing.name.localeCompare(name, "es", { sensitivity: "base" }) === 0;
      const babyMatches = Boolean(profile && body.babyName && body.birthDate
        && profile.babyName.localeCompare(body.babyName.trim(), "es", { sensitivity: "base" }) === 0
        && profile.birthDate === body.birthDate);
      if (!ownerMatches || !babyMatches) {
        return Response.json({ error: "No se ha podido verificar este espacio" }, { status: 403 });
      }
      await db.insert(caregiverTokens).values({ caregiverId: existing.id, tokenHash: accessTokenHash });
      const [claimed] = await db.select(publicCaregiverFields).from(caregivers).where(eq(caregivers.id, existing.id)).limit(1);
      return Response.json({ caregiver: claimed, accessToken });
    }

    const now = new Date().toISOString();
    const [caregiver] = await db.insert(caregivers).values({
      id: crypto.randomUUID(),
      name,
      role: "owner",
      status: "active",
      joinedAt: now,
    }).returning(publicCaregiverFields);
    await db.insert(caregiverTokens).values({ caregiverId: caregiver.id, tokenHash: accessTokenHash });
    return Response.json({ caregiver, accessToken }, { status: 201 });
  } catch (error) {
    const message = error instanceof Error ? error.message : "No se pudo crear el cuidador principal";
    return Response.json({ error: message }, { status: 500 });
  }
}
