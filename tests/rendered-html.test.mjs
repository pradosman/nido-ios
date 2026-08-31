import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

test("ships API hosting and a household-scoped schema", async () => {
  const [hosting, schema] = await Promise.all([
    readFile(new URL("../.openai/hosting.json", import.meta.url), "utf8"),
    readFile(new URL("../db/schema.ts", import.meta.url), "utf8"),
  ]);

  assert.match(hosting, /"d1": "DB"/);
  assert.match(schema, /idx_entries_household_occurred_at/);
});

test("ships a persistent and private VPS deployment path", async () => {
  const [dockerfile, compose, dockerignore, wrangler, entrypoint, schema, caddy, readme] = await Promise.all([
    readFile(new URL("../Dockerfile", import.meta.url), "utf8"),
    readFile(new URL("../compose.vps.yml", import.meta.url), "utf8"),
    readFile(new URL("../.dockerignore", import.meta.url), "utf8"),
    readFile(new URL("../wrangler.vps.jsonc", import.meta.url), "utf8"),
    readFile(new URL("../deploy/entrypoint.sh", import.meta.url), "utf8"),
    readFile(new URL("../deploy/schema.sql", import.meta.url), "utf8"),
    readFile(new URL("../deploy/Caddyfile.example", import.meta.url), "utf8"),
    readFile(new URL("../README.md", import.meta.url), "utf8"),
  ]);

  assert.match(dockerfile, /VOLUME \["\/data"\]/);
  assert.match(compose, /expose:\s+- "3000"/);
  assert.doesNotMatch(compose, /ports:/);
  assert.match(compose, /nido-data:\/data/);
  assert.match(dockerignore, /^ios$/m);
  assert.match(wrangler, /"migrations_dir": "drizzle"/);
  assert.match(entrypoint, /d1 migrations apply DB/);
  assert.match(entrypoint, /--persist-to "\$data_dir"/);
  assert.match(schema, /CREATE TABLE IF NOT EXISTS `entries`/);
  assert.match(schema, /CREATE INDEX IF NOT EXISTS `idx_entries_occurred_at`/);
  assert.match(schema, /CREATE TABLE IF NOT EXISTS `caregiver_tokens`/);
  assert.match(caddy, /nido\.momentumia\.com/);
  assert.doesNotMatch(caddy, /basic_auth/);
  assert.match(compose, /\/api\/nido\/status/);
  assert.match(readme, /app nativa para iPhone/);
  assert.match(readme, /Dokploy conecta Traefik al puerto interno `3000`/);
  assert.match(readme, /\| Path \| `\/api` \|/);
});
