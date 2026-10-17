import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { test } from "node:test";

import { isDirectInvocation, seedLocalRealAPIUITestSessions } from "../ios/Nido/Scripts/local-real-api-ui-sessions.mjs";
import { mkdtemp, rm, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

test("local real-API UI fixtures create five distinct hashed sessions", async () => {
  const statements = [];
  const now = new Date("2026-10-15T10:00:00.000Z");
  const sessions = await seedLocalRealAPIUITestSessions(async (statement, parameters) => {
    statements.push({ statement, parameters });
  }, "harness-test", now);

  assert.deepEqual(Object.keys(sessions).sort(), [
    "history",
    "ownerA",
    "ownerB",
    "permissionsCaregiver",
    "permissionsOwner",
  ]);
  assert.equal(new Set(Object.values(sessions)).size, 5);
  assert.ok(Object.values(sessions).every(token => token.length >= 32));
  assert.equal(statements.length, 15);

  for (let index = 0; index < Object.keys(sessions).length; index += 1) {
    const [user, challenge, session] = statements.slice(index * 3, index * 3 + 3);
    const token = Object.values(sessions)[index];
    assert.match(user.statement, /INSERT INTO users/);
    assert.match(challenge.statement, /INSERT INTO auth_challenges/);
    assert.match(session.statement, /INSERT INTO auth_sessions/);
    assert.equal(user.parameters[0].replace("local-ui-user-", ""), challenge.parameters[0].replace("local-ui-challenge-", ""));
    assert.equal(user.parameters[0].replace("local-ui-user-", ""), session.parameters[0].replace("local-ui-session-", ""));
    assert.equal(user.parameters[2].toISOString(), now.toISOString());
    assert.equal(challenge.parameters[3].toISOString(), now.toISOString());
    assert.equal(session.parameters[3], createHash("sha256").update(token).digest("hex"));
    assert.notEqual(session.parameters[3], token);
    assert.ok(session.parameters[4] > now);
  }
});

test("CLI entry detection follows a symlinked checkout path", async () => {
  const temporaryDirectory = await mkdtemp(join(tmpdir(), "nido-seeder-entry-"));
  const sourcePath = fileURLToPath(new URL("../ios/Nido/Scripts/local-real-api-ui-sessions.mjs", import.meta.url));
  const linkPath = join(temporaryDirectory, "seed-sessions.mjs");
  try {
    await symlink(sourcePath, linkPath);
    assert.equal(isDirectInvocation(pathToFileURL(sourcePath).href, linkPath), true);
  } finally {
    await rm(temporaryDirectory, { recursive: true, force: true });
  }
});
