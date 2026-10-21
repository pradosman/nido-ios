# XCTest appearance inventory — 2026-10-21

The appearance ledger now matches every current XCTest source method under `ios/Nido/NidoUITests` and `ios/Nido/NidoSnapshotTests`, after excluding only `PhysicalDeviceVisualUITests.swift`. The phase-plan test discovers methods from source and compares their exact selector set with the fully expanded phase selectors, including mixed-appearance expansion.

## Red evidence

Before updating the ledger or phase classification, the new inventory test failed on the selector-set assertion. It found 29 nonphysical source selectors missing from the execution plan and two stale execution selectors:

- `NidoUITests/EvolutionDesignPreviewUITests/testDefaultRhythmTabKeepsItsExistingLabel` was renamed to `testIntegratedDefaultTabUsesEvolutionLabel`.
- `NidoUITests/SwiftUIImprovementUITests/testRhythmMetricValuesRespectLargestAccessibilityTextSize` was renamed to `testEvolutionMetricValuesRespectLargestAccessibilityTextSize`.

The 29 additions comprise 5 Snapshot selectors, 8 Evolution care-detail selectors, 6 Evolution design-preview selectors, 5 Evolution live-integration selectors, 1 Evolution sync-status selector, 1 sleep-clock selector, 2 sleep-live selectors, and 1 SwiftUI-improvement selector. The two Physical Device Visual UI methods remain excluded by the single explicit file exclusion.

## Green evidence

The expanded plan now contains 241 unique baseline identifiers and 244 unique executions. Three existing mixed selectors expand to six execution selectors. Phase counts are:

| Phase | Selectors |
| --- | ---: |
| Light UI | 158 |
| Local API UI | 3 |
| Snapshots | 70 |
| Dark UI | 11 |
| Light accessibility diagnostic | 1 |
| Dark accessibility diagnostic | 1 |

`SleepEvolutionDetailUITests.testSleepDetailUsesNativeNavigationAndChartInDarkAppearance` runs in Dark. Evolution live integration selectors remain in Light because their own launch helpers control appearance explicitly; `testNativeVisualCheckpoints` itself exercises Light, Dark, and accessibility states. Goal preview dark checks retain their existing Dark classification. Baby Care's mixed selector continues to expand into its existing Light and Dark selectors.

`node --test ios/Nido/Scripts/appearance-phase-plan.test.mjs ios/Nido/Scripts/appearance-result-validation.test.mjs` passed all 32 tests. The app's canonical phased UI/API run is tracked separately by the root task; this document does not claim that result.

## Rollback boundary

Treat only this block's changes to the planner, ledger, inventory test, and this evidence note as one reversible unit. Preserve the earlier uncommitted changes in those files; do not restore whole files from Git. No application source files were changed.
