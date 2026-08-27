import { getDb } from "../../../../db";
import { entries } from "../../../../db/schema";

export async function POST(request: Request) {
  try {
    const body = await request.json() as {
      id?: string; kind?: "sleep" | "feed" | "diaper" | "health"; title?: string;
      detail?: string; occurredAt?: number; durationMinutes?: number | null; amountMl?: number | null;
    };
    if (!body.id || !body.kind || !body.title || !body.occurredAt) {
      return Response.json({ error: "Registro incompleto" }, { status: 400 });
    }
    const db = getDb();
    const [entry] = await db.insert(entries).values({
      id: body.id,
      kind: body.kind,
      title: body.title.trim(),
      detail: body.detail?.trim() ?? "",
      occurredAt: body.occurredAt,
      durationMinutes: body.durationMinutes ?? null,
      amountMl: body.amountMl ?? null,
    }).returning();
    return Response.json({ entry }, { status: 201 });
  } catch (error) {
    const message = error instanceof Error ? error.message : "No se pudo guardar el registro";
    return Response.json({ error: message }, { status: 500 });
  }
}
