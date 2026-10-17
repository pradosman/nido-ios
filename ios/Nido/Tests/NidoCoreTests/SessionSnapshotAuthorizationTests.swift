import Foundation
import Testing
@testable import NidoCore

struct SessionSnapshotAuthorizationTests {
    @Test(arguments: ["signed-out", "different-account", "expired"])
    func staleSessionCannotReplacePersistedSnapshot(scenario: String) async throws {
        let fixture = try SnapshotAuthorizationFixture()
        defer { fixture.cleanUp() }
        if scenario == "signed-out" {
            fixture.credentials.set(nil)
            await fixture.service.clearPrivateData()
        } else if scenario == "different-account" {
            fixture.credentials.set(SessionCredential(accessToken: "new", expiresAt: .distantFuture, appleUserID: nil))
        } else {
            fixture.credentials.set(SessionCredential(accessToken: "old", expiresAt: .distantPast, appleUserID: nil))
        }
        let before = try fixture.cache.load()
        await #expect(throws: APIError.missingCredential) {
            try await fixture.service.saveAppSnapshot(fixture.proposed, expectedAccessToken: "old")
        }
        let after = try fixture.cache.load()
        #expect(after.profile == before.profile)
        #expect(after.entries == before.entries)
        #expect(after.profileNeedsSync == before.profileNeedsSync)
    }

    @Test
    func matchingCredentialPersistsSnapshot() async throws {
        let fixture = try SnapshotAuthorizationFixture()
        defer { fixture.cleanUp() }
        _ = try await fixture.service.saveAppSnapshot(fixture.proposed, expectedAccessToken: "old")
        #expect(try fixture.cache.load().profile == fixture.proposed.profile)
    }

    @Test
    func omittedTokenPreservesCompatibilityWithoutCredential() async throws {
        let fixture = try SnapshotAuthorizationFixture()
        defer { fixture.cleanUp() }
        fixture.credentials.set(nil)
        _ = try await fixture.service.saveAppSnapshot(fixture.proposed)
        #expect(try fixture.cache.load().profile == fixture.proposed.profile)
    }
}

private struct SnapshotAuthorizationFixture {
    let directory: URL
    let suite: String
    let cache: LocalCache
    let credentials: SnapshotCredentialBox
    let service: RegistrationMutationService
    let proposed = NidoSnapshot(
        profile: Profile(caregiverName: "Old family", babyName: "Old baby", birthDate: "2026-01-01"),
        entries: [], pendingEntryIDs: [], profileNeedsSync: true
    )

    init() throws {
        let id = UUID().uuidString
        directory = FileManager.default.temporaryDirectory.appending(path: "SessionSnapshotAuthorization/\(id)")
        suite = "nido.snapshot-authorization.\(id)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        cache = LocalCache(fileURL: directory.appending(path: "snapshot.json"))
        try cache.save(.empty)
        let box = SnapshotCredentialBox(SessionCredential(accessToken: "old", expiresAt: .distantFuture, appleUserID: nil))
        credentials = box
        service = RegistrationMutationService(
            cache: cache,
            stateStore: RegistrationStateFileStore(fileURL: directory.appending(path: "state.json")),
            legacyDefaults: RegistrationStateDefaults(durable: defaults, legacy: defaults),
            dependencies: RegistrationMutationDependencies(
                loadCredential: { box.get() }, deleteCredential: { box.set(nil) },
                createEntry: { entry, _ in entry }, publishLocalCommit: { _ in },
                clearExternalState: {}, now: { Date() }, makeID: { UUID().uuidString }
            )
        )
    }

    func cleanUp() {
        UserDefaults.standard.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }
}

private final class SnapshotCredentialBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: SessionCredential?

    init(_ value: SessionCredential?) { self.value = value }
    func get() -> SessionCredential? { lock.withLock { value } }
    func set(_ value: SessionCredential?) { lock.withLock { self.value = value } }
}
