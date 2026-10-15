// Configuration-only scenario: does not contact Docker Engine, create containers
// or expose the generated private key. Run from the repository root.
import assert from "node:assert/strict";
import { generateKeyPairSync } from "node:crypto";
import { spawnSync } from "node:child_process";

const privateKey = generateKeyPairSync("ec", { namedCurve: "P-256", privateKeyEncoding: { type: "pkcs8", format: "pem" }, publicKeyEncoding: { type: "spki", format: "pem" } }).privateKey;
const configured = {
  ...process.env,
  NIDO_POSTGRES_PASSWORD: "synthetic-postgres-placeholder",
  NIDO_AUTH_BUCKET_SECRET: "synthetic-test-challenge-secret-32-bytes",
  NIDO_APPLE_AUDIENCE: "com.example.Nido",
  NIDO_APPLE_TEAM_ID: "TEAM123456",
  NIDO_APPLE_KEY_ID: "KEY1234567",
  NIDO_APPLE_PRIVATE_KEY: privateKey,
};
function config(env) {
  return spawnSync("docker", ["compose", "--env-file", "/dev/null", "-p", "nido-revocation-config-check", "-f", "compose.vps.yml", "config", "--format", "json"], { env, encoding: "utf8" });
}
for (const key of ["NIDO_APPLE_TEAM_ID", "NIDO_APPLE_KEY_ID", "NIDO_APPLE_PRIVATE_KEY"]) {
  for (const value of [undefined, ""]) {
    const env = { ...configured };
    if (value === undefined) delete env[key]; else env[key] = value;
    assert.notEqual(config(env).status, 0, `${key} must block configuration when missing or empty`);
  }
}
const result = config(configured);
assert.equal(result.status, 0, "fully configured Compose must resolve");
let parsed;
try { parsed = JSON.parse(result.stdout); }
catch { throw new Error("Compose configuration was not valid JSON"); }
// Compare secrets as booleans so assertion diagnostics cannot print a key.
assert.equal(parsed.services.nido.environment.NIDO_APPLE_PRIVATE_KEY === privateKey, true, "multiline PKCS#8 must survive Compose byte-for-byte");
assert.equal(parsed.services.nido.environment.NIDO_APPLE_AUDIENCE, "com.example.Nido");
assert.equal(Object.hasOwn(parsed.services.postgres.environment, "NIDO_APPLE_PRIVATE_KEY"), false);
assert.equal(Object.hasOwn(parsed.services.migrate.environment, "NIDO_APPLE_PRIVATE_KEY"), false);
console.log("PASS: six missing/empty credential guards; configured Compose; multiline PKCS#8 round trip; app-only forwarding.");
