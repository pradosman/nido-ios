import { and, eq, isNull, sql } from "drizzle-orm";
import { getDb } from "../../../../../db/index.ts";
import { authSessions } from "../../../../../db/schema.ts";
import { requireSession } from "../../auth.ts";

export async function POST(request: Request) {
  try {
    const authorization = await requireSession(request);
    if (authorization.response) return authorization.response;
    await getDb().update(authSessions).set({ revokedAt: sql`transaction_timestamp()` }).where(and(
      eq(authSessions.id, authorization.session.id),
      isNull(authSessions.revokedAt),
    ));
    return Response.json({ loggedOut: true });
  } catch {
    return Response.json({ error: "Unable to log out" }, { status: 500 });
  }
}
