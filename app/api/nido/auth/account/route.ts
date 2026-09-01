import { eq, inArray } from "drizzle-orm";
import { getDb } from "../../../../../db/index.ts";
import { caregivers, households, users } from "../../../../../db/schema.ts";
import { requireMembership } from "../../auth.ts";

export async function DELETE(request: Request) {
  try {
    const authorization = await requireMembership(request);
    if (authorization.response) return authorization.response;
    const db = getDb();
    if (authorization.caregiver.role === "owner") {
      await db.transaction(async tx => {
        const memberRows = await tx.select({ userId: caregivers.userId }).from(caregivers)
          .where(eq(caregivers.householdId, authorization.caregiver.householdId)).for("update");
        const userIds = memberRows.map(row => row.userId).filter((id): id is string => Boolean(id));
        await tx.delete(households).where(eq(households.id, authorization.caregiver.householdId));
        if (userIds.length > 0) await tx.delete(users).where(inArray(users.id, userIds));
      });
    } else {
      await db.transaction(async tx => {
        await tx.delete(users).where(eq(users.id, authorization.session.userId));
      });
    }
    return Response.json({ deleted: true });
  } catch {
    return Response.json({ error: "Unable to delete the account" }, { status: 500 });
  }
}
