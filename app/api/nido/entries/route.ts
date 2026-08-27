import { getDb } from "../../../../db";
import { eq } from "drizzle-orm";
import { entries, entryAuthors } from "../../../../db/schema";
import { requireCaregiver } from "../auth";

export async function POST(request: Request) {
  try {
    const authorization = await requireCaregiver(request);
    if (authorization.response) return authorization.response;
    const caregiver = authorization.caregiver;
    const body = await request.json() as {
      id?: string; kind?: "sleep" | "feed" | "diaper" | "health"; title?: string;
      detail?: string; occurredAt?: number; durationMinutes?: number | null; amountMl?: number | null;
      caregiverID?: string | null; caregiverName?: string | null;
    };
    if (!body.id || !body.kind || !body.title || !body.occurredAt) {
      return Response.json({ error: "Registro incompleto" }, { status: 400 });
    }
    const db = getDb();
    await db.insert(entries).values({
      id: body.id,
      kind: body.kind,
      title: body.title.trim(),
      detail: body.detail?.trim() ?? "",
      occurredAt: body.occurredAt,
      durationMinutes: body.durationMinutes ?? null,
      amountMl: body.amountMl ?? null,
    }).onConflictDoNothing();
    await db.insert(entryAuthors).values({ entryId: body.id, caregiverId: caregiver.id, caregiverName: caregiver.name }).onConflictDoNothing();
    const [entry] = await db.select().from(entries).where(eq(entries.id, body.id)).limit(1);
    return Response.json({ entry: { ...entry, caregiverID: caregiver.id, caregiverName: caregiver.name } }, { status: 201 });
  } catch (error) {
    const message = error instanceof Error ? error.message : "No se pudo guardar el registro";
    return Response.json({ error: message }, { status: 500 });
  }
}

export async function PUT(request: Request) {
  try {
    const authorization = await requireCaregiver(request);
    if (authorization.response) return authorization.response;
    const body = await request.json() as {
      id?: string; kind?: "sleep" | "feed" | "diaper" | "health"; title?: string;
      detail?: string; occurredAt?: number; durationMinutes?: number | null; amountMl?: number | null;
    };
    if (!body.id || !body.kind || !body.title || !body.occurredAt) {
      return Response.json({ error: "Registro incompleto" }, { status: 400 });
    }
    const [entry] = await getDb().update(entries).set({
      kind: body.kind,
      title: body.title.trim(),
      detail: body.detail?.trim() ?? "",
      occurredAt: body.occurredAt,
      durationMinutes: body.durationMinutes ?? null,
      amountMl: body.amountMl ?? null,
    }).where(eq(entries.id, body.id)).returning();
    if (!entry) return Response.json({ error: "El registro ya no existe" }, { status: 404 });
    return Response.json({ entry });
  } catch (error) {
    const message = error instanceof Error ? error.message : "No se pudo actualizar el registro";
    return Response.json({ error: message }, { status: 500 });
  }
}

export async function DELETE(request: Request) {
  try {
    const authorization = await requireCaregiver(request);
    if (authorization.response) return authorization.response;
    const id = new URL(request.url).searchParams.get("id")?.trim() ?? "";
    if (!id) return Response.json({ error: "Falta el registro" }, { status: 400 });
    const db = getDb();
    await db.delete(entryAuthors).where(eq(entryAuthors.entryId, id));
    await db.delete(entries).where(eq(entries.id, id));
    return Response.json({ deleted: id });
  } catch (error) {
    const message = error instanceof Error ? error.message : "No se pudo eliminar el registro";
    return Response.json({ error: message }, { status: 500 });
  }
}
