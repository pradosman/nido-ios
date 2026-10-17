import assert from "node:assert/strict";
import { generateKeyPairSync } from "node:crypto";
import { spawnSync } from "node:child_process";
import test from "node:test";

const syntheticPrivateKey = generateKeyPairSync("ec", {
  namedCurve: "P-256",
  privateKeyEncoding: { type: "pkcs8", format: "pem" },
  publicKeyEncoding: { type: "spki", format: "pem" },
}).privateKey;
const privacyController = "Synthetic Privacy Contact for Configuration Test";
const supportEmail = "support-check@nido.invalid";
const environment = {
  ...process.env,
  NIDO_POSTGRES_PASSWORD: "synthetic-postgres-compose-test",
  NIDO_AUTH_BUCKET_SECRET: "synthetic-auth-compose-test-secret-32-bytes",
  NIDO_APPLE_AUDIENCE: "com.example.Nido",
  NIDO_APPLE_TEAM_ID: "SYNTHETICTEAM",
  NIDO_APPLE_KEY_ID: "SYNTHETICKEY1",
  NIDO_APPLE_PRIVATE_KEY: syntheticPrivateKey,
  NIDO_PRIVACY_CONTROLLER: privacyController,
  NIDO_SUPPORT_EMAIL: supportEmail,
};

test("Compose forwards configured legal contacts only to nido without exposing environment values", () => {
  const result = spawnSync("docker", [
    "compose", "--env-file", "/dev/null", "-p", "nido-legal-config-check",
    "-f", "compose.vps.yml", "config", "--format", "json",
  ], { env: environment, encoding: "utf8" });
  assert.equal(result.status, 0, "Compose configuration must resolve");

  let config;
  try { config = JSON.parse(result.stdout); }
  catch { throw new Error("Compose configuration was not valid JSON"); }

  const appEnvironment = config.services.nido.environment;
  assert.equal(appEnvironment.NIDO_PRIVACY_CONTROLLER === privacyController, true,
    "privacy controller must reach the app service");
  assert.equal(appEnvironment.NIDO_SUPPORT_EMAIL === supportEmail, true,
    "support email must reach the app service");
  assert.equal(appEnvironment.NIDO_APPLE_AUDIENCE === environment.NIDO_APPLE_AUDIENCE, true,
    "required Apple configuration must remain forwarded");
  for (const service of ["postgres", "migrate"]) {
    assert.equal(Object.hasOwn(config.services[service].environment, "NIDO_PRIVACY_CONTROLLER"), false,
      "privacy controller must not reach database services");
    assert.equal(Object.hasOwn(config.services[service].environment, "NIDO_SUPPORT_EMAIL"), false,
      "support email must not reach database services");
  }
  assert.equal(appEnvironment.NIDO_APPLE_PRIVATE_KEY === syntheticPrivateKey, true,
    "generated private key must still be forwarded to nido");
  assert.equal(Object.hasOwn(config.services.postgres.environment, "NIDO_APPLE_PRIVATE_KEY"), false,
    "Apple private key must stay app-only");
  assert.equal(Object.hasOwn(config.services.migrate.environment, "NIDO_APPLE_PRIVATE_KEY"), false,
    "Apple private key must not reach migration service");
});

test("Compose defaults the public privacy and support contacts to the publisher's approved details", () => {
  const environmentWithoutOverrides = { ...environment };
  delete environmentWithoutOverrides.NIDO_PRIVACY_CONTROLLER;
  delete environmentWithoutOverrides.NIDO_SUPPORT_EMAIL;
  const result = spawnSync("docker", [
    "compose", "--env-file", "/dev/null", "-p", "nido-legal-default-config-check",
    "-f", "compose.vps.yml", "config", "--format", "json",
  ], { env: environmentWithoutOverrides, encoding: "utf8" });
  assert.equal(result.status, 0, "Compose configuration must resolve without contact overrides");

  let config;
  try { config = JSON.parse(result.stdout); }
  catch { throw new Error("Compose configuration was not valid JSON"); }
  assert.equal(config.services.nido.environment.NIDO_PRIVACY_CONTROLLER === "David Prados Mancilla", true,
    "publisher identity must be the approved Compose default");
  assert.equal(config.services.nido.environment.NIDO_SUPPORT_EMAIL === "pradosman@gmail.com", true,
    "support contact must be the approved Compose default");
});
