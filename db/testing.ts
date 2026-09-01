import { PGlite } from "@electric-sql/pglite";
import { drizzle } from "drizzle-orm/pglite";
import { migrate } from "drizzle-orm/pglite/migrator";
import { setDbForTests, type Database } from "./index.ts";
import * as schema from "./schema.ts";

export async function createTestDatabase() {
  const client = new PGlite();
  const db = drizzle(client, { schema });
  await migrate(db, { migrationsFolder: "drizzle-pg" });
  setDbForTests(db as unknown as Database);
  return {
    db,
    client,
    async close() {
      setDbForTests(undefined);
      await client.close();
    },
  };
}
