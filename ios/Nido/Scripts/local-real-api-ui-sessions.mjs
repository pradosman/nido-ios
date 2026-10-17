import { createHash, randomBytes } from "node:crypto";
import { realpathSync } from "node:fs";
import { chmod, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

const SESSION_NAMES = Object.freeze([
  "ownerA",
  "ownerB",
  "permissionsOwner",
  "permissionsCaregiver",
  "history",
]);

/**
 * Create short-lived synthetic server sessions for a disposable local database.
 * The returned bearer tokens never pass through stdout; callers own their storage.
 */
export async function seedLocalRealAPIUITestSessions(query, runID, now = new Date()) {
  if (typeof query !== "function") throw new TypeError("query must be a SQL query function");
  if (typeof runID !== "string" || !/^[A-Za-z0-9-]{1,80}$/.test(runID)) {
    throw new TypeError("runID must contain only letters, digits, and hyphens");
  }

  const expiresAt = new Date(now.getTime() + 2 * 60 * 60 * 1_000);
  const challengeExpiresAt = new Date(now.getTime() + 5 * 60 * 1_000);
  const sessions = {};

  for (const name of SESSION_NAMES) {
    const token = randomBytes(32).toString("base64url");
    const suffix = `${runID}-${name}`;
    const userID = `local-ui-user-${suffix}`;
    const challengeID = `local-ui-challenge-${suffix}`;
    const sessionID = `local-ui-session-${suffix}`;
    const subject = `local-ui-subject-${suffix}`;
    const tokenHash = createHash("sha256").update(token).digest("hex");

    await query(
      "INSERT INTO users (id, apple_subject, created_at) VALUES ($1, $2, $3)",
      [userID, subject, now],
    );
    await query(
      `INSERT INTO auth_challenges (id, nonce_hash, expires_at, consumed_at, created_at)
       VALUES ($1, $2, $3, $4, $4)`,
      [challengeID, "a".repeat(64), challengeExpiresAt, now],
    );
    await query(
      `INSERT INTO auth_sessions (id, user_id, challenge_id, token_hash, expires_at, created_at)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [sessionID, userID, challengeID, tokenHash, expiresAt, now],
    );
    sessions[name] = token;
  }

  return sessions;
}

export function isDirectInvocation(moduleURL, entryPath) {
  if (!entryPath) return false;
  try {
    return realpathSync(fileURLToPath(moduleURL)) === realpathSync(entryPath);
  } catch {
    return false;
  }
}

async function writeRunnerEnvironment() {
  const databaseURL = process.env.DATABASE_URL;
  const apiBaseURL = process.env.NIDO_UI_TEST_API_BASE_URL;
  const runID = process.env.NIDO_UI_TEST_RUN_ID;
  const outputPath = process.env.NIDO_LOCAL_API_UI_ENV_FILE;
  if (!databaseURL || !apiBaseURL || !runID || !outputPath) {
    throw new Error("DATABASE_URL, NIDO_UI_TEST_API_BASE_URL, NIDO_UI_TEST_RUN_ID, and NIDO_LOCAL_API_UI_ENV_FILE are required");
  }
  const apiURL = new URL(apiBaseURL);
  if (apiURL.protocol !== "http:" || !["127.0.0.1", "localhost"].includes(apiURL.hostname)) {
    throw new Error("The local UI test API must use HTTP loopback");
  }

  const postgres = (await import("postgres")).default;
  const client = postgres(databaseURL, { max: 1, prepare: false });
  let sessions;
  try {
    sessions = await client.begin(transaction => seedLocalRealAPIUITestSessions(
      (statement, parameters) => transaction.unsafe(statement, parameters),
      runID,
    ));
  } finally {
    await client.end();
  }

  for (const token of Object.values(sessions)) {
    const response = await fetch(new URL("/api/nido", apiURL), {
      headers: { authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(3_000),
    });
    if (response.status !== 403) {
      throw new Error(`The local API did not recognize a seeded session (expected 403, received ${response.status})`);
    }
  }

  const runnerNames = {
    NIDO_UI_TEST_API_BASE_URL: apiBaseURL,
    NIDO_UI_TEST_OWNER_A_TOKEN: sessions.ownerA,
    NIDO_UI_TEST_OWNER_B_TOKEN: sessions.ownerB,
    NIDO_UI_TEST_PERMISSIONS_OWNER_TOKEN: sessions.permissionsOwner,
    NIDO_UI_TEST_PERMISSIONS_CAREGIVER_TOKEN: sessions.permissionsCaregiver,
    NIDO_UI_TEST_HISTORY_TOKEN: sessions.history,
  };
  const contents = Object.entries(runnerNames)
    .map(([name, value]) => `TEST_RUNNER_${name}='${value}'`)
    .join("\n") + "\n";
  await writeFile(outputPath, contents, { encoding: "utf8", mode: 0o600, flag: "wx" });
  await chmod(outputPath, 0o600);
  process.stdout.write("Seeded five short-lived sessions; the local HTTP API recognized all five. No token values were printed.\n");
}

if (isDirectInvocation(import.meta.url, process.argv[1])) {
  if (process.argv[2] !== "--write-runner-environment") {
    throw new Error("Usage: node local-real-api-ui-sessions.mjs --write-runner-environment");
  }
  await writeRunnerEnvironment();
}
