import { getDb } from "../../../../db";
import { and, eq } from "drizzle-orm";
import { entries, entryAuthors } from "../../../../db/schema";
import { requireCaregiver } from "../auth";
import { decodeEntryCursor, loadEntryPage, parseEntryPageLimit } from "../entry-pagination";

export async function GET(request: Request) {
  try {
    const authorization = await requireCaregiver(request);
    if (authorization.response) return authorization.response;
    const parameters = new URL(request.url).searchParams;
    const limit = parseEntryPageLimit(parameters.get("limit"));
    if (limit === null) return Response.json({ error: "Límite no válido" }, { status: 400 });
    const rawCursor = parameters.get("cursor");
    const cursor = rawCursor === null ? null : decodeEntryCursor(rawCursor);
    if (rawCursor !== null && cursor === null) {
      return Response.json({ error: "Cursor no válido" }, { status: 400 });
    }
    return Response.json(await loadEntryPage(authorization.caregiver.householdId, cursor, limit));
  } catch (error) {
    const message = error instanceof Error ? error.message : "No se pudieron cargar los registros";
    return Response.json({ error: message }, { status: 500 });
  }
}

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
    await db.batch([
      db.insert(entries).values({
        id: body.id,
        householdId: caregiver.householdId,
        kind: body.kind,
        title: body.title.trim(),
        detail: body.detail?.trim() ?? "",
        occurredAt: body.occurredAt,
        durationMinutes: body.durationMinutes ?? null,
        amountMl: body.amountMl ?? null,
      }).onConflictDoNothing(),
      db.insert(entryAuthors).values({ entryId: body.id, householdId: caregiver.householdId, caregiverId: caregiver.id, caregiverName: caregiver.name }).onConflictDoNothing(),
    ]);
    const [entry] = await db.select().from(entries).where(and(eq(entries.id, body.id), eq(entries.householdId, caregiver.householdId))).limit(1);
    if (!entry) return Response.json({ error: "El registro ya existe en otro espacio" }, { status: 409 });
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
    }).where(and(eq(entries.id, body.id), eq(entries.householdId, authorization.caregiver.householdId))).returning();
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
    const [entry] = await db.select({ id: entries.id }).from(entries).where(and(
      eq(entries.id, id),
      eq(entries.householdId, authorization.caregiver.householdId),
    )).limit(1);
    if (!entry) return Response.json({ error: "El registro ya no existe" }, { status: 404 });
    await db.batch([
      db.delete(entryAuthors).where(and(eq(entryAuthors.entryId, id), eq(entryAuthors.householdId, authorization.caregiver.householdId))),
      db.delete(entries).where(and(eq(entries.id, id), eq(entries.householdId, authorization.caregiver.householdId))),
    ]);
    return Response.json({ deleted: id });
  } catch (error) {
    const message = error instanceof Error ? error.message : "No se pudo eliminar el registro";
    return Response.json({ error: message }, { status: 500 });
  }
}
