import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import test from "node:test";

test("PostgreSQL migration SQL, journal entries, and snapshots stay aligned", async () => {
  const migrationFiles = (await readdir("drizzle-pg"))
    .filter(file => /^\d{4}_.+\.sql$/.test(file))
    .sort();
  const journal = JSON.parse(await readFile("drizzle-pg/meta/_journal.json", "utf8"));
  const snapshotFiles = new Set(
    (await readdir("drizzle-pg/meta")).filter(file => /^\d{4}_snapshot\.json$/.test(file)),
  );

  assert.deepEqual(
    journal.entries.map(entry => `${entry.tag}.sql`),
    migrationFiles,
    "every migration SQL filename must have the same tag in the Drizzle journal",
  );
  assert.deepEqual(
    journal.entries.map(entry => `${String(entry.idx).padStart(4, "0")}_snapshot.json`),
    [...snapshotFiles].sort(),
    "every journal entry must have its indexed Drizzle snapshot",
  );
  assert.equal(journal.dialect, "postgresql");
  const sql = await Promise.all(migrationFiles.map(file => readFile(`drizzle-pg/${file}`, "utf8")));
  assert.ok(sql.every(source => !/PRAGMA|sqlite_master|CREATE TRIGGER IF NOT EXISTS/i.test(source)));
});
