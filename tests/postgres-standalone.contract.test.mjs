import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import test from "node:test";

test("PostgreSQL migrations apply to the injected PGlite adapter", async () => {
  const [{ createTestDatabase }, schema] = await Promise.all([
    import("../db/testing.ts"),
    import("../db/schema.ts"),
  ]);
  const database = await createTestDatabase();
  try {
    const householdID = crypto.randomUUID();
    await database.db.insert(schema.households).values({ id: householdID });
    const rows = await database.db.select().from(schema.households);
    assert.deepEqual(rows.map(row => row.id), [householdID]);
    await assert.rejects(
      database.db.insert(schema.caregivers).values({
        id: crypto.randomUUID(),
        householdId: householdID,
        name: "Invalid role",
        role: "administrator",
        status: "pending",
      }),
      error => {
        assert.match(error.cause?.message ?? "", /invalid input value for enum caregiver_role/);
        return true;
      },
    );
  } finally {
    await database.close();
  }
});

test("atomic route operations use PostgreSQL transactions instead of D1 batches", async () => {
  const routeFiles = [
    "app/api/nido/auth/account/route.ts",
    "app/api/nido/auth/apple/session/route.ts",
    "app/api/nido/caregivers/bootstrap/route.ts",
    "app/api/nido/caregivers/invite/route.ts",
    "app/api/nido/caregivers/join/route.ts",
    "app/api/nido/entries/route.ts",
  ];
  const sources = await Promise.all(routeFiles.map(file => readFile(file, "utf8")));
  assert.ok(sources.every(source => !source.includes(".batch(")), "D1 batch calls must be removed");
  assert.ok(sources.every(source => source.includes(".transaction(")), "atomic routes must use transactions");
});

test("production deployment is a standalone Node server backed by private PostgreSQL", async () => {
  const [packageSource, vite, dockerfile, compose, entrypoint, gitignore] = await Promise.all([
    readFile("package.json", "utf8"),
    readFile("vite.config.ts", "utf8"),
    readFile("Dockerfile", "utf8"),
    readFile("compose.vps.yml", "utf8"),
    readFile("deploy/entrypoint.sh", "utf8"),
    readFile(".gitignore", "utf8"),
  ]);
  const packageJSON = JSON.parse(packageSource);
  assert.match(packageJSON.scripts.build, /vinext build/);
  assert.equal(packageJSON.scripts.start, "node dist/standalone/server.js");
  assert.match(packageJSON.scripts["db:migrate"], /db\/migrate\.ts/);
  assert.ok(packageJSON.dependencies.postgres);
  assert.ok(packageJSON.devDependencies["@electric-sql/pglite"]);
  assert.equal(packageJSON.devDependencies.wrangler, undefined);
  assert.equal(packageJSON.devDependencies["@cloudflare/vite-plugin"], undefined);
  assert.doesNotMatch(vite, /cloudflare|wrangler|Miniflare|hosting\.json/i);
  assert.match(entrypoint, /dist\/standalone\/server\.js/);
  assert.doesNotMatch(entrypoint, /wrangler|d1/i);
  assert.match(dockerfile, /USER nido/);
  assert.doesNotMatch(dockerfile, /COPY --from=build \/app\/node_modules/);
  assert.match(compose, /postgres:/);
  assert.match(compose, /internal:\s*true/);
  assert.match(compose, /condition:\s*service_completed_successfully/);
  assert.doesNotMatch(compose, /postgres:[\s\S]*ports:/);
  assert.match(compose, /secrets:/);
  assert.match(gitignore, /deploy\/secrets\/\*/);
});

test("PostgreSQL migrations are isolated from archived SQLite history", async () => {
  const [config, files] = await Promise.all([
    readFile("drizzle.pg.config.ts", "utf8"),
    readdir("drizzle-pg"),
  ]);
  assert.match(config, /dialect:\s*["']postgresql["']/);
  assert.match(config, /out:\s*["']\.\/drizzle-pg["']/);
  assert.ok(files.some(file => /^\d{4}_.+\.sql$/.test(file)));
  assert.ok(!files.some(file => /sqlite|pragma/i.test(file)));
});
