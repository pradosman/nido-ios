# Pinned Evolution preferences core

`EvolutionPinnedPreferences` is a pure value model with default order sleep, feeds, diapers, weight, height. It normalizes unknown IDs and duplicates while preserving the first known occurrence; an explicit empty array stays empty. `toggle(_:)` pins at the end or unpins. `move(fromOffsets:toOffset:)` uses Foundation `IndexSet`, filters invalid source positions, and clamps the destination.

`EvolutionPinnedPreferencesStore` reads and writes version-1 JSON through injected `UserDefaults`. Missing, malformed, or unsupported-version data returns the default order. `EvolutionPreferenceScope` accepts caregiver and baby IDs; the key is versioned and uses SHA-256 over length-prefixed UTF-8 components, so raw identifiers and baby names or birth dates do not appear in the key. The hash is collision-resistant; component boundaries are length-prefixed before hashing. The current single-baby caller should use the stable ID `primary` with the caregiver ID. When multiple babies exist, pass each real stable baby ID. Never use a baby name or birth date as the scope.

## Validation evidence

- **RED:** `/tmp/nido-evolution-pinned-preferences-red.log` records `swift test --jobs 2 --filter EvolutionPinnedPreferencesTests` before production code existed. Compilation failed because `EvolutionPinnedPreferences` and related preference types were not in scope, as expected.
- **Focused GREEN:** `/tmp/nido-evolution-pinned-preferences-green.log` records **5 tests in 1 suite passed**, covering default order, normalization, empty state, toggle, reorder and bounds, caregiver/baby isolation, persistence across new store instances, malformed JSON, and version mismatch.
- **Full core suite:** `/tmp/nido-evolution-pinned-preferences-full-green.log` records **237 tests in 36 suites passed**.
- **Build scenario:** The Swift package compiled as part of `swift test --jobs 2`. No Xcode build, simulator, device, or backend test was run for this pure local preferences layer.
- **Rollback boundary:** Remove `ios/Nido/Nido/Core/EvolutionPinnedPreferences.swift` and `ios/Nido/Tests/NidoCoreTests/EvolutionPinnedPreferencesTests.swift`; no existing model, store, backend, or persisted format was changed. The new key prefix and JSON schema are local to this preference store.
