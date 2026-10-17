import assert from "node:assert/strict";
import test from "node:test";

import * as babyCareRoute from "../app/api/nido/baby-care/route.ts";
import { createHousehold, routeRequest, seedSession, withRouteDatabase } from "./support/nido-route-harness.mjs";

const goal = { id: "11111111-1111-4111-8111-111111111111", effectiveDate: "2026-10-17", sleepMinutes: 600, feedCount: 8, diaperCount: 6 };
const measurement = { id: "22222222-2222-4222-8222-222222222222", measuredAt: Date.UTC(2026, 9, 17, 8), weightGrams: 4200, heightMillimeters: 540, note: "" };
const payload = { expectedRevision: 0, timeZoneID: "Europe/Madrid", goalVersions: [goal], measurements: [measurement] };

async function addMember(client, householdID) {
  const session = await seedSession(client);
  await client.query(
    "INSERT INTO caregivers (id, household_id, user_id, name, role, status, joined_at) VALUES ($1, $2, $3, $4, 'caregiver', 'active', now())",
    [`member-${session.userID}`, householdID, session.userID, "Member"],
  );
  return session.token;
}

test("baby care rejects a write when caregiver membership is revoked after authorization", async () => {
  await withRouteDatabase(async ({ client, request }) => {
    const owner = await createHousehold(request, client, "A");
    const [{ household_id: householdID }] = (await client.query("SELECT household_id FROM caregivers WHERE user_id = $1", [owner.userID])).rows;
    const memberToken = await addMember(client, householdID);
    const saved = await request("/api/nido/baby-care", { method: "PUT", token: owner.token, body: payload });
    assert.equal(saved.status, 200);

    let bodyRead;
    const bodyReadStarted = new Promise(resolve => { bodyRead = resolve; });
    let releaseBody;
    const bodyRelease = new Promise(resolve => { releaseBody = resolve; });
    const encodedBody = new TextEncoder().encode(JSON.stringify({
      ...payload,
      expectedRevision: 1,
      measurements: [{ ...measurement, weightGrams: 4_300 }],
    }));
    let bodyReadOnce = false;
    const requestWithPausedBody = {
      headers: new Headers({ authorization: `Bearer ${memberToken}`, "content-length": String(encodedBody.byteLength) }),
      body: {
        getReader() {
          return {
            async read() {
              if (bodyReadOnce) return { done: true, value: undefined };
              bodyReadOnce = true;
              bodyRead();
              await bodyRelease;
              return { done: false, value: encodedBody };
            },
          };
        },
      },
    };
    const pendingWrite = babyCareRoute.PUT(requestWithPausedBody);
    const reachedBodyRead = await Promise.race([
      bodyReadStarted.then(() => "body"),
      pendingWrite.then(() => "response"),
    ]);
    assert.equal(reachedBodyRead, "body", "PUT should pass authorization before reading the request body");
    await client.query("UPDATE caregivers SET status = 'removed' WHERE household_id = $1 AND role = 'caregiver'", [householdID]);
    releaseBody();

    const response = await pendingWrite;
    const responsePayload = await response.json();
    assert.equal(response.status, 403);
    assert.deepEqual(responsePayload, { error: "An active household membership is required" });
    const state = await request("/api/nido/baby-care", { token: owner.token });
    assert.deepEqual(state.payload, saved.payload);
  });
});

test("baby care state is authenticated, household shared, role guarded and revision checked", async () => {
  await withRouteDatabase(async ({ client, request }) => {
    const first = await createHousehold(request, client, "A");
    const [{ household_id: firstHouseholdID }] = (await client.query("SELECT household_id FROM caregivers WHERE user_id = $1", [first.userID])).rows;
    const memberToken = await addMember(client, firstHouseholdID);
    const other = await createHousehold(request, client, "B");

    const initial = await request("/api/nido/baby-care", { token: first.token });
    assert.equal(initial.status, 200);
    assert.deepEqual(initial.payload, { state: null });
    assert.equal((await request("/api/nido/baby-care")).status, 401);

    const saved = await request("/api/nido/baby-care", { method: "PUT", token: first.token, body: payload });
    assert.equal(saved.status, 200);
    assert.deepEqual(saved.payload.state, { revision: 1, ...Object.fromEntries(Object.entries(payload).filter(([key]) => key !== "expectedRevision")) });
    assert.deepEqual((await request("/api/nido/baby-care", { token: memberToken })).payload, saved.payload);
    assert.deepEqual((await request("/api/nido/baby-care", { token: other.token })).payload, { state: null });

    const memberGrowthEdit = structuredClone(saved.payload.state);
    memberGrowthEdit.measurements[0].weightGrams = 4250;
    assert.equal((await request("/api/nido/baby-care", { method: "PUT", token: memberToken, body: {
      expectedRevision: 1, timeZoneID: memberGrowthEdit.timeZoneID,
      goalVersions: memberGrowthEdit.goalVersions, measurements: memberGrowthEdit.measurements,
    } })).status, 200);

    const stale = await request("/api/nido/baby-care", { method: "PUT", token: first.token, body: payload });
    assert.equal(stale.status, 409);
    assert.equal(stale.payload.state.revision, 2);

    const memberGoalEdit = { ...memberGrowthEdit, goalVersions: [{ ...goal, feedCount: 9 }] };
    assert.equal((await request("/api/nido/baby-care", { method: "PUT", token: memberToken, body: {
      expectedRevision: 2, timeZoneID: memberGoalEdit.timeZoneID,
      goalVersions: memberGoalEdit.goalVersions, measurements: memberGoalEdit.measurements,
    } })).status, 403);

    const disabledGoals = await request("/api/nido/baby-care", { method: "PUT", token: first.token, body: {
      expectedRevision: 2, timeZoneID: memberGrowthEdit.timeZoneID,
      goalVersions: [...memberGrowthEdit.goalVersions, {
        id: "55555555-5555-4555-8555-555555555555", effectiveDate: "2026-10-18",
        sleepMinutes: null, feedCount: null, diaperCount: null,
      }], measurements: memberGrowthEdit.measurements,
    } });
    assert.equal(disabledGoals.status, 200);
    assert.equal(disabledGoals.payload.state.goalVersions.at(-1).sleepMinutes, null);
  });
});

test("baby care rejects malformed dates, duplicate IDs, unbounded values and incomplete measurements", async () => {
  await withRouteDatabase(async ({ client, request }) => {
    const household = await createHousehold(request, client, "A");
    const invalid = [
      { ...payload, timeZoneID: "Not/AZone" },
      { ...payload, goalVersions: [{ ...goal, effectiveDate: "2026-02-30" }] },
      { ...payload, goalVersions: [goal, { ...goal, effectiveDate: "2026-10-18" }] },
      { ...payload, goalVersions: [goal, { ...goal, id: "33333333-3333-4333-8333-333333333333" }] },
      { ...payload, measurements: [{ ...measurement, weightGrams: null, heightMillimeters: null }] },
      { ...payload, measurements: [{ ...measurement, weightGrams: 200001 }] },
      { ...payload, measurements: [{ ...measurement, measuredAt: Date.now() + 60_000 }] },
      { ...payload, measurements: [measurement, { ...measurement, measuredAt: measurement.measuredAt + 1 }] },
    ];
    for (const body of invalid) {
      const response = await request("/api/nido/baby-care", { method: "PUT", token: household.token, body });
      assert.equal(response.status, 400, JSON.stringify(body));
    }
  });
});

test("stale caregiver growth writes conflict with owner goal edits and rebase cleanly", async () => {
  await withRouteDatabase(async ({ client, request }) => {
    const owner = await createHousehold(request, client, "A");
    const [{ household_id: householdID }] = (await client.query("SELECT household_id FROM caregivers WHERE user_id = $1", [owner.userID])).rows;
    const memberToken = await addMember(client, householdID);
    const created = await request("/api/nido/baby-care", { method: "PUT", token: owner.token, body: payload });
    assert.equal(created.status, 200);

    const ownerUpdate = await request("/api/nido/baby-care", { method: "PUT", token: owner.token, body: {
      expectedRevision: 1, timeZoneID: payload.timeZoneID,
      goalVersions: [...payload.goalVersions, {
        id: "66666666-6666-4666-8666-666666666666", effectiveDate: "2026-10-18",
        sleepMinutes: 610, feedCount: 8, diaperCount: 6,
      }], measurements: payload.measurements,
    } });
    assert.equal(ownerUpdate.status, 200);

    const editedMeasurement = { ...measurement, weightGrams: 4300 };
    const stale = await request("/api/nido/baby-care", { method: "PUT", token: memberToken, body: {
      expectedRevision: 1, timeZoneID: payload.timeZoneID,
      goalVersions: payload.goalVersions, measurements: [editedMeasurement],
    } });
    assert.equal(stale.status, 409);
    assert.equal(stale.payload.state.revision, 2);
    assert.equal(stale.payload.state.measurements[0].weightGrams, measurement.weightGrams);

    const rebased = await request("/api/nido/baby-care", { method: "PUT", token: memberToken, body: {
      expectedRevision: 2, timeZoneID: payload.timeZoneID,
      goalVersions: ownerUpdate.payload.state.goalVersions, measurements: [editedMeasurement],
    } });
    assert.equal(rebased.status, 200);
    assert.equal(rebased.payload.state.revision, 3);
    assert.equal(rebased.payload.state.goalVersions.length, 2);
    assert.equal(rebased.payload.state.measurements[0].weightGrams, editedMeasurement.weightGrams);
  });
});
