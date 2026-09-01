import { sql } from "drizzle-orm";
import { getDb } from "../../../../db/index.ts";
import { profiles } from "../../../../db/schema.ts";
import { requireCaregiver } from "../auth.ts";
import { bodyErrorResponse, boundedString, readJsonObject, recentBirthDate } from "../validation.ts";

export async function PUT(request: Request) {
  try {
    const authorization = await requireCaregiver(request, true);
    if (authorization.response) return authorization.response;
    const body = await readJsonObject(request, 2_048);
    const caregiverName = boundedString(body?.caregiverName, 80);
    const babyName = boundedString(body?.babyName, 80);
    const birthDate = recentBirthDate(body?.birthDate);
    if (!caregiverName || !babyName || !birthDate) {
      return Response.json({ error: "Completa todos los datos" }, { status: 400 });
    }
    const db = getDb();
    const [profile] = await db.insert(profiles).values({ householdId: authorization.caregiver.householdId, caregiverName, babyName, birthDate })
      .onConflictDoUpdate({ target: profiles.householdId, set: { caregiverName, babyName, birthDate, updatedAt: sql`transaction_timestamp()` } })
      .returning({ caregiverName: profiles.caregiverName, babyName: profiles.babyName, birthDate: profiles.birthDate });
    return Response.json({ profile });
  } catch (error) {
    const bodyResponse = bodyErrorResponse(error);
    if (bodyResponse) return bodyResponse;
    return Response.json({ error: "Unable to save the profile" }, { status: 500 });
  }
}
