import { desc } from "drizzle-orm";
import { getDb } from "../../../db";
import { entries, profiles } from "../../../db/schema";

export async function GET() {
  try {
    const db = getDb();
    const [profile] = await db.select().from(profiles).limit(1);
    const activity = await db.select().from(entries).orderBy(desc(entries.occurredAt)).limit(500);
    return Response.json({ profile: profile ?? null, entries: activity });
  } catch (error) {
    const message = error instanceof Error ? error.message : "No se pudieron cargar los datos";
    return Response.json({ error: message }, { status: 500 });
  }
}
