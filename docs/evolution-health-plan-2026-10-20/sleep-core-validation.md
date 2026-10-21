# Sleep evolution core validation

## Validation

- TDD red: before `SleepEvolution.swift` existed, `swift test --filter SleepEvolutionTests` failed to compile because `SleepEvolutionPeriod` and `SleepEvolutionSnapshot` could not be found. This was the red phase for the initial contract tests.
- Period-ID contract red: before adding `periodRecordIDs`, the focused test failed to compile because `SleepEvolutionSnapshot` had no `periodRecordIDs` member. The captured output is at `/tmp/nido-sleep-period-recordids-red.log`.
- Date formatting TDD red: before adding `SleepEvolutionDateFormatting`, formatter tests failed to compile because the helper did not exist. The captured output is at `/tmp/nido-sleep-date-format-red.log`.
- Regression coverage: the later edge-case tests were added after implementation, so they are regression tests rather than TDD. A temporary mirror-only negative control that reverted hourly value handling produced runtime failures for completed hours 03–05 and active-only hours. Before the final slot expansion, a current-week test also failed because only the elapsed Monday slot was emitted. Those negative controls were reverted before final validation.
- Focused green: `swift test --filter SleepEvolutionTests` passed all 12 tests. Full output is saved at `/tmp/nido-sleep-focused.log`.
- Formatter focused green: `swift test --filter SleepEvolutionDateFormattingTests` passed both tests. Full output is saved at `/tmp/nido-sleep-date-format-focused.log`.
- Full suite: `swift test` passed all 228 tests in 34 suites. Full output is saved at `/tmp/nido-full-suite.log`.
- The macOS Swift package build compiled the changed core and formatter sources. Final validation mirror hashes: `df2dd59f421fc4c6597444065eb6b55de39313dd34cde3c4f963248e75c78f2a` (`SleepEvolution.swift`), `91abf4695ed9febcb325c60335e27279fc7ab89f59e60077caa7fcd84f1356de` (`SleepEvolutionTests.swift`), `d84dd665afd36b844153d8d4eb06e4edcb2283f05fa42ea07772bcb6e56bf894` (`SleepEvolutionDateFormatting.swift`), and `05a0a5bb6342cfa72d856cb072dae780c0232da32ad8a76e80f477edc4df0b18` (`SleepEvolutionDateFormattingTests.swift`). No Xcode build, simulator run, or signed build was run; those remain with the designated QA/build owner.
- The macOS Swift package build compiled the changed `SleepEvolution.swift` and `CircularTimeline.swift`. No Xcode build, simulator run, or signed build was run; those remain with the designated QA/build owner.

## Covered behavior

The tests cover injected calendar week boundaries, half-year boundaries and deterministic forward navigation clamping, complete calendar bucket slots, period-wide record IDs alongside completed-only aggregate IDs, 23/25-hour DST days, leap February, midnight clipping, duplicate ID removal and sleep interval union, weighted monthly and period means over completed recorded days, exclusion of future entries and incomplete days from multi-day means, and active sleep limited to today’s day view without inventing a record. Date-formatting tests cover Madrid and Honolulu day, month, date, and time rollover without changing the system time zone.

## Rollback boundary

The reversible change boundary is the new `SleepEvolution.swift` and `SleepEvolutionDateFormatting.swift`, their focused test files, and the visibility-only change to `CircularTimeline.unionSeconds`. Reverting those changes removes the sleep detail core contract and formatter without affecting existing sleep summaries or rendering behavior.
