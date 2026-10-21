# Sleep Evolution live clock evidence

The LIVE sleep detail now receives a minute-timeline date from its sole caller. The detail view still resolves `previewSource.now` before the optional supplied date, keeping design previews frozen.

## TDD evidence

- Fixture setup uses one shared reference-time plus system-uptime provider for the local UI-test store and registration service. The opt-in `NIDO_UI_TEST_TICKING_CLOCK=1` path seeds an active sleep five minutes before the clock after `prepareForUITesting` completes.
- The first fixture test action was discarded as TDD evidence: compilation stopped at `NidoApp.swift:51` because the local provider needed the `@Sendable () -> Date` type expected by the store/service. The provider type was corrected before the behavioral red run.
- Valid red: on QA simulator `4A7A40BF-4FEE-41F7-9019-1D1F5F5B04AD` (iOS 26.5), the active marker existed and the nonempty summary started at `5 min`. After 90 seconds idle, the label remained `5 min`, so the label-change expectation timed out. Log: `/tmp/nido-sleep-clock-red-2-20261021.log`; result: `/tmp/nido-sleep-clock-red-2-20261021.xcresult`.
- Focused green: the same test passed after adding the LIVE timeline date. It observed the summary change without interaction and confirmed the active-sleep marker remained visible. Log: `/tmp/nido-sleep-clock-green-20261021.log`; result: `/tmp/nido-sleep-clock-green-20261021.xcresult`.
- After that green, review strengthened the change predicate to require the element to exist and its label to be nonempty as well as changed. The strengthened assertion was not rerun in the focused clock action; final app-suite validation is pending.
- Frozen-preview regression: `SleepEvolutionDetailUITests.testSleepCardOpensNativeSleepDetail` passed with the expected `12 h 30 min` summary. Log: `/tmp/nido-sleep-clock-preview-20261021.log`; result: `/tmp/nido-sleep-clock-preview-20261021.xcresult`.

No Core files changed in this block. The parent is running the final full app, Core, and Release validation. No commit was created; rollback is limited to this block's injected-date/timeline changes, the opt-in ticking fixture seam, the new UI test, and this evidence note. Preserve other edits in shared `NidoApp.swift` when rolling back its fixture seam.
