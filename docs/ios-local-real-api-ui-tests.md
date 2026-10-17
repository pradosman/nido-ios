# UI tests against a disposable local API

This harness runs three credential-backed UI scenarios against the actual Nido
HTTP routes and PostgreSQL driver without using Apple identity, a deployed
service, or production data. It seeds short-lived bearer sessions directly into
a disposable PostgreSQL database, then verifies over HTTP that the API accepts
each token. This covers API, database, and app behavior; it does not verify
Sign in with Apple, Apple's JWKS, or a deployed backend.

## Safety and lifecycle

`ios/Nido/Scripts/run-local-real-api-ui-tests.sh` starts a uniquely named
PostgreSQL 17 container with a 512 MiB `tmpfs` database and a randomly assigned
host port bound only to `127.0.0.1`. It applies the repository migrations,
starts Vinext bound to loopback, seeds five sessions, and confirms those
sessions receive the expected authenticated-but-not-yet-a-member response.
The test cases then create their own household, invite/revoke a caregiver, or
insert 505 history records. All writes stay inside that disposable database.
The EXIT cleanup stops only the server started by this invocation and removes
the container only when its unique ownership label still matches. The result
bundle from an actual XCUITest run remains under `/tmp`.

Tokens are random, short lived, stored in a mode-0600 temporary environment
file, and passed to XCTest using Xcode's `TEST_RUNNER_` environment prefix. No
token value is printed. Placeholder Apple audience and signing secret are used
only so the local API can start; the Apple identity verifier is never used by
these sessions.

## Prepare without opening Simulator

From the repository root:

```sh
ios/Nido/Scripts/run-local-real-api-ui-tests.sh --prepare-only
```

This checks PostgreSQL, migrations, local HTTP health, and all five synthetic
sessions, then cleans up without invoking `xcodebuild` or Simulator. It is safe
to use before authorizing the UI run.

## Run the three UI cases

After reviewing a successful preparation, run:

```sh
ios/Nido/Scripts/run-local-real-api-ui-tests.sh \
  --run-ui-tests \
  --project-dir "$PWD/ios/Nido" \
  --derived-data-path /tmp/nido-local-real-api-ui-derived \
  --device-id 516B4FA1-D8C4-4389-9836-79095056D5CB
```

The script serially runs only:

- `testFreshInstallationCreatesAnIndependentHouseholdAndOnlySeesItsOwnBaby`
- `testRealBackendCaregiverPermissionsAndRevocation`
- `testRealBackendHistoryLoadsAndDisplaysAnEntryBeyondTheFirstFiveHundred`

The default invocation uses `xcodebuild test` and the supplied DerivedData path
for incremental builds. To reuse an already-built test runner without building,
add `--test-without-building --xctestrun PATH`; that `.xctestrun` must have been
built from the project copy passed with `--project-dir`. `--api-root PATH` can
select the checkout that contains the Node dependencies and backend source
independently of an Xcode source copy. The destination is intentionally fixed
to the iPhone 16 Pro simulator UUID above.

Do not describe a passing run as Apple-login, deployed-API, or production
verification. Those boundaries require separate credentials and evidence.

## Closeout evidence from 15 October 2026

The harness support and session-fixture tests pass 7/7 with:

```sh
node --test --test-timeout=5000 \
  tests/local-real-api-ui-sessions.test.mjs \
  tests/local-real-api-ui-harness-support.test.mjs
```

The bounded run is recorded at `/tmp/nido-close-api-harness-node-final.log`.
`--prepare-only --api-root /tmp/nido-api-e2e` also passed migrations, local API
health, and HTTP validation of all five generated sessions; it cleaned up its
own container successfully. The log is `/tmp/nido-close-api-prepare-recovered.log`.

The credential-backed UI run is still open. The latest complete run was 1/3:
the independent-household scenario passed. The caregiver scenario received
the expected HTTP 401 after revocation. Its old test expectation was
incorrect: it expected the invitation-code screen, but the app correctly
cleared the revoked session and showed Apple sign-in with a reauthentication
message. The exported failure hierarchy confirms that state; the test now
asserts it and verifies the invitation field is absent. The history scenario
failed because its test locator included a year while the app's Spanish
accessibility label intentionally omits one. The test locator now uses the
same weekday/day/month format as `HistoryView`. Both test corrections still
need a fresh UI run. The next attempt was interrupted before Xcode produced a
valid result bundle, so it adds no pass evidence. Do not mark the three UI
scenarios as verified until a fresh run reports 3/3 and confirms cleanup.

That local API run used `/tmp/nido-api-e2e`. Its source manifest records
`app/api/nido/caregivers/join/route.ts` as an index fallback at Git blob
`a5a57c1da6fd8cb95d4a8dd6e6124c9994da013a`; the copied file matched the
recorded size and modification time, but the live iCloud source could not be
read to prove byte-for-byte equivalence. The caregiver UI result therefore
does not establish that this route was identical to the current working-tree
file. Manifest checksum: `22bb757c3e9d8505e123c115811f2645105fac5f216df6330c5e8c44effd59c8`.
