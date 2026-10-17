import assert from "node:assert/strict";
import { chmod, mkdir, mkdtemp, readFile, realpath, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { runCommandWithTimeout } from "../ios/Nido/Scripts/run-command-with-timeout.mjs";
import { sanitizeLogText } from "../ios/Nido/Scripts/sanitize-ui-test-log.mjs";

const shellSupport = fileURLToPath(new URL("../ios/Nido/Scripts/harness-shell-support.sh", import.meta.url));
const apiHarness = fileURLToPath(new URL("../ios/Nido/Scripts/run-local-real-api-ui-tests.sh", import.meta.url));

async function runApiHarnessPreflight(root, deviceId) {
  const apiRoot = join(root, "api");
  const projectDir = join(root, "project");
  const mockBin = join(root, "bin");
  const callLog = join(root, "mock-calls.log");
  await mkdir(join(apiRoot, "node_modules", ".bin"), { recursive: true });
  await mkdir(join(apiRoot, "db"), { recursive: true });
  await mkdir(join(projectDir, "Nido.xcodeproj"), { recursive: true });
  await mkdir(mockBin, { recursive: true });
  const vinext = join(apiRoot, "node_modules", ".bin", "vinext");
  await writeFile(vinext, "#!/bin/sh\nexit 0\n");
  await chmod(vinext, 0o755);
  await writeFile(join(apiRoot, "db", "migrate.ts"), "// fixture\n");
  await writeFile(join(projectDir, "Nido.xcodeproj", "project.pbxproj"), "// fixture\n");
  const mockCommand = [
    "#!/bin/sh",
    'printf "%s %s\\n" "$(basename "$0")" "$*" >> "$NIDO_MOCK_LOG"',
    'if [ "$(basename "$0")" = docker ] && [ "$1" = info ]; then exit 1; fi',
    'if [ "$(basename "$0")" = node ]; then printf "mock-run-id\\n"; fi',
    'if [ "$(basename "$0")" = openssl ]; then printf "mock-secret\\n"; fi',
    "exit 0",
    "",
  ].join("\n");
  for (const command of ["docker", "curl", "node", "npm", "xcodebuild", "openssl"]) {
    const commandPath = join(mockBin, command);
    await writeFile(commandPath, mockCommand);
    await chmod(commandPath, 0o755);
  }
  const result = spawnSync(apiHarness, [
    "--run-ui-tests",
    "--api-root", apiRoot,
    "--project-dir", projectDir,
    "--device-id", deviceId,
  ], {
    encoding: "utf8",
    env: {
      ...process.env,
      PATH: `${mockBin}:${process.env.PATH}`,
      NIDO_MOCK_LOG: callLog,
    },
  });
  return { result, callLog };
}

test("the timeout helper returns 124 when the child exceeds its limit", async () => {
  const exitCode = await runCommandWithTimeout(
    process.execPath,
    ["-e", "setTimeout(() => {}, 5000)"],
    40,
  );
  assert.equal(exitCode, 124);
});

test("the timeout helper preserves a child's ordinary exit code", async () => {
  const exitCode = await runCommandWithTimeout(process.execPath, ["-e", "process.exit(23)"], 2_000);
  assert.equal(exitCode, 23);
});

test("shell support creates a DerivedData directory that did not exist", async () => {
  const temporaryDirectory = await mkdtemp(join(tmpdir(), "nido-dd-path-"));
  const newDirectory = join(temporaryDirectory, "new", "DerivedData");
  try {
    const result = spawnSync("/bin/bash", [
      "-c",
      'source "$1"; normalize_create_directory "$2"',
      "test",
      shellSupport,
      newDirectory,
    ], { encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout.trim(), await realpath(newDirectory));
  } finally {
    await rm(temporaryDirectory, { recursive: true, force: true });
  }
});

test("API UI harness accepts any canonical simulator UDID and rejects malformed IDs before side effects", async () => {
  const temporaryDirectory = await mkdtemp(join(tmpdir(), "nido-device-id-"));
  try {
    const accepted = await runApiHarnessPreflight(join(temporaryDirectory, "accepted"), "B7819FFF-9422-4CDB-8E23-F03BAFB5CC6E");
    assert.equal(accepted.result.status, 2);
    assert.match(accepted.result.stderr, /Docker daemon is unavailable/);
    assert.match(await readFile(accepted.callLog, "utf8"), /docker info/);

    const malformed = await runApiHarnessPreflight(join(temporaryDirectory, "malformed"), "not-a-simulator-id");
    assert.equal(malformed.result.status, 2);
    assert.match(malformed.result.stderr, /invalid simulator UDID/i);
    await assert.rejects(readFile(malformed.callLog, "utf8"));
  } finally {
    await rm(temporaryDirectory, { recursive: true, force: true });
  }
});

test("cleanup fails when Docker cannot remove its owned container", () => {
  const result = spawnSync("/bin/bash", [
    "-c",
    [
      'source "$1"',
      'CONTAINER_NAME="nido-test"',
      'CONTAINER_LABEL_KEY="test.owner"',
      'CONTAINER_LABEL_VALUE="run-123"',
      'docker() { if [[ "$1" == inspect ]]; then printf "%s" "$TEST_LABEL"; else return "$TEST_RM_STATUS"; fi; }',
      "remove_owned_container",
    ].join("\n"),
    "test",
    shellSupport,
  ], {
    encoding: "utf8",
    env: { ...process.env, TEST_LABEL: "run-123", TEST_RM_STATUS: "37" },
  });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /could not be removed/i);
});

test("evidence sanitization removes bearer tokens and supplied secrets", () => {
  const token = "AbCdEf0123456789_abcdefghijklmnopqrstuvwxyz-ABCD";
  const secret = "database-password-example";
  const sanitized = sanitizeLogText(
    `Authorization: Bearer ${token}\nTEST_RUNNER_NIDO_UI_TEST_HISTORY_TOKEN='${token}'\n${secret}`,
    [token, secret],
  );
  assert.doesNotMatch(sanitized, new RegExp(token));
  assert.doesNotMatch(sanitized, new RegExp(secret));
  assert.match(sanitized, /Bearer \[REDACTED\]/);
  assert.match(sanitized, /TEST_RUNNER_NIDO_UI_TEST_HISTORY_TOKEN='\[REDACTED\]'/);
});
