import Foundation
import XCTest

@testable import Nido

@MainActor
final class RegistrationFeedbackTests: XCTestCase {
    func testQuickEntryEmitsOneSuccessFeedbackAfterLocalCommitAndUpload() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let initialFeedbackToken = fixture.store.feedbackToken
        let choice = RegistrationQuickAction.diaper(entries: [], at: fixture.now)

        await fixture.store.addQuickEntry(choice)

        XCTAssertEqual(fixture.store.feedbackToken, initialFeedbackToken + 1,
                       "One registration must produce one success feedback, including its local commit and upload")
        XCTAssertEqual(fixture.store.feedbackKind, .success)
        let entry = try XCTUnwrap(fixture.store.recentlyCreatedEntry)
        XCTAssertEqual(fixture.store.entries, [entry])
        XCTAssertEqual(fixture.store.notice, "Pañal registrado · Pis")
        let snapshot = try fixture.cache.load()
        XCTAssertEqual(snapshot.entries, [entry])
        XCTAssertTrue(snapshot.pendingEntryIDs.isEmpty, "The upload must have completed successfully")
    }

    func testFinishingSleepShowsFinalDurationAndMakesEntryEditableOrUndoable() async throws {
        try await assertFinishedSleepFeedback(offline: false)
    }

    func testFinishingSleepOfflineShowsFinalDurationAndKeepsEntryEditableOrUndoable() async throws {
        try await assertFinishedSleepFeedback(offline: true)
    }

    func testUndoDuringQuickEntryUploadDoesNotRestoreNoticeAndCompensatesRemoteCreation() async throws {
        let fixture = try RaceFixture()
        defer { fixture.cleanUp() }
        let creation = Task { await fixture.store.addQuickEntry(fixture.choice(detail: "Pis")) }
        defer { Task { await fixture.remote.releaseAll() } }
        await fulfillment(of: [fixture.firstUploadStarted], timeout: 5)
        guard await fixture.remote.isPending(detail: "Pis") else { return }
        let entry = try XCTUnwrap(fixture.store.recentlyCreatedEntry)

        await fixture.store.undoCreatedEntry()
        XCTAssertTrue(fixture.store.entries.isEmpty)
        XCTAssertTrue(try fixture.cache.load().entries.isEmpty)
        await fixture.remote.release(detail: "Pis")
        _ = await creation.value

        XCTAssertTrue(fixture.store.entries.isEmpty)
        XCTAssertTrue(try fixture.cache.load().entries.isEmpty)
        XCTAssertNil(fixture.store.recentlyCreatedEntry,
                     "An upload completed after Undo must not restore the Edit action")
        XCTAssertEqual(fixture.store.notice, "Registro deshecho")
        let pendingDeletionIDs = fixture.defaults.stringArray(forKey: "pendingDeletionIDs") ?? []
        let deletedIDs = FeedbackDeletionURLProtocol.deletedIDs(host: fixture.host)
        XCTAssertTrue(pendingDeletionIDs.contains(entry.id) || deletedIDs.contains(entry.id),
                      "The late server creation must be compensated by DELETE or a durable pending deletion")
    }

    func testOverlappingQuickEntriesKeepNewestNoticeWhenFirstUploadFinishesFirst() async throws {
        try await assertOverlappingQuickEntries(firstFinishesFirst: true)
    }

    func testOverlappingQuickEntriesKeepNewestNoticeWhenSecondUploadFinishesFirst() async throws {
        try await assertOverlappingQuickEntries(firstFinishesFirst: false)
    }

    func testQuickEntryUploadCompletionPreservesNewlyOpenedHealthForm() async throws {
        let fixture = try RaceFixture()
        defer { fixture.cleanUp() }
        defer { Task { await fixture.remote.releaseAll() } }
        let creation = Task { await fixture.store.addQuickEntry(fixture.choice(detail: "Pis")) }
        await fulfillment(of: [fixture.firstUploadStarted], timeout: 5)
        guard await fixture.remote.isPending(detail: "Pis") else { return }
        XCTAssertNotNil(fixture.store.recentlyCreatedEntry)
        fixture.store.presentedEntryKind = .health

        await fixture.remote.release(detail: "Pis")
        _ = await creation.value

        XCTAssertEqual(fixture.store.presentedEntryKind, .health,
                       "An older quick-entry acknowledgment must not dismiss a subsequently opened form")
    }

    func testRefreshAfterUndoDefersCompensatingDeleteUntilCreationUploadCompletes() async throws {
        let fixture = try RaceFixture()
        defer { fixture.cleanUp() }
        defer { Task { await fixture.remote.releaseAll() } }
        let creation = Task { await fixture.store.addQuickEntry(fixture.choice(detail: "Pis")) }
        await fulfillment(of: [fixture.firstUploadStarted], timeout: 5)
        guard await fixture.remote.isPending(detail: "Pis") else { return }
        let entry = try XCTUnwrap(fixture.store.recentlyCreatedEntry)
        await fixture.store.undoCreatedEntry()
        XCTAssertTrue((fixture.defaults.stringArray(forKey: "pendingDeletionIDs") ?? []).contains(entry.id))
        fixture.store.phase = .ready

        await fixture.store.refresh()

        XCTAssertEqual(fixture.store.phase, .ready, "The household refresh must keep the fixture authenticated")
        XCTAssertFalse(fixture.store.isOffline, "The intercepted household refresh must succeed")
        XCTAssertTrue(FeedbackDeletionURLProtocol.deletedIDs(host: fixture.host).isEmpty,
                      "DELETE before the pending POST completes cannot compensate a later server creation")
        XCTAssertTrue((fixture.defaults.stringArray(forKey: "pendingDeletionIDs") ?? []).contains(entry.id),
                      "Refresh must preserve the durable compensation until POST has finished")
        await fixture.remote.release(detail: "Pis")
        _ = await creation.value

        XCTAssertTrue(FeedbackDeletionURLProtocol.deletedIDs(host: fixture.host).contains(entry.id),
                      "The successful late POST must be followed by a compensating DELETE")
        XCTAssertFalse((fixture.defaults.stringArray(forKey: "pendingDeletionIDs") ?? []).contains(entry.id))
        XCTAssertTrue(fixture.store.entries.isEmpty)
        XCTAssertTrue(try fixture.cache.load().entries.isEmpty)
        XCTAssertNil(fixture.store.recentlyCreatedEntry)
    }

    private func assertOverlappingQuickEntries(firstFinishesFirst: Bool) async throws {
        let fixture = try RaceFixture()
        defer { fixture.cleanUp() }
        defer { Task { await fixture.remote.releaseAll() } }
        let baseline = fixture.store.feedbackToken
        let first = Task { await fixture.store.addQuickEntry(fixture.choice(detail: "Pis")) }
        await fulfillment(of: [fixture.firstUploadStarted], timeout: 5)
        guard await fixture.remote.isPending(detail: "Pis") else { return }
        let firstEntry = try XCTUnwrap(fixture.store.recentlyCreatedEntry)
        XCTAssertEqual(fixture.store.feedbackToken, baseline + 1)

        let second = Task { await fixture.store.addQuickEntry(fixture.choice(detail: "Caca")) }
        await fulfillment(of: [fixture.secondUploadStarted], timeout: 5)
        guard await fixture.remote.isPending(detail: "Caca") else { return }
        let secondEntry = try XCTUnwrap(fixture.store.recentlyCreatedEntry)
        XCTAssertNotEqual(firstEntry.id, secondEntry.id)
        XCTAssertEqual(fixture.store.feedbackToken, baseline + 2,
                       "Each distinct local registration emits exactly one success")
        XCTAssertEqual(fixture.store.notice, "Pañal registrado · Caca")

        if firstFinishesFirst {
            await fixture.remote.release(detail: "Pis")
            _ = await first.value
        } else {
            await fixture.remote.release(detail: "Caca")
            _ = await second.value
        }
        XCTAssertEqual(fixture.store.recentlyCreatedEntry?.id, secondEntry.id)
        XCTAssertEqual(fixture.store.notice, "Pañal registrado · Caca",
                       "Completion order must not replace the newest operation's notice")
        XCTAssertEqual(fixture.store.feedbackToken, baseline + 2)

        if firstFinishesFirst {
            await fixture.remote.release(detail: "Caca")
            _ = await second.value
        } else {
            await fixture.remote.release(detail: "Pis")
            _ = await first.value
        }
        XCTAssertEqual(fixture.store.recentlyCreatedEntry?.id, secondEntry.id)
        XCTAssertEqual(fixture.store.recentlyCreatedEntry?.detail, "Caca")
        XCTAssertEqual(fixture.store.notice, "Pañal registrado · Caca")
        XCTAssertEqual(fixture.store.feedbackToken, baseline + 2,
                       "Upload acknowledgments must not repeat either entry's feedback")
        let snapshot = try fixture.cache.load()
        XCTAssertEqual(Set(snapshot.entries.map(\.id)), Set([firstEntry.id, secondEntry.id]))
        XCTAssertTrue(snapshot.pendingEntryIDs.isEmpty)
    }

    @MainActor
    private struct RaceFixture {
        let firstUploadStarted: XCTestExpectation
        let secondUploadStarted: XCTestExpectation
        let remote: SuspendedFeedbackUploads
        let defaults: UserDefaults
        let cache: LocalCache
        let store: NidoStore
        let host: String
        private let directory: URL
        private let suite: String
        private let credentialStore: CredentialStore
        private let session: URLSession

        init() throws {
            let id = UUID().uuidString.lowercased()
            let suite = "nido.feedback-race.\(id)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            let directory = FileManager.default.temporaryDirectory.appending(path: suite)
            let cache = LocalCache(fileURL: directory.appending(path: "snapshot.json"))
            let credentialStore = CredentialStore(service: suite)
            let credential = SessionCredential(accessToken: id, expiresAt: .distantFuture, appleUserID: nil)
            let firstStarted = XCTestExpectation(description: "First upload suspended after local publication")
            let secondStarted = XCTestExpectation(description: "Second upload suspended after local publication")
            let remote = SuspendedFeedbackUploads(firstStarted: firstStarted, secondStarted: secondStarted)
            let host = "feedback-\(id).test"
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [FeedbackDeletionURLProtocol.self]
            let session = URLSession(configuration: configuration)
            let api = NidoAPI(baseURL: try XCTUnwrap(URL(string: "https://\(host)")), session: session)
            let hub = RegistrationMutationEventHub()
            let service = RegistrationMutationService(
                cache: cache,
                stateStore: RegistrationStateFileStore(fileURL: directory.appending(path: "state.json")),
                legacyDefaults: RegistrationStateDefaults(durable: defaults, legacy: defaults),
                dependencies: RegistrationMutationDependencies(
                    loadCredential: { credential }, deleteCredential: {},
                    createEntry: { entry, _ in await remote.create(entry) },
                    publishLocalCommit: { commit in await hub.publish(commit) },
                    clearExternalState: {}, now: { Date(timeIntervalSince1970: 20_000) },
                    makeID: { UUID().uuidString }
                )
            )
            self.firstUploadStarted = firstStarted
            self.secondUploadStarted = secondStarted
            self.remote = remote
            self.defaults = defaults
            self.directory = directory
            self.cache = cache
            self.suite = suite
            self.credentialStore = credentialStore
            self.session = session
            self.host = host
            self.store = NidoStore(
                api: api, credentialStore: credentialStore, defaults: defaults,
                shouldLoadCredential: false, initialAccessToken: id,
                registrationService: service, registrationEventHub: hub
            )
        }

        func choice(detail: String) -> RegistrationQuickAction.Choice {
            RegistrationQuickAction.Choice(
                label: "Registrar pañal · \(detail)", summary: detail,
                draft: RegistrationDraft(kind: .diaper, detail: detail,
                                         date: Date(timeIntervalSince1970: detail == "Pis" ? 20_000 : 20_001),
                                         durationMinutes: nil, amountMl: nil)
            )
        }

        func cleanUp() {
            session.invalidateAndCancel()
            FeedbackDeletionURLProtocol.clear(host: host)
            defaults.removePersistentDomain(forName: suite)
            credentialStore.delete()
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private func assertFinishedSleepFeedback(offline: Bool) async throws {
        let fixture = try Fixture(offline: offline)
        defer { fixture.cleanUp() }
        let started = await fixture.service.startSleep()
        XCTAssertEqual(started.outcome, .sleepStarted)
        let start = fixture.now.addingTimeInterval(-65 * 60)
        let correctedStart = try await fixture.service.updateSleepStart(start)
        XCTAssertEqual(correctedStart, start)
        fixture.store.activeSleepStartedAt = start
        // A previous deleted record must not keep ownership of the new notice's Undo action.
        fixture.store.recentlyDeletedEntry = Entry(
            id: "previous-deletion", kind: .diaper, title: "Pañal", detail: "Pis",
            occurredAt: 1_000, durationMinutes: nil, amountMl: nil
        )
        let initialFeedbackToken = fixture.store.feedbackToken

        await fixture.store.toggleSleep()

        let entry = try XCTUnwrap(fixture.store.entries.first)
        XCTAssertEqual(entry.kind, .sleep)
        XCTAssertEqual(entry.durationMinutes, 65)
        XCTAssertNil(fixture.store.activeSleepStartedAt)
        XCTAssertEqual(fixture.store.recentlyCreatedEntry, entry,
                       "The existing Edit and Undo actions must target the completed sleep")
        XCTAssertNil(fixture.store.recentlyDeletedEntry)
        XCTAssertEqual(fixture.store.notice, offline
                       ? "Sueño guardado · 1 h 5 min. Se sincronizará cuando vuelva la conexión."
                       : "Sueño guardado · 1 h 5 min")
        XCTAssertEqual(fixture.store.isOffline, offline)
        XCTAssertEqual(fixture.store.feedbackToken, initialFeedbackToken + 1)
        XCTAssertEqual(fixture.store.feedbackKind, .success)
        let snapshot = try fixture.cache.load()
        XCTAssertEqual(snapshot.entries, [entry])
        XCTAssertEqual(snapshot.pendingEntryIDs, offline ? Set([entry.id]) : [])
    }

    @MainActor
    private struct Fixture {
        let now: Date
        let cache: LocalCache
        let service: RegistrationMutationService
        let store: NidoStore
        private let directory: URL
        private let suite: String
        private let defaults: UserDefaults
        private let credentialStore: CredentialStore

        init(offline: Bool = false) throws {
            let id = UUID().uuidString
            let suite = "nido.registration-feedback.\(id)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defaults.removePersistentDomain(forName: suite)
            let directory = FileManager.default.temporaryDirectory
                .appending(path: "NidoRegistrationFeedbackTests/\(id)", directoryHint: .isDirectory)
            let cache = LocalCache(fileURL: directory.appending(path: "snapshot.json"))
            let credentialStore = CredentialStore(service: suite)
            let credential = SessionCredential(accessToken: id, expiresAt: .distantFuture, appleUserID: nil)
            let now = Date(timeIntervalSince1970: 20_000)
            let hub = RegistrationMutationEventHub()
            let service = RegistrationMutationService(
                cache: cache,
                stateStore: RegistrationStateFileStore(fileURL: directory.appending(path: "state.json")),
                legacyDefaults: RegistrationStateDefaults(durable: defaults, legacy: defaults),
                dependencies: RegistrationMutationDependencies(
                    loadCredential: { credential }, deleteCredential: {},
                    createEntry: { entry, _ in
                        if offline { throw URLError(.notConnectedToInternet) }
                        return entry
                    },
                    publishLocalCommit: { commit in await hub.publish(commit) },
                    clearExternalState: {}, now: { now }, makeID: { "registered-entry" }
                )
            )
            self.now = now
            self.cache = cache
            self.service = service
            self.directory = directory
            self.suite = suite
            self.defaults = defaults
            self.credentialStore = credentialStore
            store = NidoStore(
                credentialStore: credentialStore, defaults: defaults, now: { now },
                shouldLoadCredential: false, initialAccessToken: id,
                registrationService: service, registrationEventHub: hub
            )
        }

        func cleanUp() {
            defaults.removePersistentDomain(forName: suite)
            credentialStore.delete()
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

private actor SuspendedFeedbackUploads {
    private let firstStarted: XCTestExpectation
    private let secondStarted: XCTestExpectation
    private var pending: [String: CheckedContinuation<Void, Never>] = [:]

    init(firstStarted: XCTestExpectation, secondStarted: XCTestExpectation) {
        self.firstStarted = firstStarted
        self.secondStarted = secondStarted
    }

    func create(_ entry: Entry) async -> Entry {
        await withCheckedContinuation { continuation in
            pending[entry.detail] = continuation
            (entry.detail == "Pis" ? firstStarted : secondStarted).fulfill()
        }
        return entry
    }

    func release(detail: String) {
        pending.removeValue(forKey: detail)?.resume()
    }

    func isPending(detail: String) -> Bool {
        pending[detail] != nil
    }

    func releaseAll() {
        let continuations = Array(pending.values)
        pending.removeAll()
        for continuation in continuations { continuation.resume() }
    }
}

nonisolated private final class FeedbackDeletionURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var deletionsByHost: [String: [String]] = [:]

    static func deletedIDs(host: String) -> [String] {
        lock.withLock { deletionsByHost[host] ?? [] }
    }

    static func clear(host: String) {
        _ = lock.withLock { deletionsByHost.removeValue(forKey: host) }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url else { return }
        if request.httpMethod == "GET", url.path == "/api/nido" {
            respond(url: url, body: Data(#"{"profile":{"caregiverName":"Test caregiver","babyName":"Test baby","birthDate":"2026-01-01"},"entries":[],"caregivers":[{"id":"owner","name":"Test caregiver","role":"owner","status":"active"}],"currentCaregiverID":"owner"}"#.utf8))
            return
        }
        if request.httpMethod == "GET", url.path == "/api/nido/baby-care" {
            respond(url: url, body: Data(#"{"state":null}"#.utf8))
            return
        }
        guard request.httpMethod == "DELETE",
              let host = url.host,
              let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "id" })?.value else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        Self.lock.withLock { Self.deletionsByHost[host, default: []].append(id) }
        let body = try? JSONSerialization.data(withJSONObject: ["deleted": id])
        respond(url: url, body: body ?? Data())
    }

    private func respond(url: URL, body: Data) {
        guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                             headerFields: ["Content-Type": "application/json"]) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
}
