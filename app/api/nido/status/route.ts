import { sql } from "drizzle-orm";
import { getDb } from "../../../../db/index.ts";

export async function GET() {
  try {
    const result = await getDb().execute<{ healthy: number }>(sql`SELECT 1 AS healthy`);
    const rows = Array.isArray(result)
      ? result
      : (result as unknown as { rows: Array<{ healthy: number }> }).rows;
    const [database] = rows;
    if (database?.healthy !== 1) throw new Error("Database health query returned no row");
    return Response.json({ canCreateHousehold: true, canJoinWithInvitation: true });
  } catch {
    return Response.json({ error: "Database unavailable" }, { status: 503 });
  }
}
