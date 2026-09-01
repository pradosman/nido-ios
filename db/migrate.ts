import { migrate } from "drizzle-orm/postgres-js/migrator";
import { createProductionDatabase } from "./index.ts";

const MIGRATION_LOCK_ID = 7_310_202_609_01;
const { db, client } = createProductionDatabase({ max: 1 });
try {
  await client`SELECT pg_advisory_lock(${MIGRATION_LOCK_ID})`;
  await migrate(db, { migrationsFolder: "drizzle-pg" });
} finally {
  try {
    await client`SELECT pg_advisory_unlock(${MIGRATION_LOCK_ID})`;
  } finally {
    await client.end();
  }
}
