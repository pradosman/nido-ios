import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { createHash } from "node:crypto";
import { spawn, spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

let nextPort = 34100;

async function withServer(run, options = {}) {
  const ownsDataDirectory = !options.dataDirectory;
  const dataDirectory = options.dataDirectory ?? await mkdtemp(path.join(tmpdir(), "nido-households-"));
  const port = nextPort++;
  const baseURL = `http://127.0.0.1:${port}`;
  const server = spawn("sh", ["deploy/entrypoint.sh"], {
    cwd: process.cwd(),
    env: { ...process.env, NIDO_DATA_DIR: dataDirectory, NIDO_PORT: String(port) },
    stdio: ["ignore", "pipe", "pipe"],
  });
  let output = "";
  let readinessError = "";
  server.stdout.on("data", chunk => { output += chunk; });
  server.stderr.on("data", chunk => { output += chunk; });

  try {
    let ready = false;
    for (let attempt = 0; attempt < 80; attempt++) {
      if (server.exitCode !== null) throw new Error(`Server exited early:\n${output}`);
      try {
        const response = await fetch(`${baseURL}/api/nido/status`);
        if (response.ok) {
          ready = true;
          break;
        }
      } catch (error) {
        readinessError = error instanceof Error ? `${error.message} ${error.cause ?? ""}` : String(error);
      }
      await new Promise(resolve => setTimeout(resolve, 250));
    }
    if (!ready) throw new Error(`Server did not become ready (${readinessError}):\n${output}`);
    return await run({ baseURL, dataDirectory });
  } finally {
    if (server.exitCode === null) {
      const exited = new Promise(resolve => server.once("exit", resolve));
      server.kill("SIGTERM");
      await exited;
    }
    if (ownsDataDirectory) await rm(dataDirectory, { recursive: true, force: true });
  }
}

async function request(baseURL, pathname, { method = "GET", token, body } = {}) {
  const response = await fetch(`${baseURL}${pathname}`, {
    method,
    headers: {
      accept: "application/json",
      ...(body ? { "content-type": "application/json" } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const payload = await response.json();
  return { status: response.status, payload };
}

async function createHousehold(baseURL, suffix) {
  const profile = {
    caregiverName: `Owner ${suffix}`,
    babyName: `Baby ${suffix}`,
    birthDate: suffix === "A" ? "2026-01-01" : "2026-02-02",
  };
  const bootstrap = await request(baseURL, "/api/nido/caregivers/bootstrap", {
    method: "POST",
    body: { name: profile.caregiverName, babyName: profile.babyName, birthDate: profile.birthDate },
  });
  assert.equal(bootstrap.status, 201, `Household ${suffix} bootstrap failed: ${JSON.stringify(bootstrap.payload)}`);
  const token = bootstrap.payload.accessToken;
  const saved = await request(baseURL, "/api/nido/profile", { method: "PUT", token, body: profile });
  assert.equal(saved.status, 200);
  return { token, profile, caregiver: bootstrap.payload.caregiver };
}

function entry(id, suffix) {
  return {
    id,
    kind: "feed",
    title: `Feed ${suffix}`,
    detail: `Only ${suffix}`,
    occurredAt: suffix === "A" ? 1_800_000_000_000 : 1_800_000_001_000,
    durationMinutes: null,
    amountMl: suffix === "A" ? 90 : 120,
  };
}

function executeLocalD1(dataDirectory, sql) {
  const result = spawnSync("./node_modules/.bin/wrangler", [
    "d1", "execute", "DB", "--local", "--persist-to", dataDirectory,
    "--config", "wrangler.vps.jsonc", "--command", sql, "--json",
  ], { cwd: process.cwd(), encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  return JSON.parse(result.stdout)[0].results;
}

function applyLocalMigrations(dataDirectory) {
  const result = spawnSync("./node_modules/.bin/wrangler", [
    "d1", "migrations", "apply", "DB", "--local", "--persist-to", dataDirectory,
    "--config", "wrangler.vps.jsonc",
  ], { cwd: process.cwd(), encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr || result.stdout);
}

test("owner and caregiver HTTP permissions match the shared-history policy", async () => {
  await withServer(async ({ baseURL }) => {
    const familyA = await createHousehold(baseURL, "A");
    const familyB = await createHousehold(baseURL, "B");
    const ownerEntry = entry("owner-authored", "A");
    assert.equal((await request(baseURL, "/api/nido/entries", {
      method: "POST", token: familyA.token, body: ownerEntry,
    })).status, 201);

    const pending = await request(baseURL, "/api/nido/caregivers/invite", {
      method: "POST", token: familyA.token, body: { name: "Pending A" },
    });
    assert.equal(pending.status, 201);
    const joinedInvitation = await request(baseURL, "/api/nido/caregivers/invite", {
      method: "POST", token: familyA.token, body: { name: "Active A" },
    });
    assert.equal(joinedInvitation.status, 201);
    const joined = await request(baseURL, "/api/nido/caregivers/join", {
      method: "POST", body: { code: joinedInvitation.payload.caregiver.inviteCode },
    });
    assert.equal(joined.status, 200);
    const caregiverToken = joined.payload.accessToken;

    const ownerProfile = await request(baseURL, "/api/nido/profile", {
      method: "PUT", token: familyA.token,
      body: { caregiverName: "Owner A", babyName: "Owner Updated", birthDate: "2026-01-01" },
    });
    assert.equal(ownerProfile.status, 200);
    const forbiddenProfile = await request(baseURL, "/api/nido/profile", {
      method: "PUT", token: caregiverToken,
      body: { caregiverName: "Active A", babyName: "Forbidden", birthDate: "2026-03-03" },
    });
    const forbiddenInvite = await request(baseURL, "/api/nido/caregivers/invite", {
      method: "POST", token: caregiverToken, body: { name: "Forbidden invite" },
    });
    const forbiddenRemoval = await request(
      baseURL,
      `/api/nido/caregivers/invite?id=${encodeURIComponent(pending.payload.caregiver.id)}`,
      { method: "DELETE", token: caregiverToken },
    );
    assert.deepEqual(
      [forbiddenProfile.status, forbiddenInvite.status, forbiddenRemoval.status],
      [403, 403, 403],
    );

    const caregiverLoad = await request(baseURL, "/api/nido", { token: caregiverToken });
    assert.equal(caregiverLoad.status, 200);
    assert.equal(caregiverLoad.payload.profile.babyName, "Owner Updated");
    assert.deepEqual(caregiverLoad.payload.caregivers.map(value => value.name).sort(), ["Active A", "Owner A"]);
    assert.ok(caregiverLoad.payload.caregivers.every(value => value.status === "active"));
    assert.ok(caregiverLoad.payload.caregivers.every(value => value.inviteCode === null));
    const ownerLoad = await request(baseURL, "/api/nido", { token: familyA.token });
    const ownerPending = ownerLoad.payload.caregivers.find(value => value.id === pending.payload.caregiver.id);
    assert.equal(ownerPending.status, "pending");
    assert.equal(ownerPending.inviteCode, pending.payload.caregiver.inviteCode);
    assert.ok(!ownerLoad.payload.caregivers.some(value => value.name === "Forbidden invite"));

    const caregiverEntry = entry("caregiver-authored", "A");
    assert.equal((await request(baseURL, "/api/nido/entries", {
      method: "POST", token: caregiverToken, body: caregiverEntry,
    })).status, 201);
    const correctedOwnerEntry = { ...ownerEntry, detail: "Corrected by caregiver" };
    assert.equal((await request(baseURL, "/api/nido/entries", {
      method: "PUT", token: caregiverToken, body: correctedOwnerEntry,
    })).status, 200);
    assert.equal((await request(baseURL, "/api/nido/entries?id=owner-authored", {
      method: "DELETE", token: caregiverToken,
    })).status, 200);
    const afterSharedMutations = await request(baseURL, "/api/nido", { token: familyA.token });
    assert.deepEqual(afterSharedMutations.payload.entries.map(value => value.id), ["caregiver-authored"]);

    const selfRemoval = await request(
      baseURL,
      `/api/nido/caregivers/invite?id=${encodeURIComponent(familyA.caregiver.id)}`,
      { method: "DELETE", token: familyA.token },
    );
    const crossCaregiverRemoval = await request(
      baseURL,
      `/api/nido/caregivers/invite?id=${encodeURIComponent(joined.payload.caregiver.id)}`,
      { method: "DELETE", token: familyB.token },
    );
    const crossEntryUpdate = await request(baseURL, "/api/nido/entries", {
      method: "PUT", token: familyB.token, body: { ...caregiverEntry, detail: "Cross household" },
    });
    const crossEntryDelete = await request(baseURL, "/api/nido/entries?id=caregiver-authored", {
      method: "DELETE", token: familyB.token,
    });
    assert.deepEqual(
      [selfRemoval.status, crossCaregiverRemoval.status, crossEntryUpdate.status, crossEntryDelete.status],
      [400, 404, 404, 404],
    );

    const cancellation = await request(
      baseURL,
      `/api/nido/caregivers/invite?id=${encodeURIComponent(pending.payload.caregiver.id)}`,
      { method: "DELETE", token: familyA.token },
    );
    assert.equal(cancellation.status, 200);
    const removal = await request(
      baseURL,
      `/api/nido/caregivers/invite?id=${encodeURIComponent(joined.payload.caregiver.id)}`,
      { method: "DELETE", token: familyA.token },
    );
    assert.equal(removal.status, 200);
    assert.equal((await request(baseURL, "/api/nido", { token: caregiverToken })).status, 401);
    const finalOwnerLoad = await request(baseURL, "/api/nido", { token: familyA.token });
    assert.deepEqual(finalOwnerLoad.payload.caregivers.map(value => value.name), ["Owner A"]);
  });
});

test("bootstrap token failure rolls back the household, owner, and optional profile", async () => {
  const dataDirectory = await mkdtemp(path.join(tmpdir(), "nido-bootstrap-atomicity-"));
  try {
    applyLocalMigrations(dataDirectory);
    executeLocalD1(dataDirectory, "CREATE TRIGGER reject_bootstrap_token BEFORE INSERT ON caregiver_tokens BEGIN SELECT RAISE(ABORT, 'sentinel bootstrap token failure'); END;");
    await withServer(async ({ baseURL }) => {
      const bootstrap = await request(baseURL, "/api/nido/caregivers/bootstrap", {
        method: "POST",
        body: { name: "Atomic Owner", babyName: "Atomic Baby", birthDate: "2026-04-04" },
      });
      assert.equal(bootstrap.status, 500);
    }, { dataDirectory });
    const state = executeLocalD1(dataDirectory, `
      SELECT
        (SELECT COUNT(*) FROM caregivers WHERE name = 'Atomic Owner') AS caregiver_count,
        (SELECT COUNT(*) FROM households WHERE id IN (SELECT household_id FROM caregivers WHERE name = 'Atomic Owner')) AS household_count,
        (SELECT COUNT(*) FROM profiles WHERE baby_name = 'Atomic Baby') AS profile_count,
        (SELECT COUNT(*) FROM caregiver_tokens WHERE caregiver_id IN (SELECT id FROM caregivers WHERE name = 'Atomic Owner')) AS token_count;
    `);
    assert.deepEqual(state, [{ caregiver_count: 0, household_count: 0, profile_count: 0, token_count: 0 }]);
  } finally {
    await rm(dataDirectory, { recursive: true, force: true });
  }
});

test("join token failure leaves the invitation pending and reusable", async () => {
  const dataDirectory = await mkdtemp(path.join(tmpdir(), "nido-join-atomicity-"));
  let invitation;
  try {
    await withServer(async ({ baseURL }) => {
      const family = await createHousehold(baseURL, "A");
      invitation = await request(baseURL, "/api/nido/caregivers/invite", {
        method: "POST", token: family.token, body: { name: "Atomic Join" },
      });
      assert.equal(invitation.status, 201);
    }, { dataDirectory });
    const caregiverID = invitation.payload.caregiver.id;
    const inviteCode = invitation.payload.caregiver.inviteCode;
    executeLocalD1(dataDirectory, `CREATE TRIGGER reject_join_token BEFORE INSERT ON caregiver_tokens WHEN NEW.caregiver_id = '${caregiverID}' BEGIN SELECT RAISE(ABORT, 'sentinel join token failure'); END;`);
    await withServer(async ({ baseURL }) => {
      const joined = await request(baseURL, "/api/nido/caregivers/join", {
        method: "POST", body: { code: inviteCode },
      });
      assert.equal(joined.status, 500);
    }, { dataDirectory });
    const state = executeLocalD1(dataDirectory, `SELECT c.status, c.invite_code, COUNT(t.caregiver_id) AS token_count FROM caregivers c LEFT JOIN caregiver_tokens t ON t.caregiver_id = c.id WHERE c.id = '${caregiverID}' GROUP BY c.id;`);
    assert.deepEqual(state, [{ status: "pending", invite_code: inviteCode, token_count: 0 }]);
    executeLocalD1(dataDirectory, "DROP TRIGGER reject_join_token;");
    await withServer(async ({ baseURL }) => {
      const retry = await request(baseURL, "/api/nido/caregivers/join", {
        method: "POST", body: { code: inviteCode },
      });
      assert.equal(retry.status, 200);
    }, { dataDirectory });
  } finally {
    await rm(dataDirectory, { recursive: true, force: true });
  }
});

// Regression/characterization: the production batch should already make this pass.
test("pending invitation cancellation failure preserves the row and original code for retry", async () => {
  const dataDirectory = await mkdtemp(path.join(tmpdir(), "nido-cancellation-atomicity-"));
  let ownerToken;
  let invitation;
  try {
    await withServer(async ({ baseURL }) => {
      const family = await createHousehold(baseURL, "A");
      ownerToken = family.token;
      invitation = await request(baseURL, "/api/nido/caregivers/invite", {
        method: "POST", token: ownerToken, body: { name: "Atomic Cancellation" },
      });
      assert.equal(invitation.status, 201);
    }, { dataDirectory });

    const caregiverID = invitation.payload.caregiver.id;
    const inviteCode = invitation.payload.caregiver.inviteCode;
    executeLocalD1(dataDirectory, `CREATE TRIGGER reject_pending_cancellation BEFORE DELETE ON caregivers WHEN OLD.id = '${caregiverID}' AND OLD.status = 'pending' BEGIN SELECT RAISE(ABORT, 'sentinel pending cancellation failure'); END;`);

    await withServer(async ({ baseURL }) => {
      const cancellation = await request(
        baseURL,
        `/api/nido/caregivers/invite?id=${encodeURIComponent(caregiverID)}`,
        { method: "DELETE", token: ownerToken },
      );
      assert.equal(cancellation.status, 500);
    }, { dataDirectory });

    const state = executeLocalD1(dataDirectory, `SELECT status, invite_code FROM caregivers WHERE id = '${caregiverID}';`);
    assert.deepEqual(state, [{ status: "pending", invite_code: inviteCode }]);

    executeLocalD1(dataDirectory, "DROP TRIGGER reject_pending_cancellation;");
    await withServer(async ({ baseURL }) => {
      const retry = await request(baseURL, "/api/nido/caregivers/join", {
        method: "POST", body: { code: inviteCode },
      });
      assert.equal(retry.status, 200);
      assert.equal(retry.payload.caregiver.id, caregiverID);
    }, { dataDirectory });
  } finally {
    await rm(dataDirectory, { recursive: true, force: true });
  }
});

test("caregiver status failure preserves the token and active access", async () => {
  const dataDirectory = await mkdtemp(path.join(tmpdir(), "nido-removal-atomicity-"));
  let ownerToken;
  let joined;
  let accessStatus;
  try {
    await withServer(async ({ baseURL }) => {
      const family = await createHousehold(baseURL, "A");
      ownerToken = family.token;
      const invitation = await request(baseURL, "/api/nido/caregivers/invite", {
        method: "POST", token: ownerToken, body: { name: "Atomic Removal" },
      });
      joined = await request(baseURL, "/api/nido/caregivers/join", {
        method: "POST", body: { code: invitation.payload.caregiver.inviteCode },
      });
      assert.equal(joined.status, 200);
    }, { dataDirectory });
    const caregiverID = joined.payload.caregiver.id;
    executeLocalD1(dataDirectory, `CREATE TRIGGER reject_removal_status BEFORE UPDATE OF status ON caregivers WHEN NEW.id = '${caregiverID}' AND NEW.status = 'removed' BEGIN SELECT RAISE(ABORT, 'sentinel removal status failure'); END;`);
    await withServer(async ({ baseURL }) => {
      const removal = await request(
        baseURL,
        `/api/nido/caregivers/invite?id=${encodeURIComponent(caregiverID)}`,
        { method: "DELETE", token: ownerToken },
      );
      assert.equal(removal.status, 500);
      accessStatus = (await request(baseURL, "/api/nido", { token: joined.payload.accessToken })).status;
    }, { dataDirectory });
    const state = executeLocalD1(dataDirectory, `SELECT c.status, COUNT(t.caregiver_id) AS token_count FROM caregivers c LEFT JOIN caregiver_tokens t ON t.caregiver_id = c.id WHERE c.id = '${caregiverID}' GROUP BY c.id;`);
    assert.deepEqual({ ...state[0], access_status: accessStatus }, { status: "active", token_count: 1, access_status: 200 });
  } finally {
    await rm(dataDirectory, { recursive: true, force: true });
  }
});

test("entry deletion failure preserves both the entry and its author", async () => {
  const dataDirectory = await mkdtemp(path.join(tmpdir(), "nido-entry-delete-atomicity-"));
  const entryID = "atomic-delete-entry";
  let ownerToken;
  try {
    await withServer(async ({ baseURL }) => {
      const family = await createHousehold(baseURL, "A");
      ownerToken = family.token;
      assert.equal((await request(baseURL, "/api/nido/entries", {
        method: "POST", token: ownerToken, body: entry(entryID, "A"),
      })).status, 201);
    }, { dataDirectory });
    executeLocalD1(dataDirectory, `CREATE TRIGGER reject_entry_delete BEFORE DELETE ON entries WHEN OLD.id = '${entryID}' BEGIN SELECT RAISE(ABORT, 'sentinel entry deletion failure'); END;`);
    await withServer(async ({ baseURL }) => {
      const deletion = await request(baseURL, `/api/nido/entries?id=${entryID}`, {
        method: "DELETE", token: ownerToken,
      });
      assert.equal(deletion.status, 500);
    }, { dataDirectory });
    const state = executeLocalD1(dataDirectory, `SELECT (SELECT COUNT(*) FROM entries WHERE id = '${entryID}') AS entry_count, (SELECT COUNT(*) FROM entry_authors WHERE entry_id = '${entryID}') AS author_count;`);
    assert.deepEqual(state, [{ entry_count: 1, author_count: 1 }]);
  } finally {
    await rm(dataDirectory, { recursive: true, force: true });
  }
});

test("the browser UI is retired while the Nido API remains available", async () => {
  await withServer(async ({ baseURL }) => {
    const root = await fetch(`${baseURL}/`, { headers: { accept: "text/html" } });
    assert.equal(root.status, 404);
    assert.doesNotMatch(await root.text(), /Preparando vuestro espacio|Un espacio para vuestro día a día/);

    const prototype = await fetch(`${baseURL}/prototypes/inicio`, { headers: { accept: "text/html" } });
    assert.equal(prototype.status, 404);

    const status = await request(baseURL, "/api/nido/status");
    assert.equal(status.status, 200);
    assert.deepEqual(status.payload, { canCreateHousehold: true, canJoinWithInvitation: true });

    const protectedRoute = await request(baseURL, "/api/nido");
    assert.equal(protectedRoute.status, 401);
    assert.deepEqual(protectedRoute.payload, { error: "Necesitas una invitación para acceder" });
  });
});

test("two unrelated owners bootstrap independent households", async () => {
  await withServer(async ({ baseURL }) => {
    const familyA = await createHousehold(baseURL, "A");
    const familyB = await createHousehold(baseURL, "B");
    assert.notEqual(familyA.caregiver.id, familyB.caregiver.id);
  });
});

test("load, profile, caregivers, and entries stay inside the authorized household", async () => {
  await withServer(async ({ baseURL }) => {
    const familyA = await createHousehold(baseURL, "A");
    const familyB = await createHousehold(baseURL, "B");
    await request(baseURL, "/api/nido/entries", { method: "POST", token: familyA.token, body: entry("entry-a", "A") });
    await request(baseURL, "/api/nido/entries", { method: "POST", token: familyB.token, body: entry("entry-b", "B") });
    await request(baseURL, "/api/nido/caregivers/invite", { method: "POST", token: familyA.token, body: { name: "Caregiver A" } });
    await request(baseURL, "/api/nido/caregivers/invite", { method: "POST", token: familyB.token, body: { name: "Caregiver B" } });

    const loadA = await request(baseURL, "/api/nido", { token: familyA.token });
    const loadB = await request(baseURL, "/api/nido", { token: familyB.token });
    assert.equal(loadA.payload.profile.babyName, "Baby A");
    assert.equal(loadB.payload.profile.babyName, "Baby B");
    assert.deepEqual(loadA.payload.entries.map(value => value.id), ["entry-a"]);
    assert.deepEqual(loadB.payload.entries.map(value => value.id), ["entry-b"]);
    assert.deepEqual(loadA.payload.caregivers.map(value => value.name).sort(), ["Caregiver A", "Owner A"]);
    assert.deepEqual(loadB.payload.caregivers.map(value => value.name).sort(), ["Caregiver B", "Owner B"]);
  });
});

test("entry creation rolls back the entry when authorship persistence fails", async () => {
  const dataDirectory = await mkdtemp(path.join(tmpdir(), "nido-entry-atomicity-"));
  const sentinelID = "reject-author-entry";
  try {
    const migrations = spawnSync("./node_modules/.bin/wrangler", [
      "d1", "migrations", "apply", "DB", "--local", "--persist-to", dataDirectory,
      "--config", "wrangler.vps.jsonc",
    ], { cwd: process.cwd(), encoding: "utf8" });
    assert.equal(migrations.status, 0, migrations.stderr || migrations.stdout);
    executeLocalD1(dataDirectory, `CREATE TRIGGER reject_sentinel_entry_author BEFORE INSERT ON entry_authors WHEN NEW.entry_id = '${sentinelID}' BEGIN SELECT RAISE(ABORT, 'sentinel author failure'); END;`);

    await withServer(async ({ baseURL }) => {
      const family = await createHousehold(baseURL, "A");
      const creation = await request(baseURL, "/api/nido/entries", {
        method: "POST", token: family.token, body: entry(sentinelID, "A"),
      });
      assert.equal(creation.status, 500);
    }, { dataDirectory });

    const rows = executeLocalD1(
      dataDirectory,
      `SELECT 'entry' AS row_type FROM entries WHERE id = '${sentinelID}' UNION ALL SELECT 'author' AS row_type FROM entry_authors WHERE entry_id = '${sentinelID}';`,
    );
    assert.deepEqual(rows, []);
  } finally {
    await rm(dataDirectory, { recursive: true, force: true });
  }
});

test("entry creation persists authorship and same-id retries cannot overwrite household data", async () => {
  const dataDirectory = await mkdtemp(path.join(tmpdir(), "nido-entry-idempotency-"));
  const entryID = "stable-entry";
  try {
    await withServer(async ({ baseURL }) => {
      const familyA = await createHousehold(baseURL, "A");
      const familyB = await createHousehold(baseURL, "B");
      const original = entry(entryID, "A");
      const creation = await request(baseURL, "/api/nido/entries", {
        method: "POST", token: familyA.token, body: original,
      });
      assert.equal(creation.status, 201);
      assert.equal(creation.payload.entry.caregiverID, familyA.caregiver.id);
      assert.equal(creation.payload.entry.caregiverName, familyA.profile.caregiverName);

      const retry = await request(baseURL, "/api/nido/entries", {
        method: "POST", token: familyA.token, body: { ...original, title: "Unsafe overwrite", detail: "Changed" },
      });
      assert.equal(retry.status, 201);
      assert.equal(retry.payload.entry.title, original.title);
      assert.equal(retry.payload.entry.detail, original.detail);

      const crossHouseholdRetry = await request(baseURL, "/api/nido/entries", {
        method: "POST", token: familyB.token, body: entry(entryID, "B"),
      });
      assert.equal(crossHouseholdRetry.status, 409);
      assert.deepEqual((await request(baseURL, "/api/nido", { token: familyB.token })).payload.entries, []);
    }, { dataDirectory });

    const rows = executeLocalD1(
      dataDirectory,
      `SELECT e.id, e.title, e.detail, e.household_id, a.household_id AS author_household_id, a.caregiver_id, a.caregiver_name FROM entries e JOIN entry_authors a ON a.entry_id = e.id WHERE e.id = '${entryID}';`,
    );
    assert.equal(rows.length, 1);
    assert.equal(rows[0].title, "Feed A");
    assert.equal(rows[0].detail, "Only A");
    assert.equal(rows[0].household_id, rows[0].author_household_id);
  } finally {
    await rm(dataDirectory, { recursive: true, force: true });
  }
});

test("entry history cursor pagination is complete, stable, bounded, and household-scoped", async () => {
  await withServer(async ({ baseURL }) => {
    const familyA = await createHousehold(baseURL, "A");
    const familyB = await createHousehold(baseURL, "B");
    const boundaryTimestamp = 1_900_000_000_000;
    const familyAEntries = Array.from({ length: 513 }, (_, index) => ({
      ...entry(`a-${String(index).padStart(4, "0")}`, "A"),
      occurredAt: index >= 96 && index <= 104
        ? boundaryTimestamp
        : boundaryTimestamp + (513 - index) * 1_000,
    }));
    const familyBEntries = Array.from({ length: 7 }, (_, index) => ({
      ...entry(`b-${String(index).padStart(4, "0")}`, "B"),
      occurredAt: boundaryTimestamp + index * 500,
    }));

    for (let offset = 0; offset < familyAEntries.length; offset += 10) {
      const results = await Promise.all(familyAEntries.slice(offset, offset + 10).map(body =>
        request(baseURL, "/api/nido/entries", { method: "POST", token: familyA.token, body })
      ));
      assert.ok(results.every(result => result.status === 201));
    }
    const noiseResults = await Promise.all(familyBEntries.map(body =>
      request(baseURL, "/api/nido/entries", { method: "POST", token: familyB.token, body })
    ));
    assert.ok(noiseResults.every(result => result.status === 201));

    const first = await request(baseURL, "/api/nido", { token: familyA.token });
    assert.equal(first.status, 200);
    const traversed = [...first.payload.entries];
    let cursor = first.payload.nextCursor;
    const seenCursors = new Set();
    let pageCount = 1;
    while (cursor !== null) {
      assert.equal(typeof cursor, "string");
      assert.ok(!seenCursors.has(cursor), "cursor traversal must be finite");
      seenCursors.add(cursor);
      const page = await request(
        baseURL,
        `/api/nido/entries?cursor=${encodeURIComponent(cursor)}&limit=37`,
        { token: familyA.token },
      );
      assert.equal(page.status, 200);
      traversed.push(...page.payload.entries);
      cursor = page.payload.nextCursor;
      pageCount += 1;
      assert.ok(pageCount < 100, "cursor traversal exceeded its finite bound");
    }

    const expected = [...familyAEntries].sort((left, right) =>
      right.occurredAt - left.occurredAt || (left.id < right.id ? 1 : -1)
    );
    assert.equal(traversed.length, 513, "the fixed 500-entry snapshot must not truncate history");
    assert.deepEqual(traversed.map(value => value.id), expected.map(value => value.id));
    assert.equal(new Set(traversed.map(value => value.id)).size, 513);
    assert.ok(traversed.every(value => value.id.startsWith("a-")));

    const malformed = await request(baseURL, "/api/nido/entries?cursor=not-a-cursor", { token: familyA.token });
    assert.equal(malformed.status, 400);
    const capped = await request(baseURL, "/api/nido/entries?limit=10000", { token: familyA.token });
    assert.equal(capped.status, 200);
    assert.ok(capped.payload.entries.length <= 200, "caller-controlled page size must be capped");
  });
});

test("a household token cannot read, update, or delete another household entry by id", async () => {
  await withServer(async ({ baseURL }) => {
    const familyA = await createHousehold(baseURL, "A");
    const familyB = await createHousehold(baseURL, "B");
    await request(baseURL, "/api/nido/entries", { method: "POST", token: familyB.token, body: entry("entry-b", "B") });

    const update = await request(baseURL, "/api/nido/entries", {
      method: "PUT", token: familyA.token, body: { ...entry("entry-b", "A"), detail: "stolen" },
    });
    const deletion = await request(baseURL, "/api/nido/entries?id=entry-b", { method: "DELETE", token: familyA.token });
    assert.equal(update.status, 404);
    assert.equal(deletion.status, 404);
    const loadA = await request(baseURL, "/api/nido", { token: familyA.token });
    const loadB = await request(baseURL, "/api/nido", { token: familyB.token });
    assert.deepEqual(loadA.payload.entries, []);
    assert.equal(loadB.payload.entries[0].detail, "Only B");
  });
});

test("an invitation joins exactly its household and cannot cross-scope caregiver mutation", async () => {
  await withServer(async ({ baseURL }) => {
    const familyA = await createHousehold(baseURL, "A");
    const familyB = await createHousehold(baseURL, "B");
    const invitation = await request(baseURL, "/api/nido/caregivers/invite", {
      method: "POST", token: familyA.token, body: { name: "Invited A" },
    });
    const joined = await request(baseURL, "/api/nido/caregivers/join", {
      method: "POST", body: { code: invitation.payload.caregiver.inviteCode },
    });
    assert.equal(joined.status, 200);
    const joinedLoad = await request(baseURL, "/api/nido", { token: joined.payload.accessToken });
    assert.equal(joinedLoad.payload.profile.babyName, "Baby A");
    assert.ok(joinedLoad.payload.caregivers.every(value => value.name !== "Owner B"));

    const crossRemoval = await request(
      baseURL,
      `/api/nido/caregivers/invite?id=${joined.payload.caregiver.id}`,
      { method: "DELETE", token: familyB.token },
    );
    assert.equal(crossRemoval.status, 404);
    assert.equal((await request(baseURL, "/api/nido", { token: joined.payload.accessToken })).status, 200);
  });
});

test("legacy migration preserves profile, caregivers, tokens, entries, and authorship", async () => {
  const dataDirectory = await mkdtemp(path.join(tmpdir(), "nido-legacy-"));
  const legacyToken = "legacy-installed-token";
  const tokenHash = createHash("sha256").update(legacyToken).digest("hex");
  try {
    const schema = spawnSync("./node_modules/.bin/wrangler", [
      "d1", "execute", "DB", "--local", "--persist-to", dataDirectory,
      "--config", "wrangler.vps.jsonc", "--file", "tests/fixtures/nido-legacy.sql",
    ], { cwd: process.cwd(), encoding: "utf8" });
    assert.equal(schema.status, 0, schema.stderr || schema.stdout);
    const seedSQL = `INSERT INTO caregivers (id,name,role,status,joined_at) VALUES ('legacy-owner','Legacy Owner','owner','active','2026-01-01');\n`
      + `INSERT INTO caregiver_tokens (caregiver_id,token_hash) VALUES ('legacy-owner','${tokenHash}');\n`
      + "INSERT INTO profiles (id,caregiver_name,baby_name,birth_date) VALUES (1,'Legacy Owner','Legacy Baby','2025-12-01');\n"
      + "INSERT INTO entries (id,kind,title,detail,occurred_at) VALUES ('legacy-entry','feed','Legacy Feed','Preserved',1700000000000);\n"
      + "INSERT INTO entry_authors (entry_id,caregiver_id,caregiver_name) VALUES ('legacy-entry','legacy-owner','Legacy Owner');";
    const seedResult = spawnSync("./node_modules/.bin/wrangler", [
      "d1", "execute", "DB", "--local", "--persist-to", dataDirectory,
      "--config", "wrangler.vps.jsonc", "--command", seedSQL,
    ], { cwd: process.cwd(), encoding: "utf8" });
    assert.equal(seedResult.status, 0, seedResult.stderr || seedResult.stdout);
    await withServer(async ({ baseURL }) => {
      const load = await request(baseURL, "/api/nido", { token: legacyToken });
      assert.equal(load.status, 200);
      assert.equal(load.payload.profile.babyName, "Legacy Baby");
      assert.equal(load.payload.entries[0].caregiverID, "legacy-owner");
    }, { dataDirectory });

    const verification = spawnSync("./node_modules/.bin/wrangler", [
      "d1", "execute", "DB", "--local", "--persist-to", dataDirectory,
      "--config", "wrangler.vps.jsonc", "--command",
      "SELECT p.household_id AS profile_household, c.household_id AS caregiver_household, e.household_id AS entry_household, a.household_id AS author_household FROM profiles p, caregivers c, entries e, entry_authors a WHERE p.baby_name='Legacy Baby' AND c.id='legacy-owner' AND e.id='legacy-entry' AND a.entry_id='legacy-entry';",
      "--json",
    ], { cwd: process.cwd(), encoding: "utf8" });
    assert.equal(verification.status, 0, verification.stderr || verification.stdout);
    const rows = JSON.parse(verification.stdout)[0].results;
    assert.equal(rows.length, 1);
    assert.equal(new Set(Object.values(rows[0])).size, 1);
  } finally {
    await rm(dataDirectory, { recursive: true, force: true });
  }
});
