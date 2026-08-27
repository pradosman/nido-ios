import { eq } from "drizzle-orm";
import { getDb } from "../../../../../db";
import { caregivers, caregiverTokens } from "../../../../../db/schema";
import { createAccessToken, hashAccessToken, publicCaregiverFields } from "../../auth";

export async function POST(request: Request) {
  try {
    const body = await request.json() as { code?: string };
    const rawCode = body.code?.trim().toUpperCase().replaceAll(/[^A-Z0-9]/g, "") ?? "";
    const code = rawCode.length === 8
      ? `${rawCode.slice(0, 4)}-${rawCode.slice(4)}`
      : rawCode.length === 12
        ? `${rawCode.slice(0, 4)}-${rawCode.slice(4, 8)}-${rawCode.slice(8)}`
        : rawCode;
    if (!code) return Response.json({ error: "Introduce el código de invitación" }, { status: 400 });

    const db = getDb();
    const [invitation] = await db.select().from(caregivers).where(eq(caregivers.inviteCode, code)).limit(1);
    if (!invitation || invitation.status !== "pending") {
      return Response.json({ error: "La invitación no es válida o ya se ha utilizado" }, { status: 404 });
    }

    const accessToken = createAccessToken();
    const accessTokenHash = await hashAccessToken(accessToken);
    const [caregiver] = await db.update(caregivers).set({
      status: "active",
      inviteCode: null,
      joinedAt: new Date().toISOString(),
    }).where(eq(caregivers.id, invitation.id)).returning(publicCaregiverFields);
    await db.insert(caregiverTokens).values({ caregiverId: caregiver.id, tokenHash: accessTokenHash });
    return Response.json({ caregiver, accessToken });
  } catch (error) {
    const message = error instanceof Error ? error.message : "No se pudo aceptar la invitación";
    return Response.json({ error: message }, { status: 500 });
  }
}
