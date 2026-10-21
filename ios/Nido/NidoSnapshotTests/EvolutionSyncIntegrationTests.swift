import Foundation
import XCTest
@testable import Nido

#if DEBUG
@MainActor
final class EvolutionSyncIntegrationTests: XCTestCase {
    func testEvolutionStatusIncludesQueuedGrowthAndOfflineState() async {
        let runID = UUID().uuidString
        let store = NidoApp.makeLocalUITestStore(runID: runID, referenceNow: .now, isSimulator: false)
        await store.prepareForUITesting(scenario: "evolution-live")
        store.babyCareNeedsSync = true
        store.isOffline = true

        let status = await store.evolutionSyncStatus(hasRecords: false)

        XCTAssertEqual(status.availability, .noRecords)
        XCTAssertTrue(status.isOffline)
        XCTAssertTrue(status.hasPendingChanges)
    }

    func testEvolutionStatusIncludesDurablyQueuedSharedSleepMutation() async throws {
        let runID = UUID().uuidString
        let domain = "com.momentumia.nido.evolution-sync-tests.\(runID)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "EvolutionSyncTests", directoryHint: .isDirectory)
            .appending(path: runID, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            defaults.removePersistentDomain(forName: domain)
            try? FileManager.default.removeItem(at: directory)
        }

        let now = Date(timeIntervalSince1970: 20_000)
        let credential = SessionCredential(accessToken: "evolution-sync-test", expiresAt: .distantFuture, appleUserID: nil)
        let credentialStore = CredentialStore(service: "com.momentumia.nido.evolution-sync-tests.\(runID)")
        let eventHub = RegistrationMutationEventHub()
        let service = NidoRegistrationServices.make(
            cache: LocalCache(fileURL: directory.appending(path: "snapshot.json")),
            credentialStore: credentialStore,
            stateDefaults: defaults,
            legacyDefaults: defaults,
            stateStore: RegistrationStateFileStore(fileURL: directory.appending(path: "registration-state.json")),
            eventHub: eventHub,
            credentialOverride: credential,
            now: { now },
            syncSleep: { _, _, _ in throw URLError(.notConnectedToInternet) },
            loadSleep: { _ in nil },
            allowsExternalEffects: false
        )
        let store = NidoStore(
            api: NidoAPI(baseURL: AppConfiguration.apiBaseURL),
            credentialStore: credentialStore,
            defaults: defaults,
            now: { now },
            shouldLoadCredential: false,
            initialAccessToken: credential.accessToken,
            registrationService: service,
            registrationEventHub: eventHub,
            allowsExternalEffects: false
        )
        store.phase = .ready

        let result = await service.startSleep()
        XCTAssertEqual(result.outcome, .sleepStarted)

        let status = await store.evolutionSyncStatus(hasRecords: true)
        XCTAssertTrue(status.hasPendingChanges)
    }
}
#endif
