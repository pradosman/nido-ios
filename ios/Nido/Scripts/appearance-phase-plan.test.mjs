import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import {
  API_TESTS,
  DARK_ONLY_TESTS,
  MIXED_APPEARANCE_TESTS,
  buildAppearancePhasePlan,
  runAppearancePhases,
} from './appearance-phase-plan.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const ledger = JSON.parse(readFileSync(resolve(here, 'appearance-test-baseline.json'), 'utf8'));

test('the phase ledger includes palette, widget, menu and authentication regressions', () => {
  const plan = buildAppearancePhasePlan(ledger.baselineUniqueTestIdentifiers);
  const required = [
    'NidoSnapshotTests/SettingsContrastTests/testChartAccentsUseTheNidoPaletteInSRGB',
    'NidoSnapshotTests/SettingsContrastTests/testStaticCategoryColorsMatchSmallTextPaletteInEveryAppearance',
    'NidoSnapshotTests/SettingsContrastTests/testCareCategoryGlyphsKeepShortcutFallbackSeparate',
    'NidoSnapshotTests/SettingsContrastTests/testCategorySmallTextInksMeetContrastForEveryAppearance',
    'NidoSnapshotTests/NidoDayWidgetContentTests/testLegacyWidgetSnapshotPayloadDecodesWithoutNewGoalFields',
    'NidoSnapshotTests/NidoDayWidgetContentTests/testWidgetSnapshotKeepsTheV1PayloadKeysAndValues',
    'NidoSnapshotTests/NidoDayWidgetContentTests/testSmallAndMediumWidgetsRenderAllCareCategoryLabels',
    'NidoSnapshotTests/CareCategoryIconTests/testDiaperGlyphIsVisuallyDistinctFromItsShortcutDropletFallback',
    'NidoUITests/NidoUITests/testRegistrationMenuShowsTheDiaperActionForVisualGlyphReview',
    'NidoUITests/NidoUITests/testTenMinuteFeedActivityAppearsOnDynamicIsland',
    'NidoUITests/NidoUITests/testRegistrationMenuSupportsConsecutiveSelectionsAndCancellation',
    'NidoSnapshotTests/AccountDeletionSessionFenceTests/testLoadWithoutCredentialPreservesAccountRevocationNotice',
    'NidoSnapshotTests/AccountDeletionSessionFenceTests/testStoreOwnedSessionInvalidationDoesNotReenterEventHub',
    'NidoSnapshotTests/AccountDeletionSessionFenceTests/testAutomaticDismissalCannotClearReauthenticationReason',
    'NidoSnapshotTests/AccountDeletionSessionFenceTests/testAutomaticDismissalRequiresReadyPhase',
    'NidoSnapshotTests/AccountDeletionSessionFenceTests/testAutomaticDismissalDoesNotClearReplacementNotice',
    'NidoSnapshotTests/AccountDeletionSessionFenceTests/testAutomaticDismissalClearsMatchingTransientNotice',
    'NidoSnapshotTests/AccountDeletionSessionFenceTests/testAutomaticDismissalPreservesUndoableNotice',
    'NidoSnapshotTests/AccountDeletionSessionFenceTests/testManualDismissalStillClearsReauthenticationReason',
  ];
  for (const identifier of required) {
    assert(ledger.baselineUniqueTestIdentifiers.includes(identifier), `Missing regression case: ${identifier}`);
    assert.deepEqual(plan.originalToExecutions.get(identifier), [identifier]);
  }
});

test('the phase plan covers every baseline once and splits only the three mixed cases', () => {
  const plan = buildAppearancePhasePlan(ledger.baselineUniqueTestIdentifiers);
  assert.equal(plan.baselineCount, 183);
  assert.equal(plan.executionCount, 186);
  assert.deepEqual(plan.phases.map(({ name }) => name), ['light-ui', 'local-api-ui', 'snapshots', 'dark-ui']);
  assert.deepEqual(plan.phases.map(({ identifiers }) => identifiers.length), [114, 3, 59, 10]);

  const phaseIDs = plan.phases.flatMap(({ identifiers }) => identifiers);
  assert.equal(new Set(phaseIDs).size, 186);
  assert.equal(phaseIDs.filter((id) => id.startsWith('NidoSnapshotTests/')).length, 59);
  assert.deepEqual(plan.phases[1].identifiers, [...API_TESTS]);
  assert.deepEqual(plan.phases[3].identifiers.slice(0, 7), [...DARK_ONLY_TESTS]);

  for (const [baselineID, split] of Object.entries(MIXED_APPEARANCE_TESTS)) {
    assert.deepEqual(plan.originalToExecutions.get(baselineID), [split.light, split.dark]);
  }
});

test('Reduce Motion is enabled only for Snapshot and normal UI retains the initial setting', async () => {
  let appearance = 'light';
  let reduceMotion = false;
  const observed = [];
  await runAppearancePhases(['light-ui', 'local-api-ui', 'snapshots', 'dark-ui'].map((name) => ({
    name, appearance: name === 'dark-ui' ? 'dark' : 'light',
  })), {
    getAppearance: async () => appearance,
    setAppearance: async (value) => { appearance = value; },
    getReduceMotion: async () => reduceMotion,
    setReduceMotion: async (value) => { reduceMotion = value; },
    runPhase: async ({ name }) => { observed.push([name, reduceMotion]); },
  });
  assert.deepEqual(observed, [
    ['light-ui', false], ['local-api-ui', false], ['snapshots', true], ['dark-ui', false],
  ]);
  assert.equal(reduceMotion, false);
});

test('a Snapshot failure restores the original Reduce Motion setting', async () => {
  let reduceMotion = false;
  await assert.rejects(runAppearancePhases([{ name: 'snapshots', appearance: 'light' }], {
    getAppearance: async () => 'light',
    setAppearance: async () => {},
    getReduceMotion: async () => reduceMotion,
    setReduceMotion: async (value) => { reduceMotion = value; },
    runPhase: async () => { reduceMotion = true; throw new Error('Snapshot failed'); },
  }), /Snapshot failed/);
  assert.equal(reduceMotion, false);
});

test('a rejected Reduce Motion preset prevents Snapshot from starting', async () => {
  let started = false;
  await assert.rejects(runAppearancePhases([{ name: 'snapshots', appearance: 'light' }], {
    getAppearance: async () => 'light',
    setAppearance: async () => {},
    getReduceMotion: async () => false,
    setReduceMotion: async () => {},
    runPhase: async () => { started = true; },
  }), /Reduce Motion/);
  assert.equal(started, false);
});

test('the planner rejects a duplicated or incomplete baseline rather than silently dropping coverage', () => {
  assert.throws(
    () => buildAppearancePhasePlan([...ledger.baselineUniqueTestIdentifiers, ledger.baselineUniqueTestIdentifiers[0]]),
    /must not contain duplicates/
  );
  assert.throws(
    () => buildAppearancePhasePlan(ledger.baselineUniqueTestIdentifiers.slice(1)),
    /Expected the 183-test baseline ledger/
  );
});

test('each appearance is verified before its phase starts and the original mode is restored', async () => {
  let appearance = 'light';
  const events = [];
  await runAppearancePhases([
    { name: 'light-one', appearance: 'light' },
    { name: 'dark-two', appearance: 'dark' },
  ], {
    getAppearance: async () => { events.push(`read:${appearance}`); return appearance; },
    setAppearance: async (value) => { events.push(`set:${value}`); appearance = value; },
    runPhase: async ({ name }) => { events.push(`run:${name}:${appearance}`); },
  });
  assert.deepEqual(events, [
    'read:light', 'set:light', 'read:light', 'run:light-one:light',
    'set:dark', 'read:dark', 'run:dark-two:dark', 'read:dark', 'set:light', 'read:light',
  ]);
  assert.equal(appearance, 'light');
});

test('a phase failure stops later phases, propagates the error, and restores the original mode', async () => {
  let appearance = 'light';
  const started = [];
  await assert.rejects(runAppearancePhases([
    { name: 'first', appearance: 'light' },
    { name: 'second', appearance: 'dark' },
  ], {
    getAppearance: async () => appearance,
    setAppearance: async (value) => { appearance = value; },
    runPhase: async ({ name }) => {
      started.push(name);
      if (name === 'first') throw new Error('xcodebuild failed');
    },
  }), /xcodebuild failed/);
  assert.deepEqual(started, ['first']);
  assert.equal(appearance, 'light');
});

test('a rejected appearance preset prevents the test phase from starting', async () => {
  let appearance = 'light';
  let started = false;
  await assert.rejects(runAppearancePhases([{ name: 'dark', appearance: 'dark' }], {
    getAppearance: async () => appearance,
    setAppearance: async () => {},
    runPhase: async () => { started = true; },
  }), /did not enter dark/);
  assert.equal(started, false);
});

test('a phase failure is reported when simulator appearance cleanup cannot restore the original mode', async () => {
  let appearance = 'dark';
  await assert.rejects(runAppearancePhases([{ name: 'light-ui', appearance: 'light' }], {
    getAppearance: async () => appearance,
    setAppearance: async (value) => {
      if (value === 'light') appearance = value;
    },
    runPhase: async () => { throw new Error('xcodebuild failed'); },
  }), /Could not restore original simulator appearance dark/);
});
