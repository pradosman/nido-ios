import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const keys = ["NIDO_APPLE_TEAM_ID", "NIDO_APPLE_KEY_ID", "NIDO_APPLE_PRIVATE_KEY"];
test("production Compose requires and forwards every Apple revocation credential", async () => {
  const compose = await readFile("compose.vps.yml", "utf8");
  for (const key of keys) {
    assert.ok(compose.includes(`${key}: ${"${"}${key}:?${key} is required}`), `missing required forward: ${key}`);
  }
  assert.match(compose, /NIDO_APPLE_AUDIENCE:\s*\$\{NIDO_APPLE_AUDIENCE:\?/);
  assert.doesNotMatch(compose, /NIDO_APPLE_CLIENT_ID/);
});
test("environment example contains only blank credential placeholders and uses existing audience", async () => {
  const example = await readFile(".env.example", "utf8");
  for (const key of ["NIDO_POSTGRES_PASSWORD", "NIDO_APPLE_AUDIENCE", "NIDO_AUTH_BUCKET_SECRET", ...keys]) {
    assert.ok(example.split(/\r?\n/).includes(`${key}=`), `nonempty/missing placeholder: ${key}`);
  }
  assert.doesNotMatch(example, /BEGIN (?:EC )?PRIVATE KEY|NIDO_APPLE_CLIENT_ID/);
});
