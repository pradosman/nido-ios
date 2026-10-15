import { createHash } from "node:crypto";

import { createTestDatabase } from "../../db/testing.ts";
import { accountDeletionHandler } from "./apple-deletion-proof.mjs";
import * as challengeRoute from "../../app/api/nido/auth/apple/challenge/route.ts";
import * as sessionRoute from "../../app/api/nido/auth/apple/session/route.ts";
import * as logoutRoute from "../../app/api/nido/auth/logout/route.ts";
import * as bootstrapRoute from "../../app/api/nido/caregivers/bootstrap/route.ts";
import * as inviteRoute from "../../app/api/nido/caregivers/invite/route.ts";
import * as joinRoute from "../../app/api/nido/caregivers/join/route.ts";
import * as entriesRoute from "../../app/api/nido/entries/route.ts";
import * as nidoRoute from "../../app/api/nido/route.ts";
import * as profileRoute from "../../app/api/nido/profile/route.ts";
import * as statusRoute from "../../app/api/nido/status/route.ts";

const routes = new Map([
  ["/api/nido", nidoRoute],
  ["/api/nido/auth/account", { DELETE: accountDeletionHandler }],
  ["/api/nido/auth/apple/challenge", challengeRoute],
  ["/api/nido/auth/apple/session", sessionRoute],
  ["/api/nido/auth/logout", logoutRoute],
  ["/api/nido/caregivers/bootstrap", bootstrapRoute],
  ["/api/nido/caregivers/invite", inviteRoute],
  ["/api/nido/caregivers/join", joinRoute],
  ["/api/nido/entries", entriesRoute],
  ["/api/nido/profile", profileRoute],
  ["/api/nido/status", statusRoute],
]);

let nextIdentity = 1;

export async function withRouteDatabase(run) {
  const database = await createTestDatabase();
  const previousEnvironment = {
    audience: process.env.NIDO_APPLE_AUDIENCE,
    secret: process.env.NIDO_AUTH_BUCKET_SECRET,
  };
  process.env.NIDO_APPLE_AUDIENCE = "com.example.Nido";
  process.env.NIDO_AUTH_BUCKET_SECRET = "test-only-source-bucket-secret-32-bytes";
  try {
    await run({ ...database, request: routeRequest });
  } finally {
    if (previousEnvironment.audience === undefined) delete process.env.NIDO_APPLE_AUDIENCE;
    else process.env.NIDO_APPLE_AUDIENCE = previousEnvironment.audience;
    if (previousEnvironment.secret === undefined) delete process.env.NIDO_AUTH_BUCKET_SECRET;
    else process.env.NIDO_AUTH_BUCKET_SECRET = previousEnvironment.secret;
    await database.close();
  }
}

export async function routeRequest(pathname, { method = "GET", token, body, headers = {} } = {}) {
  const url = new URL(pathname, "http://nido.test");
  const route = routes.get(url.pathname);
  const handler = route?.[method];
  if (!handler) return { status: 404, payload: null, response: new Response(null, { status: 404 }) };
  const request = new Request(url, {
    method,
    headers: {
      accept: "application/json",
      ...(body === undefined ? {} : { "content-type": "application/json" }),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...headers,
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const response = await handler(request);
  const text = await response.text();
  let payload = null;
  if (text) {
    try { payload = JSON.parse(text); }
    catch { payload = { raw: text }; }
  }
  return { status: response.status, payload, response };
}

export async function seedSession(client) {
  const identity = nextIdentity++;
  const token = `test-session-${identity}-${"x".repeat(40)}`;
  const tokenHash = createHash("sha256").update(token).digest("hex");
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 86_400_000);
  const challengeExpiresAt = new Date(now.getTime() + 300_000);
  const userID = `test-user-${identity}`;
  const challengeID = `test-challenge-${identity}`;
  await client.query(
    "INSERT INTO users (id, apple_subject) VALUES ($1, $2)",
    [userID, `test-apple-subject-${identity}`],
  );
  await client.query(
    `INSERT INTO auth_challenges (id, nonce_hash, expires_at, consumed_at, created_at)
     VALUES ($1, $2, $3, $4, $4)`,
    [challengeID, "a".repeat(64), challengeExpiresAt, now],
  );
  await client.query(
    `INSERT INTO auth_sessions (id, user_id, challenge_id, token_hash, expires_at, created_at)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [`test-session-${identity}`, userID, challengeID, tokenHash, expiresAt, now],
  );
  return { token, userID, challengeID };
}

export async function createHousehold(request, client, suffix) {
  const session = await seedSession(client);
  const profile = {
    caregiverName: `Owner ${suffix}`,
    babyName: `Baby ${suffix}`,
    birthDate: suffix === "A" ? "2026-01-01" : "2026-02-02",
  };
  const bootstrap = await request("/api/nido/caregivers/bootstrap", {
    method: "POST",
    token: session.token,
    body: { name: profile.caregiverName, babyName: profile.babyName, birthDate: profile.birthDate },
  });
  if (bootstrap.status !== 201) throw new Error(`Household bootstrap failed: ${JSON.stringify(bootstrap.payload)}`);
  return { ...session, profile, caregiver: bootstrap.payload.caregiver };
}

export function entry(id, suffix) {
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
