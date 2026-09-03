import assert from "node:assert/strict";
import { chmod, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import test from "node:test";

function run(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, options);
    let stdout = "";
    let stderr = "";
    child.stdout?.on("data", chunk => { stdout += chunk; });
    child.stderr?.on("data", chunk => { stderr += chunk; });
    child.once("error", reject);
    child.once("close", code => resolve({ code, stdout, stderr }));
  });
}

test("Docker context excludes secrets and the exact user-owned duplicate files", async () => {
  const source = await readFile(".dockerignore", "utf8");
  const exclusions = new Set(source.split(/\r?\n/).map(value => value.trim()).filter(Boolean));
  for (const expected of [
    "deploy/secrets/",
    "**/*.pem",
    "**/*.key",
    "Dockerfile 2",
    "compose.vps 2.yml",
    "db/index 2.ts",
    "db/schema 2.ts",
    "deploy/entrypoint 2.sh",
  ]) {
    assert.ok(exclusions.has(expected), `missing Docker context exclusion: ${expected}`);
  }
});

test("TypeScript excludes only the known untouched duplicate source files", async () => {
  const config = JSON.parse(await readFile("tsconfig.json", "utf8"));
  assert.deepEqual(config.exclude, [
    "node_modules",
    "db/index 2.ts",
    "db/schema 2.ts",
  ]);
});

test("PostgreSQL domains, health, migration locking, and explicit database user are configured", async () => {
  const [schema, status, migration, compose] = await Promise.all([
    readFile("db/schema.ts", "utf8"),
    readFile("app/api/nido/status/route.ts", "utf8"),
    readFile("db/migrate.ts", "utf8"),
    readFile("compose.vps.yml", "utf8"),
  ]);
  assert.match(schema, /pgEnum\(["']caregiver_role["']/);
  assert.match(schema, /pgEnum\(["']caregiver_status["']/);
  assert.match(schema, /pgEnum\(["']entry_kind["']/);
  assert.match(status, /execute<[^>]+>\(sql`SELECT 1 AS healthy`/);
  assert.match(status, /status:\s*503/);
  assert.match(migration, /pg_advisory_lock/);
  assert.match(migration, /pg_advisory_unlock/);
  assert.match(migration, /finally/);
  assert.match(compose, /postgres:\s*[\s\S]*?user:\s*["']?postgres["']?/);
});

test("Dokploy supplies Compose secrets from protected environment variables", async () => {
  const [compose, readme] = await Promise.all([
    readFile("compose.vps.yml", "utf8"),
    readFile("README.md", "utf8"),
  ]);

  assert.match(compose, /postgres_password:\s*\n\s+environment:\s*NIDO_POSTGRES_PASSWORD/);
  assert.match(compose, /auth_bucket_secret:\s*\n\s+environment:\s*NIDO_AUTH_BUCKET_SECRET/);
  assert.doesNotMatch(compose, /file:\s*\.\/deploy\/secrets\//);
  assert.match(readme, /NIDO_POSTGRES_PASSWORD/);
  assert.match(readme, /NIDO_AUTH_BUCKET_SECRET/);
  assert.match(readme, /NIDO_APPLE_AUDIENCE/);
});

test("deployment documentation states the no-migration boundary and failed-restore recovery", async () => {
  const readme = await readFile("README.md", "utf8");
  assert.match(readme, /pre-user/i);
  assert.match(readme, /NO (?:incluye|realiza).*migraci[oó]n.*D1/i);
  assert.match(readme, /exportaci[oó]n.*transformaci[oó]n.*importaci[oó]n/i);
  assert.match(readme, /si la restauraci[oó]n falla/i);
  assert.match(readme, /no reinicies.*API/i);
});

test("backup fails when pg_dump fails even if the encryption consumer succeeds", async () => {
  const directory = await mkdtemp(path.join(tmpdir(), "nido-backup-contract-"));
  const bin = path.join(directory, "bin");
  const output = path.join(directory, "backup.dump.age");
  await import("node:fs/promises").then(({ mkdir }) => mkdir(bin));
  try {
    const docker = path.join(bin, "docker");
    const age = path.join(bin, "age");
    await writeFile(docker, "#!/bin/sh\nexit 17\n");
    await writeFile(age, `#!/bin/sh\nwhile [ "$#" -gt 0 ]; do\n  if [ "$1" = "--output" ]; then shift; output=$1; fi\n  shift\ndone\nprintf encrypted > "$output"\nexit 0\n`);
    await Promise.all([chmod(docker, 0o755), chmod(age, 0o755)]);
    const result = await run("./deploy/backup-postgres.sh", [output], {
      cwd: process.cwd(),
      env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, NIDO_AGE_RECIPIENT: "age1test" },
      stdio: ["ignore", "pipe", "pipe"],
    });
    assert.notEqual(result.code, 0, `backup unexpectedly succeeded: ${result.stdout}${result.stderr}`);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
