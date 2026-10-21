# Evolution care detail core validation

## Validation

- TDD red: before `EvolutionCareDetail.swift` existed, `swift test --filter EvolutionCareDetailTests` failed to compile because `EvolutionCareSnapshot` could not be found. Captured output: `/tmp/nido-evolution-care-red.log`.
- Focused green: `swift test --filter EvolutionCareDetailTests` passed all 4 tests. Captured output: `/tmp/nido-evolution-care-focused.log`.
- Full suite: `swift test` passed all 232 tests in 35 suites. Captured output: `/tmp/nido-evolution-care-full.log`.
- The package build compiled the new core file. Validation mirror hashes: `3cd41b9fcc1289c409a924969ccbed5af0e61c083e47e5e350c9f4298a8f1fba` (`EvolutionCareDetail.swift`) and `e3ebbdfc11ea070e432202fcf916f3bd07b9c8c115b0715bf354467d747111f6` (`EvolutionCareDetailTests.swift`). No Xcode or simulator build was run.

## Covered behavior

Tests cover full week and half-year slots, completed-day averages, current-day hourly feed and diaper counts, duplicate ID removal, missing values staying `nil`, current-day and future record scoping, and delegation to the existing sleep snapshot and units.

## Rollback boundary

Reverting `EvolutionCareDetail.swift` and `EvolutionCareDetailTests.swift` removes this new care detail series API without changing the existing sleep or evolution summaries.
