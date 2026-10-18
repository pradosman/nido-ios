import { readFileSync } from 'node:fs';

export const MIXED_APPEARANCE_TESTS = Object.freeze({
  'NidoUITests/BabyCareUITests/testNativeVisualCheckpointsLightAndDark': {
    light: 'NidoUITests/BabyCareUITests/testNativeVisualCheckpointsInLightAppearance',
    dark: 'NidoUITests/BabyCareUITests/testNativeVisualCheckpointsInDarkAppearance',
  },
  'NidoUITests/NidoUITests/testPremiumTodayVisualReviewCaptures': {
    light: 'NidoUITests/NidoUITests/testPremiumTodayVisualReviewCapturesInLightAppearance',
    dark: 'NidoUITests/NidoUITests/testPremiumTodayVisualReviewCapturesInDarkAppearance',
  },
  'NidoUITests/GoalDesignPreviewUITests/testOverGoalKeepsTheRealQuantity': {
    light: 'NidoUITests/GoalDesignPreviewUITests/testOverGoalKeepsTheRealQuantityInLightAppearance',
    dark: 'NidoUITests/GoalDesignPreviewUITests/testOverGoalKeepsTheRealQuantityInDarkAppearance',
  },
});

export const DARK_ONLY_TESTS = Object.freeze([
  'NidoUITests/NidoUITests/testTodayUnfilteredAccessibilityAuditDiagnosticInDarkAppearance',
  'NidoUITests/NidoUITests/testTodayHeadingLeavesAccessibilityTreeWhenScrolledOutOfView',
  'NidoUITests/NidoUITests/testTodayDarkScrolledHeadingAtAccessibilityXXXL',
  'NidoUITests/NidoUITests/testTodayVisibleHitRegionsPassInDarkAppearance',
  'NidoUITests/HistoryFitnessUITests/testDarkAppearanceKeepsDateAndChartContentAccessible',
  'NidoUITests/HistoryFitnessUITests/testDarkCalendarSelectsADayAndDisablesFutureDates',
  'NidoUITests/GoalDesignPreviewUITests/testDarkGoalsRemainReadable',
]);

export const API_TESTS = Object.freeze([
  'NidoUITests/NidoUITests/testFreshInstallationCreatesAnIndependentHouseholdAndOnlySeesItsOwnBaby',
  'NidoUITests/NidoUITests/testRealBackendCaregiverPermissionsAndRevocation',
  'NidoUITests/NidoUITests/testRealBackendHistoryLoadsAndDisplaysAnEntryBeyondTheFirstFiveHundred',
]);

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

export function buildAppearancePhasePlan(baselineIdentifiers) {
  assert(Array.isArray(baselineIdentifiers), 'Baseline identifiers must be an array.');
  const baseline = baselineIdentifiers.map((identifier) => String(identifier).trim()).filter(Boolean);
  assert(baseline.length === new Set(baseline).size, 'Baseline identifiers must not contain duplicates.');
  assert(baseline.length === 174, `Expected the 174-test baseline ledger, received ${baseline.length}.`);

  const baselineSet = new Set(baseline);
  const splitNames = new Set(Object.keys(MIXED_APPEARANCE_TESTS));
  const darkNames = new Set(DARK_ONLY_TESTS);
  const apiNames = new Set(API_TESTS);
  for (const identifier of splitNames) assert(baselineSet.has(identifier), `Missing mixed-appearance baseline test: ${identifier}`);
  for (const identifier of darkNames) assert(baselineSet.has(identifier), `Missing dark-only baseline test: ${identifier}`);
  for (const identifier of apiNames) assert(baselineSet.has(identifier), `Missing API baseline test: ${identifier}`);

  const lightUI = [];
  const darkUI = [...DARK_ONLY_TESTS];
  const snapshots = [];
  const apiUI = [...API_TESTS];
  const originalToExecutions = new Map();

  for (const identifier of baseline) {
    if (apiNames.has(identifier)) {
      originalToExecutions.set(identifier, [identifier]);
      continue;
    }
    if (identifier.startsWith('NidoSnapshotTests/')) {
      snapshots.push(identifier);
      originalToExecutions.set(identifier, [identifier]);
      continue;
    }
    if (splitNames.has(identifier)) {
      const split = MIXED_APPEARANCE_TESTS[identifier];
      lightUI.push(split.light);
      darkUI.push(split.dark);
      originalToExecutions.set(identifier, [split.light, split.dark]);
      continue;
    }
    if (darkNames.has(identifier)) {
      originalToExecutions.set(identifier, [identifier]);
      continue;
    }
    lightUI.push(identifier);
    originalToExecutions.set(identifier, [identifier]);
  }

  const phaseIDs = [...lightUI, ...apiUI, ...snapshots, ...darkUI];
  assert(phaseIDs.length === new Set(phaseIDs).size, 'Phase selector lists overlap or contain duplicates.');
  assert(lightUI.length === 113, `Expected 113 non-API Light UI cases, got ${lightUI.length}.`);
  assert(apiUI.length === 3, `Expected 3 API UI cases, got ${apiUI.length}.`);
  assert(snapshots.length === 51, `Expected 51 Snapshot cases, got ${snapshots.length}.`);
  assert(darkUI.length === 10, `Expected 10 Dark UI cases, got ${darkUI.length}.`);
  assert(phaseIDs.length === 177, `Expected 177 phase executions, got ${phaseIDs.length}.`);
  assert(originalToExecutions.size === 174, 'Every baseline test must map to a phase execution.');

  return Object.freeze({
    baselineCount: baseline.length,
    executionCount: phaseIDs.length,
    phases: Object.freeze([
      Object.freeze({ name: 'light-ui', appearance: 'light', kind: 'xcodebuild', identifiers: lightUI }),
      Object.freeze({ name: 'local-api-ui', appearance: 'light', kind: 'api-helper', identifiers: apiUI }),
      Object.freeze({ name: 'snapshots', appearance: 'light', kind: 'xcodebuild', identifiers: snapshots }),
      Object.freeze({ name: 'dark-ui', appearance: 'dark', kind: 'xcodebuild', identifiers: darkUI }),
    ]),
    originalToExecutions,
  });
}

export function readBaselineLedger(path) {
  const parsed = JSON.parse(readFileSync(path, 'utf8'));
  assert(parsed.schemaVersion === 1, 'Unsupported appearance test ledger schema.');
  return parsed.baselineUniqueTestIdentifiers;
}

export async function runAppearancePhases(phases, { getAppearance, setAppearance, getReduceMotion, setReduceMotion, runPhase }) {
  const initial = await getAppearance();
  assert(initial === 'light' || initial === 'dark', `Cannot restore unknown simulator appearance: ${initial}`);
  const controlsMotion = getReduceMotion !== undefined || setReduceMotion !== undefined;
  assert(!controlsMotion || (typeof getReduceMotion === 'function' && typeof setReduceMotion === 'function'),
    'Reduce Motion requires both read and write hooks.');
  const initialMotion = controlsMotion ? await getReduceMotion() : undefined;
  assert(!controlsMotion || typeof initialMotion === 'boolean', 'Cannot restore unknown Reduce Motion state.');
  try {
    for (const phase of phases) {
      await setAppearance(phase.appearance);
      const observed = await getAppearance();
      assert(observed === phase.appearance, `Simulator did not enter ${phase.appearance} before ${phase.name}; observed ${observed}.`);
      if (controlsMotion) {
        const requiredMotion = phase.name === 'snapshots' ? true : initialMotion;
        if (await getReduceMotion() !== requiredMotion) await setReduceMotion(requiredMotion);
        assert(await getReduceMotion() === requiredMotion, `Reduce Motion preset was not applied before ${phase.name}.`);
      }
      await runPhase(phase);
    }
  } finally {
    try {
      if (await getAppearance() !== initial) await setAppearance(initial);
      const restored = await getAppearance();
      assert(restored === initial, `Could not restore original simulator appearance ${initial}; observed ${restored}.`);
    } finally {
      if (controlsMotion) {
        if (await getReduceMotion() !== initialMotion) await setReduceMotion(initialMotion);
        assert(await getReduceMotion() === initialMotion, 'Could not restore original Reduce Motion state.');
      }
    }
  }
}
