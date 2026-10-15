import assert from "node:assert/strict";
import test from "node:test";

import { createTestDatabase } from "../db/testing.ts";
import { hashAccessToken } from "../app/api/nido/auth.ts";
import { accountDeletionHandler, appleDeletionProof } from "./support/apple-deletion-proof.mjs";

async function addUser(client, { id, householdId = null, role = "caregiver", status = "active" }) {
  const userId = `${id}-user`;
  const token = `${id}-token-${"x".repeat(40)}`;
  const now = new Date();
  await client.query("INSERT INTO users (id, apple_subject) VALUES ($1, $2)", [userId, `${id}-subject`]);
  if (householdId) {
    await client.query(
      "INSERT INTO caregivers (id, household_id, user_id, name, role, status, joined_at) VALUES ($1, $2, $3, $4, $5, $6, $7)",
      [id, householdId, userId, id, role, status, status === "active" ? now : null],
    );
  }
  await client.query(
    "INSERT INTO auth_sessions (id, user_id, token_hash, expires_at) VALUES ($1, $2, $3, $4)",
    [`${id}-session`, userId, await hashAccessToken(token), new Date(now.getTime() + 60_000)],
  );
  return { userId, token };
}

async function deleteAccount(token) {
  const response = await accountDeletionHandler(new Request("http://nido.test/api/nido/auth/account", {
    method: "DELETE",
    ...(token ? { headers: { authorization: `Bearer ${token}` } } : {}),
    ...(token ? { body: JSON.stringify(await appleDeletionProof(`${token.split("-token-")[0]}-subject`)) } : {}),
  }));
  return { status: response.status, payload: await response.json() };
}

async function rowCount(client, table, column, value) {
  const result = await client.query(`SELECT count(*)::int AS count FROM ${table} WHERE ${column} = $1`, [value]);
  return result.rows[0].count;
}

test("authenticated account without household membership can delete itself and its sessions", async () => {
  const { client, close } = await createTestDatabase();
  try {
    const orphan = await addUser(client, { id: "orphan-account" });
    const other = await addUser(client, { id: "other-account" });

    assert.deepEqual(await deleteAccount(orphan.token), { status: 200, payload: { deleted: true } });
    assert.equal(await rowCount(client, "users", "id", orphan.userId), 0);
    assert.equal(await rowCount(client, "auth_sessions", "user_id", orphan.userId), 0);
    assert.equal(await rowCount(client, "users", "id", other.userId), 1);
    assert.equal(await rowCount(client, "auth_sessions", "user_id", other.userId), 1);
  } finally {
    await close();
  }
});

test("account deletion still requires authentication", async () => {
  const { client, close } = await createTestDatabase();
  try {
    const user = await addUser(client, { id: "unauthenticated-account" });
    assert.deepEqual(await deleteAccount(null), {
      status: 401, payload: { error: "Authentication is required" },
    });
    assert.equal(await rowCount(client, "users", "id", user.userId), 1);
    assert.equal(await rowCount(client, "auth_sessions", "user_id", user.userId), 1);
  } finally {
    await close();
  }
});

test("caregiver account deletion preserves its household and other members", async () => {
  const { client, close } = await createTestDatabase();
  try {
    await client.query("INSERT INTO households (id) VALUES ('member-delete-household')");
    const owner = await addUser(client, {
      id: "member-delete-owner", householdId: "member-delete-household", role: "owner",
    });
    const member = await addUser(client, {
      id: "member-delete-caregiver", householdId: "member-delete-household",
    });

    assert.deepEqual(await deleteAccount(member.token), { status: 200, payload: { deleted: true } });
    assert.equal(await rowCount(client, "households", "id", "member-delete-household"), 1);
    assert.equal(await rowCount(client, "users", "id", owner.userId), 1);
    assert.equal(await rowCount(client, "auth_sessions", "user_id", owner.userId), 1);
    assert.equal(await rowCount(client, "users", "id", member.userId), 0);
    assert.equal(await rowCount(client, "auth_sessions", "user_id", member.userId), 0);
  } finally {
    await close();
  }
});

test("owner account deletion still removes its household and member sessions", async () => {
  const { client, close } = await createTestDatabase();
  try {
    await client.query("INSERT INTO households (id) VALUES ('owner-delete-household')");
    const owner = await addUser(client, {
      id: "owner-delete-owner", householdId: "owner-delete-household", role: "owner",
    });
    const member = await addUser(client, {
      id: "owner-delete-caregiver", householdId: "owner-delete-household",
    });

    assert.deepEqual(await deleteAccount(owner.token), { status: 200, payload: { deleted: true } });
    assert.equal(await rowCount(client, "households", "id", "owner-delete-household"), 0);
    assert.equal(await rowCount(client, "users", "id", owner.userId), 0);
    assert.equal(await rowCount(client, "auth_sessions", "user_id", owner.userId), 0);
    assert.equal(await rowCount(client, "users", "id", member.userId), 0);
    assert.equal(await rowCount(client, "auth_sessions", "user_id", member.userId), 0);
  } finally {
    await close();
  }
});
