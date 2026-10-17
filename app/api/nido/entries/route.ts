import { getDb } from "../../../../db/index.ts";
import { and, eq } from "drizzle-orm";
import { entries, entryAuthors, users } from "../../../../db/schema.ts";
import { requireCaregiver } from "../auth.ts";
import { decodeEntryCursor, loadEntryPage, parseEntryPageLimit } from "../entry-pagination.ts";
import {
  bodyErrorResponse,
  boundedInteger,
  boundedOptionalString,
  boundedString,
  readJsonObject,
} from "../validation.ts";

const ENTRY_BODY_LIMIT_BYTES = 4_096;
const EARLIEST_ENTRY_TIMESTAMP = Date.UTC(2000, 0, 1);
const LATEST_ENTRY_TIMESTAMP = Date.UTC(2100, 0, 1);
const ENTRY_KINDS = new Set(["sleep", "feed", "diaper", "health"] as const);

function parseEntry(body: Record<string, unknown> | null) {
  const id = boundedString(body?.id, 128);
  const kind = typeof body?.kind === "string" && ENTRY_KINDS.has(body.kind as "sleep" | "feed" | "diaper" | "health")
    ? body.kind as "sleep" | "feed" | "diaper" | "health"
    : null;
  const title = boundedString(body?.title, 120);
  const detail = boundedOptionalString(body?.detail, 1_000);
  const occurredAt = boundedInteger(body?.occurredAt, EARLIEST_ENTRY_TIMESTAMP, LATEST_ENTRY_TIMESTAMP);
  const durationMinutes = boundedInteger(body?.durationMinutes, 1, 1_440, true);
  const amountMl = boundedInteger(body?.amountMl, 1, 5_000, true);
  if (!id || !kind || !title || detail === null || occurredAt == null
    || durationMinutes === undefined || amountMl === undefined) return null;
  return { id, kind, title, detail, occurredAt, durationMinutes, amountMl };
}

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
  } catch {
    return Response.json({ error: "Unable to load entries" }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const authorization = await requireCaregiver(request);
    if (authorization.response) return authorization.response;
    const caregiver = authorization.caregiver;
    const body = parseEntry(await readJsonObject(request, ENTRY_BODY_LIMIT_BYTES));
    if (!body) return Response.json({ error: "Registro incompleto" }, { status: 400 });
    const db = getDb();
    const result = await db.transaction(async tx => {
      const [lockedUser] = await tx.select({ id: users.id }).from(users)
        .where(eq(users.id, caregiver.userId)).limit(1).for("update");
      if (!lockedUser) return { authorized: false as const };
      await tx.insert(entries).values({ ...body, householdId: caregiver.householdId }).onConflictDoNothing();
      const [entry] = await tx.select().from(entries).where(and(
        eq(entries.id, body.id),
        eq(entries.householdId, caregiver.householdId),
      )).limit(1).for("update");
      if (!entry) return { authorized: true as const, entry: null };
      await tx.insert(entryAuthors).values({
        entryId: body.id,
        householdId: caregiver.householdId,
        caregiverId: caregiver.id,
        caregiverName: caregiver.name,
      }).onConflictDoNothing();
      const [author] = await tx.select({
        caregiverID: entryAuthors.caregiverId,
        caregiverName: entryAuthors.caregiverName,
      }).from(entryAuthors).where(eq(entryAuthors.entryId, body.id)).limit(1);
      return { authorized: true as const, entry, author };
    });
    if (!result.authorized) return Response.json({ error: "Authentication is required" }, { status: 401 });
    const entry = result?.entry;
    if (!entry) return Response.json({ error: "El registro ya existe en otro espacio" }, { status: 409 });
    return Response.json({ entry: { ...entry, ...result?.author } }, { status: 201 });
  } catch (error) {
    const bodyResponse = bodyErrorResponse(error);
    if (bodyResponse) return bodyResponse;
    return Response.json({ error: "Unable to save the entry" }, { status: 500 });
  }
}

export async function PUT(request: Request) {
  try {
    const authorization = await requireCaregiver(request);
    if (authorization.response) return authorization.response;
    const body = parseEntry(await readJsonObject(request, ENTRY_BODY_LIMIT_BYTES));
    if (!body) return Response.json({ error: "Registro incompleto" }, { status: 400 });
    const [entry] = await getDb().update(entries).set({
      kind: body.kind,
      title: body.title,
      detail: body.detail,
      occurredAt: body.occurredAt,
      durationMinutes: body.durationMinutes,
      amountMl: body.amountMl,
    }).where(and(eq(entries.id, body.id), eq(entries.householdId, authorization.caregiver.householdId))).returning();
    if (!entry) return Response.json({ error: "El registro ya no existe" }, { status: 404 });
    return Response.json({ entry });
  } catch (error) {
    const bodyResponse = bodyErrorResponse(error);
    if (bodyResponse) return bodyResponse;
    return Response.json({ error: "Unable to update the entry" }, { status: 500 });
  }
}

export async function DELETE(request: Request) {
  try {
    const authorization = await requireCaregiver(request);
    if (authorization.response) return authorization.response;
    const id = new URL(request.url).searchParams.get("id")?.trim() ?? "";
    if (!id || id.length > 128) return Response.json({ error: "Falta el registro" }, { status: 400 });
    const db = getDb();
    const entry = await db.transaction(async tx => {
      const [row] = await tx.select({ id: entries.id }).from(entries).where(and(
        eq(entries.id, id),
        eq(entries.householdId, authorization.caregiver.householdId),
      )).limit(1).for("update");
      if (!row) return null;
      await tx.delete(entries).where(and(
        eq(entries.id, id),
        eq(entries.householdId, authorization.caregiver.householdId),
      ));
      return row;
    });
    if (!entry) return Response.json({ error: "El registro ya no existe" }, { status: 404 });
    return Response.json({ deleted: id });
  } catch {
    return Response.json({ error: "Unable to delete the entry" }, { status: 500 });
  }
}
