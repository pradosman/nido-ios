import Foundation
import XCTest

@testable import Nido

@MainActor
final class SessionLifecycleTests: XCTestCase {
    func testLegacyGrowthDeleteUsesExistingOfflineEntryDeletionWhenNoWireCopyExists() async throws {
        let fixture = try makeBabyCareDeleteStore(failEntryDelete: true)
        defer { fixture.cleanup() }
        let source = legacyGrowthEntry(id: "legacy-growth")
        fixture.store.currentCaregiver = Caregiver(
            id: "owner", name: "David", role: .owner, status: .active,
            inviteCode: nil, createdAt: nil, joinedAt: nil
        )
        fixture.store.entries = [source]
        fixture.store.babyCareState = BabyCareState(revision: 1, timeZoneID: "Europe/Madrid")

        let deleted = await fixture.store.deleteGrowthMeasurement(id: source.id)

        XCTAssertTrue(deleted)
        XCTAssertTrue(fixture.store.entries.isEmpty)
        XCTAssertEqual(fixture.defaults.stringArray(forKey: "pendingDeletionIDs"), [source.id])
        XCTAssertEqual(fixture.recorder.paths, ["/api/nido/entries"])
    }

    func testDeletingAnExplicitOverrideAlsoDeletesItsLegacySourceEntry() async throws {
        let override = GrowthMeasurement(id: "shared-growth", measuredAt: 1_797_000_000_000, weightGrams: 7_000)
        let fixture = try makeBabyCareDeleteStore(failEntryDelete: false)
        defer { fixture.cleanup() }
        let source = legacyGrowthEntry(id: override.id)
        fixture.store.currentCaregiver = Caregiver(
            id: "owner", name: "David", role: .owner, status: .active,
            inviteCode: nil, createdAt: nil, joinedAt: nil
        )
        fixture.store.entries = [source]
        fixture.store.babyCareState = BabyCareState(revision: 1, timeZoneID: "Europe/Madrid", measurements: [override])

        let deleted = await fixture.store.deleteGrowthMeasurement(id: override.id)

        XCTAssertTrue(deleted)
        XCTAssertTrue(fixture.store.entries.isEmpty)
        XCTAssertTrue(fixture.store.babyCareState.measurements.isEmpty)
        XCTAssertEqual(fixture.recorder.paths, ["/api/nido/baby-care", "/api/nido/entries"])
    }

    func testEditingLegacyGrowthUpdatesItsEntryWithoutCreatingWireOverride() async throws {
        let fixture = try makeBabyCareDeleteStore(failEntryDelete: false)
        defer { fixture.cleanup() }
        let source = legacyGrowthEntry(id: "legacy-edit-growth")
        fixture.store.currentCaregiver = Caregiver(
            id: "owner", name: "David", role: .owner, status: .active,
            inviteCode: nil, createdAt: nil, joinedAt: nil
        )
        fixture.store.entries = [source]
        _ = try await fixture.service.saveAppSnapshot(
            NidoSnapshot(profile: nil, entries: [source], pendingEntryIDs: [], profileNeedsSync: false)
        )
        fixture.store.babyCareState = BabyCareState(revision: 1, timeZoneID: "Europe/Madrid")
        let updatedAt = Int64(Date.now.addingTimeInterval(-60).timeIntervalSince1970 * 1_000)

        let saved = await fixture.store.saveGrowthMeasurement(GrowthMeasurement(
            id: source.id,
            measuredAt: updatedAt,
            weightGrams: 7_000,
            heightMillimeters: 650,
            note: "Control"
        ))

        XCTAssertTrue(saved)
        XCTAssertEqual(fixture.store.babyCareState.measurements, [])
        XCTAssertEqual(fixture.store.entries.first?.occurredAt, updatedAt)
        XCTAssertTrue(fixture.store.entries.first?.detail.contains("7 kg") == true)
        XCTAssertTrue(fixture.store.entries.first?.detail.contains("65 cm") == true)
        XCTAssertEqual(fixture.store.entries.first.flatMap(LegacyGrowthMeasurement.init(entry:))?.weightKilograms, 7)
        XCTAssertEqual(fixture.store.entries.first.flatMap(LegacyGrowthMeasurement.init(entry:))?.heightCentimeters, 65)
        XCTAssertEqual(fixture.recorder.paths, ["/api/nido/entries"])
    }

    func testLegacyGrowthDisplayDoesNotAutomaticallyPersistAServerMigration() async throws {
        let id = UUID().uuidString
        let suite = "nido.baby-care-legacy-load.\(id)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appending(path: id, directoryHint: .isDirectory)
        let source = legacyGrowthEntry(id: "legacy-load-growth")
        let recorder = BabyCareDeleteRequestRecorder()
        let api = NidoAPI(baseURL: URL(string: "https://baby-care-legacy-load.test")!) { request in
            recorder.record("\(request.httpMethod ?? "") \(request.url?.path ?? "")")
            let body: String
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/nido/sleep"), ("PUT", "/api/nido/sleep"):
                body = #"{"activeSleepStartedAt":null}"#
            case ("GET", "/api/nido"):
                body = #"{"profile":{"caregiverName":"David","babyName":"Marco","birthDate":"2026-08-01"},"entries":[{"id":"legacy-load-growth","kind":"health","title":"Cuidados","detail":"Medidas · 6,5 kg · 64 cm","occurredAt":1797000000000,"durationMinutes":null,"amountMl":null}],"nextCursor":null,"caregivers":[{"id":"owner","name":"David","role":"owner","status":"active","inviteCode":null,"createdAt":null,"joinedAt":null}],"currentCaregiverID":"owner"}"#
            case ("GET", "/api/nido/baby-care"):
                body = #"{"state":null}"#
            default:
                body = #"{"error":"unexpected route"}"#
            }
            return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!)
        }
        let credential = SessionCredential(accessToken: id, expiresAt: .distantFuture, appleUserID: nil)
        let eventHub = RegistrationMutationEventHub()
        let registrationService = NidoRegistrationServices.make(
            api: api,
            cache: LocalCache(fileURL: directory.appending(path: "snapshot.json")),
            stateDefaults: defaults,
            legacyDefaults: defaults,
            stateStore: RegistrationStateFileStore(fileURL: directory.appending(path: "state.json")),
            eventHub: eventHub,
            credentialOverride: credential,
            allowsExternalEffects: false
        )
        let store = NidoStore(
            api: api,
            babyCareCache: BabyCareCache(fileURL: directory.appending(path: "baby-care.json")),
            defaults: defaults,
            now: { Date(timeIntervalSince1970: 1_797_000_000) },
            shouldLoadCredential: false,
            initialAccessToken: id,
            registrationService: registrationService,
            registrationEventHub: eventHub,
            allowsExternalEffects: false
        )
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }

        await store.load()

        XCTAssertTrue(store.babyCareState.measurements.isEmpty)
        XCTAssertEqual(BabyCareReconciliation.mergedMeasurements(state: store.babyCareState, entries: store.entries).count, 1)
        XCTAssertFalse(recorder.paths.contains("PUT /api/nido/baby-care"))
    }

    func testConcurrentBabyCareSaveRebasesChangeMadeWhileFirstPutIsSuspended() async throws {
        let gate = SuspendedBabyCareSaveTransport()
        let api = NidoAPI(baseURL: URL(string: "https://baby-care-race.test")!, transport: { request in
            try await gate.respond(to: request)
        })
        let fixture = try makeBabyCareDeleteStore(failEntryDelete: false, apiOverride: api)
        defer { fixture.cleanup() }
        fixture.store.currentCaregiver = Caregiver(
            id: "owner", name: "David", role: .owner, status: .active,
            inviteCode: nil, createdAt: nil, joinedAt: nil
        )
        fixture.store.babyCareState = BabyCareState(revision: 1, timeZoneID: "Europe/Madrid")
        let measuredAt = Int64(Date.now.addingTimeInterval(-60).timeIntervalSince1970 * 1_000)
        let firstMeasurement = GrowthMeasurement(id: "race-first", measuredAt: measuredAt, weightGrams: 6_700)
        let secondMeasurement = GrowthMeasurement(id: "race-second", measuredAt: measuredAt, heightMillimeters: 640)

        let firstSave = Task { await fixture.store.saveGrowthMeasurement(firstMeasurement) }
        await fulfillment(of: [gate.firstPutStarted], timeout: 3)
        let secondSaved = await fixture.store.saveGrowthMeasurement(secondMeasurement)
        XCTAssertTrue(secondSaved)
        gate.releaseFirstPut()
        let firstSaved = await firstSave.value
        XCTAssertTrue(firstSaved)
        await fulfillment(of: [gate.secondPutStarted], timeout: 3)
        for _ in 0..<100 where fixture.store.babyCareNeedsSync {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertFalse(fixture.store.babyCareNeedsSync)
        XCTAssertFalse(fixture.store.babyCareHasConflict)
        XCTAssertEqual(Set(fixture.store.babyCareState.measurements.map(\.id)), [firstMeasurement.id, secondMeasurement.id])
    }

    func testOfflineCachedHouseholdDoesNotPromoteUnknownCaregiverToOwner() async throws {
        let id = UUID().uuidString
        let suite = "nido.offline-role.\(id)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appending(path: id, directoryHint: .isDirectory)
        let credential = SessionCredential(accessToken: id, expiresAt: .distantFuture, appleUserID: nil)
        let api = NidoAPI(baseURL: URL(string: "https://offline-role.test")!) { _ in throw URLError(.notConnectedToInternet) }
        let eventHub = RegistrationMutationEventHub()
        let service = NidoRegistrationServices.make(
            api: api,
            cache: LocalCache(fileURL: directory.appending(path: "snapshot.json")),
            stateDefaults: defaults,
            legacyDefaults: defaults,
            stateStore: RegistrationStateFileStore(fileURL: directory.appending(path: "state.json")),
            eventHub: eventHub,
            credentialOverride: credential,
            allowsExternalEffects: false
        )
        let profile = Profile(caregiverName: "David", babyName: "Marco", birthDate: "2026-08-01")
        _ = try await service.saveAppSnapshot(NidoSnapshot(profile: profile, entries: [], pendingEntryIDs: [], profileNeedsSync: false))
        let cache = BabyCareCache(fileURL: directory.appending(path: "baby-care.json"))
        let growth = GrowthMeasurement(id: "offline-growth", measuredAt: 1_797_000_000_000, weightGrams: 6_800)
        try cache.save(BabyCareCacheSnapshot(state: BabyCareState(revision: 3, timeZoneID: "Europe/Madrid", measurements: [growth]), baseState: nil, conflictedRemoteState: nil, needsSync: false))
        let store = NidoStore(api: api, babyCareCache: cache, defaults: defaults, shouldLoadCredential: false, initialAccessToken: id, registrationService: service, registrationEventHub: eventHub, allowsExternalEffects: false)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }

        await store.load()

        XCTAssertFalse(store.canEditGoals)
        XCTAssertTrue(store.babyCareState.measurements.contains(where: { $0.id == growth.id }), "Offline growth history remains available")
    }

    func testConfirmedOwnerCanRestoreMatchingOfflineCacheAndSignOutClearsRole() async throws {
        let id = UUID().uuidString
        let suite = "nido.cached-owner-role.\(id)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appending(path: id, directoryHint: .isDirectory)
        let credential = SessionCredential(accessToken: id, expiresAt: .distantFuture, appleUserID: nil)
        let onlineAPI = NidoAPI(baseURL: URL(string: "https://online-owner.test")!) { request in
            guard let path = request.url?.path else { throw APIError.invalidResponse }
            switch (request.httpMethod, path) {
            case ("GET", "/api/nido/sleep"), ("PUT", "/api/nido/sleep"):
                return Self.response(request, #"{"activeSleepStartedAt":null}"#)
            case ("GET", "/api/nido"):
                return Self.response(request, #"{"profile":{"caregiverName":"David","babyName":"Marco","birthDate":"2026-08-01"},"entries":[],"nextCursor":null,"caregivers":[{"id":"owner","name":"David","role":"owner","status":"active"}],"currentCaregiverID":"owner"}"#)
            case ("GET", "/api/nido/baby-care"):
                return Self.response(request, #"{"state":null}"#)
            default:
                throw URLError(.unsupportedURL)
            }
        }
        let eventHub = RegistrationMutationEventHub()
        let service = NidoRegistrationServices.make(
            api: onlineAPI,
            cache: LocalCache(fileURL: directory.appending(path: "snapshot.json")),
            stateDefaults: defaults,
            legacyDefaults: defaults,
            stateStore: RegistrationStateFileStore(fileURL: directory.appending(path: "state.json")),
            eventHub: eventHub,
            credentialOverride: credential,
            allowsExternalEffects: false
        )
        let cache = BabyCareCache(fileURL: directory.appending(path: "baby-care.json"))
        let originalStore = NidoStore(api: onlineAPI, babyCareCache: cache, defaults: defaults, shouldLoadCredential: false, initialAccessToken: id, registrationService: service, registrationEventHub: eventHub, allowsExternalEffects: false)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        await originalStore.load()
        XCTAssertTrue(originalStore.canEditGoals)
        let cachedEnvelope = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: cache.fileURL)) as? [String: Any])
        XCTAssertNotNil(cachedEnvelope["confirmedCaregiver"], "The owner role is persisted in the private cache after server confirmation")
        XCTAssertNotNil(cachedEnvelope["sessionBinding"], "The cached role is bound to this credential")
        XCTAssertFalse(String(data: try JSONSerialization.data(withJSONObject: cachedEnvelope), encoding: .utf8)!.contains(id), "The cache must not store the raw session token")

        let offlineAPI = NidoAPI(baseURL: URL(string: "https://offline-owner.test")!) { request in
            if request.url?.path == "/api/nido/auth/logout" { return Self.response(request, #"{"loggedOut":true}"#) }
            throw URLError(.notConnectedToInternet)
        }
        let otherCredentialCache = BabyCareCache(fileURL: directory.appending(path: "other-session-baby-care.json"))
        try FileManager.default.createDirectory(at: otherCredentialCache.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contentsOf: cache.fileURL).write(to: otherCredentialCache.fileURL)
        let otherCredentialStore = NidoStore(api: offlineAPI, babyCareCache: otherCredentialCache, defaults: defaults, shouldLoadCredential: false, initialAccessToken: "different-\(id)", registrationService: service, registrationEventHub: eventHub, allowsExternalEffects: false)
        await otherCredentialStore.load()
        XCTAssertFalse(otherCredentialStore.canEditGoals, "A cached owner role must not transfer to a different session")

        let restoredStore = NidoStore(api: offlineAPI, babyCareCache: cache, defaults: defaults, shouldLoadCredential: false, initialAccessToken: id, registrationService: service, registrationEventHub: eventHub, allowsExternalEffects: false)
        await restoredStore.load()
        XCTAssertTrue(restoredStore.canEditGoals, "A confirmed owner role restores for the same cached session")

        await restoredStore.signOut()
        XCTAssertFalse(restoredStore.canEditGoals)
        XCTAssertNil(restoredStore.currentCaregiver)
    }

    func testCachedOwnerRoleIsNotTransferredToDifferentCredential() async throws {
        let id = UUID().uuidString
        let suite = "nido.cached-owner-binding.\(id)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appending(path: id, directoryHint: .isDirectory)
        let credential = SessionCredential(accessToken: id, expiresAt: .distantFuture, appleUserID: nil)
        let onlineAPI = NidoAPI(baseURL: URL(string: "https://online-owner.test")!) { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/nido/sleep"), ("PUT", "/api/nido/sleep"):
                return Self.response(request, #"{"activeSleepStartedAt":null}"#)
            case ("GET", "/api/nido"):
                return Self.response(request, #"{"profile":{"caregiverName":"David","babyName":"Marco","birthDate":"2026-08-01"},"entries":[],"nextCursor":null,"caregivers":[{"id":"owner","name":"David","role":"owner","status":"active"}],"currentCaregiverID":"owner"}"#)
            case ("GET", "/api/nido/baby-care"):
                return Self.response(request, #"{"state":null}"#)
            default:
                throw URLError(.unsupportedURL)
            }
        }
        let eventHub = RegistrationMutationEventHub()
        let service = NidoRegistrationServices.make(api: onlineAPI, cache: LocalCache(fileURL: directory.appending(path: "snapshot.json")), stateDefaults: defaults, legacyDefaults: defaults, stateStore: RegistrationStateFileStore(fileURL: directory.appending(path: "state.json")), eventHub: eventHub, credentialOverride: credential, allowsExternalEffects: false)
        let cache = BabyCareCache(fileURL: directory.appending(path: "baby-care.json"))
        let ownerStore = NidoStore(api: onlineAPI, babyCareCache: cache, defaults: defaults, shouldLoadCredential: false, initialAccessToken: id, registrationService: service, registrationEventHub: eventHub, allowsExternalEffects: false)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        await ownerStore.load()
        XCTAssertTrue(ownerStore.canEditGoals)

        let differentSessionStore = NidoStore(
            api: NidoAPI(baseURL: URL(string: "https://different-session.test")!) { _ in throw URLError(.notConnectedToInternet) },
            babyCareCache: cache,
            defaults: defaults,
            shouldLoadCredential: false,
            initialAccessToken: "different-\(id)",
            registrationService: service,
            registrationEventHub: eventHub,
            allowsExternalEffects: false
        )
        await differentSessionStore.load()

        XCTAssertFalse(differentSessionStore.canEditGoals)
    }

    func testBackupImportCannotRestoreGrowthAfterSignOutDuringProfileWrite() async throws {
        let id = UUID().uuidString
        let suite = "nido.backup-session-fence.\(id)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appending(path: id, directoryHint: .isDirectory)
        let credential = SessionCredential(accessToken: id, expiresAt: .distantFuture, appleUserID: nil)
        let transport = SuspendedBackupProfileTransport()
        let api = NidoAPI(baseURL: URL(string: "https://backup-session-fence.test")!, transport: { request in
            try await transport.respond(to: request)
        })
        let eventHub = RegistrationMutationEventHub()
        let service = NidoRegistrationServices.make(
            api: api,
            cache: LocalCache(fileURL: directory.appending(path: "snapshot.json")),
            stateDefaults: defaults,
            legacyDefaults: defaults,
            stateStore: RegistrationStateFileStore(fileURL: directory.appending(path: "state.json")),
            eventHub: eventHub,
            credentialOverride: credential,
            allowsExternalEffects: false
        )
        let babyCareCache = BabyCareCache(fileURL: directory.appending(path: "baby-care.json"))
        let store = NidoStore(api: api, babyCareCache: babyCareCache, defaults: defaults, shouldLoadCredential: false, initialAccessToken: id, registrationService: service, registrationEventHub: eventHub, allowsExternalEffects: false)
        store.currentCaregiver = Caregiver(id: "owner", name: "David", role: .owner, status: .active, inviteCode: nil, createdAt: nil, joinedAt: nil)
        let profile = Profile(caregiverName: "David", babyName: "Marco", birthDate: "2026-08-01")
        let imported = GrowthMeasurement(id: "late-backup-growth", measuredAt: 1_797_000_000_000, weightGrams: 7_000)
        let backup = NidoBackup(version: 1, exportedAt: .now, profile: profile, caregivers: [], entries: [], babyCareState: BabyCareState(revision: 0, timeZoneID: "Europe/Madrid", measurements: [imported]))
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }

        let restore = Task { await store.restoreBackup(backup) }
        await fulfillment(of: [transport.profileWriteStarted], timeout: 3)
        await store.signOut()
        transport.releaseProfileWrite()
        await restore.value

        XCTAssertTrue(store.babyCareState.measurements.isEmpty)
        XCTAssertFalse(transport.paths.contains("PUT /api/nido/baby-care"))
    }

    func testFailedEntryUpdateKeepsEditorAndOriginalEntryForRetry() async throws {
        let id = UUID().uuidString
        let suite = "nido.editor-storage.\(id)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appending(path: id)
        let cacheURL = directory.appending(path: "cache.json")
        let cache = LocalCache(fileURL: cacheURL)
        let original = Entry(id: "entry", kind: .diaper, title: "Pañal", detail: "Pis",
                             occurredAt: 1_000, durationMinutes: nil, amountMl: nil)
        let draft = original.edited(detail: "Pis y caca · Borrador conservado", occurredAt: original.date,
                                    durationMinutes: nil, amountMl: nil)
        try cache.save(NidoSnapshot(profile: nil, entries: [original], pendingEntryIDs: [], profileNeedsSync: false))
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let credential = SessionCredential(accessToken: id, expiresAt: .distantFuture, appleUserID: nil)
        let service = RegistrationMutationService(
            cache: cache,
            stateStore: RegistrationStateFileStore(fileURL: directory.appending(path: "state.json")),
            legacyDefaults: RegistrationStateDefaults(durable: defaults, legacy: defaults),
            dependencies: RegistrationMutationDependencies(
                loadCredential: { credential }, deleteCredential: {},
                createEntry: { entry, _ in entry }, publishLocalCommit: { _ in },
                clearExternalState: {}, now: { .now }, makeID: { UUID().uuidString }
            )
        )
        _ = try await service.snapshot()
        // A directory at the snapshot path reproduces an actual atomic disk-write failure.
        try FileManager.default.removeItem(at: cacheURL)
        try FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: false)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SessionRaceURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        SessionRaceURLProtocol.install(DelayedSessionResponse(status: 200, path: "/unused"))
        let api = NidoAPI(baseURL: try XCTUnwrap(URL(string: "https://editor-storage.test")), session: session)
        let store = NidoStore(api: api, defaults: defaults, shouldLoadCredential: false, initialAccessToken: id,
                              registrationService: service, registrationEventHub: RegistrationMutationEventHub())
        store.entries = [original]
        store.editingEntry = original
        store.recentlyCreatedEntry = original

        let saved = await store.updateEntry(draft)

        XCTAssertFalse(saved, "The editor must receive an explicit failure instead of dismissing")
        XCTAssertEqual(store.editingEntry, original, "A failed local write must keep the editor open with its draft")
        XCTAssertEqual(store.entries, [original], "An unpersisted edit must not appear saved")
        XCTAssertEqual(store.recentlyCreatedEntry, original)
        XCTAssertTrue(defaults.stringArray(forKey: "pendingUpdatedEntryIDs")?.isEmpty ?? true)
        let persisted = try await service.snapshot().0
        XCTAssertEqual(persisted.entries, [original])
        XCTAssertNotNil(store.notice)

        try FileManager.default.removeItem(at: cacheURL)
        let retried = await store.updateEntry(draft)
        XCTAssertTrue(retried, "The same retained draft must remain saveable after storage recovers")
        XCTAssertNil(store.editingEntry)
        XCTAssertEqual(store.entries, [draft])
        XCTAssertEqual(try cache.load().entries, [draft])
    }

    func testLateLoadCannotRestoreDataAfterSignOut() async throws {
        try await assertLateLoadIsDiscarded(status: 200)
    }

    func testLateUnauthorizedLoadCannotChangeSignedOutState() async throws {
        try await assertLateLoadIsDiscarded(status: 401)
    }

    func testLatePendingProfileSyncCannotRestorePrivateDataAfterSignOut() async throws {
        try await assertLateLoadIsDiscarded(status: 200, pendingProfile: true)
    }

    private func assertLateLoadIsDiscarded(status: Int, pendingProfile: Bool = false) async throws {
        let id = UUID().uuidString
        let suite = "nido.session-race.\(id)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appending(path: id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let cache = LocalCache(fileURL: directory.appending(path: "cache.json"))
        if pendingProfile {
            try cache.save(NidoSnapshot(
                profile: Profile(caregiverName: "Old family", babyName: "Old baby", birthDate: "2026-01-01"),
                entries: [], pendingEntryIDs: [], profileNeedsSync: true
            ))
        }
        let credentialStore = CredentialStore(service: suite)
        defer {
            defaults.removePersistentDomain(forName: suite)
            credentialStore.delete()
            if FileManager.default.fileExists(atPath: directory.path) {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let credential = SessionCredential(accessToken: id, expiresAt: .distantFuture, appleUserID: nil)
        let controller = DelayedSessionResponse(status: status, path: pendingProfile ? "/api/nido/profile" : "/api/nido")
        SessionRaceURLProtocol.install(controller)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SessionRaceURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let api = NidoAPI(baseURL: try XCTUnwrap(URL(string: "https://session-race.test")), session: session)
        let hub = RegistrationMutationEventHub()
        let service = NidoRegistrationServices.make(
            api: api, cache: cache, credentialStore: credentialStore,
            stateDefaults: defaults, legacyDefaults: defaults,
            stateStore: RegistrationStateFileStore(fileURL: directory.appending(path: "state.json")),
            eventHub: hub, credentialOverride: credential,
            loadSleep: { _ in nil }
        )
        let store = NidoStore(
            api: api, credentialStore: credentialStore, defaults: defaults,
            shouldLoadCredential: false, initialAccessToken: id,
            registrationService: service, registrationEventHub: hub
        )
        let loading = Task { await store.load() }
        await fulfillment(of: [controller.started], timeout: 5)
        await store.signOut()
        XCTAssertEqual(store.phase, .authentication)
        controller.release()
        await loading.value

        XCTAssertEqual(store.phase, .authentication, "A response from the old session must not reopen the household")
        XCTAssertNil(store.profile, "Private profile must stay cleared")
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertNil(credentialStore.load())
        let snapshot = try await service.snapshot().0
        XCTAssertNil(snapshot.profile, "A late response must not repopulate the cache")
        XCTAssertTrue(snapshot.entries.isEmpty)
        XCTAssertNil(store.notice, "Old authorization errors must not replace the signed-out screen")
    }

    private func makeBabyCareDeleteStore(
        failEntryDelete: Bool,
        apiOverride: NidoAPI? = nil
    ) throws -> (store: NidoStore, service: RegistrationMutationService, defaults: UserDefaults, recorder: BabyCareDeleteRequestRecorder, cleanup: () -> Void) {
        let id = UUID().uuidString
        let suite = "nido.baby-care-delete.\(id)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appending(path: id, directoryHint: .isDirectory)
        let recorder = BabyCareDeleteRequestRecorder()
        let api = apiOverride ?? NidoAPI(baseURL: URL(string: "https://baby-care-delete.test")!) { request in
            recorder.record(request.url?.path ?? "")
            let (status, body): (Int, String)
            switch (request.httpMethod, request.url?.path) {
            case ("PUT", "/api/nido/entries"):
                status = 200
                body = #"{"entry":{"id":"legacy-edit-growth","kind":"health","title":"Cuidados","detail":"Medidas · 7 kg · 65 cm","occurredAt":1797000000000,"durationMinutes":null,"amountMl":null}}"#
            case ("PUT", "/api/nido/baby-care"):
                status = 200
                body = #"{"state":{"revision":2,"timeZoneID":"Europe/Madrid","goalVersions":[],"measurements":[]}}"#
            case ("DELETE", "/api/nido/entries"):
                status = failEntryDelete ? 503 : 200
                body = failEntryDelete ? #"{"error":"offline"}"# : #"{"deleted":"shared-growth"}"#
            default:
                status = 404
                body = #"{"error":"unexpected route"}"#
            }
            return (
                Data(body.utf8),
                HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            )
        }
        let credential = SessionCredential(accessToken: id, expiresAt: .distantFuture, appleUserID: nil)
        let eventHub = RegistrationMutationEventHub()
        let registrationService = NidoRegistrationServices.make(
            api: api,
            cache: LocalCache(fileURL: directory.appending(path: "snapshot.json")),
            stateDefaults: defaults,
            legacyDefaults: defaults,
            stateStore: RegistrationStateFileStore(fileURL: directory.appending(path: "state.json")),
            eventHub: eventHub,
            credentialOverride: credential,
            allowsExternalEffects: false
        )
        let store = NidoStore(
            api: api,
            babyCareCache: BabyCareCache(fileURL: directory.appending(path: "baby-care.json")),
            defaults: defaults,
            shouldLoadCredential: false,
            initialAccessToken: id,
            registrationService: registrationService,
            registrationEventHub: eventHub,
            allowsExternalEffects: false
        )
        return (store, registrationService, defaults, recorder, {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        })
    }

    nonisolated private static func response(_ request: URLRequest, _ body: String) -> (Data, URLResponse) {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        return (Data(body.utf8), response)
    }

    private func legacyGrowthEntry(id: String) -> Entry {
        Entry(
            id: id, kind: .health, title: "Cuidados", detail: "Medidas · 6,5 kg · 64 cm",
            occurredAt: 1_797_000_000_000, durationMinutes: nil, amountMl: nil
        )
    }
}

private final class BabyCareDeleteRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var paths: [String] { lock.withLock { storage } }
    func record(_ path: String) { lock.withLock { storage.append(path) } }
}

nonisolated private final class SuspendedBackupProfileTransport: @unchecked Sendable {
    let profileWriteStarted = XCTestExpectation(description: "Backup profile write is suspended")
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var recordedPaths: [String] = []

    var paths: [String] { lock.withLock { recordedPaths } }

    func respond(to request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url else { throw APIError.invalidResponse }
        let path = "\(request.httpMethod ?? "") \(url.path)"
        lock.withLock { recordedPaths.append(path) }
        if path == "PUT /api/nido/profile" {
            await withCheckedContinuation { continuation in
                lock.withLock { self.continuation = continuation }
                profileWriteStarted.fulfill()
            }
            return response(url, #"{"profile":{"caregiverName":"David","babyName":"Marco","birthDate":"2026-08-01"}}"#)
        }
        if path == "POST /api/nido/auth/logout" {
            return response(url, #"{"loggedOut":true}"#)
        }
        throw URLError(.unsupportedURL)
    }

    func releaseProfileWrite() {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            let value = self.continuation
            self.continuation = nil
            return value
        }
        continuation?.resume()
    }

    private func response(_ url: URL, _ body: String) -> (Data, URLResponse) {
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        return (Data(body.utf8), response)
    }
}

nonisolated private final class SuspendedBabyCareSaveTransport: @unchecked Sendable {
    let firstPutStarted = XCTestExpectation(description: "First baby-care save is suspended")
    let secondPutStarted = XCTestExpectation(description: "Rebased baby-care save is sent")
    private let lock = NSLock()
    private var putCount = 0
    private var firstContinuation: CheckedContinuation<Void, Never>?

    func respond(to request: URLRequest) async throws -> (Data, URLResponse) {
        let ordinal = lock.withLock { () -> Int in
            putCount += 1
            return putCount
        }
        if ordinal == 1 {
            await withCheckedContinuation { continuation in
                lock.withLock { firstContinuation = continuation }
                firstPutStarted.fulfill()
            }
        } else if ordinal == 2 {
            secondPutStarted.fulfill()
        }
        guard let url = request.url,
              let requestData = request.httpBody,
              var payload = try JSONSerialization.jsonObject(with: requestData) as? [String: Any] else {
            throw APIError.invalidData
        }
        payload["revision"] = ordinal + 1
        let body = try JSONSerialization.data(withJSONObject: ["state": payload])
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])
        guard let response else { throw APIError.invalidResponse }
        return (body, response)
    }

    func releaseFirstPut() {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            let value = firstContinuation
            firstContinuation = nil
            return value
        }
        continuation?.resume()
    }
}

nonisolated private final class DelayedSessionResponse: @unchecked Sendable {
    let started = XCTestExpectation(description: "Bootstrap is suspended")
    private let lock = NSLock()
    private var pending: SessionRaceURLProtocol?
    private let status: Int
    private let path: String

    init(status: Int, path: String) { self.status = status; self.path = path }

    func receive(_ request: SessionRaceURLProtocol) {
        if request.request.url?.path == path {
            lock.withLock { pending = request }
            started.fulfill()
        } else {
            request.respond(status: 200, body: #"{"loggedOut":true}"#)
        }
    }

    func release() {
        let request = lock.withLock { let value = pending; pending = nil; return value }
        request?.respond(status: status, body: status == 200
            ? #"{"profile":{"caregiverName":"Old family","babyName":"Old baby","birthDate":"2026-01-01"},"entries":[],"caregivers":[{"id":"owner","name":"Old family","role":"owner","status":"active"}],"currentCaregiverID":"owner"}"#
            : #"{"error":"Old session expired"}"#)
    }
}

nonisolated private final class SessionRaceURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var controller: DelayedSessionResponse?

    static func install(_ value: DelayedSessionResponse) { lock.withLock { controller = value } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.lock.withLock { Self.controller }?.receive(self) }
    override func stopLoading() {}

    func respond(status: Int, body: String) {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil,
                                             headerFields: ["Content-Type": "application/json"]) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
