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
  assert(baseline.length === 164, `Expected the 164-test baseline ledger, received ${baseline.length}.`);

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
  assert(lightUI.length === 111, `Expected 111 non-API Light UI cases, got ${lightUI.length}.`);
  assert(apiUI.length === 3, `Expected 3 API UI cases, got ${apiUI.length}.`);
  assert(snapshots.length === 43, `Expected 43 Snapshot cases, got ${snapshots.length}.`);
  assert(darkUI.length === 10, `Expected 10 Dark UI cases, got ${darkUI.length}.`);
  assert(phaseIDs.length === 167, `Expected 167 phase executions, got ${phaseIDs.length}.`);
  assert(originalToExecutions.size === 164, 'Every baseline test must map to a phase execution.');

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

export async function runAppearancePhases(phases, { getAppearance, setAppearance, runPhase }) {
  const initial = await getAppearance();
  assert(initial === 'light' || initial === 'dark', `Cannot restore unknown simulator appearance: ${initial}`);
  try {
    for (const phase of phases) {
      await setAppearance(phase.appearance);
      const observed = await getAppearance();
      assert(observed === phase.appearance, `Simulator did not enter ${phase.appearance} before ${phase.name}; observed ${observed}.`);
      await runPhase(phase);
    }
  } finally {
    if (await getAppearance() !== initial) await setAppearance(initial);
    const restored = await getAppearance();
    assert(restored === initial, `Could not restore original simulator appearance ${initial}; observed ${restored}.`);
  }
}
