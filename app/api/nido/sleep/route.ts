import { and, eq, isNull } from "drizzle-orm";
import { getDb } from "../../../../db/index.ts";
import { caregivers, households } from "../../../../db/schema.ts";
import { requireCaregiver } from "../auth.ts";
import { bodyErrorResponse, readJsonObject } from "../validation.ts";

const EARLIEST_SLEEP_TIMESTAMP = Date.UTC(2000, 0, 1);
const LATEST_SLEEP_TIMESTAMP = Date.UTC(2100, 0, 1);
const SLEEP_BODY_LIMIT_BYTES = 1_024;

type SleepUpdateBody = {
  startedAt: number | null;
  expectedStartedAt: number | null;
};

function parseTimestamp(value: unknown): number | null | undefined {
  if (value === null) return null;
  if (typeof value !== "number" || !Number.isSafeInteger(value)
    || value < EARLIEST_SLEEP_TIMESTAMP || value > LATEST_SLEEP_TIMESTAMP) return undefined;
  return value;
}

function parseSleepUpdate(body: Record<string, unknown> | null): SleepUpdateBody | null {
  if (!body || !("startedAt" in body) || !("expectedStartedAt" in body)) return null;
  const startedAt = parseTimestamp(body.startedAt);
  const expectedStartedAt = parseTimestamp(body.expectedStartedAt);
  if (startedAt === undefined || expectedStartedAt === undefined) return null;
  return { startedAt, expectedStartedAt };
}

export async function GET(request: Request) {
  try {
    const authorization = await requireCaregiver(request);
    if (authorization.response) return authorization.response;
    const [household] = await getDb().select({
      activeSleepStartedAt: households.activeSleepStartedAt,
    }).from(households).where(eq(households.id, authorization.caregiver.householdId)).limit(1);
    if (!household) return Response.json({ error: "Household not found" }, { status: 404 });
    return Response.json({ activeSleepStartedAt: household.activeSleepStartedAt ?? null });
  } catch {
    return Response.json({ error: "Unable to load active sleep" }, { status: 500 });
  }
}

export async function PUT(request: Request) {
  try {
    const authorization = await requireCaregiver(request);
    if (authorization.response) return authorization.response;
    const body = parseSleepUpdate(await readJsonObject(request, SLEEP_BODY_LIMIT_BYTES));
    if (!body) return Response.json({ error: "Estado de sueño no válido" }, { status: 400 });

    return await getDb().transaction(async tx => {
      const [caregiver] = await tx.select({ id: caregivers.id }).from(caregivers).where(and(
        eq(caregivers.id, authorization.caregiver.id),
        eq(caregivers.userId, authorization.caregiver.userId),
        eq(caregivers.householdId, authorization.caregiver.householdId),
        eq(caregivers.status, "active"),
      )).limit(1).for("update");
      if (!caregiver) return Response.json({ error: "An active household membership is required" }, { status: 403 });

      const expectedPredicate = body.expectedStartedAt === null
        ? isNull(households.activeSleepStartedAt)
        : eq(households.activeSleepStartedAt, body.expectedStartedAt);
      const [updated] = await tx.update(households).set({
        activeSleepStartedAt: body.startedAt,
        updatedAt: new Date(),
      }).where(and(eq(households.id, authorization.caregiver.householdId), expectedPredicate)).returning({
        activeSleepStartedAt: households.activeSleepStartedAt,
      });
      if (updated) return Response.json({ activeSleepStartedAt: updated.activeSleepStartedAt ?? null });

      const [current] = await tx.select({
        activeSleepStartedAt: households.activeSleepStartedAt,
      }).from(households).where(eq(households.id, authorization.caregiver.householdId)).limit(1);
      if (!current) return Response.json({ error: "Household not found" }, { status: 404 });
      const activeSleepStartedAt = current.activeSleepStartedAt ?? null;
      if (activeSleepStartedAt === body.startedAt) return Response.json({ activeSleepStartedAt });
      return Response.json({ activeSleepStartedAt }, { status: 409 });
    });
  } catch (error) {
    const bodyResponse = bodyErrorResponse(error);
    if (bodyResponse) return bodyResponse;
    return Response.json({ error: "Unable to update active sleep" }, { status: 500 });
  }
}
