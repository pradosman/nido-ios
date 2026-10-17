import CryptoKit
import Foundation

nonisolated enum RegistrationMutationOutcome: String, CaseIterable, Codable, Sendable {
    case registered
    case queued
    case noReusableFeed
    case sleepStarted
    case sleepAlreadyActive
    case sleepFinished
    case noActiveSleep
    case authenticationRequired
    case storageUnavailable
}

nonisolated enum RegistrationMutationCategory: String, Codable, Sendable {
    case diaper
    case feed
    case sleep
    case session
}

nonisolated struct RegistrationMutationResult: Sendable {
    let outcome: RegistrationMutationOutcome
    let category: RegistrationMutationCategory
    let entry: Entry?
    let snapshot: NidoSnapshot
    let activeSleepStartedAt: Date?

    var dialog: String {
        Self.dialog(for: outcome, category: category)
    }

    static func dialog(
        for outcome: RegistrationMutationOutcome,
        category: RegistrationMutationCategory = .session
    ) -> String {
        switch (outcome, category) {
        case (.registered, .diaper): "Pañal registrado."
        case (.queued, .diaper): "Pañal guardado para sincronizar."
        case (.registered, .feed): "Toma registrada."
        case (.queued, .feed): "Toma guardada para sincronizar."
        case (.noReusableFeed, _): "No encuentro una toma reutilizable; abre Nido."
        case (.sleepStarted, _): "Sueño iniciado."
        case (.sleepAlreadyActive, _): "Ya hay un sueño en curso."
        case (.sleepFinished, _), (.registered, .sleep): "Sueño terminado y guardado."
        case (.queued, .sleep): "Sueño guardado para sincronizar."
        case (.noActiveSleep, _): "No hay un sueño activo."
        case (.authenticationRequired, _): "Abre Nido para volver a iniciar sesión."
        case (.storageUnavailable, _): "No he podido guardar el registro. Abre Nido para intentarlo de nuevo."
        case (.registered, _): "Actividad registrada."
        case (.queued, _): "Actividad guardada para sincronizar."
        }
    }
}

nonisolated struct RegistrationLocalCommit: Sendable {
    let category: RegistrationMutationCategory
    let entry: Entry?
    let snapshot: NidoSnapshot
    let activeSleepStartedAt: Date?
}

@MainActor
protocol RegistrationMutationEventReceiver: AnyObject {
    func registrationServiceDidCommit(_ commit: RegistrationLocalCommit)
    func registrationServiceDidInvalidate()
}

@MainActor
final class RegistrationMutationEventHub {
    private weak var receiver: (any RegistrationMutationEventReceiver)?

    func attach(_ receiver: any RegistrationMutationEventReceiver) {
        self.receiver = receiver
    }

    func publish(_ commit: RegistrationLocalCommit) {
        receiver?.registrationServiceDidCommit(commit)
    }

    func invalidate() {
        receiver?.registrationServiceDidInvalidate()
    }
}

nonisolated struct RegistrationMutationDependencies: Sendable {
    let loadCredential: @Sendable () -> SessionCredential?
    let deleteCredential: @Sendable () -> Void
    let createEntry: @Sendable (Entry, String) async throws -> Entry
    let publishLocalCommit: @Sendable (RegistrationLocalCommit) async -> Void
    let clearExternalState: @Sendable () async -> Void
    let now: @Sendable () -> Date
    let makeID: @Sendable () -> String
    let syncSleep: @Sendable (Date?, Date?, String) async throws -> Date?
    let loadSleep: @Sendable (String) async throws -> Date?

    init(
        loadCredential: @escaping @Sendable () -> SessionCredential?,
        deleteCredential: @escaping @Sendable () -> Void,
        createEntry: @escaping @Sendable (Entry, String) async throws -> Entry,
        publishLocalCommit: @escaping @Sendable (RegistrationLocalCommit) async -> Void,
        clearExternalState: @escaping @Sendable () async -> Void,
        now: @escaping @Sendable () -> Date,
        makeID: @escaping @Sendable () -> String,
        syncSleep: @escaping @Sendable (Date?, Date?, String) async throws -> Date? = { proposed, _, _ in proposed },
        loadSleep: @escaping @Sendable (String) async throws -> Date? = { _ in nil }
    ) {
        self.loadCredential = loadCredential
        self.deleteCredential = deleteCredential
        self.createEntry = createEntry
        self.publishLocalCommit = publishLocalCommit
        self.clearExternalState = clearExternalState
        self.now = now
        self.makeID = makeID
        self.syncSleep = syncSleep
        self.loadSleep = loadSleep
    }
}

nonisolated struct RegistrationStateDefaults: @unchecked Sendable {
    let durable: UserDefaults
    let legacy: UserDefaults
}

nonisolated struct RegistrationStateFileStore: Sendable {
    static let iOSWriteOptions: Data.WritingOptions = [.atomic, .completeFileProtection]

    private let loadData: @Sendable () throws -> Data?
    private let saveData: @Sendable (Data) throws -> Void
    private let removeData: @Sendable () throws -> Void

    init(fileURL: URL) {
        loadData = {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
            return try Data(contentsOf: fileURL)
        }
        saveData = { data in
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            #if os(iOS)
            try data.write(to: fileURL, options: Self.iOSWriteOptions)
            #else
            try data.write(to: fileURL, options: .atomic)
            #endif
        }
        removeData = {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    init(
        load: @escaping @Sendable () throws -> Data?,
        save: @escaping @Sendable (Data) throws -> Void,
        remove: @escaping @Sendable () throws -> Void
    ) {
        loadData = load
        saveData = save
        removeData = remove
    }

    func load() throws -> Data? { try loadData() }
    func save(_ data: Data) throws { try saveData(data) }
    func remove() throws { try removeData() }
}

nonisolated struct RegistrationVoiceReceipt: Codable, Equatable, Sendable {
    let digest: String
    let entryID: String
    let expiresAt: Date
}

nonisolated struct RegistrationDurableState: Codable, Equatable, Sendable {
    var activeSleepStartedAt: Date?
    var finishingSleepEntry: Entry?
    var voiceReceipts: [RegistrationVoiceReceipt]
    var hasPendingSleepMutation: Bool
    var pendingSleepStartedAt: Date?
    var pendingSleepExpectedStartedAt: Date?
    var finishingSleepStartedAt: Date?

    init(
        activeSleepStartedAt: Date? = nil,
        finishingSleepEntry: Entry? = nil,
        voiceReceipts: [RegistrationVoiceReceipt] = [],
        hasPendingSleepMutation: Bool = false,
        pendingSleepStartedAt: Date? = nil,
        pendingSleepExpectedStartedAt: Date? = nil,
        finishingSleepStartedAt: Date? = nil
    ) {
        self.activeSleepStartedAt = activeSleepStartedAt
        self.finishingSleepEntry = finishingSleepEntry
        self.voiceReceipts = voiceReceipts
        self.hasPendingSleepMutation = hasPendingSleepMutation
        self.pendingSleepStartedAt = pendingSleepStartedAt
        self.pendingSleepExpectedStartedAt = pendingSleepExpectedStartedAt
        self.finishingSleepStartedAt = finishingSleepStartedAt
    }

    private enum CodingKeys: String, CodingKey { case activeSleepStartedAt, finishingSleepEntry, voiceReceipts, hasPendingSleepMutation, pendingSleepStartedAt, pendingSleepExpectedStartedAt, finishingSleepStartedAt }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        activeSleepStartedAt = try values.decodeIfPresent(Date.self, forKey: .activeSleepStartedAt)
        finishingSleepEntry = try values.decodeIfPresent(Entry.self, forKey: .finishingSleepEntry)
        voiceReceipts = try values.decodeIfPresent([RegistrationVoiceReceipt].self, forKey: .voiceReceipts) ?? []
        hasPendingSleepMutation = try values.decodeIfPresent(Bool.self, forKey: .hasPendingSleepMutation)
            ?? (activeSleepStartedAt != nil)
        pendingSleepStartedAt = try values.decodeIfPresent(Date.self, forKey: .pendingSleepStartedAt)
            ?? (hasPendingSleepMutation ? activeSleepStartedAt : nil)
        pendingSleepExpectedStartedAt = try values.decodeIfPresent(Date.self, forKey: .pendingSleepExpectedStartedAt)
        finishingSleepStartedAt = try values.decodeIfPresent(Date.self, forKey: .finishingSleepStartedAt)
    }
}

private nonisolated struct LegacyRegistrationVoiceReceipt: Codable {
    let entryID: String
}

private nonisolated struct LegacyRegistrationDurableState: Codable {
    let activeSleepStartedAt: Date?
    let finishingSleepEntry: Entry?
    let voiceReceipts: [LegacyRegistrationVoiceReceipt]
}

actor RegistrationMutationService {
    static let stateKey = "nido.registration.state.v1"
    static let voiceReceiptWindow: TimeInterval = 8

    private let cache: LocalCache
    private let stateStore: RegistrationStateFileStore
    private let legacyDefaults: RegistrationStateDefaults
    private let dependencies: RegistrationMutationDependencies
    private var loadedSnapshot: NidoSnapshot?
    private var loadedState: RegistrationDurableState?
    private var stateRevision: UInt64 = 0
    private var privateStateGeneration: UInt64 = 0
    private var sleepMutationInFlight = false

    init(
        cache: LocalCache,
        stateStore: RegistrationStateFileStore,
        legacyDefaults: RegistrationStateDefaults,
        dependencies: RegistrationMutationDependencies
    ) {
        self.cache = cache
        self.stateStore = stateStore
        self.legacyDefaults = legacyDefaults
        self.dependencies = dependencies
    }

    func registerDiaper(caregiverID: String?, caregiverName: String?) async -> RegistrationMutationResult {
        guard let credential = await validCredential() else { return authenticationResult() }
        do {
            let snapshot = try loadSnapshot()
            if let duplicate = try recentVoiceResult(category: .diaper, credential: credential, snapshot: snapshot) {
                return duplicate
            }
            let draft = RegistrationQuickAction.diaper(entries: snapshot.entries, at: dependencies.now()).draft
            return await create(
                draft: draft,
                caregiverID: caregiverID,
                caregiverName: caregiverName,
                category: .diaper,
                credential: credential,
                recordsVoiceReceipt: true
            )
        } catch {
            return storageResult(category: .diaper)
        }
    }

    func registerFeed(caregiverID: String?, caregiverName: String?) async -> RegistrationMutationResult {
        guard let credential = await validCredential() else { return authenticationResult() }
        do {
            let snapshot = try loadSnapshot()
            if let duplicate = try recentVoiceResult(category: .feed, credential: credential, snapshot: snapshot) {
                return duplicate
            }
            guard let draft = RegistrationQuickAction.feed(entries: snapshot.entries, at: dependencies.now())?.draft else {
                return try result(.noReusableFeed, category: .feed, snapshot: snapshot)
            }
            return await create(
                draft: draft,
                caregiverID: caregiverID,
                caregiverName: caregiverName,
                category: .feed,
                credential: credential,
                recordsVoiceReceipt: true
            )
        } catch {
            return storageResult(category: .feed)
        }
    }

    func create(
        draft: RegistrationDraft,
        caregiverID: String?,
        caregiverName: String?,
        onLocalCommit: (@Sendable (Entry) async -> Void)? = nil
    ) async -> RegistrationMutationResult {
        guard let credential = await validCredential() else { return authenticationResult() }
        return await create(
            draft: draft,
            caregiverID: caregiverID,
            caregiverName: caregiverName,
            category: category(for: draft.kind),
            credential: credential,
            recordsVoiceReceipt: false,
            onLocalCommit: onLocalCommit
        )
    }

    func startSleep() async -> RegistrationMutationResult {
        guard let credential = await validCredential() else { return authenticationResult() }
        do {
            var state = try durableState()
            let snapshot = try loadSnapshot()
            if state.activeSleepStartedAt != nil {
                return try result(.sleepAlreadyActive, category: .sleep, snapshot: snapshot, state: state)
            }
            let remoteExpectation = state.hasPendingSleepMutation ? state.pendingSleepExpectedStartedAt : nil
            state.activeSleepStartedAt = dependencies.now()
            state.hasPendingSleepMutation = true
            state.pendingSleepStartedAt = state.activeSleepStartedAt
            state.pendingSleepExpectedStartedAt = remoteExpectation
            try saveState(state)
            let commit = RegistrationLocalCommit(
                category: .sleep,
                entry: nil,
                snapshot: snapshot,
                activeSleepStartedAt: state.activeSleepStartedAt
            )
            await dependencies.publishLocalCommit(commit)
            await trySyncPendingSleep(state: state, credential: credential)
            state = try durableState()
            return try result(.sleepStarted, category: .sleep, snapshot: snapshot, state: state)
        } catch {
            return storageResult(category: .sleep)
        }
    }

    func finishSleep(caregiverID: String?, caregiverName: String?) async -> RegistrationMutationResult {
        guard let credential = await validCredential() else { return authenticationResult() }
        let requestGeneration = privateStateGeneration
        let requestToken = credential.accessToken
        do {
            var state = try durableState()
            let entry: Entry
            if let finishing = state.finishingSleepEntry {
                entry = finishing
            } else {
                guard let start = state.activeSleepStartedAt else {
                    return try result(.noActiveSleep, category: .sleep, snapshot: loadSnapshot(), state: state)
                }
                let interval = SleepInterval(start: start, end: dependencies.now())
                entry = RegistrationDraft(
                    kind: .sleep,
                    detail: interval.detail(note: ""),
                    date: interval.end,
                    durationMinutes: interval.durationMinutes,
                    amountMl: nil
                ).makeEntry(id: dependencies.makeID(), caregiverID: caregiverID, caregiverName: caregiverName)
                state.finishingSleepEntry = entry
                try saveState(state)
            }

            var snapshot = try loadSnapshot()
            if !snapshot.entries.contains(where: { $0.id == entry.id }) {
                snapshot.entries.insert(entry, at: 0)
                snapshot.pendingEntryIDs.insert(entry.id)
                try saveSnapshot(snapshot)
            }
            let finishedStart = state.activeSleepStartedAt ?? state.finishingSleepStartedAt
            let remoteExpectation = state.hasPendingSleepMutation
                ? state.pendingSleepExpectedStartedAt
                : finishedStart
            state.activeSleepStartedAt = nil
            state.finishingSleepStartedAt = finishedStart
            state.hasPendingSleepMutation = true
            state.pendingSleepStartedAt = nil
            state.pendingSleepExpectedStartedAt = remoteExpectation
            state.finishingSleepEntry = nil
            try saveState(state)
            await publishLocalCommit(category: .sleep, entry: entry, snapshot: snapshot, state: state)
            let uploaded = await upload(entry, credential: credential, category: .sleep)
            guard requestGeneration == privateStateGeneration,
                  currentCredentialMatches(requestToken) else { return authenticationResult() }
            if uploaded.outcome == .registered || uploaded.outcome == .sleepFinished {
                await trySyncPendingSleep(state: try durableState(), credential: credential)
            }
            guard requestGeneration == privateStateGeneration,
                  currentCredentialMatches(requestToken) else { return authenticationResult() }
            return try result(uploaded.outcome, category: .sleep, entry: uploaded.entry, snapshot: uploaded.snapshot, state: try durableState())
        } catch {
            return storageResult(category: .sleep)
        }
    }

    func activeSleepStartedAt() throws -> Date? {
        try durableState().activeSleepStartedAt
    }

    func updateSleepStart(_ startedAt: Date) async throws -> Date? {
        guard let credential = await validCredential() else { return nil }
        let requestGeneration = privateStateGeneration
        let requestToken = credential.accessToken
        var state = try durableState()
        guard state.activeSleepStartedAt != nil else { return nil }
        let previousStart = state.activeSleepStartedAt
        let remoteExpectation = state.hasPendingSleepMutation
            ? state.pendingSleepExpectedStartedAt
            : previousStart
        let correctedStart = min(startedAt, dependencies.now())
        state.activeSleepStartedAt = correctedStart
        state.hasPendingSleepMutation = true
        state.pendingSleepStartedAt = correctedStart
        state.pendingSleepExpectedStartedAt = remoteExpectation
        try saveState(state)
        await publishLocalCommit(
            category: .sleep,
            entry: nil,
            snapshot: try loadSnapshot(),
            state: state
        )
        guard requestGeneration == privateStateGeneration,
              currentCredentialMatches(requestToken) else { return nil }
        await trySyncPendingSleep(state: state, credential: credential)
        guard requestGeneration == privateStateGeneration,
              currentCredentialMatches(requestToken) else { return nil }
        return try durableState().activeSleepStartedAt
    }

    func synchronizeSleep() async throws -> Date? {
        guard let credential = await validCredential() else { return try durableState().activeSleepStartedAt }
        var state = try durableState()
        if state.hasPendingSleepMutation {
            // A finish is only acknowledged remotely after its durable entry has uploaded.
            let snapshot = try loadSnapshot()
            if state.pendingSleepStartedAt == nil,
               snapshot.entries.contains(where: { $0.kind == .sleep && snapshot.pendingEntryIDs.contains($0.id) }) {
                return state.activeSleepStartedAt
            }
            do { try await applyPendingSleep(state: state, credential: credential) }
            catch {
                if SessionFailurePolicy.disposition(for: error, during: .update) == .invalidateSession,
                   currentCredentialMatches(credential.accessToken) {
                    await invalidatePrivateState()
                }
                throw error
            }
            state = try durableState()
        }
        let requestRevision = stateRevision
        let requestGeneration = privateStateGeneration
        let remote: Date?
        do { remote = try await dependencies.loadSleep(credential.accessToken) }
        catch {
            if SessionFailurePolicy.disposition(for: error, during: .update) == .invalidateSession,
               currentCredentialMatches(credential.accessToken) {
                await invalidatePrivateState()
            }
            throw error
        }
        // A local mutation created while the remote read was suspended always wins.
        var latest = try durableState()
        guard stateRevision == requestRevision,
              privateStateGeneration == requestGeneration,
              currentCredentialMatches(credential.accessToken) else { return latest.activeSleepStartedAt }
        if latest.hasPendingSleepMutation { return latest.activeSleepStartedAt }
        if latest.activeSleepStartedAt != remote {
            latest.activeSleepStartedAt = remote
            try saveState(latest)
            await publishLocalCommit(category: .sleep, entry: nil, snapshot: try loadSnapshot(), state: latest)
        }
        return latest.activeSleepStartedAt
    }

    private func trySyncPendingSleep(state: RegistrationDurableState, credential: SessionCredential) async {
        do { try await applyPendingSleep(state: state, credential: credential) }
        catch {
            if SessionFailurePolicy.disposition(for: error, during: .update) == .invalidateSession,
               currentCredentialMatches(credential.accessToken) {
                await invalidatePrivateState()
            }
        }
    }

    private func applyPendingSleep(
        state original: RegistrationDurableState,
        credential: SessionCredential
    ) async throws {
        guard original.hasPendingSleepMutation else { return }
        guard currentCredentialMatches(credential.accessToken) else { return }
        guard !sleepMutationInFlight else { return }
        let snapshot = try loadSnapshot()
        if original.pendingSleepStartedAt == nil,
           snapshot.entries.contains(where: { $0.kind == .sleep && snapshot.pendingEntryIDs.contains($0.id) }) {
            return
        }
        sleepMutationInFlight = true
        let requestRevision = stateRevision
        let requestGeneration = privateStateGeneration
        let response: Date?
        do {
            response = try await dependencies.syncSleep(original.pendingSleepStartedAt, original.pendingSleepExpectedStartedAt, credential.accessToken)
        } catch {
            sleepMutationInFlight = false
            throw error
        }
        sleepMutationInFlight = false
        var latest = try durableState()
        guard privateStateGeneration == requestGeneration,
              currentCredentialMatches(credential.accessToken),
              latest.hasPendingSleepMutation else { return }
        if stateRevision != requestRevision
            || latest.pendingSleepStartedAt != original.pendingSleepStartedAt
            || latest.pendingSleepExpectedStartedAt != original.pendingSleepExpectedStartedAt {
            // A successful earlier PUT establishes the base for a newer local mutation.
            guard response == original.pendingSleepStartedAt else {
                latest.activeSleepStartedAt = response
                latest.hasPendingSleepMutation = false
                latest.pendingSleepStartedAt = nil
                latest.pendingSleepExpectedStartedAt = nil
                latest.finishingSleepStartedAt = nil
                try saveState(latest)
                await publishLocalCommit(category: .sleep, entry: nil, snapshot: try loadSnapshot(), state: latest)
                return
            }
            latest.pendingSleepExpectedStartedAt = response
            try saveState(latest)
            await publishLocalCommit(category: .sleep, entry: nil, snapshot: try loadSnapshot(), state: latest)
            try await applyPendingSleep(state: latest, credential: credential)
            return
        }
        if response != original.pendingSleepStartedAt {
            latest.activeSleepStartedAt = response
            latest.hasPendingSleepMutation = false
            latest.pendingSleepStartedAt = nil
            latest.pendingSleepExpectedStartedAt = nil
            latest.finishingSleepStartedAt = nil
            try saveState(latest)
            await publishLocalCommit(category: .sleep, entry: nil, snapshot: try loadSnapshot(), state: latest)
            return
        }
        latest.hasPendingSleepMutation = false
        latest.pendingSleepStartedAt = nil
        latest.pendingSleepExpectedStartedAt = nil
        latest.finishingSleepStartedAt = nil
        latest.activeSleepStartedAt = response
        try saveState(latest)
        await publishLocalCommit(category: .sleep, entry: nil, snapshot: try loadSnapshot(), state: latest)
    }

    func snapshot() throws -> (NidoSnapshot, Date?) {
        (try loadSnapshot(), try durableState().activeSleepStartedAt)
    }

    func updateAppEntry(_ entry: Entry, expectedAccessToken: String?) throws -> Bool {
        if let expectedAccessToken, !currentCredentialMatches(expectedAccessToken) {
            throw APIError.missingCredential
        }
        var latest = try loadSnapshot()
        guard let index = latest.entries.firstIndex(where: { $0.id == entry.id }) else { return false }
        latest.entries[index] = entry
        latest.entries.sort { $0.occurredAt > $1.occurredAt }
        try saveSnapshot(latest)
        return true
    }

    func saveAppSnapshot(
        _ proposed: NidoSnapshot,
        removingEntryIDs: Set<String> = [],
        acknowledgedEntryIDs: Set<String> = [],
        expectedAccessToken: String? = nil
    ) throws -> NidoSnapshot {
        if let expectedAccessToken, !currentCredentialMatches(expectedAccessToken) {
            throw APIError.missingCredential
        }
        let latest = try loadSnapshot()
        var merged = proposed
        if merged.profile == nil { merged.profile = latest.profile }
        for id in latest.pendingEntryIDs {
            guard let latestEntry = latest.entries.first(where: { $0.id == id }) else { continue }
            if !removingEntryIDs.contains(id), !merged.entries.contains(where: { $0.id == id }) {
                merged.entries.append(latestEntry)
            }
            if !removingEntryIDs.contains(id), !acknowledgedEntryIDs.contains(id) {
                merged.pendingEntryIDs.insert(id)
            }
        }
        merged.entries.removeAll { removingEntryIDs.contains($0.id) }
        merged.pendingEntryIDs.subtract(removingEntryIDs.union(acknowledgedEntryIDs))
        merged.entries.sort { $0.occurredAt > $1.occurredAt }
        try saveSnapshot(merged)
        return merged
    }

    func clearPrivateData() async {
        await invalidatePrivateState()
    }

    func clearPersistentHouseholdData() async {
        privateStateGeneration &+= 1
        try? cache.remove()
        try? stateStore.remove()
        legacyDefaults.durable.removeObject(forKey: Self.stateKey)
        legacyDefaults.legacy.removeObject(forKey: "activeSleepStartedAt")
        loadedSnapshot = .empty
        loadedState = RegistrationDurableState()
    }

    private func create(
        draft: RegistrationDraft,
        caregiverID: String?,
        caregiverName: String?,
        category: RegistrationMutationCategory,
        credential: SessionCredential,
        recordsVoiceReceipt: Bool,
        onLocalCommit: (@Sendable (Entry) async -> Void)? = nil
    ) async -> RegistrationMutationResult {
        let entry = draft.makeEntry(
            id: dependencies.makeID(),
            caregiverID: caregiverID,
            caregiverName: caregiverName
        )
        do {
            var snapshot = try loadSnapshot()
            if recordsVoiceReceipt {
                var state = try durableState()
                let now = dependencies.now()
                state.voiceReceipts.removeAll { $0.expiresAt <= now }
                state.voiceReceipts.append(RegistrationVoiceReceipt(
                    digest: receiptDigest(credential: credential, category: category),
                    entryID: entry.id,
                    expiresAt: now.addingTimeInterval(Self.voiceReceiptWindow)
                ))
                try saveState(state)
            }
            snapshot.entries.insert(entry, at: 0)
            snapshot.pendingEntryIDs.insert(entry.id)
            try saveSnapshot(snapshot)
            await publishLocalCommit(category: category, entry: entry, snapshot: snapshot)
            await onLocalCommit?(entry)
            return await upload(entry, credential: credential, category: category)
        } catch {
            return storageResult(category: category)
        }
    }

    private func upload(
        _ entry: Entry,
        credential: SessionCredential,
        category: RegistrationMutationCategory
    ) async -> RegistrationMutationResult {
        let requestGeneration = privateStateGeneration
        guard currentCredentialMatches(credential.accessToken) else { return authenticationResult() }
        do {
            let saved = try await dependencies.createEntry(entry, credential.accessToken)
            guard requestGeneration == privateStateGeneration,
                  currentCredentialMatches(credential.accessToken) else { return authenticationResult() }
            var latest = try loadSnapshot()
            if let index = latest.entries.firstIndex(where: { $0.id == entry.id }), latest.entries[index] == entry {
                latest.entries[index] = saved
            }
            latest.pendingEntryIDs.remove(entry.id)
            do {
                try saveSnapshot(latest)
            } catch {
                return try result(.queued, category: category, entry: entry, snapshot: loadSnapshot())
            }
            await publishLocalCommit(category: category, entry: saved, snapshot: latest)
            let outcome: RegistrationMutationOutcome = category == .sleep ? .sleepFinished : .registered
            return try result(outcome, category: category, entry: saved, snapshot: latest)
        } catch {
            if SessionFailurePolicy.disposition(for: error, during: .create) == .invalidateSession,
               requestGeneration == privateStateGeneration,
               currentCredentialMatches(credential.accessToken) {
                await invalidatePrivateState()
                return authenticationResult()
            }
            do {
                return try result(.queued, category: category, entry: entry, snapshot: loadSnapshot())
            } catch {
                return storageResult(category: category)
            }
        }
    }

    private func recentVoiceResult(
        category: RegistrationMutationCategory,
        credential: SessionCredential,
        snapshot: NidoSnapshot
    ) throws -> RegistrationMutationResult? {
        let state = try durableState()
        let digest = receiptDigest(credential: credential, category: category)
        guard let receipt = state.voiceReceipts.last(where: {
            $0.digest == digest && $0.expiresAt > dependencies.now()
        }), let entry = snapshot.entries.first(where: { $0.id == receipt.entryID }) else { return nil }
        let outcome: RegistrationMutationOutcome = snapshot.pendingEntryIDs.contains(entry.id) ? .queued : .registered
        return try result(outcome, category: category, entry: entry, snapshot: snapshot, state: state)
    }

    private func receiptDigest(
        credential: SessionCredential,
        category: RegistrationMutationCategory
    ) -> String {
        let identity = credential.appleUserID ?? ""
        let material = Data("\(identity)|\(credential.accessToken)|\(category.rawValue)".utf8)
        return SHA256.hash(data: material).map { String(format: "%02x", $0) }.joined()
    }

    private func validCredential() async -> SessionCredential? {
        guard let credential = dependencies.loadCredential(), !credential.isExpired(at: dependencies.now()) else {
            await invalidatePrivateState()
            return nil
        }
        return credential
    }

    private func invalidatePrivateState() async {
        privateStateGeneration &+= 1
        dependencies.deleteCredential()
        try? cache.remove()
        try? stateStore.remove()
        legacyDefaults.durable.removeObject(forKey: Self.stateKey)
        legacyDefaults.legacy.removeObject(forKey: "activeSleepStartedAt")
        loadedSnapshot = .empty
        loadedState = RegistrationDurableState()
        await dependencies.clearExternalState()
    }

    private func durableState() throws -> RegistrationDurableState {
        if let loadedState { return loadedState }
        if let data = try stateStore.load() {
            let state = try JSONDecoder().decode(RegistrationDurableState.self, from: data)
            loadedState = state
            return state
        }

        var migrated = RegistrationDurableState()
        if let data = legacyDefaults.durable.data(forKey: Self.stateKey) {
            if let current = try? JSONDecoder().decode(RegistrationDurableState.self, from: data) {
                migrated.activeSleepStartedAt = current.activeSleepStartedAt
                migrated.finishingSleepEntry = current.finishingSleepEntry
                migrated.hasPendingSleepMutation = current.hasPendingSleepMutation
                migrated.pendingSleepStartedAt = current.pendingSleepStartedAt
                migrated.pendingSleepExpectedStartedAt = current.pendingSleepExpectedStartedAt
                migrated.finishingSleepStartedAt = current.finishingSleepStartedAt
            } else {
                let legacy = try JSONDecoder().decode(LegacyRegistrationDurableState.self, from: data)
                migrated.activeSleepStartedAt = legacy.activeSleepStartedAt
                migrated.finishingSleepEntry = legacy.finishingSleepEntry
                migrated.hasPendingSleepMutation = legacy.activeSleepStartedAt != nil
                migrated.pendingSleepStartedAt = legacy.activeSleepStartedAt
            }
        } else if let timestamp = legacyDefaults.legacy.object(forKey: "activeSleepStartedAt") as? Double {
            migrated.activeSleepStartedAt = Date(timeIntervalSince1970: timestamp)
            migrated.hasPendingSleepMutation = true
            migrated.pendingSleepStartedAt = migrated.activeSleepStartedAt
        }
        try saveState(migrated)
        legacyDefaults.durable.removeObject(forKey: Self.stateKey)
        legacyDefaults.legacy.removeObject(forKey: "activeSleepStartedAt")
        return migrated
    }

    private func saveState(_ state: RegistrationDurableState) throws {
        let encoded = try JSONEncoder().encode(state)
        try stateStore.save(encoded)
        loadedState = state
        stateRevision &+= 1
    }

    private func currentCredentialMatches(_ accessToken: String) -> Bool {
        guard let current = dependencies.loadCredential(),
              current.accessToken == accessToken,
              !current.isExpired(at: dependencies.now()) else { return false }
        return true
    }

    private func loadSnapshot() throws -> NidoSnapshot {
        if let loadedSnapshot { return loadedSnapshot }
        let snapshot = try cache.load()
        loadedSnapshot = snapshot
        return snapshot
    }

    private func saveSnapshot(_ snapshot: NidoSnapshot) throws {
        try cache.save(snapshot)
        loadedSnapshot = snapshot
    }

    private func publishLocalCommit(
        category: RegistrationMutationCategory,
        entry: Entry?,
        snapshot: NidoSnapshot,
        state: RegistrationDurableState? = nil
    ) async {
        let activeSleepStartedAt = state?.activeSleepStartedAt ?? (try? durableState().activeSleepStartedAt)
        await dependencies.publishLocalCommit(RegistrationLocalCommit(
            category: category,
            entry: entry,
            snapshot: snapshot,
            activeSleepStartedAt: activeSleepStartedAt
        ))
    }

    private func authenticationResult() -> RegistrationMutationResult {
        RegistrationMutationResult(
            outcome: .authenticationRequired,
            category: .session,
            entry: nil,
            snapshot: .empty,
            activeSleepStartedAt: nil
        )
    }

    private func storageResult(category: RegistrationMutationCategory) -> RegistrationMutationResult {
        RegistrationMutationResult(
            outcome: .storageUnavailable,
            category: category,
            entry: nil,
            snapshot: loadedSnapshot ?? .empty,
            activeSleepStartedAt: loadedState?.activeSleepStartedAt
        )
    }

    private func result(
        _ outcome: RegistrationMutationOutcome,
        category: RegistrationMutationCategory,
        entry: Entry? = nil,
        snapshot: NidoSnapshot,
        state: RegistrationDurableState? = nil
    ) throws -> RegistrationMutationResult {
        RegistrationMutationResult(
            outcome: outcome,
            category: category,
            entry: entry,
            snapshot: snapshot,
            activeSleepStartedAt: try (state ?? durableState()).activeSleepStartedAt
        )
    }

    private func category(for kind: EntryKind) -> RegistrationMutationCategory {
        switch kind {
        case .diaper: .diaper
        case .feed: .feed
        case .sleep: .sleep
        case .health: .session
        }
    }
}
