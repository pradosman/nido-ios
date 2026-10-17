import assert from "node:assert/strict";
import test from "node:test";

import { createTestDatabase } from "../db/testing.ts";
import { hashAccessToken } from "../app/api/nido/auth.ts";
import * as householdRoute from "../app/api/nido/route.ts";
import * as sleepRoute from "../app/api/nido/sleep/route.ts";

async function addCaregiver(client, { id, householdID, name }) {
  const userID = `${id}-user`;
  const token = `${id}-token-${"x".repeat(40)}`;
  const now = new Date();
  await client.query("INSERT INTO users (id, apple_subject) VALUES ($1, $2)", [userID, `${id}-subject`]);
  await client.query(
    "INSERT INTO caregivers (id, household_id, user_id, name, role, status, joined_at) VALUES ($1, $2, $3, $4, 'caregiver', 'active', $5)",
    [id, householdID, userID, name, now],
  );
  await client.query(
    "INSERT INTO auth_sessions (id, user_id, token_hash, expires_at) VALUES ($1, $2, $3, $4)",
    [`${id}-session`, userID, await hashAccessToken(token), new Date(now.getTime() + 60_000)],
  );
  return token;
}

async function call(route, method, token, body) {
  const response = await route[method](new Request(`http://nido.test/api/nido/sleep`, {
    method,
    headers: {
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(body ? { "content-type": "application/json" } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  }));
  return { status: response.status, payload: await response.json() };
}

function pausedBodyRequest(token, body) {
  const encodedBody = new TextEncoder().encode(JSON.stringify(body));
  let bodyRead;
  const bodyReadStarted = new Promise(resolve => { bodyRead = resolve; });
  let releaseBody;
  const bodyRelease = new Promise(resolve => { releaseBody = resolve; });
  let readOnce = false;
  return {
    bodyReadStarted,
    releaseBody,
    request: {
      headers: new Headers({ authorization: `Bearer ${token}`, "content-length": String(encodedBody.byteLength) }),
      body: {
        getReader() {
          return {
            async read() {
              if (readOnce) return { done: true, value: undefined };
              readOnce = true;
              bodyRead();
              await bodyRelease;
              return { done: false, value: encodedBody };
            },
          };
        },
      },
    },
  };
}

test("active sleep is shared by household and stale finish cannot clear a newer sleep", async () => {
  const { client, close } = await createTestDatabase();
  try {
    const householdID = "sleep-test-household";
    const otherHouseholdID = "sleep-other-household";
    await client.query("INSERT INTO households (id) VALUES ($1), ($2)", [householdID, otherHouseholdID]);
    const ownerToken = await addCaregiver(client, { id: "sleep-owner", householdID, name: "Sleep Owner" });
    const memberToken = await addCaregiver(client, { id: "sleep-member", householdID, name: "Sleep Member" });
    const otherHouseholdToken = await addCaregiver(client, {
      id: "sleep-other-member", householdID: otherHouseholdID, name: "Other Household",
    });

    assert.deepEqual(await call(sleepRoute, "GET", memberToken), {
      status: 200, payload: { activeSleepStartedAt: null },
    });
    assert.equal((await call(sleepRoute, "GET", null)).status, 401);
    assert.equal((await call(sleepRoute, "PUT", ownerToken, { startedAt: "invalid", expectedStartedAt: null })).status, 400);

    const startedAt = Date.now() - 120_000;
    const started = await call(sleepRoute, "PUT", ownerToken, { startedAt, expectedStartedAt: null });
    assert.deepEqual(started, { status: 200, payload: { activeSleepStartedAt: startedAt } });
    assert.deepEqual(await call(sleepRoute, "PUT", ownerToken, { startedAt, expectedStartedAt: null }), started);
    assert.deepEqual(await call(sleepRoute, "GET", memberToken), started);

    const snapshotResponse = await householdRoute.GET(new Request("http://nido.test/api/nido", {
      headers: { authorization: `Bearer ${memberToken}` },
    }));
    const snapshot = await snapshotResponse.json();
    assert.equal(snapshotResponse.status, 200);
    assert.equal(snapshot.activeSleepStartedAt, startedAt);
    assert.deepEqual(await call(sleepRoute, "GET", otherHouseholdToken), {
      status: 200, payload: { activeSleepStartedAt: null },
    });

    const newerStartedAt = startedAt + 60_000;
    assert.deepEqual(await call(sleepRoute, "PUT", memberToken, {
      startedAt: newerStartedAt, expectedStartedAt: startedAt,
    }), { status: 200, payload: { activeSleepStartedAt: newerStartedAt } });
    assert.deepEqual(await call(sleepRoute, "PUT", ownerToken, {
      startedAt: null, expectedStartedAt: startedAt,
    }), { status: 409, payload: { activeSleepStartedAt: newerStartedAt } });
    assert.deepEqual(await call(sleepRoute, "PUT", ownerToken, {
      startedAt: null, expectedStartedAt: newerStartedAt,
    }), { status: 200, payload: { activeSleepStartedAt: null } });
    assert.deepEqual(await call(sleepRoute, "PUT", ownerToken, {
      startedAt: null, expectedStartedAt: newerStartedAt,
    }), { status: 200, payload: { activeSleepStartedAt: null } });
    assert.deepEqual(await call(sleepRoute, "GET", memberToken), {
      status: 200, payload: { activeSleepStartedAt: null },
    });
  } finally {
    await close();
  }
});

test("active sleep rejects a write when caregiver membership is removed after authorization", async () => {
  const { client, close } = await createTestDatabase();
  try {
    const householdID = "sleep-revoked-household";
    await client.query("INSERT INTO households (id) VALUES ($1)", [householdID]);
    const ownerToken = await addCaregiver(client, { id: "sleep-revoked-owner", householdID, name: "Owner" });
    const memberToken = await addCaregiver(client, { id: "sleep-revoked-member", householdID, name: "Member" });
    const gate = pausedBodyRequest(memberToken, { startedAt: Date.now() - 60_000, expectedStartedAt: null });
    const pendingWrite = sleepRoute.PUT(gate.request);
    await gate.bodyReadStarted;
    await client.query("UPDATE caregivers SET status = 'removed' WHERE id = $1", ["sleep-revoked-member"]);
    gate.releaseBody();

    const response = await pendingWrite;
    assert.equal(response.status, 403);
    assert.deepEqual(await call(sleepRoute, "GET", ownerToken), {
      status: 200, payload: { activeSleepStartedAt: null },
    });
  } finally {
    await close();
  }
});
