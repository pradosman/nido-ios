# Evolution preview selector inventory

The Light UI phase records seven selectors from `NidoUITests/EvolutionDesignPreviewUITests.swift`, including `testPreviewUsesNativeNavigationBarTitle`. The ledger now contains 205 unique selectors: Light 128, API 3, Snapshot 65, Dark 10, plus two raw diagnostics, for 208 planned executions.

This is a metadata-only update; unit TDD does not apply. The proportional checks verify the seven expected selectors are each in the baseline and Light exactly once, the baseline has 205 unique entries, the phase plan totals 208 with the expected per-phase counts, and no previous selector was removed. The Node suite has 30 tests (29 existing plus the inventory assertion); it is run during this update. The 208-execution simulator matrix has not been run; this remains the first visual checkpoint.
