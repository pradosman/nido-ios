# Core baby-care validation note

## Sleep interval union

`CircularTimeline.Day.totalSleepSeconds` merges saved and active sleep intervals using their clipped `Date` bounds. `HistoryAnalytics` independently merges the same intervals before distributing seconds into elapsed 15-minute bins. Existing coverage checks saved overlap, saved/active overlap, an active interval clipped at midnight, and real elapsed sleep on Madrid DST transition dates.

The overlap expectations were changed after the union implementation was already present. The earlier focused run failed because the old additive expectation (11 minutes) disagreed with the then-written 5-minute expectation; review showed the correct union for that fixture is 8 minutes because the saved interval begins at 07:52 and the active interval ends at 08:00. The other changed fixture correctly unions to 10 minutes. This is not valid red-before-green evidence. No clean failing test run for the interval-union implementation was captured, so the TDD requirement for this behavior remains unverified. The original baby-care model test run failed at compile time because `BabyCareMetrics` and its model types did not exist yet; it does not prove the sleep-union behavior.

Regression coverage has since been added for overlapping saved and active intervals crossing midnight on both Madrid DST transition dates, at the `BabyCareMetrics.summary` and `HistoryAnalytics` bin levels. These tests were added after the union implementation, so they are regression coverage rather than red-before-green evidence.

## Event identity counting

Feed and diaper counts previously used every point item and could inflate when the input repeated an `Entry.id`. New tests first reproduced this in `BabyCareMetrics.summary` and `NidoMetrics.day`; both reported a count of two for the same event supplied twice, and NidoMetrics doubled the feed volume too. `CircularTimeline.day` now retains only the first occurrence of each ID, and `NidoMetrics.entries(on:from:calendar:)` applies the same ID deduplication so counts and feed volume agree. The duplicate-ID tests are proper red-before-green evidence for this change.

`BabyCareReconciliation.rebased(local:base:remote:)` now provides the pure CAS rebase primitive. Its initial focused run failed because the method did not exist. The green run verifies that local goal edits and remote measurement edits survive together, and that different edits to the same measurement return a conflict (`nil`). Goal versions are keyed by effective date, measurements by ID, and conflicting time-zone edits are also rejected.

## Verification performed for this note

For the duplicate-ID change and cross-midnight/DST regression cases, the focused suite passed 23 tests across 3 suites at `/tmp/nido-baby-care-robustness-green.log`. Rebase red and green logs are `/tmp/nido-baby-care-rebase-red.log` and `/tmp/nido-baby-care-rebase-green.log`. The final full suite passed 202 tests across 29 suites at `/tmp/nido-baby-care-robustness-full-final.log`. These checks used the separate `/tmp/nido-core-review-build` scratch directory. They don't change the lack of original red-run evidence for interval union itself.
