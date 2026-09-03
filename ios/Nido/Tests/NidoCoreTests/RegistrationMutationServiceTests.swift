import Foundation
import Testing
@testable import NidoCore

@Suite(.serialized)
struct RegistrationMutationServiceTests {
    private let now = Date(timeIntervalSince1970: 20_000)

    @Test
    func diaperUsesLatestReusableDetailsAndSafeDefault() async throws {
        let latest = entry(id: "latest", kind: .diaper, detail: "Pis y caca · Normal", timestamp: 2_000)
        let harness = try Harness(entries: [latest])

        let repeated = await harness.service.registerDiaper(caregiverID: "caregiver", caregiverName: "Name")
        #expect(repeated.outcome == .registered)
        #expect(repeated.entry?.detail == "Pis y caca")

        let emptyHarness = try Harness()
        let fallback = await emptyHarness.service.registerDiaper(caregiverID: nil, caregiverName: nil)
        #expect(fallback.entry?.detail == "Pis")
    }

    @Test
    func feedReusesOnlySemanticDetailsOrRequestsOpeningNido() async throws {
        let reusable = entry(
            id: "feed",
            kind: .feed,
            detail: "Biberón · Fórmula · Nota privada",
            timestamp: 3_000,
            durationMinutes: 18,
            amountMl: 120
        )
        let harness = try Harness(entries: [reusable])

        let result = await harness.service.registerFeed(caregiverID: nil, caregiverName: nil)
        #expect(result.outcome == .registered)
        #expect(result.entry?.detail == "Biberón · Fórmula")
        #expect(result.entry?.amountMl == 120)
        #expect(result.entry?.durationMinutes == nil)

        let emptyHarness = try Harness(entries: [entry(id: "legacy", kind: .feed, detail: "Texto libre", timestamp: 2_000)])
        let missing = await emptyHarness.service.registerFeed(caregiverID: nil, caregiverName: nil)
        #expect(missing.outcome == .noReusableFeed)
        #expect(missing.entry == nil)
    }

    @Test(arguments: [CredentialCase.missing, .expired])
    func missingOrExpiredCredentialRejectsMutation(credentialCase: CredentialCase) async throws {
        let credential = credentialCase == .missing
            ? nil
            : SessionCredential(accessToken: "expired", expiresAt: now.addingTimeInterval(-1), appleUserID: nil)
        let harness = try Harness(credential: .some(credential))

        let result = await harness.service.registerDiaper(caregiverID: nil, caregiverName: nil)

        #expect(result.outcome == .authenticationRequired)
        #expect(result.entry == nil)
        #expect(try harness.cache.load().entries.isEmpty)
        #expect(await harness.cleanup.count == 1)
    }

    @Test
    func validCredentialAllowsMutation() async throws {
        let harness = try Harness()
        let result = await harness.service.registerDiaper(caregiverID: nil, caregiverName: nil)
        #expect(result.outcome == .registered)
        #expect(try harness.cache.load().pendingEntryIDs.isEmpty)
    }

    @Test
    func transportFailureKeepsPendingButUnauthorizedClearsPrivateState() async throws {
        let offline = try Harness(remoteError: URLError(.notConnectedToInternet))
        let queued = await offline.service.registerDiaper(caregiverID: nil, caregiverName: nil)
        #expect(queued.outcome == .queued)
        #expect(try offline.cache.load().pendingEntryIDs == Set([try #require(queued.entry?.id)]))
        #expect(await offline.cleanup.count == 0)

        let unauthorized = try Harness(remoteError: APIError.server(status: 401, message: "revoked"))
        let rejected = await unauthorized.service.registerDiaper(caregiverID: nil, caregiverName: nil)
        #expect(rejected.outcome == .authenticationRequired)
        #expect(try unauthorized.cache.load() == .empty)
        #expect(await unauthorized.cleanup.count == 1)
    }

    @Test
    func sleepStartAndFinishHaveExactExistingIntervalSemantics() async throws {
        let start = now.addingTimeInterval(-125)
        let harness = try Harness(now: start)

        let started = await harness.service.startSleep()
        let duplicateStart = await harness.service.startSleep()
        #expect(started.outcome == .sleepStarted)
        #expect(duplicateStart.outcome == .sleepAlreadyActive)
        #expect(duplicateStart.activeSleepStartedAt == start)

        let correctedStart = start.addingTimeInterval(-60)
        #expect(try await harness.service.updateSleepStart(correctedStart) == correctedStart)

        await harness.clock.set(now)
        let finished = await harness.service.finishSleep(caregiverID: "caregiver", caregiverName: "Name")
        #expect(finished.outcome == .sleepFinished)
        #expect(finished.entry?.occurredAt == Int64(now.timeIntervalSince1970 * 1_000))
        #expect(finished.entry?.durationMinutes == 3)
        #expect(finished.entry?.detail == SleepInterval(start: correctedStart, end: now).detail(note: ""))
        #expect(finished.activeSleepStartedAt == nil)

        let noActive = await harness.service.finishSleep(caregiverID: nil, caregiverName: nil)
        #expect(noActive.outcome == .noActiveSleep)
        #expect(noActive.entry == nil)
    }

    @Test
    func concurrentSleepFinishCreatesExactlyOneStableEntry() async throws {
        let start = now.addingTimeInterval(-600)
        let harness = try Harness(activeSleepStartedAt: start, remoteError: URLError(.timedOut))

        async let first = harness.service.finishSleep(caregiverID: nil, caregiverName: nil)
        async let second = harness.service.finishSleep(caregiverID: nil, caregiverName: nil)
        let results = await [first, second]

        let snapshot = try harness.cache.load()
        #expect(snapshot.entries.count == 1)
        #expect(snapshot.pendingEntryIDs == Set([snapshot.entries[0].id]))
        #expect(results.filter { $0.entry != nil }.count == 1)
        #expect(results.contains { $0.outcome == .noActiveSleep })
    }

    @Test
    func retriesReuseStableIDAndDuplicateVoiceDeliveryIsBounded() async throws {
        let harness = try Harness(remoteError: URLError(.timedOut), ids: ["stable-id", "unused-id"])

        let first = await harness.service.registerDiaper(caregiverID: nil, caregiverName: nil)
        let duplicate = await harness.service.registerDiaper(caregiverID: nil, caregiverName: nil)
        #expect(first.entry?.id == "stable-id")
        #expect(duplicate.entry?.id == "stable-id")
        #expect(try harness.cache.load().entries.count == 1)
        #expect(await harness.remote.ids == ["stable-id"])

        await harness.clock.advance(by: RegistrationMutationService.voiceReceiptWindow + 1)
        let later = await harness.service.registerDiaper(caregiverID: nil, caregiverName: nil)
        #expect(later.entry?.id == "unused-id")
        #expect(try harness.cache.load().entries.count == 2)
    }

    @Test
    func migratesLegacyStandardSleepStateOnce() async throws {
        let legacyStart = now.addingTimeInterval(-300)
        let harness = try Harness(legacySleepStartedAt: legacyStart)

        #expect(try await harness.service.activeSleepStartedAt() == legacyStart)
        #expect(harness.legacyDefaults.object(forKey: "activeSleepStartedAt") == nil)

        harness.legacyDefaults.set(now.timeIntervalSince1970, forKey: "activeSleepStartedAt")
        #expect(try await harness.service.activeSleepStartedAt() == legacyStart)

        let appGroupHarness = try Harness(activeSleepStartedAt: legacyStart)
        #expect(try await appGroupHarness.service.activeSleepStartedAt() == legacyStart)
        #expect(appGroupHarness.stateDefaults.data(forKey: RegistrationMutationService.stateKey) == nil)
    }

    @Test
    func publicDialogsContainOnlyCategoryAndOutcome() {
        let forbidden = ["Marco", "Biberón", "120", "20:00", "2 min", "Caregiver", "secret-token", "Fórmula"]
        for outcome in RegistrationMutationOutcome.allCases {
            let dialog = RegistrationMutationResult.dialog(for: outcome)
            #expect(forbidden.allSatisfy { !dialog.localizedCaseInsensitiveContains($0) })
        }
    }

    @Test
    func cacheWriteFailureNeverCallsAPIOrClaimsQueued() async throws {
        let remote = RemoteRecorder(error: nil)
        let fixture = try CorrectionFixture(
            cache: LocalCache(fileURL: URL(fileURLWithPath: "/dev/null/nido-snapshot.json")),
            remote: { entry, _ in try await remote.create(entry) }
        )

        let result = await fixture.service.registerDiaper(caregiverID: nil, caregiverName: nil)

        #expect(result.outcome == .storageUnavailable)
        #expect(result.dialog == "No he podido guardar el registro. Abre Nido para intentarlo de nuevo.")
        #expect(await remote.ids.isEmpty)
    }

    @Test
    func stateWriteFailureNeverCallsAPIOrClaimsQueued() async throws {
        let remote = RemoteRecorder(error: nil)
        let fixture = try CorrectionFixture(
            stateStore: RegistrationStateFileStore(
                load: { nil },
                save: { _ in throw CorrectionTestError.storage },
                remove: {}
            ),
            remote: { entry, _ in try await remote.create(entry) }
        )

        let result = await fixture.service.registerDiaper(caregiverID: nil, caregiverName: nil)

        #expect(result.outcome == .storageUnavailable)
        #expect(await remote.ids.isEmpty)
    }

    @Test
    func optimisticSnapshotPublishesBeforeSuspendedUploadCompletes() async throws {
        let gate = SuspendedRemote()
        let publications = PublicationRecorder()
        let fixture = try CorrectionFixture(
            publish: { commit in await publications.record(commit) },
            remote: { entry, _ in try await gate.create(entry) }
        )

        let operation = Task {
            await fixture.service.registerDiaper(caregiverID: nil, caregiverName: nil)
        }
        await gate.waitUntilStarted()

        let commit = try #require(await publications.last)
        #expect(commit.snapshot.entries.count == 1)
        #expect(commit.snapshot.pendingEntryIDs == Set([commit.snapshot.entries[0].id]))

        await gate.resume()
        #expect(await operation.value.outcome == .registered)
    }

    @Test
    func actorSerializedAppSaveRetainsSiriPendingEntryAndPostUploadEdit() async throws {
        let gate = SuspendedRemote()
        let publications = PublicationRecorder()
        let fixture = try CorrectionFixture(
            publish: { commit in await publications.record(commit) },
            remote: { entry, _ in try await gate.create(entry) }
        )
        let operation = Task {
            await fixture.service.registerDiaper(caregiverID: nil, caregiverName: nil)
        }
        await gate.waitUntilStarted()
        let committed = try #require(await publications.last?.snapshot.entries.first)

        let staleAppSnapshot = NidoSnapshot(
            profile: Profile(caregiverName: "Owner", babyName: "Baby", birthDate: "2026-01-01"),
            entries: [],
            pendingEntryIDs: [],
            profileNeedsSync: false
        )
        let merged = try await fixture.service.saveAppSnapshot(staleAppSnapshot)
        #expect(merged.entries.contains { $0.id == committed.id })
        #expect(merged.pendingEntryIDs.contains(committed.id))

        var edited = committed.edited(
            detail: "Pis y caca",
            occurredAt: committed.date,
            durationMinutes: nil,
            amountMl: nil
        )
        edited.caregiverID = committed.caregiverID
        edited.caregiverName = committed.caregiverName
        let editedSnapshot = NidoSnapshot(
            profile: staleAppSnapshot.profile,
            entries: [edited],
            pendingEntryIDs: [edited.id],
            profileNeedsSync: false
        )
        _ = try await fixture.service.saveAppSnapshot(editedSnapshot)

        await gate.resume()
        _ = await operation.value
        let final = try await fixture.service.snapshot().0
        #expect(final.profile == staleAppSnapshot.profile)
        #expect(final.entries.first(where: { $0.id == edited.id })?.detail == "Pis y caca")
    }

    @MainActor
    @Test
    func foregroundInvalidationHubClearsActiveReceiver() {
        let hub = RegistrationMutationEventHub()
        let receiver = InvalidationReceiver()
        hub.attach(receiver)

        hub.invalidate()

        #expect(receiver.didInvalidate)
        #expect(receiver.entries.isEmpty)
        #expect(receiver.phaseIsAuthentication)
    }

    @Test
    func voiceDedupeIsScopedToTheCurrentSession() async throws {
        let credential = MutableCredentialSource(SessionCredential(
            accessToken: "first-real-session",
            expiresAt: now.addingTimeInterval(3_600),
            appleUserID: "first-user"
        ))
        let fixture = try CorrectionFixture(
            credential: { credential.value },
            remote: { _, _ in throw URLError(.timedOut) }
        )
        let first = await fixture.service.registerDiaper(caregiverID: nil, caregiverName: nil)

        credential.value = SessionCredential(
            accessToken: "second-real-session",
            expiresAt: now.addingTimeInterval(3_600),
            appleUserID: "second-user"
        )
        let second = await fixture.service.registerDiaper(caregiverID: nil, caregiverName: nil)

        #expect(first.entry?.id != second.entry?.id)
        #expect(try fixture.cache.load().entries.count == 2)
    }

    @Test
    func durableStateFileIsOpaqueAtomicAndCompletelyProtected() async throws {
        let fixture = try CorrectionFixture(remote: { _, _ in throw URLError(.timedOut) })
        _ = await fixture.service.registerDiaper(caregiverID: "private-caregiver", caregiverName: "Private Name")

        let data = try Data(contentsOf: fixture.stateURL)
        let representation = try #require(String(data: data, encoding: .utf8))
        for forbidden in ["diaper", "private-caregiver", "Private Name", "real-session", "createdAt", "category"] {
            #expect(!representation.contains(forbidden))
        }
        #expect(representation.contains("digest"))
        #expect(RegistrationStateFileStore.iOSWriteOptions.contains(.atomic))
        #expect(RegistrationStateFileStore.iOSWriteOptions.contains(.completeFileProtection))
    }
}

@Suite
struct AppIntentsRegistrationContractTests {
    @Test
    func sourcePublishesFourAuthenticatedSpanishShortcutsWithoutDebugTokens() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Nido/App/NidoRegistrationIntents.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        for intent in ["RegisterDiaperIntent", "RepeatFeedIntent", "StartSleepIntent", "FinishSleepIntent"] {
            #expect(source.contains("struct \(intent): AppIntent"))
        }
        #expect(source.components(separatedBy: "AppShortcut(").count - 1 == 4)
        for phrase in ["Registra un pañal", "Repite la última toma", "Inicia el sueño", "Termina el sueño"] {
            #expect(source.contains(phrase))
        }
        #expect(source.components(separatedBy: "\\(.applicationName)").count - 1 >= 4)
        #expect(source.components(separatedBy: "authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication").count - 1 == 4)
        #expect(!source.contains("NIDO_UI_TEST_ACCESS_TOKEN"))
        #expect(!source.contains("ProcessInfo.processInfo.environment"))
    }

    @Test
    func nidoStoreRoutesCreationAndSleepThroughSharedMutationService() throws {
        let storeURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Nido/App/NidoStore.swift")
        let source = try String(contentsOf: storeURL, encoding: .utf8)

        #expect(source.contains("private let registrationService: RegistrationMutationService"))
        #expect(source.contains("await registrationService.create("))
        #expect(source.contains("await registrationService.startSleep()"))
        #expect(source.contains("await registrationService.finishSleep("))
        #expect(!source.contains("defaults.set(startedAt.timeIntervalSince1970, forKey: \"activeSleepStartedAt\")"))
    }
}

enum CredentialCase: Sendable {
    case missing
    case expired
}

private final class Harness: @unchecked Sendable {
    let cache: LocalCache
    let service: RegistrationMutationService
    let cleanup = Counter()
    let clock: TestClock
    let remote: RemoteRecorder
    let legacyDefaults: UserDefaults
    let stateDefaults: UserDefaults

    init(
        entries: [Entry] = [],
        credential: SessionCredential?? = nil,
        now: Date = Date(timeIntervalSince1970: 20_000),
        activeSleepStartedAt: Date? = nil,
        legacySleepStartedAt: Date? = nil,
        remoteError: (any Error)? = nil,
        ids: [String] = [UUID().uuidString, UUID().uuidString]
    ) throws {
        let id = UUID().uuidString
        let directory = FileManager.default.temporaryDirectory.appending(path: "NidoRegistrationTests/\(id)", directoryHint: .isDirectory)
        cache = LocalCache(fileURL: directory.appending(path: "snapshot.json"))
        try cache.save(NidoSnapshot(profile: nil, entries: entries, pendingEntryIDs: [], profileNeedsSync: false))
        stateDefaults = try #require(UserDefaults(suiteName: "com.momentumia.nido.tests.state.\(id)"))
        legacyDefaults = try #require(UserDefaults(suiteName: "com.momentumia.nido.tests.legacy.\(id)"))
        stateDefaults.removePersistentDomain(forName: "com.momentumia.nido.tests.state.\(id)")
        legacyDefaults.removePersistentDomain(forName: "com.momentumia.nido.tests.legacy.\(id)")
        if let legacySleepStartedAt {
            legacyDefaults.set(legacySleepStartedAt.timeIntervalSince1970, forKey: "activeSleepStartedAt")
        }
        clock = TestClock(now)
        remote = RemoteRecorder(error: remoteError)
        let idSource = IDSource(ids)
        let stateURL = directory.appending(path: "registration-state.json")
        let validCredential = SessionCredential(
            accessToken: "real-test-session",
            expiresAt: now.addingTimeInterval(3_600),
            appleUserID: "apple-user"
        )
        let suppliedCredential: SessionCredential? = credential ?? validCredential
        service = RegistrationMutationService(
            cache: cache,
            stateStore: RegistrationStateFileStore(fileURL: stateURL),
            legacyDefaults: RegistrationStateDefaults(durable: stateDefaults, legacy: legacyDefaults),
            dependencies: RegistrationMutationDependencies(
                loadCredential: { suppliedCredential },
                deleteCredential: {},
                createEntry: { [remote] entry, _ in try await remote.create(entry) },
                publishLocalCommit: { _ in },
                clearExternalState: { [cleanup] in await cleanup.increment() },
                now: { [clock] in clock.value },
                makeID: { idSource.next() }
            )
        )
        if let activeSleepStartedAt {
            stateDefaults.set(try JSONEncoder().encode(RegistrationDurableState(activeSleepStartedAt: activeSleepStartedAt)), forKey: RegistrationMutationService.stateKey)
        }
    }
}

private actor Counter {
    private(set) var count = 0
    func increment() { count += 1 }
}

private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var now: Date
    init(_ now: Date) { self.now = now }
    var value: Date { lock.withLock { now } }
    func set(_ value: Date) async { lock.withLock { now = value } }
    func advance(by interval: TimeInterval) async { lock.withLock { now = now.addingTimeInterval(interval) } }
}

private final class IDSource: @unchecked Sendable {
    private let lock = NSLock()
    private var ids: [String]
    init(_ ids: [String]) { self.ids = ids }
    func next() -> String { lock.withLock { ids.isEmpty ? UUID().uuidString : ids.removeFirst() } }
}

private actor RemoteRecorder {
    private(set) var ids: [String] = []
    let error: (any Error)?
    init(error: (any Error)?) { self.error = error }
    func create(_ entry: Entry) throws -> Entry {
        ids.append(entry.id)
        if let error { throw error }
        return entry
    }
}

private enum CorrectionTestError: Error {
    case storage
}

private final class CorrectionFixture: @unchecked Sendable {
    let cache: LocalCache
    let stateURL: URL
    let service: RegistrationMutationService
    private let stateDefaults: UserDefaults
    private let legacyDefaults: UserDefaults

    init(
        cache: LocalCache? = nil,
        stateStore: RegistrationStateFileStore? = nil,
        credential: @escaping @Sendable () -> SessionCredential? = {
            SessionCredential(
                accessToken: "real-session",
                expiresAt: Date(timeIntervalSince1970: 30_000),
                appleUserID: "real-user"
            )
        },
        publish: @escaping @Sendable (RegistrationLocalCommit) async -> Void = { _ in },
        remote: @escaping @Sendable (Entry, String) async throws -> Entry
    ) throws {
        let id = UUID().uuidString
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "NidoRegistrationCorrectionTests/\(id)", directoryHint: .isDirectory)
        self.cache = cache ?? LocalCache(fileURL: directory.appending(path: "snapshot.json"))
        stateURL = directory.appending(path: "registration-state.json")
        let stateDefaultsName = "com.momentumia.nido.tests.correction.state.\(id)"
        let legacyDefaultsName = "com.momentumia.nido.tests.correction.legacy.\(id)"
        stateDefaults = try #require(UserDefaults(suiteName: stateDefaultsName))
        legacyDefaults = try #require(UserDefaults(suiteName: legacyDefaultsName))
        stateDefaults.removePersistentDomain(forName: stateDefaultsName)
        legacyDefaults.removePersistentDomain(forName: legacyDefaultsName)
        service = RegistrationMutationService(
            cache: self.cache,
            stateStore: stateStore ?? RegistrationStateFileStore(fileURL: stateURL),
            legacyDefaults: RegistrationStateDefaults(durable: stateDefaults, legacy: legacyDefaults),
            dependencies: RegistrationMutationDependencies(
                loadCredential: credential,
                deleteCredential: {},
                createEntry: remote,
                publishLocalCommit: publish,
                clearExternalState: {},
                now: { Date(timeIntervalSince1970: 20_000) },
                makeID: { UUID().uuidString }
            )
        )
    }
}

private actor PublicationRecorder {
    private(set) var last: RegistrationLocalCommit?
    func record(_ commit: RegistrationLocalCommit) { last = commit }
}

private actor SuspendedRemote {
    private var started = false
    private var continuation: CheckedContinuation<Void, Never>?

    func create(_ entry: Entry) async throws -> Entry {
        started = true
        await withCheckedContinuation { continuation = $0 }
        return entry
    }

    func waitUntilStarted() async {
        while !started { await Task.yield() }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

private final class MutableCredentialSource: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: SessionCredential
    init(_ credential: SessionCredential) { stored = credential }
    var value: SessionCredential {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

@MainActor
private final class InvalidationReceiver: RegistrationMutationEventReceiver {
    var entries = [entry(id: "private", kind: .diaper, detail: "Pis", timestamp: 1)]
    var phaseIsAuthentication = false
    var didInvalidate = false

    func registrationServiceDidCommit(_ commit: RegistrationLocalCommit) {
        entries = commit.snapshot.entries
    }

    func registrationServiceDidInvalidate() {
        entries = []
        phaseIsAuthentication = true
        didInvalidate = true
    }
}

private func entry(
    id: String,
    kind: EntryKind,
    detail: String,
    timestamp: Int64,
    durationMinutes: Int? = nil,
    amountMl: Int? = nil
) -> Entry {
    Entry(
        id: id,
        kind: kind,
        title: kind.title,
        detail: detail,
        occurredAt: timestamp,
        durationMinutes: durationMinutes,
        amountMl: amountMl
    )
}
