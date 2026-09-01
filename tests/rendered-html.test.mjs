import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

test("ships standalone API hosting and a household-scoped PostgreSQL schema", async () => {
  const [hosting, schema] = await Promise.all([
    readFile(new URL("../.openai/hosting.json", import.meta.url), "utf8"),
    readFile(new URL("../db/schema.ts", import.meta.url), "utf8"),
  ]);

  assert.match(hosting, /"d1": null/);
  assert.match(schema, /drizzle-orm\/pg-core/);
  assert.match(schema, /idx_entries_household_occurred_at/);
});

test("ships a persistent and private VPS deployment path", async () => {
  const [dockerfile, compose, dockerignore, entrypoint, migration, caddy, backup, restore, readme] = await Promise.all([
    readFile(new URL("../Dockerfile", import.meta.url), "utf8"),
    readFile(new URL("../compose.vps.yml", import.meta.url), "utf8"),
    readFile(new URL("../.dockerignore", import.meta.url), "utf8"),
    readFile(new URL("../deploy/entrypoint.sh", import.meta.url), "utf8"),
    readFile(new URL("../drizzle-pg/0000_flowery_bishop.sql", import.meta.url), "utf8"),
    readFile(new URL("../deploy/Caddyfile.example", import.meta.url), "utf8"),
    readFile(new URL("../deploy/backup-postgres.sh", import.meta.url), "utf8"),
    readFile(new URL("../deploy/restore-postgres.sh", import.meta.url), "utf8"),
    readFile(new URL("../README.md", import.meta.url), "utf8"),
  ]);

  assert.match(dockerfile, /node:24\.19\.0-bookworm-slim@sha256:/);
  assert.match(dockerfile, /USER nido/);
  assert.match(compose, /expose:\s+- "3000"/);
  assert.doesNotMatch(compose, /ports:/);
  assert.match(compose, /postgres:17\.10-bookworm@sha256:/);
  assert.match(compose, /postgres-data:\/var\/lib\/postgresql\/data/);
  assert.match(compose, /internal:\s*true/);
  assert.match(dockerignore, /^ios$/m);
  assert.match(entrypoint, /dist\/standalone\/server\.js/);
  assert.doesNotMatch(entrypoint, /wrangler|d1/i);
  assert.match(migration, /CREATE TABLE "entries"/);
  assert.match(migration, /CREATE INDEX "idx_entries_household_occurred_at_id"/);
  assert.match(migration, /CREATE TABLE "auth_sessions"/);
  assert.match(migration, /CREATE TRIGGER auth_session_requires_consumed_challenge/);
  assert.match(caddy, /nido\.momentumia\.com/);
  assert.doesNotMatch(caddy, /basic_auth/);
  assert.match(backup, /pg_dump/);
  assert.match(backup, /age --recipient/);
  assert.match(restore, /pg_restore/);
  assert.match(restore, /NIDO_RESTORE_CONFIRMED/);
  assert.match(compose, /\/api\/nido\/status/);
  assert.match(readme, /app nativa para iPhone/);
  assert.match(readme, /PostgreSQL/);
  assert.match(readme, /fuera del VPS/);
  assert.match(readme, /restauración de prueba/);
  assert.match(readme, /\| Path \| `\/api` \|/);
});
