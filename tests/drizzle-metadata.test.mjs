import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import test from "node:test";

test("Drizzle migration SQL, journal entries, and snapshots stay aligned", async () => {
  const migrationFiles = (await readdir("drizzle"))
    .filter(file => /^\d{4}_.+\.sql$/.test(file))
    .sort();
  const journal = JSON.parse(await readFile("drizzle/meta/_journal.json", "utf8"));
  const snapshotFiles = new Set(
    (await readdir("drizzle/meta")).filter(file => /^\d{4}_snapshot\.json$/.test(file)),
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
});
