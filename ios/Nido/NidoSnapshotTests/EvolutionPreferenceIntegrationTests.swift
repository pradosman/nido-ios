import Foundation
import XCTest
@testable import Nido

#if DEBUG
/// Store integration regressions added after the UI red/green persistence flow.
@MainActor
final class EvolutionPreferenceIntegrationTests: XCTestCase {
    func testEmptySelectionSurvivesStoreRecreation() async {
        let runID = UUID().uuidString
        defer { cleanup(runID) }
        let first = makeStore(runID)
        await first.prepareForUITesting(scenario: "evolution-live")
        first.saveEvolutionPinnedPreferences(EvolutionPinnedPreferences(pinnedMetrics: []))

        let reloaded = makeStore(runID)
        await reloaded.prepareForUITesting(scenario: "evolution-live")
        XCTAssertEqual(reloaded.evolutionPinnedPreferences.pinnedMetrics, [])
    }

    func testOrderedSelectionIsIsolatedBetweenCaregiversInOneStore() async {
        let runID = UUID().uuidString
        defer { cleanup(runID) }
        let store = makeStore(runID)
        await store.prepareForUITesting(scenario: "evolution-live")
        let firstCaregiver = store.currentCaregiver!
        store.saveEvolutionPinnedPreferences(EvolutionPinnedPreferences(pinnedMetrics: [.height, .sleep]))
        store.currentCaregiver = Caregiver(id: "other-caregiver", name: "Ana", role: .caregiver,
                                          status: .active, inviteCode: nil, createdAt: nil, joinedAt: nil)
        XCTAssertEqual(store.evolutionPinnedPreferences.pinnedMetrics, EvolutionPinnedPreferences.defaultOrder)
        store.saveEvolutionPinnedPreferences(EvolutionPinnedPreferences(pinnedMetrics: [.feeds]))
        store.currentCaregiver = firstCaregiver
        XCTAssertEqual(store.evolutionPinnedPreferences.pinnedMetrics, [.height, .sleep])
    }

    func testSignOutClearsPinPresentationAndPreventsAnonymousSave() async {
        let runID = UUID().uuidString
        defer { cleanup(runID) }
        let store = makeStore(runID)
        await store.prepareForUITesting(scenario: "evolution-live")
        store.saveEvolutionPinnedPreferences(EvolutionPinnedPreferences(pinnedMetrics: [.weight]))
        store.isEditingEvolutionPins = true
        await store.signOut()
        XCTAssertNil(store.evolutionPreferenceScope)
        XCTAssertFalse(store.isEditingEvolutionPins)
        store.saveEvolutionPinnedPreferences(EvolutionPinnedPreferences(pinnedMetrics: []))

        await store.prepareForUITesting(scenario: "evolution-live")
        XCTAssertEqual(store.evolutionPinnedPreferences.pinnedMetrics, [.weight])
        XCTAssertFalse(store.isEditingEvolutionPins)
    }

    private func makeStore(_ runID: String) -> NidoStore {
        NidoApp.makeLocalUITestStore(runID: runID, referenceNow: .now,
                                   isSimulator: false, preservesDefaults: true)
    }

    private func cleanup(_ runID: String) {
        UserDefaults.standard.removePersistentDomain(forName: "com.momentumia.nido.uitests.\(runID)")
        CredentialStore(service: "com.momentumia.nido.uitests.\(runID)").delete()
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "NidoUITests", directoryHint: .isDirectory)
            .appending(path: runID, directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: directory)
    }
}
#endif
