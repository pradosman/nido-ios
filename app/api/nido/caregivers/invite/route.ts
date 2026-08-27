import { getDb } from "../../../../../db";
import { eq } from "drizzle-orm";
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
    if (!name) return Response.json({ error: "Indica el nombre del cuidador" }, { status: 400 });

    const db = getDb();
    const [caregiver] = await db.insert(caregivers).values({
      id: crypto.randomUUID(),
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
    if (!id) return Response.json({ error: "Falta el cuidador" }, { status: 400 });
    if (id === authorization.caregiver.id) {
      return Response.json({ error: "No puedes retirar tu propio acceso" }, { status: 400 });
    }
    const db = getDb();
    await db.delete(caregiverTokens).where(eq(caregiverTokens.caregiverId, id));
    await db.delete(caregivers).where(eq(caregivers.id, id));
    return Response.json({ deleted: id });
  } catch (error) {
    const message = error instanceof Error ? error.message : "No se pudo retirar el acceso";
    return Response.json({ error: message }, { status: 500 });
  }
}
