import { and, eq, ne } from "drizzle-orm";
import { getDb } from "../../../db";
import { caregivers, profiles } from "../../../db/schema";
import { publicCaregiverFields, requireCaregiver } from "./auth";
import { DEFAULT_ENTRY_PAGE_SIZE, loadEntryPage } from "./entry-pagination";

export async function GET(request: Request) {
  try {
    const authorization = await requireCaregiver(request);
    if (authorization.response) return authorization.response;
    const db = getDb();
    const householdId = authorization.caregiver.householdId;
    const [profile] = await db.select({
      caregiverName: profiles.caregiverName,
      babyName: profiles.babyName,
      birthDate: profiles.birthDate,
    }).from(profiles).where(eq(profiles.householdId, householdId)).limit(1);
    const activity = await loadEntryPage(householdId, null, DEFAULT_ENTRY_PAGE_SIZE);
    const familyRows = await db.select(publicCaregiverFields).from(caregivers).where(and(
      eq(caregivers.householdId, householdId),
      ne(caregivers.status, "removed"),
      authorization.caregiver.role === "owner" ? undefined : eq(caregivers.status, "active"),
    )).orderBy(caregivers.createdAt);
    const family = authorization.caregiver.role === "owner"
      ? familyRows
      : familyRows.map(caregiver => ({ ...caregiver, inviteCode: null }));
    return Response.json({
      profile: profile ?? null,
      entries: activity.entries,
      nextCursor: activity.nextCursor,
      caregivers: family,
      currentCaregiverID: authorization.caregiver.id,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "No se pudieron cargar los datos";
    return Response.json({ error: message }, { status: 500 });
  }
}
