import { getDb } from "../../../../../db";
import { and, eq } from "drizzle-orm";
import { caregiverTokens, caregivers } from "../../../../../db/schema";
import { requireCaregiver } from "../../auth";

function invitationCode() {
  const raw = crypto.randomUUID().replaceAll("-", "").slice(0, 12).toUpperCase();
  return `${raw.slice(0, 4)}-${raw.slice(4, 8)}-${raw.slice(8)}`;
}

export async function POST(request: Request) {
  try {
    const authorization = await requireCaregiver(request, true);
    if (authorization.response) return authorization.response;
    const body = await request.json() as { name?: string };
    const name = body.name?.trim() ?? "";
    if (!name) return Response.json({ error: "Indica el nombre del familiar" }, { status: 400 });

    const db = getDb();
    const [caregiver] = await db.insert(caregivers).values({
      id: crypto.randomUUID(),
      householdId: authorization.caregiver.householdId,
      name,
      role: "caregiver",
      status: "pending",
      inviteCode: invitationCode(),
    }).returning();
    return Response.json({ caregiver }, { status: 201 });
  } catch (error) {
    const message = error instanceof Error ? error.message : "No se pudo crear la invitación";
    return Response.json({ error: message }, { status: 500 });
  }
}

export async function DELETE(request: Request) {
  try {
    const authorization = await requireCaregiver(request, true);
    if (authorization.response) return authorization.response;
    const id = new URL(request.url).searchParams.get("id")?.trim() ?? "";
    if (!id) return Response.json({ error: "Falta el familiar" }, { status: 400 });
    if (id === authorization.caregiver.id) {
      return Response.json({ error: "No puedes retirar tu propio acceso" }, { status: 400 });
    }
    const db = getDb();
    const [target] = await db.select({ status: caregivers.status }).from(caregivers).where(and(
      eq(caregivers.id, id),
      eq(caregivers.householdId, authorization.caregiver.householdId),
    )).limit(1);
    if (!target) return Response.json({ error: "El familiar ya no existe" }, { status: 404 });
    if (target.status === "pending") {
      await db.batch([
        db.delete(caregiverTokens).where(eq(caregiverTokens.caregiverId, id)),
        db.delete(caregivers).where(and(eq(caregivers.id, id), eq(caregivers.householdId, authorization.caregiver.householdId))),
      ]);
    } else {
      await db.batch([
        db.delete(caregiverTokens).where(eq(caregiverTokens.caregiverId, id)),
        db.update(caregivers).set({ status: "removed" }).where(and(
          eq(caregivers.id, id),
          eq(caregivers.householdId, authorization.caregiver.householdId),
        )),
      ]);
    }
    return Response.json({ deleted: id });
  } catch (error) {
    const message = error instanceof Error ? error.message : "No se pudo retirar el acceso";
    return Response.json({ error: message }, { status: 500 });
  }
}
