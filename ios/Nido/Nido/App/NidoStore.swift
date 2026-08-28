import Foundation
import Observation
import os

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
    var isEditingProfile = false
    var feedbackToken = 0

    private var pendingEntryIDs: Set<String> = []
    private var profileNeedsSync = false
    private var pendingUpdatedEntryIDs: Set<String> = []
    private var pendingDeletionIDs: Set<String> = []
    private var accessToken: String?
    private let api: NidoAPI
    private let cache: LocalCache
    private let credentialStore: CredentialStore
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.momentumia.nido", category: "store")
    private let caregiverIDKey = "currentCaregiverID"

    init(
        api: NidoAPI = NidoAPI(baseURL: AppConfiguration.apiBaseURL),
        cache: LocalCache = LocalCache(),
        credentialStore: CredentialStore = CredentialStore(),
        defaults: UserDefaults = .standard
    ) {
        self.api = api
        self.cache = cache
        self.credentialStore = credentialStore
        self.defaults = defaults
        accessToken = credentialStore.load()
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
                        notice = "Este espacio ya existe. Necesitas una invitación de otro cuidador."
                    } else {
                        phase = .onboarding
                        isOffline = true
                        notice = error.localizedDescription
                    }
                    return
                }
            } else {
                do {
                    phase = try await api.status() ? .caregiverAccess : .onboarding
                    isOffline = false
                } catch {
                    phase = .onboarding
                    isOffline = true
                    notice = "No se ha podido conectar con Nido."
                }
                return
            }
        }
        guard let token = accessToken else { phase = .caregiverAccess; return }
        do {
            try await synchronizePendingChanges()
            let remote = try await api.load(accessToken: token)
            profile = remote.profile ?? profile
            entries = merge(remote: remote.entries, local: entries, pendingIDs: pendingEntryIDs)
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
            feedbackToken += 1
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
        let entry = Entry(
            id: UUID().uuidString,
            kind: kind,
            title: kind.title,
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
            occurredAt: Int64(date.timeIntervalSince1970 * 1_000),
            durationMinutes: durationMinutes,
            amountMl: amountMl,
            caregiverID: currentCaregiver?.id,
            caregiverName: currentCaregiver?.name
        )
        entries.insert(entry, at: 0)
        pendingEntryIDs.insert(entry.id)
        presentedEntryKind = nil
        feedbackToken += 1
        persist()
        do {
            guard let accessToken else { throw APIError.server(status: 401, message: "Necesitas una invitación para acceder") }
            let saved = try await api.create(entry: entry, accessToken: accessToken)
            if let index = entries.firstIndex(where: { $0.id == entry.id }) { entries[index] = saved }
            pendingEntryIDs.remove(entry.id)
            isOffline = false
            notice = "\(entry.title) guardado"
            persist()
            if kind == .feed, defaults.bool(forKey: "feedCheckReminder"), let profile {
                await ReminderManager.scheduleFeedCheck(babyName: profile.babyName)
            }
        } catch {
            isOffline = true
            notice = "Guardado. Se sincronizará cuando vuelva la conexión."
        }
    }

    func updateEntry(_ entry: Entry) async {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
        entries.sort { $0.occurredAt > $1.occurredAt }
        pendingUpdatedEntryIDs.insert(entry.id)
        editingEntry = nil
        persist()
        do {
            guard let accessToken else { throw APIError.server(status: 401, message: "Necesitas una invitación para acceder") }
            let saved = try await api.update(entry: entry, accessToken: accessToken)
            if let savedIndex = entries.firstIndex(where: { $0.id == entry.id }) {
                var attributed = saved
                attributed.caregiverID = entry.caregiverID
                attributed.caregiverName = entry.caregiverName
                entries[savedIndex] = attributed
            }
            pendingUpdatedEntryIDs.remove(entry.id)
            isOffline = false
            notice = "Registro actualizado"
        } catch {
            isOffline = true
            notice = "Cambio guardado. Se sincronizará cuando vuelva la conexión."
        }
        feedbackToken += 1
        persist()
    }

    func deleteEntry(_ entry: Entry) async {
        entries.removeAll { $0.id == entry.id }
        pendingEntryIDs.remove(entry.id)
        pendingUpdatedEntryIDs.remove(entry.id)
        pendingDeletionIDs.insert(entry.id)
        recentlyDeletedEntry = entry
        notice = "Registro eliminado"
        feedbackToken += 1
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
        feedbackToken += 1
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
        feedbackToken += 1
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
            feedbackToken += 1
            updateWidgets()
        }
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
        feedbackToken += 1
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
        notice = "Invitación preparada"
        feedbackToken += 1
        return invitation
    }

    func removeCaregiver(_ caregiver: Caregiver) async {
        guard caregiver.id != currentCaregiver?.id, let accessToken else { return }
        do {
            try await api.removeCaregiver(id: caregiver.id, accessToken: accessToken)
            caregivers.removeAll { $0.id == caregiver.id }
            notice = caregiver.status == .pending ? "Invitación cancelada" : "Acceso retirado"
            feedbackToken += 1
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
        notice = "Ya compartes el espacio de \(profile?.babyName ?? "Nido")"
        feedbackToken += 1
        await refresh()
    }

    func dismissNotice() {
        notice = nil
        recentlyDeletedEntry = nil
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

    private func merge(remote: [Entry], local: [Entry], pendingIDs: Set<String>) -> [Entry] {
        let pending = local.filter { pendingIDs.contains($0.id) }
        return Array(Dictionary(uniqueKeysWithValues: (remote + pending).map { ($0.id, $0) }).values)
            .sorted { $0.occurredAt > $1.occurredAt }
    }
}

enum AppTab: Hashable {
    case today
    case history
    case trends
    case settings
}

enum AppConfiguration {
    static let apiBaseURL = URL(string: "https://nido.momentumia.com")!
}
