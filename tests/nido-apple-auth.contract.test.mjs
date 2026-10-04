import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import test from "node:test";

import { seedSession, withRouteDatabase } from "./support/nido-route-harness.mjs";

test("Apple challenge is stateless and ignores client-controlled source headers", async () => {
  await withRouteDatabase(async ({ client, request }) => {
    const responses = await Promise.all(Array.from({ length: 12 }, (_, index) => request(
      "/api/nido/auth/apple/challenge",
      { method: "POST", headers: { "cf-connecting-ip": index < 11 ? "192.0.2.10" : "198.51.100.99" } },
    )));
    assert.deepEqual(responses.map(value => value.status), Array(12).fill(201));
    assert.match(responses[0].payload.challengeID, /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/);
    assert.match(responses[0].payload.nonce, /^[A-Za-z0-9_-]{32,}$/);
    assert.ok(Date.parse(responses[0].payload.expiresAt) > Date.now());
    assert.doesNotMatch(JSON.stringify(responses[0].payload), /192\.0\.2\.10|198\.51\.100\.99/);
    const result = await client.query(`SELECT
      (SELECT COUNT(*)::int FROM auth_challenges) AS challenges,
      (SELECT COUNT(*)::int FROM auth_rate_limits) AS rate_limits`);
    assert.deepEqual(result.rows, [{ challenges: 0, rate_limits: 0 }]);
  });
});

test("JSON routes reject oversized and invalid bodies before persistence", async () => {
  await withRouteDatabase(async ({ client, request }) => {
    const owner = await seedSession(client);
    const oversized = "x".repeat(30_000);
    const oversizedResponses = await Promise.all([
      request("/api/nido/caregivers/bootstrap", {
        method: "POST", token: owner.token,
        body: { name: oversized, babyName: "Baby", birthDate: "2026-01-01" },
      }),
      request("/api/nido/caregivers/join", { method: "POST", token: owner.token, body: { code: oversized } }),
      request("/api/nido/auth/apple/session", {
        method: "POST", body: { challengeID: "challenge", identityToken: oversized },
      }),
    ]);
    assert.deepEqual(oversizedResponses.map(value => value.status), [413, 413, 413]);

    assert.equal((await request("/api/nido/caregivers/bootstrap", {
      method: "POST", token: owner.token,
      body: { name: "Owner", babyName: "Baby", birthDate: "2026-01-01" },
    })).status, 201);
    const invalid = await Promise.all([
      request("/api/nido/profile", {
        method: "PUT", token: owner.token,
        body: { caregiverName: "Owner", babyName: "Baby", birthDate: "2026-02-30" },
      }),
      request("/api/nido/entries", {
        method: "POST", token: owner.token,
        body: { id: "bad-title", kind: "health", title: 42, detail: "", occurredAt: Date.now() },
      }),
      request("/api/nido/entries", {
        method: "POST", token: owner.token,
        body: { id: "bad-duration", kind: "sleep", title: "Sleep", detail: "", occurredAt: Date.now(), durationMinutes: -1 },
      }),
    ]);
    assert.deepEqual(invalid.map(value => value.status), [400, 400, 400]);
    assert.equal((await client.query("SELECT COUNT(*)::int AS count FROM entries")).rows[0].count, 0);
  });
});

test("PostgreSQL rejects a session tied to an unconsumed challenge and challenge replay", async () => {
  await withRouteDatabase(async ({ client }) => {
    const now = new Date();
    await client.query("INSERT INTO users (id, apple_subject) VALUES ('schema-user', 'schema-subject')");
    await client.query(
      `INSERT INTO auth_challenges (id, nonce_hash, expires_at, created_at)
       VALUES ('unconsumed', $1, $2, $3)`,
      ["a".repeat(64), new Date(now.getTime() + 300_000), now],
    );
    await assert.rejects(
      client.query(
        `INSERT INTO auth_sessions (id, user_id, challenge_id, token_hash, expires_at, created_at)
         VALUES ('forbidden', 'schema-user', 'unconsumed', $1, $2, $3)`,
        ["b".repeat(64), new Date(now.getTime() + 86_400_000), now],
      ),
      error => /invalid auth challenge consumption/i.test(error.cause?.message ?? error.message),
    );

    const session = await seedSession(client);
    await assert.rejects(client.query(
      `INSERT INTO auth_sessions (id, user_id, challenge_id, token_hash, expires_at, created_at)
       SELECT 'replay', user_id, challenge_id, $1, expires_at, created_at
       FROM auth_sessions WHERE user_id = $2`,
      [createHash("sha256").update(`${session.token}-replay`).digest("hex"), session.userID],
    ));
    assert.equal((await client.query(
      "SELECT COUNT(*)::int AS count FROM auth_sessions WHERE user_id = $1",
      [session.userID],
    )).rows[0].count, 1);
  });
});

test("authentication routes fail closed and legacy unauthenticated membership is unavailable", async () => {
  await withRouteDatabase(async ({ request }) => {
    const bootstrap = await request("/api/nido/caregivers/bootstrap", {
      method: "POST", body: { name: "Owner", babyName: "Baby", birthDate: "2026-01-01" },
    });
    const join = await request("/api/nido/caregivers/join", { method: "POST", body: { code: "unknown" } });
    assert.deepEqual([bootstrap.status, join.status], [401, 401]);
    assert.equal("accessToken" in bootstrap.payload, false);
    assert.equal("accessToken" in join.payload, false);

    const audience = process.env.NIDO_APPLE_AUDIENCE;
    const secret = process.env.NIDO_AUTH_BUCKET_SECRET;
    delete process.env.NIDO_APPLE_AUDIENCE;
    delete process.env.NIDO_AUTH_BUCKET_SECRET;
    try {
      assert.equal((await request("/api/nido/auth/apple/challenge", { method: "POST" })).status, 503);
    } finally {
      process.env.NIDO_APPLE_AUDIENCE = audience;
      process.env.NIDO_AUTH_BUCKET_SECRET = secret;
    }
  });
});

test("logout revokes only the current session", async () => {
  await withRouteDatabase(async ({ client, request }) => {
    const session = await seedSession(client);
    const bootstrap = await request("/api/nido/caregivers/bootstrap", {
      method: "POST", token: session.token,
      body: { name: "Owner", babyName: "Baby", birthDate: "2026-01-01" },
    });
    assert.equal(bootstrap.status, 201);
    assert.equal("token" in bootstrap.payload || "accessToken" in bootstrap.payload, false);
    assert.equal((await request("/api/nido", { token: session.token })).status, 200);
    assert.equal((await request("/api/nido/auth/logout", { method: "POST", token: session.token })).status, 200);
    assert.equal((await request("/api/nido", { token: session.token })).status, 401);
  });
});

test("owner deletion cascades the household and every related identity", async () => {
  await withRouteDatabase(async ({ client, request }) => {
    const owner = await seedSession(client);
    assert.equal((await request("/api/nido/caregivers/bootstrap", {
      method: "POST", token: owner.token,
      body: { name: "Owner", babyName: "Baby", birthDate: "2026-01-01" },
    })).status, 201);
    const invitation = await request("/api/nido/caregivers/invite", {
      method: "POST", token: owner.token, body: { name: "Member" },
    });
    const code = invitation.payload.invitation.code;
    const stored = (await client.query("SELECT code_hash FROM invitations")).rows[0].code_hash;
    assert.equal(stored, createHash("sha256").update(code.replaceAll("-", "")).digest("hex"));
    assert.notEqual(stored, code);
    const member = await seedSession(client);
    assert.equal((await request("/api/nido/caregivers/join", {
      method: "POST", token: member.token, body: { code },
    })).status, 200);
    assert.equal((await request("/api/nido/auth/account", { method: "DELETE", token: owner.token })).status, 200);
    const state = await client.query(`SELECT
      (SELECT COUNT(*)::int FROM households) AS households,
      (SELECT COUNT(*)::int FROM caregivers) AS caregivers,
      (SELECT COUNT(*)::int FROM invitations) AS invitations,
      (SELECT COUNT(*)::int FROM users) AS users,
      (SELECT COUNT(*)::int FROM auth_sessions) AS sessions`);
    assert.deepEqual(state.rows, [{ households: 0, caregivers: 0, invitations: 0, users: 0, sessions: 0 }]);
  });
});

test("member deletion preserves the household and owner", async () => {
  await withRouteDatabase(async ({ client, request }) => {
    const owner = await seedSession(client);
    await request("/api/nido/caregivers/bootstrap", {
      method: "POST", token: owner.token,
      body: { name: "Owner", babyName: "Baby", birthDate: "2026-01-01" },
    });
    const invitation = await request("/api/nido/caregivers/invite", {
      method: "POST", token: owner.token, body: { name: "Member" },
    });
    const member = await seedSession(client);
    assert.equal((await request("/api/nido/caregivers/join", {
      method: "POST", token: member.token, body: { code: invitation.payload.invitation.code },
    })).status, 200);
    assert.equal((await request("/api/nido/auth/account", { method: "DELETE", token: member.token })).status, 200);
    assert.equal((await request("/api/nido", { token: member.token })).status, 401);
    assert.equal((await request("/api/nido", { token: owner.token })).status, 200);
    const state = await client.query(`SELECT
      (SELECT COUNT(*)::int FROM households) AS households,
      (SELECT COUNT(*)::int FROM caregivers) AS caregivers,
      (SELECT COUNT(*)::int FROM users) AS users,
      (SELECT COUNT(*)::int FROM auth_sessions) AS sessions`);
    assert.deepEqual(state.rows, [{ households: 1, caregivers: 1, users: 1, sessions: 1 }]);
  });
});
