import { sql } from "drizzle-orm";
import { getDb } from "../../../db/index.ts";
import { authRateLimits } from "../../../db/schema.ts";

export async function consumeRateLimit(key: string, now: Date, windowMs: number, maximumAttempts: number) {
  const windowStart = new Date(now.getTime() - windowMs);
  const encodedWindowStart = sql.param(windowStart, authRateLimits.windowStartedAt);
  const encodedNow = sql.param(now, authRateLimits.windowStartedAt);
  const [result] = await getDb().insert(authRateLimits).values({
    key,
    windowStartedAt: now,
    attempts: 1,
  }).onConflictDoUpdate({
    target: authRateLimits.key,
    set: {
      windowStartedAt: sql`CASE WHEN ${authRateLimits.windowStartedAt} <= ${encodedWindowStart} THEN ${encodedNow} ELSE ${authRateLimits.windowStartedAt} END`,
      attempts: sql`CASE WHEN ${authRateLimits.windowStartedAt} <= ${encodedWindowStart} THEN 1 ELSE ${authRateLimits.attempts} + 1 END`,
    },
  }).returning({ attempts: authRateLimits.attempts });
  return Boolean(result && result.attempts <= maximumAttempts);
}
