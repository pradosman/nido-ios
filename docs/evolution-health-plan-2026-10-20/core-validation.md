# HITO1 core validation

The public surface is `EvolutionSummary.build(entries:measurements:now:calendar:)`. It returns one snapshot for each `EvolutionMetric` (`sleep`, `feeds`, `diapers`, `weight`, `height`). Care snapshots contain seven completed local calendar-day samples; missing days have `nil` values, and means divide only by recorded days. Sleep uses `BabyCareMetrics` so intervals crossing midnight are attributed to both days and elapsed seconds account for DST. Growth snapshots retain actual dated values in kg/cm, choose latest values independently by metric, and ignore future observations.

## TDD evidence

- **Initial contract RED:** `/tmp/nido-evolution-focused-red.log` records `swift test --jobs 2 --filter EvolutionSummaryTests` with `EvolutionSummary.swift` temporarily removed from the hydrated mirror. Compilation failed at the test call sites with `cannot find 'EvolutionSummary' in scope`, the expected missing-contract failure.
- **Future-sleep bug RED:** `/tmp/nido-evolution-future-sleep-red.log` records the focused suite failing the new regression case: expected yesterday's 3,600 seconds but got 86,400 because a sleep interval ending after `now` was included by `BabyCareMetrics`.
- **GREEN:** `/tmp/nido-evolution-future-sleep-green.log` records the focused command passing **5 tests in 1 suite** after future-dated entries were excluded from the sleep calculation. The DST case verifies a 5-hour entered interval spanning the local spring-forward transition contributes 1 elapsed hour to the prior day and 4 to the next; the 7-day mean uses both recorded days.
- **Full core suite:** `/tmp/nido-evolution-full-green.log` records `swift test --jobs 2` passing **214 tests in 32 suites**, including the 5 new tests.
- **Build / real scenario:** Swift Package debug compilation completed as part of `swift test`. No Xcode, simulator, or device build was run; HITO1 is a pure domain layer.
- **Rollback boundary:** Remove `EvolutionSummary.swift` and `EvolutionSummaryTests.swift`; no existing files or persisted data changed.

The DST test expectation was corrected after implementation because its interval crosses local midnight: elapsed sleep is split across both calendar days, and both recorded days contribute to the mean. The final test records that behavior.
