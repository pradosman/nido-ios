import { and, eq } from "drizzle-orm";
import { getDb } from "../../../../db/index.ts";
import { babyCareStates, caregivers } from "../../../../db/schema.ts";
import { requireCaregiver } from "../auth.ts";
import { bodyErrorResponse, readJsonObject } from "../validation.ts";

const MAX_BODY_BYTES = 4_000_000;
const EARLIEST_TIMESTAMP = Date.UTC(2000, 0, 1);
const LATEST_TIMESTAMP = Date.UTC(2100, 0, 1);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DATE = /^(\d{4})-(\d{2})-(\d{2})$/;

type GoalVersion = {
  id: string;
  effectiveDate: string;
  sleepMinutes: number | null;
  feedCount: number | null;
  diaperCount: number | null;
};
type Measurement = {
  id: string;
  measuredAt: number;
  weightGrams: number | null;
  heightMillimeters: number | null;
  note: string;
};
type Update = { expectedRevision: number; timeZoneID: string; goalVersions: GoalVersion[]; measurements: Measurement[] };

function integerBetween(value: unknown, min: number, max: number): value is number {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= min && value <= max;
}

function optionalInteger(value: unknown, max: number): value is number | null {
  return value === null || integerBetween(value, 1, max);
}

function localDate(value: unknown): value is string {
  if (typeof value !== "string") return false;
  const match = DATE.exec(value);
  if (!match) return false;
  const [, year, month, day] = match.map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year && date.getUTCMonth() === month - 1 && date.getUTCDate() === day;
}

function timezone(value: unknown): value is string {
  if (typeof value !== "string" || value.length > 100) return false;
  try { new Intl.DateTimeFormat("en", { timeZone: value }); return true; }
  catch { return false; }
}

function parseUpdate(body: Record<string, unknown> | null): Update | null {
  if (!body || !integerBetween(body.expectedRevision, 0, 2_147_483_646)
    || !timezone(body.timeZoneID) || !Array.isArray(body.goalVersions) || body.goalVersions.length > 500
    || !Array.isArray(body.measurements) || body.measurements.length > 5_000) return null;

  const goalIDs = new Set<string>();
  const dates = new Set<string>();
  const goalVersions: GoalVersion[] = [];
  for (const value of body.goalVersions) {
    if (!value || typeof value !== "object" || Array.isArray(value)) return null;
    const goal = value as Record<string, unknown>;
    if (typeof goal.id !== "string" || !UUID.test(goal.id) || goalIDs.has(goal.id)
      || !localDate(goal.effectiveDate) || dates.has(goal.effectiveDate)
      || !optionalInteger(goal.sleepMinutes, 1_440) || !optionalInteger(goal.feedCount, 100)
      || !optionalInteger(goal.diaperCount, 100)) return null;
    goalIDs.add(goal.id);
    dates.add(goal.effectiveDate);
    goalVersions.push({ id: goal.id, effectiveDate: goal.effectiveDate, sleepMinutes: goal.sleepMinutes,
      feedCount: goal.feedCount, diaperCount: goal.diaperCount });
  }

  const measurementIDs = new Set<string>();
  const measurements: Measurement[] = [];
  for (const value of body.measurements) {
    if (!value || typeof value !== "object" || Array.isArray(value)) return null;
    const measurement = value as Record<string, unknown>;
    if (typeof measurement.id !== "string" || !UUID.test(measurement.id) || measurementIDs.has(measurement.id)
      || !integerBetween(measurement.measuredAt, EARLIEST_TIMESTAMP, LATEST_TIMESTAMP)
      || measurement.measuredAt > Date.now()
      || !optionalInteger(measurement.weightGrams, 200_000) || !optionalInteger(measurement.heightMillimeters, 2_500)
      || (measurement.weightGrams === null && measurement.heightMillimeters === null)
      || (measurement.note !== undefined && (typeof measurement.note !== "string" || measurement.note.length > 500))) return null;
    measurementIDs.add(measurement.id);
    measurements.push({ id: measurement.id, measuredAt: measurement.measuredAt,
      weightGrams: measurement.weightGrams, heightMillimeters: measurement.heightMillimeters,
      note: (measurement.note as string | undefined) ?? "" });
  }
  return { expectedRevision: body.expectedRevision, timeZoneID: body.timeZoneID, goalVersions, measurements };
}

function stableValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(stableValue);
  if (value && typeof value === "object") return Object.fromEntries(Object.entries(value)
    .sort(([left], [right]) => left.localeCompare(right)).map(([key, item]) => [key, stableValue(item)]));
  return value;
}
function sameValue(a: unknown, b: unknown) { return JSON.stringify(stableValue(a)) === JSON.stringify(stableValue(b)); }
function responseState(row: typeof babyCareStates.$inferSelect) {
  return { revision: row.revision, timeZoneID: row.timeZoneID, goalVersions: row.goalVersions, measurements: row.measurements };
}

export async function GET(request: Request) {
  try {
    const authorization = await requireCaregiver(request);
    if (authorization.response) return authorization.response;
    const [row] = await getDb().select().from(babyCareStates)
      .where(eq(babyCareStates.householdId, authorization.caregiver.householdId)).limit(1);
    return Response.json({ state: row ? responseState(row) : null });
  } catch {
    return Response.json({ error: "Unable to load baby care state" }, { status: 500 });
  }
}

export async function PUT(request: Request) {
  try {
    const authorization = await requireCaregiver(request);
    if (authorization.response) return authorization.response;
    const update = parseUpdate(await readJsonObject(request, MAX_BODY_BYTES));
    if (!update) return Response.json({ error: "Estado de cuidado no válido" }, { status: 400 });
    const db = getDb();
    const householdId = authorization.caregiver.householdId;
    return await db.transaction(async tx => {
      const [caregiver] = await tx.select({ role: caregivers.role }).from(caregivers).where(and(
        eq(caregivers.id, authorization.caregiver.id),
        eq(caregivers.userId, authorization.caregiver.userId),
        eq(caregivers.householdId, householdId),
        eq(caregivers.status, "active"),
      )).limit(1).for("update");
      if (!caregiver) return Response.json({ error: "An active household membership is required" }, { status: 403 });

      const [existing] = await tx.select().from(babyCareStates).where(eq(babyCareStates.householdId, householdId)).limit(1);
      if (!existing) {
        if (update.expectedRevision !== 0) return Response.json({ error: "Revision conflict", state: null }, { status: 409 });
        if (caregiver.role !== "owner" && update.goalVersions.length > 0) {
          return Response.json({ error: "Only the owner can change goals" }, { status: 403 });
        }
        const [created] = await tx.insert(babyCareStates).values({ householdId, revision: 1,
          timeZoneID: update.timeZoneID, goalVersions: update.goalVersions, measurements: update.measurements })
          .onConflictDoNothing().returning();
        if (created) return Response.json({ state: responseState(created) });
        const [current] = await tx.select().from(babyCareStates).where(eq(babyCareStates.householdId, householdId)).limit(1);
        if (current && sameValue(update.goalVersions, current.goalVersions) && sameValue(update.measurements, current.measurements)
          && update.timeZoneID === current.timeZoneID) return Response.json({ state: responseState(current) });
        return Response.json({ error: "Revision conflict", state: current ? responseState(current) : null }, { status: 409 });
      }

      const goalsChanged = !sameValue(update.goalVersions, existing.goalVersions);
      const timezoneChanged = update.timeZoneID !== existing.timeZoneID;
      if (update.expectedRevision !== existing.revision) {
        if (!goalsChanged && !timezoneChanged && sameValue(update.measurements, existing.measurements)) {
          return Response.json({ state: responseState(existing) });
        }
        return Response.json({ error: "Revision conflict", state: responseState(existing) }, { status: 409 });
      }
      if (caregiver.role !== "owner" && (goalsChanged || timezoneChanged)) {
        return Response.json({ error: "Only the owner can change goals or time zone" }, { status: 403 });
      }
      const [updated] = await tx.update(babyCareStates).set({ revision: existing.revision + 1,
        timeZoneID: update.timeZoneID, goalVersions: update.goalVersions, measurements: update.measurements, updatedAt: new Date() })
        .where(and(eq(babyCareStates.householdId, householdId), eq(babyCareStates.revision, existing.revision))).returning();
      if (updated) return Response.json({ state: responseState(updated) });
      const [current] = await tx.select().from(babyCareStates).where(eq(babyCareStates.householdId, householdId)).limit(1);
      if (current && !goalsChanged && !timezoneChanged && sameValue(update.measurements, current.measurements)) {
        return Response.json({ state: responseState(current) });
      }
      return Response.json({ error: "Revision conflict", state: current ? responseState(current) : null }, { status: 409 });
    });
  } catch (error) {
    const bodyResponse = bodyErrorResponse(error);
    if (bodyResponse) return bodyResponse;
    return Response.json({ error: "Unable to save baby care state" }, { status: 500 });
  }
}
