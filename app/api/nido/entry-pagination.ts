import { and, desc, eq, lt, or } from "drizzle-orm";
import { getDb } from "../../../db";
import { entries, entryAuthors } from "../../../db/schema";

export const DEFAULT_ENTRY_PAGE_SIZE = 100;
export const MAX_ENTRY_PAGE_SIZE = 200;

type EntryCursor = {
  occurredAt: number;
  id: string;
};

export function parseEntryPageLimit(value: string | null) {
  if (value === null) return DEFAULT_ENTRY_PAGE_SIZE;
  if (!/^\d+$/.test(value)) return null;
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 1) return null;
  return Math.min(parsed, MAX_ENTRY_PAGE_SIZE);
}

export function encodeEntryCursor(cursor: EntryCursor) {
  return Buffer.from(JSON.stringify([cursor.occurredAt, cursor.id]), "utf8").toString("base64url");
}

export function decodeEntryCursor(value: string): EntryCursor | null {
  try {
    if (!value || value.length > 2_048 || !/^[A-Za-z0-9_-]+$/.test(value)) return null;
    const decoded = JSON.parse(Buffer.from(value, "base64url").toString("utf8")) as unknown;
    if (!Array.isArray(decoded) || decoded.length !== 2) return null;
    const [occurredAt, id] = decoded;
    if (!Number.isSafeInteger(occurredAt) || typeof id !== "string" || !id) return null;
    const cursor = { occurredAt, id };
    return encodeEntryCursor(cursor) === value ? cursor : null;
  } catch {
    return null;
  }
}

export async function loadEntryPage(
  householdId: string,
  cursor: EntryCursor | null,
  limit: number,
) {
  const cursorPredicate = cursor
    ? or(
        lt(entries.occurredAt, cursor.occurredAt),
        and(eq(entries.occurredAt, cursor.occurredAt), lt(entries.id, cursor.id)),
      )
    : undefined;
  const rows = await getDb().select({
    id: entries.id,
    kind: entries.kind,
    title: entries.title,
    detail: entries.detail,
    occurredAt: entries.occurredAt,
    durationMinutes: entries.durationMinutes,
    amountMl: entries.amountMl,
    caregiverID: entryAuthors.caregiverId,
    caregiverName: entryAuthors.caregiverName,
  }).from(entries)
    .leftJoin(entryAuthors, and(
      eq(entries.id, entryAuthors.entryId),
      eq(entries.householdId, entryAuthors.householdId),
    ))
    .where(and(eq(entries.householdId, householdId), cursorPredicate))
    .orderBy(desc(entries.occurredAt), desc(entries.id))
    .limit(limit + 1);
  const pageEntries = rows.slice(0, limit);
  const last = pageEntries.at(-1);
  return {
    entries: pageEntries,
    nextCursor: rows.length > limit && last
      ? encodeEntryCursor({ occurredAt: last.occurredAt, id: last.id })
      : null,
  };
}
