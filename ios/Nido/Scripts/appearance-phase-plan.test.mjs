import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
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

test('expanded appearance phases exactly match current nonphysical XCTest source methods', () => {
  const sourceRoot = resolve(here, '..');
  const sourceIDs = [];
  const visit = (directory, prefix) => {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      if (entry.isDirectory()) {
        visit(resolve(directory, entry.name), `${prefix}/${entry.name}`);
      } else if (entry.isFile() && entry.name.endsWith('.swift')) {
        if (entry.name === 'PhysicalDeviceVisualUITests.swift') continue;
        const source = readFileSync(resolve(directory, entry.name), 'utf8');
        for (const match of source.matchAll(/^\s*func\s+(test\w+)\s*\(/gm)) {
          sourceIDs.push(`${prefix}/${entry.name.slice(0, -'.swift'.length)}/${match[1]}`);
        }
      }
    }
  };
  for (const target of ['NidoUITests', 'NidoSnapshotTests']) {
    visit(resolve(sourceRoot, target), target);
  }

  const plan = buildAppearancePhasePlan(ledger.baselineUniqueTestIdentifiers);
  const executionIDs = plan.phases.flatMap(({ identifiers }) => identifiers);
  const executionSet = new Set(executionIDs);
  const sourceSet = new Set(sourceIDs);
  const missing = sourceIDs.filter((identifier) => !executionSet.has(identifier)).sort();
  const stale = executionIDs.filter((identifier) => !sourceSet.has(identifier)).sort();
  assert.deepEqual([...new Set(sourceIDs)].sort(), sourceIDs.slice().sort(), 'XCTest source selectors must be unique.');
  assert.deepEqual([...new Set(executionIDs)].sort(), executionIDs.slice().sort(), 'Expanded phase selectors must be unique.');
  assert.deepEqual({ missing, stale }, { missing: [], stale: [] },
    `Expanded phases must match current XCTest source methods; missing: ${missing.join(', ')}; stale: ${stale.join(', ')}.`);
});

test('the full gate inventories every sleep detail selector exactly once', () => {
  const source = readFileSync(resolve(here, '../NidoUITests/SleepEvolutionDetailUITests.swift'), 'utf8');
  const names = [...source.matchAll(/func (test\w+)\(/g)].map((match) => match[1]);
  const plan = buildAppearancePhasePlan(ledger.baselineUniqueTestIdentifiers);
  for (const name of names) {
    const identifier = `NidoUITests/SleepEvolutionDetailUITests/${name}`;
    assert(ledger.baselineUniqueTestIdentifiers.includes(identifier), `Missing sleep detail baseline test: ${identifier}`);
    assert.equal(plan.phases.flatMap(({ identifiers }) => identifiers).filter((candidate) => candidate === identifier).length, 1);
  }
  const darkDetail = 'NidoUITests/SleepEvolutionDetailUITests/testSleepDetailUsesNativeNavigationAndChartInDarkAppearance';
  assert(plan.phases.find(({ name }) => name === 'dark-ui').identifiers.includes(darkDetail));
});

test('the simulator snapshot phase covers local fixture gate regressions', () => {
  const required = [
    'NidoSnapshotTests/LocalUITestStoreIsolationTests/testPhysicalDeviceLocalFixtureDisablesExternalEffects',
    'NidoSnapshotTests/LocalUITestStoreIsolationTests/testSimulatorLocalFixtureKeepsExternalEffectsEnabled',
    'NidoSnapshotTests/LocalUITestStoreIsolationTests/testSignOutDeletesOnlyTheRunScopedFixtureCredential',
  ];
  const plan = buildAppearancePhasePlan(ledger.baselineUniqueTestIdentifiers);
  for (const identifier of required) {
    assert(ledger.baselineUniqueTestIdentifiers.includes(identifier), `Missing baseline test: ${identifier}`);
    assert(plan.phases.find(({ name }) => name === 'snapshots').identifiers.includes(identifier), `Missing snapshot phase test: ${identifier}`);
  }
});

test('the simulator snapshot phase covers the native diaper icon template regression', () => {
  const identifier = 'NidoSnapshotTests/CareCategoryIconTests/testNativeMenuDiaperUsesAnUnderlyingTemplateImage';
  const plan = buildAppearancePhasePlan(ledger.baselineUniqueTestIdentifiers);
  assert(ledger.baselineUniqueTestIdentifiers.includes(identifier), `Missing baseline test: ${identifier}`);
  assert(plan.phases.find(({ name }) => name === 'snapshots').identifiers.includes(identifier), `Missing snapshot phase test: ${identifier}`);
});

test('the full-suite plan covers physical-review UI and native history pager regressions', () => {
  const lightUI = [
    'NidoUITests/PhysicalReviewRegressionUITests/testRegistrationActionAlignsWithFourTabTargets',
    'NidoUITests/PhysicalReviewRegressionUITests/testEmptyGoalSetupIsDiscoverableAndAddsTheFirstRings',
    'NidoUITests/PhysicalReviewRegressionUITests/testTodayMarkerStaysOnTodayWhilePreviousDayRemainsSelected',
    'NidoUITests/PhysicalReviewRegressionUITests/testRapidConsecutiveWeekSelectionsCommitTheLatestDate',
    'NidoUITests/PhysicalReviewRegressionUITests/testShortSlowHorizontalRingDragDoesNotChangeTheSelectedDay',
  ];
  const snapshots = [
    'NidoSnapshotTests/HistoryNativePagerTests/testNonanimatedLatestSelectionClosesTheTransitionLifecycle',
    'NidoSnapshotTests/HistoryNativePagerTests/testLatestExternalSelectionIsAppliedAfterAnAnimatedSelectionSettles',
  ];
  const plan = buildAppearancePhasePlan(ledger.baselineUniqueTestIdentifiers);
  for (const identifier of lightUI) {
    assert(ledger.baselineUniqueTestIdentifiers.includes(identifier), `Missing baseline test: ${identifier}`);
    assert(plan.phases.find(({ name }) => name === 'light-ui').identifiers.includes(identifier), `Missing Light UI test: ${identifier}`);
  }
  for (const identifier of snapshots) {
    assert(ledger.baselineUniqueTestIdentifiers.includes(identifier), `Missing baseline test: ${identifier}`);
    assert(plan.phases.find(({ name }) => name === 'snapshots').identifiers.includes(identifier), `Missing snapshot test: ${identifier}`);
  }
});

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

test('the ledger runs both raw accessibility diagnostics after 243 ordinary executions', () => {
  const plan = buildAppearancePhasePlan(ledger.baselineUniqueTestIdentifiers);
  assert.equal(plan.executionCount, 245);
  assert.deepEqual(plan.phases.map(({ name, kind, identifiers }) => [name, kind, identifiers.length]), [
    ['light-ui', 'xcodebuild', 159], ['local-api-ui', 'api-helper', 3],
    ['snapshots', 'xcodebuild', 70], ['dark-ui', 'xcodebuild', 11],
    ['light-accessibility-diagnostic', 'diagnostic', 1], ['dark-accessibility-diagnostic', 'diagnostic', 1],
  ]);
  const diagnostics = plan.phases.slice(-2).flatMap(({ identifiers }) => identifiers);
  assert.deepEqual(diagnostics, [
    'NidoUITests/NidoUITests/testTodayUnfilteredAccessibilityAuditDiagnosticInLightAppearance',
    'NidoUITests/NidoUITests/testTodayUnfilteredAccessibilityAuditDiagnosticInDarkAppearance',
  ]);
  assert.equal(plan.phases.slice(0, 4).reduce((n, phase) => n + phase.identifiers.length, 0), 243);
});

test('rendered contrast selectors are included exactly once in their matching phases', () => {
  const plan = buildAppearancePhasePlan(ledger.baselineUniqueTestIdentifiers);
  const cases = [
    ['NidoUITests/NidoUITests/testFloatingNavigationTabLabelsMeetRenderedContrastInLightAppearance', 'light-ui'],
    ['NidoUITests/NidoUITests/testFloatingNavigationTabLabelsMeetRenderedContrastInDarkAppearance', 'dark-ui'],
  ];
  for (const [identifier, phaseName] of cases) {
    assert(ledger.baselineUniqueTestIdentifiers.includes(identifier), `Missing contrast baseline test: ${identifier}`);
    assert.deepEqual(plan.originalToExecutions.get(identifier), [identifier]);
    const phase = plan.phases.find(({ name }) => name === phaseName);
    assert.equal(phase.identifiers.filter((candidate) => candidate === identifier).length, 1);
  }
});

test('floating navigation geometry is included exactly once in the light phase', () => {
  const identifier = 'NidoUITests/FloatingNavigationUITests/testTodayScrollAndFloatingNavigationGeometry';
  const plan = buildAppearancePhasePlan(ledger.baselineUniqueTestIdentifiers);
  assert(ledger.baselineUniqueTestIdentifiers.includes(identifier), 'The full gate must include the floating navigation regression.');
  assert.deepEqual(plan.originalToExecutions.get(identifier), [identifier]);
  assert.equal(plan.phases[0].identifiers.filter((candidate) => candidate === identifier).length, 1);
});

test('all seven evolution design preview selectors are in the light UI phase', () => {
  const identifiers = [
    'NidoUITests/EvolutionDesignPreviewUITests/testSummaryShowsReadOnlySevenDayCatalogInLightAppearance',
    'NidoUITests/EvolutionDesignPreviewUITests/testSummaryShowsTheSameCatalogInDarkAppearance',
    'NidoUITests/EvolutionDesignPreviewUITests/testPreviewUsesNativeNavigationBarTitle',
    'NidoUITests/EvolutionDesignPreviewUITests/testPopulatedCareCardsRenderVisibleMiniBars',
    'NidoUITests/EvolutionDesignPreviewUITests/testEmptyScenarioUsesNoRecordStatesInsteadOfZeroes',
    'NidoUITests/EvolutionDesignPreviewUITests/testAllFiveValuesRemainReachableAtAccessibilityXXXL',
'NidoUITests/EvolutionDesignPreviewUITests/testIntegratedDefaultTabUsesEvolutionLabel',
  ];
  const plan = buildAppearancePhasePlan(ledger.baselineUniqueTestIdentifiers);
  const light = plan.phases.find(({ name }) => name === 'light-ui').identifiers;

  assert.equal(identifiers.length, 7);
  for (const identifier of identifiers) {
    assert(ledger.baselineUniqueTestIdentifiers.includes(identifier), `Missing evolution baseline test: ${identifier}`);
    assert.deepEqual(plan.originalToExecutions.get(identifier), [identifier]);
    assert.equal(light.filter((candidate) => candidate === identifier).length, 1);
  }
});

test('the phase plan covers every baseline once and splits only the three mixed cases', () => {
  const plan = buildAppearancePhasePlan(ledger.baselineUniqueTestIdentifiers);
  assert.equal(plan.baselineCount, 242);
  assert.equal(plan.executionCount, 245);
  assert.deepEqual(plan.phases.map(({ name }) => name), ['light-ui', 'local-api-ui', 'snapshots', 'dark-ui', 'light-accessibility-diagnostic', 'dark-accessibility-diagnostic']);
  assert.deepEqual(plan.phases.map(({ identifiers }) => identifiers.length), [159, 3, 70, 11, 1, 1]);

  const phaseIDs = plan.phases.flatMap(({ identifiers }) => identifiers);
  assert.equal(new Set(phaseIDs).size, 245);
  assert.equal(phaseIDs.filter((id) => id.startsWith('NidoSnapshotTests/')).length, 70);
  assert.deepEqual(plan.phases[1].identifiers, [...API_TESTS]);
  assert.deepEqual(plan.phases[3].identifiers.slice(0, DARK_ONLY_TESTS.length - 1), DARK_ONLY_TESTS.slice(1));
  assert.equal(plan.phases[3].identifiers.length, 11);

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
    /Expected the 242-test baseline ledger/
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

test('ordinary failures abort, diagnostic findings continue and are retained', async () => {
  const phases = [
    { name: 'ordinary', appearance: 'light' },
    { name: 'diagnostic-light', appearance: 'light', kind: 'diagnostic' },
    { name: 'diagnostic-dark', appearance: 'dark', kind: 'diagnostic' },
  ];
  const started = [];
  let phaseAppearance = 'light';
  const result = await runAppearancePhases(phases, {
    getAppearance: async () => phaseAppearance, setAppearance: async (value) => { phaseAppearance = value; },
    runPhase: async (phase) => {
      started.push(phase.name);
      if (phase.kind === 'diagnostic') throw Object.assign(new Error('raw assertion failures'), { diagnosticFindings: true });
    },
  });
  assert.deepEqual(started, phases.map(({ name }) => name));
  assert.deepEqual(result.diagnosticFailures.map(({ name }) => name), ['diagnostic-light', 'diagnostic-dark']);
  let appearance = 'light';
  await assert.rejects(runAppearancePhases(phases, {
    getAppearance: async () => appearance, setAppearance: async (value) => { appearance = value; },
    runPhase: async (phase) => { if (phase.name === 'ordinary') throw Error('ordinary failed'); },
  }), /ordinary failed/);
  await assert.rejects(runAppearancePhases([
    { name: 'diagnostic', appearance: 'light', kind: 'diagnostic' },
    { name: 'later-diagnostic', appearance: 'dark', kind: 'diagnostic' },
  ], {
    getAppearance: async () => 'light', setAppearance: async () => {},
    runPhase: async () => { throw Error('xcresulttool unavailable'); },
  }), /xcresulttool unavailable/);
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
