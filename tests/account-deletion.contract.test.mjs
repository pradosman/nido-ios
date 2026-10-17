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

test("caregiver account deletion removes only that member's entry attribution and preserves care entries", async () => {
  const { client, close } = await createTestDatabase();
  try {
    await client.query("INSERT INTO households (id) VALUES ('attribution-household'), ('unrelated-attribution-household')");
    const owner = await addUser(client, {
      id: "attribution-owner", householdId: "attribution-household", role: "owner",
    });
    const member = await addUser(client, {
      id: "attribution-member", householdId: "attribution-household",
    });
    const unrelated = await addUser(client, {
      id: "unrelated-attribution-author", householdId: "unrelated-attribution-household",
    });
    await client.query(
      "INSERT INTO entries (id, household_id, kind, title, occurred_at) VALUES ('member-entry', 'attribution-household', 'sleep', 'Sleep', 1), ('owner-entry', 'attribution-household', 'feed', 'Feed', 2), ('unrelated-entry', 'unrelated-attribution-household', 'health', 'Checkup', 3)",
    );
    await client.query(
      "INSERT INTO entry_authors (entry_id, household_id, caregiver_id, caregiver_name) VALUES ('member-entry', 'attribution-household', 'attribution-member', 'Attribution Member'), ('owner-entry', 'attribution-household', 'attribution-owner', 'Attribution Owner'), ('unrelated-entry', 'unrelated-attribution-household', 'unrelated-attribution-author', 'Unrelated Author')",
    );

    assert.deepEqual(await deleteAccount(member.token), { status: 200, payload: { deleted: true } });
    assert.equal(await rowCount(client, "entries", "household_id", "attribution-household"), 2);
    assert.equal(await rowCount(client, "entry_authors", "caregiver_id", "attribution-member"), 0);
    assert.equal(await rowCount(client, "entry_authors", "caregiver_id", "attribution-owner"), 1);
    assert.equal(await rowCount(client, "entry_authors", "caregiver_id", "unrelated-attribution-author"), 1);
    assert.equal(await rowCount(client, "entries", "household_id", "unrelated-attribution-household"), 1);
    assert.equal(await rowCount(client, "users", "id", owner.userId), 1);
    assert.equal(await rowCount(client, "users", "id", unrelated.userId), 1);
  } finally {
    await close();
  }
});

test("deleting an account for a removed membership clears its stale entry attribution", async () => {
  const { client, close } = await createTestDatabase();
  try {
    await client.query("INSERT INTO households (id) VALUES ('removed-attribution-household')");
    const removedMember = await addUser(client, {
      id: "removed-attribution-member", householdId: "removed-attribution-household", status: "removed",
    });
    await client.query(
      "INSERT INTO entries (id, household_id, kind, title, occurred_at) VALUES ('removed-member-entry', 'removed-attribution-household', 'diaper', 'Diaper', 1)",
    );
    await client.query(
      "INSERT INTO entry_authors (entry_id, household_id, caregiver_id, caregiver_name) VALUES ('removed-member-entry', 'removed-attribution-household', 'removed-attribution-member', 'Removed Member')",
    );

    assert.deepEqual(await deleteAccount(removedMember.token), { status: 200, payload: { deleted: true } });
    assert.equal(await rowCount(client, "entries", "household_id", "removed-attribution-household"), 1);
    assert.equal(await rowCount(client, "entry_authors", "caregiver_id", "removed-attribution-member"), 0);
  } finally {
    await close();
  }
});

test("owner account deletion still removes its household and member sessions", async () => {
  const { client, close } = await createTestDatabase();
  try {
    await client.query("INSERT INTO households (id) VALUES ('owner-delete-household'), ('unrelated-owner-household')");
    const owner = await addUser(client, {
      id: "owner-delete-owner", householdId: "owner-delete-household", role: "owner",
    });
    const member = await addUser(client, {
      id: "owner-delete-caregiver", householdId: "owner-delete-household",
    });
    const unrelated = await addUser(client, {
      id: "unrelated-owner-caregiver", householdId: "unrelated-owner-household",
    });
    await client.query(
      "INSERT INTO profiles (household_id, caregiver_name, baby_name, birth_date) VALUES ('owner-delete-household', 'Owner', 'Baby', '2025-01-01'), ('unrelated-owner-household', 'Other', 'Other Baby', '2025-02-01')",
    );
    await client.query(
      "INSERT INTO entries (id, household_id, kind, title, occurred_at) VALUES ('owner-delete-entry', 'owner-delete-household', 'sleep', 'Sleep', 1), ('unrelated-owner-entry', 'unrelated-owner-household', 'feed', 'Feed', 2)",
    );
    await client.query(
      "INSERT INTO entry_authors (entry_id, household_id, caregiver_id, caregiver_name) VALUES ('owner-delete-entry', 'owner-delete-household', 'owner-delete-caregiver', 'Caregiver'), ('unrelated-owner-entry', 'unrelated-owner-household', 'unrelated-owner-caregiver', 'Unrelated')",
    );
    await client.query(
      "INSERT INTO invitations (id, caregiver_id, code_hash, expires_at) VALUES ('owner-delete-invitation', 'owner-delete-caregiver', 'owner-delete-hash', now() + interval '1 day'), ('unrelated-owner-invitation', 'unrelated-owner-caregiver', 'unrelated-owner-hash', now() + interval '1 day')",
    );
    await client.query(
      "INSERT INTO invitation_claims (invitation_id, user_id) VALUES ('owner-delete-invitation', $1), ('unrelated-owner-invitation', $2)",
      [member.userId, unrelated.userId],
    );
    await client.query(
      "INSERT INTO baby_care_states (household_id, revision, time_zone_id) VALUES ('owner-delete-household', 1, 'Europe/Madrid'), ('unrelated-owner-household', 1, 'Europe/Madrid')",
    );

    assert.deepEqual(await deleteAccount(owner.token), { status: 200, payload: { deleted: true } });
    assert.equal(await rowCount(client, "households", "id", "owner-delete-household"), 0);
    assert.equal(await rowCount(client, "profiles", "household_id", "owner-delete-household"), 0);
    assert.equal(await rowCount(client, "entries", "household_id", "owner-delete-household"), 0);
    assert.equal(await rowCount(client, "entry_authors", "household_id", "owner-delete-household"), 0);
    assert.equal(await rowCount(client, "invitations", "id", "owner-delete-invitation"), 0);
    assert.equal(await rowCount(client, "invitation_claims", "invitation_id", "owner-delete-invitation"), 0);
    assert.equal(await rowCount(client, "baby_care_states", "household_id", "owner-delete-household"), 0);
    assert.equal(await rowCount(client, "users", "id", owner.userId), 0);
    assert.equal(await rowCount(client, "auth_sessions", "user_id", owner.userId), 0);
    assert.equal(await rowCount(client, "users", "id", member.userId), 0);
    assert.equal(await rowCount(client, "auth_sessions", "user_id", member.userId), 0);
    assert.equal(await rowCount(client, "households", "id", "unrelated-owner-household"), 1);
    assert.equal(await rowCount(client, "profiles", "household_id", "unrelated-owner-household"), 1);
    assert.equal(await rowCount(client, "entries", "household_id", "unrelated-owner-household"), 1);
    assert.equal(await rowCount(client, "entry_authors", "household_id", "unrelated-owner-household"), 1);
    assert.equal(await rowCount(client, "invitations", "id", "unrelated-owner-invitation"), 1);
    assert.equal(await rowCount(client, "invitation_claims", "invitation_id", "unrelated-owner-invitation"), 1);
    assert.equal(await rowCount(client, "baby_care_states", "household_id", "unrelated-owner-household"), 1);
    assert.equal(await rowCount(client, "users", "id", unrelated.userId), 1);
    assert.equal(await rowCount(client, "auth_sessions", "user_id", unrelated.userId), 1);
  } finally {
    await close();
  }
});
