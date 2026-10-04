import assert from "node:assert/strict";
import test from "node:test";
import { createHash } from "node:crypto";

import {
  createHousehold,
  entry,
  seedSession,
  withRouteDatabase,
} from "./support/nido-route-harness.mjs";

test("owner and caregiver permissions preserve shared history within one household", async () => {
  await withRouteDatabase(async ({ client, request }) => {
    const familyA = await createHousehold(request, client, "A");
    const familyB = await createHousehold(request, client, "B");
    const invitation = await request("/api/nido/caregivers/invite", {
      method: "POST", token: familyA.token, body: { name: "Active A" },
    });
    const member = await seedSession(client);
    const joined = await request("/api/nido/caregivers/join", {
      method: "POST", token: member.token, body: { code: invitation.payload.invitation.code },
    });
    assert.equal(joined.status, 200);

    const forbidden = await Promise.all([
      request("/api/nido/profile", {
        method: "PUT", token: member.token,
        body: { caregiverName: "Active A", babyName: "Forbidden", birthDate: "2026-01-01" },
      }),
      request("/api/nido/caregivers/invite", {
        method: "POST", token: member.token, body: { name: "Forbidden" },
      }),
      request(`/api/nido/caregivers/invite?id=${joined.payload.caregiver.id}`, {
        method: "DELETE", token: familyB.token,
      }),
    ]);
    assert.deepEqual(forbidden.map(value => value.status), [403, 403, 404]);

    assert.equal((await request("/api/nido/entries", {
      method: "POST", token: familyA.token, body: entry("shared", "A"),
    })).status, 201);
    assert.equal((await request("/api/nido/entries", {
      method: "PUT", token: member.token, body: { ...entry("shared", "A"), detail: "Corrected" },
    })).status, 200);
    const memberLoad = await request("/api/nido", { token: member.token });
    assert.equal(memberLoad.payload.entries[0].detail, "Corrected");
    assert.equal(memberLoad.payload.profile.babyName, "Baby A");
    assert.ok(memberLoad.payload.caregivers.every(value => value.status === "active"));
    assert.ok(memberLoad.payload.caregivers.every(value => value.inviteCode === null));

    assert.equal((await request("/api/nido/entries", {
      method: "PUT", token: familyB.token, body: { ...entry("shared", "B"), detail: "Cross household" },
    })).status, 404);
    assert.equal((await request("/api/nido/entries?id=shared", {
      method: "DELETE", token: familyB.token,
    })).status, 404);
    assert.deepEqual((await request("/api/nido", { token: familyB.token })).payload.entries, []);
  });
});

test("concurrent bootstrap creates exactly one household for a user", async () => {
  await withRouteDatabase(async ({ client, request }) => {
    const session = await seedSession(client);
    const body = { name: "Race Owner", babyName: "Race Baby", birthDate: "2026-01-01" };
    const results = await Promise.all([
      request("/api/nido/caregivers/bootstrap", { method: "POST", token: session.token, body }),
      request("/api/nido/caregivers/bootstrap", { method: "POST", token: session.token, body }),
    ]);
    assert.deepEqual(results.map(value => value.status).sort(), [201, 409]);
    const counts = await client.query(`SELECT
      (SELECT COUNT(*)::int FROM households) AS households,
      (SELECT COUNT(*)::int FROM caregivers) AS caregivers,
      (SELECT COUNT(*)::int FROM profiles) AS profiles`);
    assert.deepEqual(counts.rows, [{ households: 1, caregivers: 1, profiles: 1 }]);
  });
});

test("an invitation can be claimed only once under concurrent requests", async () => {
  await withRouteDatabase(async ({ client, request }) => {
    const owner = await createHousehold(request, client, "A");
    const invitation = await request("/api/nido/caregivers/invite", {
      method: "POST", token: owner.token, body: { name: "Race Member" },
    });
    const first = await seedSession(client);
    const second = await seedSession(client);
    const results = await Promise.all([
      request("/api/nido/caregivers/join", {
        method: "POST", token: first.token, body: { code: invitation.payload.invitation.code },
      }),
      request("/api/nido/caregivers/join", {
        method: "POST", token: second.token, body: { code: invitation.payload.invitation.code },
      }),
    ]);
    assert.deepEqual(results.map(value => value.status).sort(), [200, 404]);
    const state = await client.query(`SELECT
      (SELECT COUNT(*)::int FROM invitation_claims) AS claims,
      (SELECT COUNT(*)::int FROM caregivers WHERE status = 'active' AND role = 'caregiver') AS active_members,
      (SELECT failed_attempts FROM invitations LIMIT 1) AS failed_attempts`);
    assert.deepEqual(state.rows, [{ claims: 1, active_members: 1, failed_attempts: 1 }]);
  });
});

test("an invitation joins through the iPhone's grouped code representation", async () => {
  await withRouteDatabase(async ({ client, request }) => {
    const owner = await createHousehold(request, client, "A");
    const invitation = await request("/api/nido/caregivers/invite", {
      method: "POST", token: owner.token, body: { name: "iPhone Member" },
    });
    assert.equal(invitation.status, 201);

    const groupedCodePattern = /^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$/;
    const submittedCode = invitation.payload.invitation.code;
    assert.match(submittedCode, groupedCodePattern);
    assert.equal(invitation.payload.caregiver.inviteCode, submittedCode);
    const member = await seedSession(client);
    const joined = await request("/api/nido/caregivers/join", {
      method: "POST", token: member.token, body: { code: submittedCode },
    });

    assert.equal(joined.status, 200);
  });
});

test("a previously issued Base64URL invitation keeps its exact value", async () => {
  await withRouteDatabase(async ({ client, request }) => {
    const owner = await createHousehold(request, client, "A");
    const invitation = await request("/api/nido/caregivers/invite", {
      method: "POST", token: owner.token, body: { name: "Legacy Member" },
    });
    const legacyCode = "aBcdEFgh_IJklMNopQRstU";
    const codeHash = createHash("sha256").update(legacyCode).digest("hex");
    await client.query("UPDATE invitations SET code_hash = $1 WHERE caregiver_id = $2", [
      codeHash,
      invitation.payload.caregiver.id,
    ]);

    const member = await seedSession(client);
    const joined = await request("/api/nido/caregivers/join", {
      method: "POST", token: member.token, body: { code: legacyCode },
    });

    assert.equal(joined.status, 200);
  });
});

test("entry creation is idempotent, authorship is immutable, and ids cannot cross households", async () => {
  await withRouteDatabase(async ({ client, request }) => {
    const familyA = await createHousehold(request, client, "A");
    const familyB = await createHousehold(request, client, "B");
    const original = entry("stable-entry", "A");
    const created = await request("/api/nido/entries", {
      method: "POST", token: familyA.token, body: original,
    });
    assert.equal(created.status, 201);
    assert.equal(created.payload.entry.caregiverID, familyA.caregiver.id);
    assert.equal(created.payload.entry.caregiverName, familyA.profile.caregiverName);

    const retry = await request("/api/nido/entries", {
      method: "POST", token: familyA.token,
      body: { ...original, title: "Unsafe overwrite", detail: "Unsafe overwrite" },
    });
    assert.equal(retry.status, 201);
    assert.equal(retry.payload.entry.title, original.title);
    assert.equal(retry.payload.entry.detail, original.detail);
    assert.equal((await request("/api/nido/entries", {
      method: "POST", token: familyB.token, body: entry("stable-entry", "B"),
    })).status, 409);

    const rows = await client.query(`SELECT e.household_id, a.household_id AS author_household_id,
      a.caregiver_id, a.caregiver_name FROM entries e JOIN entry_authors a ON a.entry_id = e.id
      WHERE e.id = 'stable-entry'`);
    assert.equal(rows.rows.length, 1);
    assert.equal(rows.rows[0].household_id, rows.rows[0].author_household_id);
    assert.equal(rows.rows[0].caregiver_id, familyA.caregiver.id);
  });
});

test("failed entry authorship rolls back the entry transaction", async () => {
  await withRouteDatabase(async ({ client, request }) => {
    const family = await createHousehold(request, client, "A");
    await client.exec(`
      CREATE FUNCTION reject_test_author() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.entry_id = 'reject-author-entry' THEN RAISE EXCEPTION 'sentinel author failure'; END IF;
        RETURN NEW;
      END $$;
      CREATE TRIGGER reject_test_author BEFORE INSERT ON entry_authors
        FOR EACH ROW EXECUTE FUNCTION reject_test_author();
    `);
    const result = await request("/api/nido/entries", {
      method: "POST", token: family.token, body: entry("reject-author-entry", "A"),
    });
    assert.equal(result.status, 500);
    const state = await client.query(`SELECT
      (SELECT COUNT(*)::int FROM entries WHERE id = 'reject-author-entry') AS entries,
      (SELECT COUNT(*)::int FROM entry_authors WHERE entry_id = 'reject-author-entry') AS authors`);
    assert.deepEqual(state.rows, [{ entries: 0, authors: 0 }]);
  });
});

test("status remains public while household data requires a session", async () => {
  await withRouteDatabase(async ({ request }) => {
    const status = await request("/api/nido/status");
    assert.equal(status.status, 200);
    assert.deepEqual(status.payload, { canCreateHousehold: true, canJoinWithInvitation: true });
    const protectedRoute = await request("/api/nido");
    assert.equal(protectedRoute.status, 401);
    assert.deepEqual(protectedRoute.payload, { error: "Authentication is required" });
  });
});
