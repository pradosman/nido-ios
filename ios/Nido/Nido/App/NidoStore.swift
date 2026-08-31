import Foundation
import Observation
import os

enum NidoFeedbackKind {
    case selection
    case success
    case warning
    case error
}

@Observable
final class NidoStore {
    enum Phase: Equatable {
        case loading
        case onboarding
        case caregiverAccess
        case ready
    }

    var phase: Phase = .loading
    var profile: Profile?
    var entries: [Entry] = []
    var caregivers: [Caregiver] = []
    var currentCaregiver: Caregiver?
    var activeSleepStartedAt: Date?
    var activeFeedStartedAt: Date?
    var activeFeedSide: BreastSide?
    var notice: String?
    var isOffline = false
    var selectedTab = AppTab.today
    var presentedEntryKind: EntryKind?
    var editingEntry: Entry?
    var recentlyDeletedEntry: Entry?
    var recentlyCreatedEntry: Entry?
    var isEditingProfile = false
    var feedbackToken = 0
    var feedbackKind = NidoFeedbackKind.selection

    private var pendingEntryIDs: Set<String> = []
    private var profileNeedsSync = false
    private var pendingUpdatedEntryIDs: Set<String> = []
    private var pendingDeletionIDs: Set<String> = []
    private var accessToken: String?
    private let api: NidoAPI
    private let cache: LocalCache
    private let credentialStore: CredentialStore
    private let defaults: UserDefaults
    private let nowProvider: () -> Date
    private let hasInjectedNowProvider: Bool
    private let logger = Logger(subsystem: "com.momentumia.nido", category: "store")
    private let caregiverIDKey = "currentCaregiverID"

    init(
        api: NidoAPI = NidoAPI(baseURL: AppConfiguration.apiBaseURL),
        cache: LocalCache = LocalCache(),
        credentialStore: CredentialStore = CredentialStore(),
        defaults: UserDefaults = .standard,
        now: (() -> Date)? = nil,
        shouldLoadCredential: Bool = true,
        initialAccessToken: String? = nil
    ) {
        self.api = api
        self.cache = cache
        self.credentialStore = credentialStore
        self.defaults = defaults
        self.nowProvider = now ?? { .now }
        self.hasInjectedNowProvider = now != nil
        accessToken = initialAccessToken ?? (shouldLoadCredential ? credentialStore.load() : nil)
        pendingUpdatedEntryIDs = Set(defaults.stringArray(forKey: "pendingUpdatedEntryIDs") ?? [])
        pendingDeletionIDs = Set(defaults.stringArray(forKey: "pendingDeletionIDs") ?? [])
        if let timestamp = defaults.object(forKey: "activeSleepStartedAt") as? Double {
            activeSleepStartedAt = Date(timeIntervalSince1970: timestamp)
        }
        if let timestamp = defaults.object(forKey: "activeFeedStartedAt") as? Double {
            activeFeedStartedAt = Date(timeIntervalSince1970: timestamp)
            activeFeedSide = defaults.string(forKey: "activeFeedSide").flatMap(BreastSide.init(rawValue:)) ?? .left
        }
    }

    var now: Date { nowProvider() }

    func currentDate(for timelineDate: Date) -> Date {
        hasInjectedNowProvider ? nowProvider() : timelineDate
    }

    #if DEBUG
    func prepareForUITesting(scenario: String) {
        phase = .loading
        profile = nil
        entries = []
        caregivers = []
        currentCaregiver = nil
        activeSleepStartedAt = nil
        activeFeedStartedAt = nil
        activeFeedSide = nil
        notice = nil
        isOffline = false
        selectedTab = .today
        presentedEntryKind = nil
        editingEntry = nil
        recentlyDeletedEntry = nil
        recentlyCreatedEntry = nil
        isEditingProfile = false
        pendingEntryIDs = []
        pendingUpdatedEntryIDs = []
        pendingDeletionIDs = []
        profileNeedsSync = false
        accessToken = nil

        guard scenario != "onboarding" else {
            phase = .onboarding
            return
        }

        let caregiver = Caregiver(
            id: "ui-test-caregiver",
            name: "David",
            role: .owner,
            status: .active,
            inviteCode: nil,
            createdAt: nil,
            joinedAt: nil
        )
        profile = Profile(caregiverName: caregiver.name, babyName: "Marco", birthDate: "2026-08-01")
        caregivers = [caregiver]
        currentCaregiver = caregiver
        if scenario == "quick-diaper-registration" {
            entries = [
                Entry(
                    id: "ui-test-latest-diaper",
                    kind: .diaper,
                    title: EntryKind.diaper.title,
                    detail: "Pis y caca · Normal",
                    occurredAt: Int64(now.addingTimeInterval(-60).timeIntervalSince1970 * 1_000),
                    durationMinutes: nil,
                    amountMl: nil,
                    caregiverID: caregiver.id,
                    caregiverName: caregiver.name
                ),
                Entry(
                    id: "ui-test-older-diaper",
                    kind: .diaper,
                    title: EntryKind.diaper.title,
                    detail: "Caca",
                    occurredAt: Int64(now.addingTimeInterval(-3_600).timeIntervalSince1970 * 1_000),
                    durationMinutes: nil,
                    amountMl: nil,
                    caregiverID: caregiver.id,
                    caregiverName: caregiver.name
                ),
            ]
        } else if scenario == "repeat-feed-registration" {
            entries = [Entry(
                id: "ui-test-latest-feed",
                kind: .feed,
                title: EntryKind.feed.title,
                detail: "Biberón · Fórmula · Tomó despacio",
                occurredAt: Int64(now.addingTimeInterval(-1_800).timeIntervalSince1970 * 1_000),
                durationMinutes: 18,
                amountMl: 120,
                caregiverID: "ui-test-other-caregiver",
                caregiverName: "Ana"
            )]
        } else if scenario == "active-sleep" {
            activeSleepStartedAt = Date.now.addingTimeInterval(-47 * 60)
        } else if scenario == "active-feed" {
            activeFeedStartedAt = now.addingTimeInterval(-12 * 60)
            activeFeedSide = .right
            entries = [Entry(
                id: "ui-test-yesterday-feed",
                kind: .feed,
                title: EntryKind.feed.title,
                detail: "Biberón · Fórmula",
                occurredAt: Int64(now.addingTimeInterval(-25 * 60 * 60).timeIntervalSince1970 * 1_000),
                durationMinutes: nil,
                amountMl: 90,
                caregiverID: caregiver.id,
                caregiverName: caregiver.name
            )]
        } else if scenario == "undo-notice" {
            let deleted = Entry(
                id: "ui-test-deleted-entry",
                kind: .diaper,
                title: EntryKind.diaper.title,
                detail: "Pis",
                occurredAt: Int64(now.timeIntervalSince1970 * 1_000),
                durationMinutes: nil,
                amountMl: nil,
                caregiverID: caregiver.id,
                caregiverName: caregiver.name
            )
            recentlyDeletedEntry = deleted
            notice = "Registro eliminado"
        } else if scenario == "caregiver-removal" {
            caregivers.append(Caregiver(
                id: "ui-test-caregiver-ana",
                name: "Ana",
                role: .caregiver,
                status: .active,
                inviteCode: nil,
                createdAt: nil,
                joinedAt: nil
            ))
        } else if scenario == "semantic-edit" {
            entries = [
                Entry(
                    id: "ui-test-semantic-feed",
                    kind: .feed,
                    title: EntryKind.feed.title,
                    detail: "Biberón · Fórmula · Sin incidencias",
                    occurredAt: Int64(now.addingTimeInterval(-60).timeIntervalSince1970 * 1_000),
                    durationMinutes: nil,
                    amountMl: 90,
                    caregiverID: caregiver.id,
                    caregiverName: caregiver.name
                ),
                Entry(
                    id: "ui-test-semantic-diaper",
                    kind: .diaper,
                    title: EntryKind.diaper.title,
                    detail: "Pis y caca · Normal",
                    occurredAt: Int64(now.addingTimeInterval(-120).timeIntervalSince1970 * 1_000),
                    durationMinutes: nil,
                    amountMl: nil,
                    caregiverID: caregiver.id,
                    caregiverName: caregiver.name
                ),
                Entry(
                    id: "ui-test-semantic-care",
                    kind: .health,
                    title: EntryKind.health.title,
                    detail: "Temperatura · 37,2 °C · Axilar",
                    occurredAt: Int64(now.addingTimeInterval(-180).timeIntervalSince1970 * 1_000),
                    durationMinutes: nil,
                    amountMl: nil,
                    caregiverID: caregiver.id,
                    caregiverName: caregiver.name
                ),
            ]
        } else if scenario == "history-calendar" {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
            let monthStart = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
            func historyEntry(id: String, kind: EntryKind, day: Int, hour: Int, title: String) -> Entry {
                let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart)!
                    .addingTimeInterval(TimeInterval(hour * 3_600))
                return Entry(
                    id: id,
                    kind: kind,
                    title: title,
                    detail: kind == .feed ? "Biberón · Fórmula" : kind == .diaper ? "Pis" : "",
                    occurredAt: Int64(date.timeIntervalSince1970 * 1_000),
                    durationMinutes: kind == .sleep ? 90 : nil,
                    amountMl: kind == .feed ? 90 : nil,
                    caregiverID: caregiver.id,
                    caregiverName: caregiver.name
                )
            }
            entries = [
                historyEntry(id: "history-wednesday", kind: .diaper, day: 26, hour: 9, title: "Pañal del miércoles"),
                historyEntry(id: "history-thursday", kind: .feed, day: 27, hour: 11, title: "Toma del jueves"),
                historyEntry(id: "history-friday-sleep", kind: .sleep, day: 28, hour: 8, title: EntryKind.sleep.title),
                historyEntry(id: "history-friday-feed", kind: .feed, day: 28, hour: 10, title: EntryKind.feed.title),
                historyEntry(id: "history-friday-diaper", kind: .diaper, day: 28, hour: 11, title: EntryKind.diaper.title),
            ]
        } else if scenario == "timeline-duration" {
            entries = [Entry(
                id: "ui-test-sleep",
                kind: .sleep,
                title: EntryKind.sleep.title,
                detail: "",
                occurredAt: Int64(Date.now.timeIntervalSince1970 * 1_000),
                durationMinutes: 75,
                amountMl: nil,
                caregiverID: caregiver.id,
                caregiverName: caregiver.name
            )]
        } else if scenario == "circular-timeline" || scenario == "circular-timeline-dense" {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
            let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 28))!
            if scenario == "circular-timeline-dense" {
                entries = (0..<6).map { index in
                    Entry(
                        id: "dense-\(index)",
                        kind: index.isMultiple(of: 2) ? .feed : .diaper,
                        title: index.isMultiple(of: 2) ? EntryKind.feed.title : EntryKind.diaper.title,
                        detail: index.isMultiple(of: 2) ? "Leche de fórmula" : "Pis",
                        occurredAt: Int64(today.addingTimeInterval(8 * 3_600 + TimeInterval(index * 60)).timeIntervalSince1970 * 1_000),
                        durationMinutes: nil,
                        amountMl: index.isMultiple(of: 2) ? 60 : nil,
                        caregiverID: caregiver.id,
                        caregiverName: caregiver.name
                    )
                }
                phase = .ready
                return
            }
            func fixtureEntry(
                id: String,
                kind: EntryKind,
                hour: Int,
                minute: Int = 0,
                durationMinutes: Int? = nil
            ) -> Entry {
                Entry(
                    id: id,
                    kind: kind,
                    title: kind.title,
                    detail: kind == .feed ? "Leche de fórmula" : kind == .diaper ? "Pis" : kind == .health ? "Baño" : "",
                    occurredAt: Int64(today.addingTimeInterval(TimeInterval(hour * 3_600 + minute * 60)).timeIntervalSince1970 * 1_000),
                    durationMinutes: durationMinutes,
                    amountMl: kind == .feed ? 60 : nil,
                    caregiverID: caregiver.id,
                    caregiverName: caregiver.name
                )
            }

            entries = [
                fixtureEntry(id: "ui-test-overnight", kind: .sleep, hour: 6, minute: 30, durationMinutes: 540),
                fixtureEntry(id: "ui-test-sleep", kind: .sleep, hour: 8, minute: 15, durationMinutes: 75),
                fixtureEntry(id: "ui-test-midday-sleep", kind: .sleep, hour: 11, minute: 35, durationMinutes: 95),
                fixtureEntry(id: "ui-test-afternoon-sleep", kind: .sleep, hour: 14, minute: 30, durationMinutes: 120),
                fixtureEntry(id: "ui-test-feed-0115", kind: .feed, hour: 1, minute: 15),
                fixtureEntry(id: "ui-test-feed-0355", kind: .feed, hour: 3, minute: 55),
                fixtureEntry(id: "ui-test-feed-0850", kind: .feed, hour: 8, minute: 50),
                fixtureEntry(id: "ui-test-feed-1223", kind: .feed, hour: 12, minute: 23),
                fixtureEntry(id: "ui-test-feed-1540", kind: .feed, hour: 15, minute: 40),
                fixtureEntry(id: "ui-test-feed", kind: .feed, hour: 18, minute: 25),
                fixtureEntry(id: "ui-test-feed-2110", kind: .feed, hour: 21, minute: 10),
                fixtureEntry(id: "ui-test-diaper-0210", kind: .diaper, hour: 2, minute: 10),
                fixtureEntry(id: "ui-test-diaper-0642", kind: .diaper, hour: 6, minute: 42),
                fixtureEntry(id: "ui-test-diaper-1105", kind: .diaper, hour: 11, minute: 5),
                fixtureEntry(id: "ui-test-diaper-1530", kind: .diaper, hour: 15, minute: 30),
                fixtureEntry(id: "ui-test-diaper-2035", kind: .diaper, hour: 20, minute: 35),
                fixtureEntry(id: "ui-test-health", kind: .health, hour: 13),
            ]
        } else if scenario == "diaper-edit" {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
            let occurredAt = calendar.date(from: DateComponents(
                year: 2026,
                month: 8,
                day: 28,
                hour: 15,
                minute: 24
            ))!
            entries = [Entry(
                id: "ui-test-diaper",
                kind: .diaper,
                title: EntryKind.diaper.title,
                detail: "Pis",
                occurredAt: Int64(occurredAt.timeIntervalSince1970 * 1_000),
                durationMinutes: nil,
                amountMl: nil,
                caregiverID: caregiver.id,
                caregiverName: caregiver.name
            )]
        }
        phase = .ready
    }
    #endif

    func load() async {
        restoreCache()
        if accessToken == nil {
            if let profile {
                do {
                    let credential = try await api.bootstrapCaregiver(name: profile.caregiverName, legacyProfile: profile)
                    try storeCredential(credential)
                } catch {
                    if case APIError.server(status: 409, message: _) = error {
                        phase = .caregiverAccess
                        notice = "Este espacio ya existe. Pide al administrador del hogar un código de invitación."
                    } else {
                        phase = .onboarding
                        isOffline = true
                        notice = error.localizedDescription
                    }
                    return
                }
            } else {
                phase = .onboarding
                isOffline = false
                return
            }
        }
        guard let token = accessToken else { phase = .caregiverAccess; return }
        do {
            try await synchronizePendingChanges()
            let remote = try await api.load(accessToken: token)
            profile = remote.profile ?? profile
            entries = EntryReconciliation.merge(
                remote: remote.entries,
                local: entries,
                protectedIDs: pendingEntryIDs.union(pendingUpdatedEntryIDs),
                excludedIDs: pendingDeletionIDs
            )
            caregivers = remote.caregivers
            if let authenticated = caregivers.first(where: { $0.id == remote.currentCaregiverID && $0.status == .active }) {
                selectCaregiver(authenticated)
            }
            isOffline = false
            persist()
        } catch {
            if case APIError.server(status: 401, message: _) = error {
                credentialStore.delete()
                accessToken = nil
                currentCaregiver = nil
                phase = .caregiverAccess
                notice = "Vuelve a introducir una invitación para acceder."
                return
            }
            isOffline = true
            logger.error("Initial sync failed: \(error.localizedDescription, privacy: .private(mask: .hash))")
            if profile != nil {
                notice = "Sin conexión. Algunos datos pueden no estar actualizados."
                if currentCaregiver == nil, let profile {
                    selectCaregiver(Caregiver(
                        id: defaults.string(forKey: caregiverIDKey) ?? UUID().uuidString,
                        name: profile.caregiverName,
                        role: .owner,
                        status: .active,
                        inviteCode: nil,
                        createdAt: nil,
                        joinedAt: nil
                    ))
                }
            }
        }
        if profile == nil {
            phase = .onboarding
        } else {
            phase = currentCaregiver == nil ? .caregiverAccess : .ready
        }
        if phase == .ready {
            await restoreLiveActivities()
        }
    }

    func saveProfile(_ value: Profile) async {
        do {
            if accessToken == nil {
                let credential = try await api.bootstrapCaregiver(name: value.caregiverName, legacyProfile: value)
                try storeCredential(credential)
            }
            guard let accessToken else { throw APIError.invalidResponse }
            profile = try await api.save(profile: value, accessToken: accessToken)
            profileNeedsSync = false
            isOffline = false
            phase = .ready
            notice = "Perfil guardado"
            signalFeedback(.success)
            persist()
        } catch {
            isOffline = true
            notice = error.localizedDescription
            if accessToken == nil {
                phase = .onboarding
            } else {
                profile = value
                profileNeedsSync = true
                phase = currentCaregiver == nil ? .caregiverAccess : .ready
                persist()
            }
        }
    }

    func addEntry(kind: EntryKind, detail: String, date: Date, durationMinutes: Int?, amountMl: Int?) async {
        await addEntry(draft: RegistrationDraft(
            kind: kind,
            detail: detail,
            date: date,
            durationMinutes: durationMinutes,
            amountMl: amountMl
        ))
    }

    func addQuickEntry(_ choice: RegistrationQuickAction.Choice) async {
        let notice = switch choice.draft.kind {
        case .feed: "Toma registrada · \(choice.summary)"
        case .diaper: "Pañal registrado · \(choice.summary)"
        case .sleep, .health: "\(choice.draft.kind.title) registrado"
        }
        await addEntry(draft: choice.draft, actionableNotice: notice)
    }

    private func addEntry(draft: RegistrationDraft, actionableNotice: String? = nil) async {
        let entry = draft.makeEntry(
            id: UUID().uuidString,
            caregiverID: currentCaregiver?.id,
            caregiverName: currentCaregiver?.name
        )
        entries.insert(entry, at: 0)
        pendingEntryIDs.insert(entry.id)
        presentedEntryKind = nil
        signalFeedback(.success)
        persist()
        if let actionableNotice {
            recentlyDeletedEntry = nil
            recentlyCreatedEntry = entry
            notice = actionableNotice
        }
        do {
            guard let accessToken else { throw APIError.server(status: 401, message: "Necesitas una invitación para acceder") }
            let saved = try await api.create(entry: entry, accessToken: accessToken)
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[index] = saved
                pendingEntryIDs.remove(entry.id)
                if recentlyCreatedEntry?.id == entry.id {
                    recentlyCreatedEntry = saved
                }
            } else {
                try await api.delete(entryID: saved.id, accessToken: accessToken)
            }
            isOffline = false
            if actionableNotice == nil {
                notice = "\(entry.title) guardado"
            }
            persist()
            if draft.kind == .feed, defaults.bool(forKey: "feedCheckReminder"), let profile {
                await ReminderManager.scheduleFeedCheck(babyName: profile.babyName)
            }
        } catch {
            isOffline = true
            if actionableNotice == nil {
                notice = "Guardado. Se sincronizará cuando vuelva la conexión."
            }
        }
    }

    func updateEntry(_ entry: Entry) async {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
        if recentlyCreatedEntry?.id == entry.id {
            recentlyCreatedEntry = entry
        }
        entries.sort { $0.occurredAt > $1.occurredAt }
        pendingUpdatedEntryIDs.insert(entry.id)
        editingEntry = nil
        persist()
        do {
            guard let accessToken else { throw APIError.server(status: 401, message: "Necesitas una invitación para acceder") }
            let saved = try await api.update(entry: entry, accessToken: accessToken)
            if let savedIndex = entries.firstIndex(where: { $0.id == entry.id }),
               entries[savedIndex] == entry {
                var confirmed = entries[savedIndex]
                confirmed.caregiverID = saved.caregiverID ?? entry.caregiverID
                confirmed.caregiverName = saved.caregiverName ?? entry.caregiverName
                entries[savedIndex] = confirmed
                pendingUpdatedEntryIDs.remove(entry.id)
            }
            isOffline = false
            notice = "Registro actualizado"
        } catch {
            isOffline = true
            notice = "Cambio guardado. Se sincronizará cuando vuelva la conexión."
        }
        signalFeedback(.success)
        persist()
    }

    func deleteEntry(_ entry: Entry) async {
        if recentlyCreatedEntry?.id == entry.id {
            recentlyCreatedEntry = nil
        }
        entries.removeAll { $0.id == entry.id }
        pendingEntryIDs.remove(entry.id)
        pendingUpdatedEntryIDs.remove(entry.id)
        pendingDeletionIDs.insert(entry.id)
        recentlyDeletedEntry = entry
        notice = "Registro eliminado"
        signalFeedback(.warning)
        persist()
        do {
            guard let accessToken else { throw APIError.server(status: 401, message: "Necesitas una invitación para acceder") }
            try await api.delete(entryID: entry.id, accessToken: accessToken)
            pendingDeletionIDs.remove(entry.id)
        } catch {
            isOffline = true
        }
        persist()
    }

    func undoDelete() async {
        guard let entry = recentlyDeletedEntry else { return }
        recentlyDeletedEntry = nil
        pendingDeletionIDs.remove(entry.id)
        entries.insert(entry, at: 0)
        entries.sort { $0.occurredAt > $1.occurredAt }
        pendingEntryIDs.insert(entry.id)
        persist()
        do {
            guard let accessToken else { throw APIError.server(status: 401, message: "Necesitas una invitación para acceder") }
            _ = try await api.create(entry: entry, accessToken: accessToken)
            pendingEntryIDs.remove(entry.id)
            notice = "Registro recuperado"
        } catch {
            isOffline = true
            notice = "Registro recuperado. Se sincronizará cuando vuelva la conexión."
        }
        signalFeedback(.success)
        persist()
    }

    func editRecentlyCreatedEntry() {
        guard let created = recentlyCreatedEntry,
              let current = entries.first(where: { $0.id == created.id })
        else { return }
        editingEntry = current
    }

    func undoCreatedEntry() async {
        guard let entry = recentlyCreatedEntry else { return }
        recentlyCreatedEntry = nil
        entries.removeAll { $0.id == entry.id }
        let wasPendingCreation = pendingEntryIDs.remove(entry.id) != nil
        pendingUpdatedEntryIDs.remove(entry.id)
        if !wasPendingCreation {
            pendingDeletionIDs.insert(entry.id)
        }
        notice = "Registro deshecho"
        signalFeedback(.warning)
        persist()

        guard !wasPendingCreation else { return }
        do {
            guard let accessToken else {
                throw APIError.server(status: 401, message: "Necesitas una invitación para acceder")
            }
            try await api.delete(entryID: entry.id, accessToken: accessToken)
            pendingDeletionIDs.remove(entry.id)
            isOffline = false
        } catch {
            isOffline = true
        }
        persist()
    }

    func restoreBackup(_ backup: NidoBackup) async {
        guard let accessToken else {
            notice = "Necesitas acceso al espacio para restaurar una copia."
            return
        }
        if currentCaregiver?.role == .owner, let backupProfile = backup.profile {
            do { profile = try await api.save(profile: backupProfile, accessToken: accessToken) }
            catch { notice = error.localizedDescription; return }
        }

        let existingIDs = Set(entries.map(\.id))
        let missing = backup.entries.filter { !existingIDs.contains($0.id) }
        for var entry in missing {
            entry.caregiverID = currentCaregiver?.id
            entry.caregiverName = currentCaregiver?.name
            entries.append(entry)
            pendingEntryIDs.insert(entry.id)
        }
        entries.sort { $0.occurredAt > $1.occurredAt }
        persist()
        do {
            try await synchronizePendingChanges()
            isOffline = false
            notice = missing.isEmpty ? "La copia no contiene registros nuevos" : "Copia restaurada · \(missing.count) registros"
        } catch {
            isOffline = true
            notice = "Copia restaurada. Se sincronizará cuando vuelva la conexión."
        }
        signalFeedback(.success)
        persist()
    }

    func toggleSleep() async {
        if let start = activeSleepStartedAt {
            let interval = SleepInterval(start: start, end: .now)
            activeSleepStartedAt = nil
            defaults.removeObject(forKey: "activeSleepStartedAt")
            await addEntry(
                kind: .sleep,
                detail: interval.detail(note: ""),
                date: interval.end,
                durationMinutes: interval.durationMinutes,
                amountMl: nil
            )
            await NidoLiveActivity.end(kind: "sleep")
        } else {
            let startedAt = Date.now
            activeSleepStartedAt = startedAt
            defaults.set(startedAt.timeIntervalSince1970, forKey: "activeSleepStartedAt")
            _ = NidoLiveActivity.start(
                kind: "sleep",
                babyName: profile?.babyName ?? "Bebé",
                startedAt: startedAt
            )
            notice = "Sueño iniciado"
            signalFeedback(.selection)
            updateWidgets()
        }
    }

    func updateActiveSleepStart(_ startedAt: Date) async {
        guard activeSleepStartedAt != nil else { return }

        let correctedStart = min(startedAt, .now)
        activeSleepStartedAt = correctedStart
        defaults.set(correctedStart.timeIntervalSince1970, forKey: "activeSleepStartedAt")
        await NidoLiveActivity.reconcile(
            sleepStartedAt: correctedStart,
            feedStartedAt: activeFeedStartedAt,
            babyName: profile?.babyName ?? "Bebé"
        )
        notice = "Hora de inicio actualizada"
        signalFeedback(.selection)
        updateWidgets()
    }

    func startFeed(side: BreastSide) {
        activeFeedStartedAt = .now
        activeFeedSide = side
        defaults.set(Date.now.timeIntervalSince1970, forKey: "activeFeedStartedAt")
        defaults.set(side.rawValue, forKey: "activeFeedSide")
        _ = NidoLiveActivity.start(
            kind: "feed",
            babyName: profile?.babyName ?? "Bebé",
            startedAt: activeFeedStartedAt ?? .now
        )
        notice = "Lactancia iniciada"
        signalFeedback(.selection)
        updateWidgets()
    }

    func finishFeed() async {
        guard let start = activeFeedStartedAt else { return }
        let side = activeFeedSide ?? .left
        let minutes = max(1, Int(Date.now.timeIntervalSince(start) / 60))
        activeFeedStartedAt = nil
        activeFeedSide = nil
        defaults.removeObject(forKey: "activeFeedStartedAt")
        defaults.removeObject(forKey: "activeFeedSide")
        await addEntry(
            kind: .feed,
            detail: "Lactancia · Pecho \(side.title.lowercased()) · Temporizador",
            date: .now,
            durationMinutes: minutes,
            amountMl: nil
        )
        await NidoLiveActivity.end(kind: "feed")
    }

    func refresh() async {
        await load()
    }

    func inviteCaregiver(name: String) async throws -> Caregiver {
        guard let accessToken else { throw APIError.server(status: 401, message: "Necesitas una invitación para acceder") }
        let invitation = try await api.inviteCaregiver(name: name.trimmingCharacters(in: .whitespacesAndNewlines), accessToken: accessToken)
        caregivers.removeAll { $0.id == invitation.id }
        caregivers.append(invitation)
        notice = "Invitación creada"
        signalFeedback(.success)
        return invitation
    }

    func removeCaregiver(_ caregiver: Caregiver) async {
        guard caregiver.id != currentCaregiver?.id, let accessToken else { return }
        do {
            try await api.removeCaregiver(id: caregiver.id, accessToken: accessToken)
            caregivers.removeAll { $0.id == caregiver.id }
            notice = caregiver.status == .pending ? "Invitación cancelada" : "Acceso retirado"
            signalFeedback(.warning)
        } catch {
            notice = error.localizedDescription
        }
    }

    func joinCaregiver(code: String) async throws {
        let credential = try await api.joinCaregiver(code: code)
        try storeCredential(credential)
        let caregiver = credential.caregiver
        caregivers.removeAll { $0.id == caregiver.id }
        caregivers.append(caregiver)
        selectCaregiver(caregiver)
        phase = .ready
        notice = "Ya puedes consultar y registrar la información de \(profile?.babyName ?? "Nido")"
        signalFeedback(.success)
        await refresh()
    }

    func showCaregiverAccess() {
        notice = nil
        phase = .caregiverAccess
    }

    func showOnboarding() {
        notice = nil
        phase = .onboarding
    }

    func dismissNotice() {
        notice = nil
        recentlyDeletedEntry = nil
        recentlyCreatedEntry = nil
    }

    private func signalFeedback(_ kind: NidoFeedbackKind) {
        feedbackKind = kind
        feedbackToken += 1
    }

    private func restoreCache() {
        do {
            let snapshot = try cache.load()
            profile = snapshot.profile
            entries = snapshot.entries.sorted { $0.occurredAt > $1.occurredAt }
            pendingEntryIDs = snapshot.pendingEntryIDs
            profileNeedsSync = snapshot.profileNeedsSync
        } catch {
            logger.error("Cache could not be read: \(error.localizedDescription, privacy: .private(mask: .hash))")
        }
    }

    private func restoreLiveActivities() async {
        await NidoLiveActivity.reconcile(
            sleepStartedAt: activeSleepStartedAt,
            feedStartedAt: activeFeedStartedAt,
            babyName: profile?.babyName ?? "Bebé"
        )
    }

    private func synchronizePendingChanges() async throws {
        guard let accessToken else { return }
        if profileNeedsSync, let profile {
            self.profile = try await api.save(profile: profile, accessToken: accessToken)
            profileNeedsSync = false
        }

        for entry in entries where pendingEntryIDs.contains(entry.id) {
            do {
                _ = try await api.create(entry: entry, accessToken: accessToken)
                pendingEntryIDs.remove(entry.id)
            } catch {
                let remote = try await api.load(accessToken: accessToken)
                if remote.entries.contains(where: { $0.id == entry.id }) {
                    pendingEntryIDs.remove(entry.id)
                } else {
                    throw error
                }
            }
        }
        for id in Array(pendingUpdatedEntryIDs) {
            guard let entry = entries.first(where: { $0.id == id }) else { continue }
            _ = try await api.update(entry: entry, accessToken: accessToken)
            pendingUpdatedEntryIDs.remove(id)
        }
        for id in Array(pendingDeletionIDs) {
            try await api.delete(entryID: id, accessToken: accessToken)
            pendingDeletionIDs.remove(id)
        }
        persist()
    }

    private func persist() {
        defaults.set(Array(pendingUpdatedEntryIDs), forKey: "pendingUpdatedEntryIDs")
        defaults.set(Array(pendingDeletionIDs), forKey: "pendingDeletionIDs")
        do {
            try cache.save(NidoSnapshot(
                profile: profile,
                entries: entries,
                pendingEntryIDs: pendingEntryIDs,
                profileNeedsSync: profileNeedsSync
            ))
        } catch {
            logger.error("Cache could not be saved: \(error.localizedDescription, privacy: .private(mask: .hash))")
        }
        updateWidgets()
    }

    private func updateWidgets() {
        NidoWidgetBridge.update(
            profile: profile,
            entries: entries,
            activeSleepStartedAt: activeSleepStartedAt,
            activeFeedStartedAt: activeFeedStartedAt
        )
    }

    private func storeCredential(_ credential: CaregiverCredential) throws {
        try credentialStore.save(credential.accessToken)
        accessToken = credential.accessToken
        caregivers.removeAll { $0.id == credential.caregiver.id }
        caregivers.append(credential.caregiver)
        selectCaregiver(credential.caregiver)
    }

    private func selectCaregiver(_ caregiver: Caregiver) {
        currentCaregiver = caregiver
        defaults.set(caregiver.id, forKey: caregiverIDKey)
    }

}

enum AppTab: Hashable {
    case today
    case history
    case more
    case trends
    case settings
}

enum AppConfiguration {
    static let apiBaseURL = URL(string: "https://nido.momentumia.com")!
}
