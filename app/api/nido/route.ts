import { desc, eq } from "drizzle-orm";
import { getDb } from "../../../db";
import { caregivers, entries, entryAuthors, profiles } from "../../../db/schema";
import { publicCaregiverFields, requireCaregiver } from "./auth";

export async function GET(request: Request) {
  try {
    const authorization = await requireCaregiver(request);
    if (authorization.response) return authorization.response;
    const db = getDb();
    const [profile] = await db.select().from(profiles).limit(1);
    const activity = await db.select({
      id: entries.id,
      kind: entries.kind,
      title: entries.title,
      detail: entries.detail,
      occurredAt: entries.occurredAt,
      durationMinutes: entries.durationMinutes,
      amountMl: entries.amountMl,
      caregiverID: entryAuthors.caregiverId,
      caregiverName: entryAuthors.caregiverName,
    }).from(entries)
      .leftJoin(entryAuthors, eq(entries.id, entryAuthors.entryId))
      .orderBy(desc(entries.occurredAt))
      .limit(500);
    const familyRows = await db.select(publicCaregiverFields).from(caregivers).orderBy(caregivers.createdAt);
    const family = authorization.caregiver.role === "owner"
      ? familyRows
      : familyRows.map(caregiver => ({ ...caregiver, inviteCode: null }));
    return Response.json({ profile: profile ?? null, entries: activity, caregivers: family, currentCaregiverID: authorization.caregiver.id });
  } catch (error) {
    const message = error instanceof Error ? error.message : "No se pudieron cargar los datos";
    return Response.json({ error: message }, { status: 500 });
  }
}
