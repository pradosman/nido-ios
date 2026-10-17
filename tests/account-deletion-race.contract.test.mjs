import assert from "node:assert/strict";
import test from "node:test";

import { hashAccessToken } from "../app/api/nido/auth.ts";
import { POST as createEntry } from "../app/api/nido/entries/route.ts";
import { routeRequest, withRouteDatabase } from "./support/nido-route-harness.mjs";
import { appleDeletionProof } from "./support/apple-deletion-proof.mjs";

test("a delayed entry POST cannot restore attribution after account deletion", async () => {
  await withRouteDatabase(async ({ client }) => {
    const token = `delayed-member-token-${"x".repeat(40)}`;
    const userID = "delayed-member-user";
    const caregiverID = "delayed-member-caregiver";
    const householdID = "delayed-member-household";
    const subject = "delayed-member-apple-subject";
    const now = new Date();
    await client.query("INSERT INTO households (id) VALUES ($1)", [householdID]);
    await client.query("INSERT INTO users (id, apple_subject) VALUES ($1, $2)", [userID, subject]);
    await client.query(
      "INSERT INTO caregivers (id, household_id, user_id, name, role, status, joined_at) VALUES ($1, $2, $3, $4, 'caregiver', 'active', $5)",
      [caregiverID, householdID, userID, "Member to delete", now],
    );
    await client.query(
      "INSERT INTO auth_sessions (id, user_id, token_hash, expires_at) VALUES ($1, $2, $3, $4)",
      ["delayed-member-session", userID, await hashAccessToken(token), new Date(now.getTime() + 86_400_000)],
    );
    const delayedBody = JSON.stringify({
      id: "delayed-after-account-delete",
      kind: "feed",
      title: "Late feed",
      detail: "Should not retain deleted author",
      occurredAt: 1_800_000_000_000,
      durationMinutes: null,
      amountMl: 90,
    });

    let bodyReadStarted;
    const bodyReadStartedPromise = new Promise(resolve => { bodyReadStarted = resolve; });
    let releaseBody;
    const bodyGate = new Promise(resolve => { releaseBody = resolve; });
    let bodySent = false;
    const body = new ReadableStream({
      async pull(controller) {
        if (bodySent) return;
        bodySent = true;
        bodyReadStarted();
        await bodyGate;
        controller.enqueue(new TextEncoder().encode(delayedBody));
        controller.close();
      },
    });
    const pendingPost = createEntry(new Request("http://nido.test/api/nido/entries", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${token}`,
      },
      body,
      duplex: "half",
    }));

    try {
      // Body reading starts only after requireCaregiver has cached the session and caregiver.
      const bodyReadBegan = await Promise.race([
        bodyReadStartedPromise.then(() => true),
        new Promise(resolve => setTimeout(() => resolve(false), 10_000)),
      ]);
      if (!bodyReadBegan) {
        releaseBody();
        const unexpectedResponse = await pendingPost;
        assert.fail(`POST exited before reading its body: ${unexpectedResponse.status} ${await unexpectedResponse.text()}`);
      }
      const deletion = await routeRequest("/api/nido/auth/account", {
        method: "DELETE",
        token,
        body: await appleDeletionProof(subject),
      });
      assert.deepEqual({ status: deletion.status, payload: deletion.payload }, {
        status: 200,
        payload: { deleted: true },
      });
    } finally {
      releaseBody();
    }

    const postResponse = await pendingPost;
    const postPayload = await postResponse.json();
    const staleAuthors = await client.query(
      "SELECT caregiver_id, caregiver_name FROM entry_authors WHERE entry_id = $1",
      ["delayed-after-account-delete"],
    );
    assert.equal(postResponse.status, 401, JSON.stringify({ postPayload, authors: staleAuthors.rows }));
    assert.deepEqual(staleAuthors.rows, []);
  });
});
