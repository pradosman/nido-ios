import Foundation
import Testing
@testable import NidoCore

struct EvolutionPinnedPreferencesTests {
    @Test func defaultOrderAndNormalizationKeepFirstKnownMetricOccurrences() {
        #expect(EvolutionPinnedPreferences().pinnedMetrics == [.sleep, .feeds, .diapers, .weight, .height])

        let normalized = EvolutionPinnedPreferences(metricIDs: ["weight", "unknown", "feeds", "weight", "sleep"])
        #expect(normalized.pinnedMetrics == [.weight, .feeds, .sleep])
        #expect(EvolutionPinnedPreferences(metricIDs: []).pinnedMetrics.isEmpty)
    }

    @Test func togglingAndMovingPreserveOrderAndHandleInvalidOffsets() {
        var preferences = EvolutionPinnedPreferences()
        preferences.toggle(.sleep)
        preferences.move(fromOffsets: IndexSet(integer: 3), toOffset: 1)
        #expect(preferences.pinnedMetrics == [.feeds, .height, .diapers, .weight])

        let beforeInvalidMove = preferences
        preferences.move(fromOffsets: IndexSet([1, 99]), toOffset: -5)
        #expect(preferences.pinnedMetrics == [.height, .feeds, .diapers, .weight])
        #expect(preferences != beforeInvalidMove)
        preferences.toggle(.sleep)
        #expect(preferences.pinnedMetrics == [.height, .feeds, .diapers, .weight, .sleep])
        preferences.toggle(.sleep)
        #expect(preferences.pinnedMetrics == [.height, .feeds, .diapers, .weight])
    }

    @Test func scopedKeysAreDistinctForCaregiverAndBabyPairs() {
        let first = EvolutionPreferenceScope(caregiverID: "a.b", babyID: "c")
        let second = EvolutionPreferenceScope(caregiverID: "a", babyID: "b.c")
        let otherBaby = EvolutionPreferenceScope(caregiverID: "a.b", babyID: "d")

        #expect(first.defaultsKey != second.defaultsKey)
        #expect(first.defaultsKey != otherBaby.defaultsKey)
        #expect(!first.defaultsKey.contains("a.b"))
    }

    @Test func preferencesPersistAcrossStoreInstancesAndRemainScoped() throws {
        let domain = "com.momentumia.nido.evolution-preferences-tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let scope = EvolutionPreferenceScope(caregiverID: "caregiver-1", babyID: "primary")
        let store = EvolutionPinnedPreferencesStore(defaults: defaults, scope: scope)
        var saved = store.load()
        saved.toggle(.weight)
        saved.move(fromOffsets: IndexSet(integer: 3), toOffset: 1)
        store.save(saved)

        let reopened = EvolutionPinnedPreferencesStore(defaults: defaults, scope: scope)
        #expect(reopened.load() == saved)
        #expect(EvolutionPinnedPreferencesStore(
            defaults: defaults,
            scope: EvolutionPreferenceScope(caregiverID: "caregiver-2", babyID: "primary")
        ).load() == EvolutionPinnedPreferences())
        #expect(EvolutionPinnedPreferencesStore(
            defaults: defaults,
            scope: EvolutionPreferenceScope(caregiverID: "caregiver-1", babyID: "baby-2")
        ).load() == EvolutionPinnedPreferences())
    }

    @Test func missingMalformedAndVersionMismatchUseDefaultsButEmptyListPersists() throws {
        let domain = "com.momentumia.nido.evolution-preferences-tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let scope = EvolutionPreferenceScope(caregiverID: "caregiver-1", babyID: "primary")
        let store = EvolutionPinnedPreferencesStore(defaults: defaults, scope: scope)

        #expect(store.load() == EvolutionPinnedPreferences())
        defaults.set(Data("{bad json".utf8), forKey: scope.defaultsKey)
        #expect(store.load() == EvolutionPinnedPreferences())
        defaults.set(Data(#"{"schemaVersion":2,"pinnedMetricIDs":[]}"#.utf8), forKey: scope.defaultsKey)
        #expect(store.load() == EvolutionPinnedPreferences())

        store.save(EvolutionPinnedPreferences(pinnedMetrics: []))
        #expect(store.load().pinnedMetrics.isEmpty)
    }
}
