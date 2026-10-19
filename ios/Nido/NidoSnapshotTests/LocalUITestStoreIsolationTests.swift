import Foundation
import XCTest

@testable import Nido

#if DEBUG
@MainActor
final class LocalUITestStoreIsolationTests: XCTestCase {
    func testPhysicalDeviceLocalFixtureDisablesExternalEffects() {
        let store = makeStore(isSimulator: false)

        XCTAssertFalse(
            store.allowsExternalEffects,
            "A local UI-test fixture on a physical device must not allow live external effects."
        )
    }

    func testSimulatorLocalFixtureKeepsExternalEffectsEnabled() {
        let store = makeStore(isSimulator: true)

        XCTAssertTrue(
            store.allowsExternalEffects,
            "The simulator UI-test gallery relies on external effects remaining enabled."
        )
    }

#if targetEnvironment(simulator)
    func testSignOutDeletesOnlyTheRunScopedFixtureCredential() async throws {
        let runID = UUID().uuidString
        let credentialService = "com.momentumia.nido.uitests.\(runID)"
        let credentialStore = CredentialStore(service: credentialService)
        defer { credentialStore.delete() }

        try credentialStore.save(SessionCredential(
            accessToken: "sentinel-\(runID)",
            expiresAt: .now.addingTimeInterval(3_600),
            appleUserID: nil
        ))
        XCTAssertEqual(credentialStore.load()?.accessToken, "sentinel-\(runID)")

        let store = makeStore(runID: runID, isSimulator: true)
        await store.signOut()

        XCTAssertNil(
            credentialStore.load(),
            "Signing out the fixture must delete its run-scoped credential."
        )
    }
#endif

    private func makeStore(runID: String = UUID().uuidString, isSimulator: Bool) -> NidoStore {
        NidoApp.makeLocalUITestStore(runID: runID, referenceNow: .now, isSimulator: isSimulator)
    }
}
#endif
