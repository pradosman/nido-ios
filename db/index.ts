import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema.ts";

export type Database = ReturnType<typeof drizzle<typeof schema>>;

let injectedDatabase: Database | undefined;
let productionDatabase: Database | undefined;

function requiredDatabaseURL() {
  const value = process.env.DATABASE_URL?.trim();
  if (!value) throw new Error("DATABASE_URL is required");
  return value;
}

export function createProductionDatabase(options: { max?: number } = {}) {
  const client = postgres(requiredDatabaseURL(), {
    max: options.max ?? Number(process.env.DATABASE_POOL_SIZE ?? 10),
    idle_timeout: 20,
    connect_timeout: 10,
    prepare: false,
  });
  return { db: drizzle(client, { schema }), client };
}

export function getDb(): Database {
  if (injectedDatabase) return injectedDatabase;
  productionDatabase ??= createProductionDatabase().db;
  return productionDatabase;
}

export function setDbForTests(database: Database | undefined) {
  if (process.env.NODE_ENV === "production") {
    throw new Error("Test database injection is disabled in production");
  }
  injectedDatabase = database;
}
