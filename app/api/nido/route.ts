import { and, eq, ne } from "drizzle-orm";
import { getDb } from "../../../db/index.ts";
import { caregivers, households, profiles } from "../../../db/schema.ts";
import { publicCaregiverFields, requireCaregiver } from "./auth.ts";
import { DEFAULT_ENTRY_PAGE_SIZE, loadEntryPage } from "./entry-pagination.ts";

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
    const [household] = await db.select({
      activeSleepStartedAt: households.activeSleepStartedAt,
    }).from(households).where(eq(households.id, householdId)).limit(1);
    const activity = await loadEntryPage(householdId, null, DEFAULT_ENTRY_PAGE_SIZE);
    const familyRows = await db.select(publicCaregiverFields).from(caregivers).where(and(
      eq(caregivers.householdId, householdId),
      ne(caregivers.status, "removed"),
      authorization.caregiver.role === "owner" ? undefined : eq(caregivers.status, "active"),
    )).orderBy(caregivers.createdAt);
    const family = familyRows.map(caregiver => ({ ...caregiver, inviteCode: null }));
    return Response.json({
      profile: profile ?? null,
      entries: activity.entries,
      nextCursor: activity.nextCursor,
      activeSleepStartedAt: household?.activeSleepStartedAt ?? null,
      caregivers: family,
      currentCaregiverID: authorization.caregiver.id,
    });
  } catch {
    return Response.json({ error: "Unable to load household data" }, { status: 500 });
  }
}
