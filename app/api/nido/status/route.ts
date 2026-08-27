import { eq } from "drizzle-orm";
import { getDb } from "../../../../db";
import { caregivers } from "../../../../db/schema";

export async function GET() {
  try {
    const [caregiver] = await getDb().select({ id: caregivers.id })
      .from(caregivers).where(eq(caregivers.status, "active")).limit(1);
    return Response.json({ configured: Boolean(caregiver) });
  } catch {
    return Response.json({ configured: false });
  }
}
