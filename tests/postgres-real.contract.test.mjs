import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { after, beforeEach, test } from "node:test";

import postgres from "postgres";

const databaseURL = process.env.NIDO_REAL_POSTGRES_URL;
const realTest = databaseURL ? test : test.skip;
if (databaseURL) process.env.DATABASE_URL = databaseURL;
process.env.NIDO_APPLE_AUDIENCE = "com.example.Nido";
process.env.NIDO_AUTH_BUCKET_SECRET = "real-postgres-contract-secret-32-bytes";

const client = databaseURL ? postgres(databaseURL, { max: 12, prepare: false }) : null;
let nextIdentity = 1;

const routeModules = databaseURL ? await Promise.all([
  import("../app/api/nido/caregivers/bootstrap/route.ts"),
  import("../app/api/nido/caregivers/invite/route.ts"),
  import("../app/api/nido/caregivers/join/route.ts"),
  import("../app/api/nido/status/route.ts"),
]) : [];

const routes = new Map(databaseURL ? [
  ["/api/nido/caregivers/bootstrap", routeModules[0]],
  ["/api/nido/caregivers/invite", routeModules[1]],
  ["/api/nido/caregivers/join", routeModules[2]],
  ["/api/nido/status", routeModules[3]],
] : []);

beforeEach(async () => {
  if (!client) return;
  await client.unsafe(`TRUNCATE TABLE
    invitation_claims, invitations, entry_authors, entries, profiles, caregivers,
    auth_sessions, auth_challenges, auth_rate_limits, households, users
    RESTART IDENTITY CASCADE`);
});

after(async () => {
  if (client) await client.end();
});

async function request(pathname, { method = "GET", token, body } = {}) {
  const url = new URL(pathname, "http://nido.test");
  const handler = routes.get(url.pathname)?.[method];
  assert.equal(typeof handler, "function", `missing ${method} handler for ${url.pathname}`);
  const response = await handler(new Request(url, {
    method,
    headers: {
      accept: "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(body === undefined ? {} : { "content-type": "application/json" }),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  }));
  const text = await response.text();
  return { status: response.status, payload: text ? JSON.parse(text) : null };
}

async function seedSession() {
  const identity = nextIdentity++;
  const token = `real-postgres-session-${identity}-${"x".repeat(32)}`;
  const now = new Date();
  const userID = `real-user-${identity}`;
  const challengeID = `real-challenge-${identity}`;
  await client.begin(async sql => {
    await sql`INSERT INTO users (id, apple_subject) VALUES (${userID}, ${`real-subject-${identity}`})`;
    await sql`INSERT INTO auth_challenges (id, nonce_hash, expires_at, consumed_at, created_at)
      VALUES (${challengeID}, ${"a".repeat(64)}, ${new Date(now.getTime() + 300_000)}, ${now}, ${now})`;
    await sql`INSERT INTO auth_sessions (id, user_id, challenge_id, token_hash, expires_at, created_at)
      VALUES (${`real-session-${identity}`}, ${userID}, ${challengeID},
        ${createHash("sha256").update(token).digest("hex")}, ${new Date(now.getTime() + 86_400_000)}, ${now})`;
  });
  return { token, userID };
}

realTest("rate limiting encodes timestamps through the real PostgreSQL driver", async () => {
  const { consumeRateLimit } = await import("../app/api/nido/rate-limit.ts");
  assert.equal(await consumeRateLimit("real-driver", new Date(), 60_000, 2), true);
  assert.equal(await consumeRateLimit("real-driver", new Date(), 60_000, 2), true);
});

realTest("Apple exchange succeeds once and rejects challenge replay on real PostgreSQL", async () => {
  const [{ createOpaqueAppleChallenge }, { createAppleSessionHandler }, route] = await Promise.all([
    import("../app/api/nido/apple-challenge.ts"),
    import("../app/api/nido/apple-session-handler.ts"),
    import("../app/api/nido/auth/apple/session/route.ts"),
  ]);
  assert.equal(typeof route.createProductionAppleSessionStore, "function");
  const secret = process.env.NIDO_AUTH_BUCKET_SECRET;
  const challenge = await createOpaqueAppleChallenge(secret);
  const handler = createAppleSessionHandler({
    challengeSecret: secret,
    verifyIdentity: async () => ({ subject: "real-apple-subject" }),
    store: route.createProductionAppleSessionStore(secret),
  });
  const exchange = () => handler(new Request("http://nido.test/api/nido/auth/apple/session", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ challengeID: challenge.challengeID, identityToken: "locally-verified-token" }),
  }));
  assert.equal((await exchange()).status, 201);
  assert.equal((await exchange()).status, 401);
  assert.equal((await client`SELECT COUNT(*)::int AS count FROM auth_sessions`)[0].count, 1);
});

realTest("concurrent same-user bootstrap returns 201 and 409 with one complete household", async () => {
  const session = await seedSession();
  await client.unsafe(`
    CREATE OR REPLACE FUNCTION delay_owner_insert() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      IF NEW.role = 'owner' THEN PERFORM pg_sleep(0.2); END IF;
      RETURN NEW;
    END $$;
    DROP TRIGGER IF EXISTS delay_owner_insert ON caregivers;
    CREATE TRIGGER delay_owner_insert BEFORE INSERT ON caregivers
      FOR EACH ROW EXECUTE FUNCTION delay_owner_insert();
  `);
  const body = { name: "Race Owner", babyName: "Race Baby", birthDate: "2026-01-01" };
  const results = await Promise.all([
    request("/api/nido/caregivers/bootstrap", { method: "POST", token: session.token, body }),
    request("/api/nido/caregivers/bootstrap", { method: "POST", token: session.token, body }),
  ]);
  assert.deepEqual(results.map(result => result.status).sort(), [201, 409]);
  const [counts] = await client`SELECT
    (SELECT COUNT(*)::int FROM households) AS households,
    (SELECT COUNT(*)::int FROM caregivers) AS caregivers,
    (SELECT COUNT(*)::int FROM profiles) AS profiles`;
  assert.deepEqual(counts, { households: 1, caregivers: 1, profiles: 1 });
});

realTest("invitation join succeeds once and rejects replay on real PostgreSQL", async () => {
  const owner = await seedSession();
  assert.equal((await request("/api/nido/caregivers/bootstrap", {
    method: "POST", token: owner.token,
    body: { name: "Owner", babyName: "Baby", birthDate: "2026-01-01" },
  })).status, 201);
  const invitation = await request("/api/nido/caregivers/invite", {
    method: "POST", token: owner.token, body: { name: "Member" },
  });
  const first = await seedSession();
  const second = await seedSession();
  assert.equal((await request("/api/nido/caregivers/join", {
    method: "POST", token: first.token, body: { code: invitation.payload.invitation.code },
  })).status, 200);
  assert.equal((await request("/api/nido/caregivers/join", {
    method: "POST", token: second.token, body: { code: invitation.payload.invitation.code },
  })).status, 404);
  assert.equal((await client`SELECT COUNT(*)::int AS count FROM invitation_claims`)[0].count, 1);
});

realTest("health endpoint verifies real PostgreSQL availability", async () => {
  const result = await request("/api/nido/status");
  assert.equal(result.status, 200);
  assert.deepEqual(result.payload, { canCreateHousehold: true, canJoinWithInvitation: true });
});
