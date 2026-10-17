import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import os

enum NidoFeedbackKind {
    case selection
    case success
    case warning
    case error
}

private enum NidoSyncCheckpointError: Error {
    case persistenceFailed
}

@Observable
final class NidoStore: RegistrationMutationEventReceiver {
    enum Phase: Equatable {
        case loading
        case authentication
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
    var babyCareState = BabyCareState()
    var babyCareNeedsSync = false
    var babyCareHasConflict = false
    var babyCareError: String?
    var isSavingBabyCare = false
    var notice: String?
    var isOffline = false
    var selectedTab = AppTab.today
    var historySelectedDay: Date?
    var presentedEntryKind: EntryKind?
    var editingEntry: Entry?
    var recentlyDeletedEntry: Entry?
    var recentlyCreatedEntry: Entry?
    var isEditingProfile = false
    var feedbackToken = 0
    var feedbackKind = NidoFeedbackKind.selection
    var appleSignInChallenge: AppleSignInChallenge?
    var isPreparingAppleSignIn = false
    private var accountDeletionChallenge: AppleSignInChallenge?

    private var pendingEntryIDs: Set<String> = []
    private var profileNeedsSync = false
    private var pendingUpdatedEntryIDs: Set<String> = []
    private var pendingDeletionIDs: Set<String> = []
    private var isSynchronizingSharedSleep = false
    private var sessionGeneration = UUID()
    private var preservesReauthenticationReason = false
    private var sessionCredential: SessionCredential? {
        didSet {
            sessionGeneration = UUID()
            accountDeletionChallenge = nil
        }
    }
    #if DEBUG
    private var isIsolatedUITestFixture = false
    var isCompletingAppleSignInForUITest = false
    var isStartingDemoForUITest = false
    #endif
    private var latestRegistrationOperationID: UUID?
    private var inFlightRegistrationEntryIDs: [UUID: String] = [:]
    private var accessToken: String? { sessionCredential?.accessToken }
    var hasAccountSession: Bool { sessionCredential != nil }
    private let api: NidoAPI
    private let babyCareCache: BabyCareCache
    private var babyCareBaseState: BabyCareState?
    private var conflictedBabyCareState: BabyCareState?
    private var caregiverRoleIsConfirmed = false
    private let credentialStore: CredentialStore
    private let defaults: UserDefaults
    private let registrationService: RegistrationMutationService
    private let registrationEventHub: RegistrationMutationEventHub
    let allowsExternalEffects: Bool
    private let nowProvider: () -> Date
    private let hasInjectedNowProvider: Bool
    private let logger = Logger(subsystem: "com.momentumia.nido", category: "store")
    private let caregiverIDKey = "currentCaregiverID"

    init(
        api: NidoAPI = NidoAPI(baseURL: AppConfiguration.apiBaseURL),
        babyCareCache: BabyCareCache = BabyCareCache(),
        credentialStore: CredentialStore = CredentialStore(),
        defaults: UserDefaults = .standard,
        now: (() -> Date)? = nil,
        shouldLoadCredential: Bool = true,
        initialAccessToken: String? = nil,
        registrationService: RegistrationMutationService = NidoRegistrationServices.shared,
        registrationEventHub: RegistrationMutationEventHub = NidoRegistrationServices.eventHub,
        allowsExternalEffects: Bool = true
    ) {
        self.api = api
        self.babyCareCache = babyCareCache
        self.credentialStore = credentialStore
        self.defaults = defaults
        self.registrationService = registrationService
        self.registrationEventHub = registrationEventHub
        self.allowsExternalEffects = allowsExternalEffects
        self.nowProvider = now ?? { .now }
        self.hasInjectedNowProvider = now != nil
        if let initialAccessToken {
            sessionCredential = SessionCredential(
                accessToken: initialAccessToken,
                expiresAt: .distantFuture,
                appleUserID: nil
            )
        } else if shouldLoadCredential {
            sessionCredential = credentialStore.load()
        }
        pendingUpdatedEntryIDs = Set(defaults.stringArray(forKey: "pendingUpdatedEntryIDs") ?? [])
        pendingDeletionIDs = Set(defaults.stringArray(forKey: "pendingDeletionIDs") ?? [])
        if let timestamp = defaults.object(forKey: "activeFeedStartedAt") as? Double {
            activeFeedStartedAt = Date(timeIntervalSince1970: timestamp)
            activeFeedSide = defaults.string(forKey: "activeFeedSide").flatMap(BreastSide.init(rawValue:)) ?? .left
        }
        registrationEventHub.attach(self)
    }

    var now: Date { nowProvider() }

    var canEditGoals: Bool {
        accessToken != nil && currentCaregiver?.status == .active && currentCaregiver?.role == .owner
    }

    @discardableResult
    func saveGoals(sleepMinutes: Int?, feedCount: Int?, diaperCount: Int?, effectiveDate: String) async -> Bool {
        guard canEditGoals,
              (sleepMinutes == nil || (1...1_440).contains(sleepMinutes!)),
              (feedCount == nil || (1...100).contains(feedCount!)),
              (diaperCount == nil || (1...100).contains(diaperCount!)),
              isValidFamilyDate(effectiveDate, timeZoneID: babyCareState.timeZoneID),
              effectiveDate >= Self.familyDate(now, timeZoneID: babyCareState.timeZoneID)
        else { return false }

        let existing = babyCareState.goalVersions.first { $0.effectiveDate == effectiveDate }
        guard existing != nil || babyCareState.goalVersions.count < 500 else { return false }
        let goal = CareGoalVersion(
            id: existing?.id ?? UUID().uuidString.lowercased(),
            effectiveDate: effectiveDate,
            sleepMinutes: sleepMinutes,
            feedCount: feedCount,
            diaperCount: diaperCount
        )
        var versions = babyCareState.goalVersions.filter { $0.effectiveDate != effectiveDate }
        versions.append(goal)
        versions.sort { $0.effectiveDate < $1.effectiveDate }
        return await stageBabyCare(BabyCareState(
            revision: babyCareState.revision,
            timeZoneID: babyCareState.timeZoneID,
            goalVersions: versions,
            measurements: babyCareState.measurements
        ))
    }

    @discardableResult
    func saveGrowthMeasurement(_ measurement: GrowthMeasurement) async -> Bool {
        guard accessToken != nil, currentCaregiver?.status == .active,
              babyCareState.measurements.count <= 5_000,
              Self.validGrowthMeasurement(measurement, now: now)
        else { return false }
        if let source = entries.first(where: { $0.id == measurement.id && LegacyGrowthMeasurement(entry: $0) != nil }) {
            return await updateEntry(source.edited(
                detail: Self.legacyGrowthDetail(for: measurement),
                occurredAt: Date(timeIntervalSince1970: TimeInterval(measurement.measuredAt) / 1_000),
                durationMinutes: nil,
                amountMl: nil
            ))
        }
        guard babyCareState.measurements.contains(where: { $0.id == measurement.id }) || babyCareState.measurements.count < 5_000 else { return false }
        var measurements = babyCareState.measurements.filter { $0.id != measurement.id }
        measurements.append(measurement)
        measurements.sort { $0.measuredAt < $1.measuredAt }
        return await stageBabyCare(BabyCareState(
            revision: babyCareState.revision,
            timeZoneID: babyCareState.timeZoneID,
            goalVersions: babyCareState.goalVersions,
            measurements: measurements
        ))
    }

    @discardableResult
    func deleteGrowthMeasurement(id: String) async -> Bool {
        guard accessToken != nil, currentCaregiver?.status == .active else { return false }
        let hasWireMeasurement = babyCareState.measurements.contains(where: { $0.id == id })
        guard let source = entries.first(where: { $0.id == id && $0.kind == .health && $0.detail.hasPrefix("Medidas") }) else {
            guard hasWireMeasurement else { return false }
            return await stageBabyCare(BabyCareState(
                revision: babyCareState.revision,
                timeZoneID: babyCareState.timeZoneID,
                goalVersions: babyCareState.goalVersions,
                measurements: babyCareState.measurements.filter { $0.id != id }
            ))
        }
        if hasWireMeasurement {
            let saved = await stageBabyCare(BabyCareState(
                revision: babyCareState.revision,
                timeZoneID: babyCareState.timeZoneID,
                goalVersions: babyCareState.goalVersions,
                measurements: babyCareState.measurements.filter { $0.id != id }
            ))
            await deleteEntry(source)
            return saved
        }
        await deleteEntry(source)
        return true
    }

    func retryBabyCareSync() async {
        guard babyCareNeedsSync, !babyCareHasConflict else { return }
        await synchronizeBabyCare()
    }

    func resolveBabyCareConflict(keepLocal: Bool) async {
        guard let remote = conflictedBabyCareState else { return }
        if keepLocal {
            babyCareBaseState = remote
            babyCareState = BabyCareState(
                revision: remote.revision,
                timeZoneID: babyCareState.timeZoneID,
                goalVersions: babyCareState.goalVersions,
                measurements: babyCareState.measurements
            )
            conflictedBabyCareState = nil
            babyCareHasConflict = false
            babyCareNeedsSync = true
        } else {
            babyCareState = remote
            babyCareBaseState = remote
            conflictedBabyCareState = nil
            babyCareHasConflict = false
            babyCareNeedsSync = false
        }
        try? persistBabyCareCache()
        if keepLocal { await synchronizeBabyCare() }
    }

    func showHistory(on date: Date) {
        var familyCalendar = Calendar(identifier: .gregorian)
        familyCalendar.timeZone = TimeZone(identifier: babyCareState.timeZoneID) ?? .current
        historySelectedDay = HistoryPresentation.select(date, through: now, calendar: familyCalendar)
        selectedTab = .history
    }

    func currentDate(for timelineDate: Date) -> Date {
        hasInjectedNowProvider ? nowProvider() : timelineDate
    }

    #if DEBUG
    var goalDesignPreviewScenario: String?

    func prepareForUITesting(scenario: String) async {
        goalDesignPreviewScenario = scenario.hasPrefix("goal-design-") ? scenario : nil
        isIsolatedUITestFixture = true
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
        historySelectedDay = nil
        presentedEntryKind = nil
        editingEntry = nil
        recentlyDeletedEntry = nil
        recentlyCreatedEntry = nil
        isEditingProfile = false
        isCompletingAppleSignInForUITest = false
        isStartingDemoForUITest = false
        pendingEntryIDs = []
        pendingUpdatedEntryIDs = []
        pendingDeletionIDs = []
        profileNeedsSync = false
        babyCareState = BabyCareState()
        babyCareBaseState = nil
        conflictedBabyCareState = nil
        babyCareNeedsSync = false
        babyCareHasConflict = false
        babyCareError = nil
        try? babyCareCache.remove()
        sessionCredential = nil

        if scenario == "apple-auth-completing" || scenario == "demo-starting" {
            phase = .authentication
            isCompletingAppleSignInForUITest = scenario == "apple-auth-completing"
            appleSignInChallenge = AppleSignInChallenge(
                challengeID: "ui-test-apple-sign-in",
                nonce: "ui-test-nonce",
                expiresAt: .distantFuture
            )
            isStartingDemoForUITest = scenario == "demo-starting"
            return
        }

        if scenario == "account-deletion-onboarding" {
            sessionCredential = SessionCredential(
                accessToken: "offline-sync-test-token",
                expiresAt: .distantFuture,
                appleUserID: nil
            )
            phase = .onboarding
            return
        }
        if scenario == "account-deletion-caregiver-access" {
            sessionCredential = SessionCredential(
                accessToken: "offline-sync-test-token",
                expiresAt: .distantFuture,
                appleUserID: nil
            )
            phase = .caregiverAccess
            return
        }

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
        if scenario == "baby-care" || scenario == "baby-care-empty" {
            var familyCalendar = Calendar(identifier: .gregorian)
            familyCalendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
            let todayStart = familyCalendar.startOfDay(for: now)
            let todayKey = Self.familyDate(now, timeZoneID: "Europe/Madrid")
            if scenario == "baby-care" {
                babyCareState = BabyCareState(
                    revision: 12,
                    timeZoneID: "Europe/Madrid",
                    goalVersions: [CareGoalVersion(
                        id: "fixture-goal-today",
                        effectiveDate: todayKey,
                        sleepMinutes: 720,
                        feedCount: 8,
                        diaperCount: 6
                    )],
                    measurements: [
                        GrowthMeasurement(id: "fixture-growth-birth", measuredAt: Int64(familyCalendar.date(byAdding: .day, value: -77, to: todayStart)!.timeIntervalSince1970 * 1_000), weightGrams: 3_450, heightMillimeters: 510, note: "Nacimiento"),
                        GrowthMeasurement(id: "fixture-growth-recent", measuredAt: Int64(familyCalendar.date(byAdding: .day, value: -2, to: todayStart)!.addingTimeInterval(10 * 3_600).timeIntervalSince1970 * 1_000), weightGrams: 6_800, heightMillimeters: 645, note: "Control pediátrico"),
                    ]
                )
                entries = [
                    Entry(id: "fixture-baby-sleep", kind: .sleep, title: EntryKind.sleep.title, detail: "12:30–14:00", occurredAt: Int64(todayStart.addingTimeInterval(14 * 3_600).timeIntervalSince1970 * 1_000), durationMinutes: 90, amountMl: nil, caregiverID: caregiver.id, caregiverName: caregiver.name),
                    Entry(id: "fixture-baby-feed-one", kind: .feed, title: EntryKind.feed.title, detail: "Biberón · Fórmula", occurredAt: Int64(todayStart.addingTimeInterval(9 * 3_600).timeIntervalSince1970 * 1_000), durationMinutes: nil, amountMl: 120, caregiverID: caregiver.id, caregiverName: caregiver.name),
                    Entry(id: "fixture-baby-feed-two", kind: .feed, title: EntryKind.feed.title, detail: "Pecho", occurredAt: Int64(todayStart.addingTimeInterval(12 * 3_600).timeIntervalSince1970 * 1_000), durationMinutes: 18, amountMl: nil, caregiverID: caregiver.id, caregiverName: caregiver.name),
                    Entry(id: "fixture-baby-diaper", kind: .diaper, title: EntryKind.diaper.title, detail: "Pis", occurredAt: Int64(todayStart.addingTimeInterval(11 * 3_600).timeIntervalSince1970 * 1_000), durationMinutes: nil, amountMl: nil, caregiverID: caregiver.id, caregiverName: caregiver.name),
                ]
            } else {
                babyCareState = BabyCareState(revision: 0, timeZoneID: "Europe/Madrid")
                entries = []
            }
        } else if scenario == "quick-diaper-registration" {
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
                _ = await persist()
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
        if scenario == "baby-care" || scenario == "baby-care-empty" {
            sessionCredential = SessionCredential(
                accessToken: "local-ui-test-session",
                expiresAt: .distantFuture,
                appleUserID: nil
            )
        }
        phase = .ready
        _ = await persist()
        _ = persistBabyCareCache()
    }
    #endif

    func load() async {
        guard let credential = sessionCredential, !credential.isExpired(at: now) else {
            await invalidateSession(message: nil)
            return
        }
        let generation = sessionGeneration
        if let appleUserID = credential.appleUserID {
            let state = await appleCredentialState(for: appleUserID)
            guard sessionGeneration == generation else { return }
            if state != .authorized {
                await invalidateSession(message: "Tu acceso con Apple ya no está autorizado.")
                return
            }
        }
        await restoreCache()
        guard sessionGeneration == generation else { return }
        let token = credential.accessToken
        do {
            try await synchronizePendingChanges()
            guard sessionGeneration == generation else { return }
            let sharedSleepStart = try await registrationService.synchronizeSleep()
            guard sessionGeneration == generation else { return }
            activeSleepStartedAt = sharedSleepStart
            let remote = try await api.load(accessToken: token)
            guard sessionGeneration == generation else { return }
            profile = remote.profile ?? profile
            entries = EntryReconciliation.merge(
                remote: remote.entries,
                local: entries,
                protectedIDs: pendingEntryIDs.union(pendingUpdatedEntryIDs),
                excludedIDs: pendingDeletionIDs
            )
            caregivers = remote.caregivers
            if let authenticated = caregivers.first(where: { $0.id == remote.currentCaregiverID && $0.status == .active }) {
                if let previous = currentCaregiver, previous.id != authenticated.id {
                    clearBabyCareData()
                }
                selectCaregiver(authenticated)
            } else {
                currentCaregiver = nil
                caregiverRoleIsConfirmed = false
            }
            let remoteBabyCare = try await api.loadBabyCare(accessToken: token)
            guard sessionGeneration == generation else { return }
            if let remoteBabyCare {
                await acceptRemoteBabyCare(remoteBabyCare)
            } else if !babyCareNeedsSync {
                babyCareState = BabyCareState()
                babyCareBaseState = nil
            }
            _ = persistBabyCareCache()
            if babyCareNeedsSync { await synchronizeBabyCare() }
            isOffline = false
            _ = await persist()
        } catch {
            guard sessionGeneration == generation else { return }
            if isUnauthorized(error) {
                await invalidateSession(message: "Vuelve a iniciar sesión para acceder.")
                return
            }
            if case APIError.server(status: 403, message: _) = error {
                await clearHouseholdData()
                guard sessionGeneration == generation else { return }
                phase = .onboarding
                isOffline = false
                return
            }
            isOffline = true
            logger.error("Initial sync failed: \(error.localizedDescription, privacy: .private(mask: .hash))")
            if profile != nil {
                notice = "Sin conexión. Algunos datos pueden no estar actualizados."
                if currentCaregiver == nil, let profile {
                    let offlineCaregiver = Caregiver(
                        id: defaults.string(forKey: caregiverIDKey) ?? UUID().uuidString,
                        name: profile.caregiverName,
                        role: .caregiver,
                        status: .active,
                        inviteCode: nil,
                        createdAt: nil,
                        joinedAt: nil
                    )
                    currentCaregiver = offlineCaregiver
                    caregivers = [offlineCaregiver]
                    caregiverRoleIsConfirmed = false
                }
            }
        }
        guard sessionGeneration == generation else { return }
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
            guard let accessToken else { throw APIError.invalidResponse }
            if currentCaregiver == nil {
                let caregiver = try await api.bootstrapCaregiver(
                    name: value.caregiverName,
                    profile: value,
                    accessToken: accessToken
                )
                caregivers = [caregiver]
                selectCaregiver(caregiver)
            }
            profile = try await api.save(profile: value, accessToken: accessToken)
            profileNeedsSync = false
            isOffline = false
            phase = .ready
            notice = "Perfil guardado"
            signalFeedback(.success)
            _ = await persist()
        } catch {
            if isUnauthorized(error) {
                await invalidateSession(message: "Vuelve a iniciar sesión para acceder.")
                return
            }
            isOffline = true
            notice = error.localizedDescription
            if currentCaregiver == nil {
                phase = .onboarding
            } else {
                profile = value
                profileNeedsSync = true
                phase = currentCaregiver == nil ? .caregiverAccess : .ready
                _ = await persist()
            }
        }
    }

    @discardableResult
    func addEntry(kind: EntryKind, detail: String, date: Date, durationMinutes: Int?, amountMl: Int?) async -> Bool {
        await addEntry(draft: RegistrationDraft(
            kind: kind,
            detail: detail,
            date: date,
            durationMinutes: durationMinutes,
            amountMl: amountMl
        ))
    }

    @discardableResult
    func addQuickEntry(_ choice: RegistrationQuickAction.Choice) async -> Bool {
        let notice = switch choice.draft.kind {
        case .feed: "Toma registrada · \(choice.summary)"
        case .diaper: "Pañal registrado · \(choice.summary)"
        case .sleep, .health: "\(choice.draft.kind.title) registrado"
        }
        return await addEntry(draft: choice.draft, actionableNotice: notice)
    }

    private func addEntry(draft: RegistrationDraft, actionableNotice: String? = nil) async -> Bool {
        let operationID = UUID()
        let generation = sessionGeneration
        let token = accessToken
        latestRegistrationOperationID = operationID
        defer { inFlightRegistrationEntryIDs.removeValue(forKey: operationID) }
        let result = await registrationService.create(
            draft: draft,
            caregiverID: currentCaregiver?.id,
            caregiverName: currentCaregiver?.name,
            onLocalCommit: { [weak self] entry in
                await self?.acknowledgeLocalRegistration(
                    entry, notice: actionableNotice, operationID: operationID,
                    generation: generation, token: token
                )
            }
        )
        guard sessionGeneration == generation, accessToken == token else { return false }
        if result.outcome == .authenticationRequired { return false }
        if result.outcome == .storageUnavailable {
            if latestRegistrationOperationID == operationID { notice = result.dialog }
            signalFeedback(.error)
            return false
        }
        guard result.outcome == .registered || result.outcome == .queued || result.outcome == .sleepFinished else {
            return false
        }
        if let entry = result.entry, pendingDeletionIDs.contains(entry.id) {
            await compensateUndoneCreation(entry.id, generation: generation, token: token)
            return true
        }
        if actionableNotice == nil { signalFeedback(.success) }
        if let actionableNotice, let entry = result.entry,
           latestRegistrationOperationID == operationID,
           recentlyCreatedEntry?.id == entry.id {
            recentlyCreatedEntry = entries.first { $0.id == entry.id }
            notice = actionableNotice
        }
        switch result.outcome {
        case .registered, .sleepFinished:
            isOffline = false
            if actionableNotice == nil, latestRegistrationOperationID == operationID, let entry = result.entry {
                notice = "\(entry.title) guardado"
            }
            if allowsExternalEffects, draft.kind == .feed, defaults.bool(forKey: "feedCheckReminder"), let profile {
                await ReminderManager.scheduleFeedCheck(babyName: profile.babyName)
            }
        case .queued:
            isOffline = true
            if actionableNotice == nil, latestRegistrationOperationID == operationID {
                notice = "Guardado. Se sincronizará cuando vuelva la conexión."
            }
        case .storageUnavailable:
            notice = result.dialog
            signalFeedback(.error)
        case .noReusableFeed, .sleepStarted, .sleepAlreadyActive, .noActiveSleep, .authenticationRequired:
            break
        }
        return true
    }

    private func acknowledgeLocalRegistration(
        _ entry: Entry, notice message: String?, operationID: UUID,
        generation: UUID, token: String?
    ) {
        guard sessionGeneration == generation, accessToken == token else { return }
        inFlightRegistrationEntryIDs[operationID] = entry.id
        guard let message else { return }
        signalFeedback(.success)
        guard latestRegistrationOperationID == operationID else { return }
        recentlyDeletedEntry = nil
        recentlyCreatedEntry = entries.first { $0.id == entry.id }
        notice = message
    }

    private func compensateUndoneCreation(_ entryID: String, generation: UUID, token: String?) async {
        do {
            guard let token else { throw APIError.missingCredential }
            try await api.delete(entryID: entryID, accessToken: token)
            guard sessionGeneration == generation, accessToken == token else { return }
            pendingDeletionIDs.remove(entryID)
        } catch {
            guard sessionGeneration == generation, accessToken == token else { return }
            if SessionFailurePolicy.disposition(for: error, during: .delete) == .invalidateSession {
                await invalidateSession(message: "Vuelve a iniciar sesión para acceder.")
                return
            }
            isOffline = true
        }
        _ = await persist(removingEntryIDs: [entryID])
    }

    @discardableResult
    func updateEntry(_ entry: Entry) async -> Bool {
        guard entries.contains(where: { $0.id == entry.id }) else { return false }
        let generation = sessionGeneration
        let token = accessToken
        do {
            guard try await registrationService.updateAppEntry(entry, expectedAccessToken: token) else {
                return false
            }
        } catch {
            guard sessionGeneration == generation, accessToken == token else { return false }
            logger.error("Entry edit could not be saved: \(error.localizedDescription, privacy: .private(mask: .hash))")
            notice = RegistrationMutationResult.dialog(for: .storageUnavailable)
            signalFeedback(.error)
            return false
        }
        guard sessionGeneration == generation, accessToken == token,
              let index = entries.firstIndex(where: { $0.id == entry.id }) else { return false }
        entries[index] = entry
        if recentlyCreatedEntry?.id == entry.id {
            recentlyCreatedEntry = entry
        }
        entries.sort { $0.occurredAt > $1.occurredAt }
        pendingUpdatedEntryIDs.insert(entry.id)
        defaults.set(Array(pendingUpdatedEntryIDs), forKey: "pendingUpdatedEntryIDs")
        if editingEntry?.id == entry.id { editingEntry = nil }
        updateWidgets()
        do {
            guard let token else { throw APIError.missingCredential }
            let saved = try await api.update(entry: entry, accessToken: token)
            guard sessionGeneration == generation, accessToken == token else { return false }
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
            guard sessionGeneration == generation, accessToken == token else { return false }
            if SessionFailurePolicy.disposition(for: error, during: .update) == .invalidateSession {
                await invalidateSession(message: "Vuelve a iniciar sesión para acceder.")
                return false
            }
            isOffline = true
            notice = "Cambio guardado. Se sincronizará cuando vuelva la conexión."
        }
        signalFeedback(.success)
        _ = await persist()
        return sessionGeneration == generation && accessToken == token
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
        guard await persist(removingEntryIDs: [entry.id]) else { return }
        do {
            guard let accessToken else { throw APIError.missingCredential }
            try await api.delete(entryID: entry.id, accessToken: accessToken)
            pendingDeletionIDs.remove(entry.id)
        } catch {
            if SessionFailurePolicy.disposition(for: error, during: .delete) == .invalidateSession {
                await invalidateSession(message: "Vuelve a iniciar sesión para acceder.")
                return
            }
            isOffline = true
        }
        _ = await persist(removingEntryIDs: [entry.id])
    }

    func undoDelete() async {
        guard let entry = recentlyDeletedEntry else { return }
        recentlyDeletedEntry = nil
        pendingDeletionIDs.remove(entry.id)
        entries.insert(entry, at: 0)
        entries.sort { $0.occurredAt > $1.occurredAt }
        pendingEntryIDs.insert(entry.id)
        guard await persist() else { return }
        do {
            guard let accessToken else { throw APIError.missingCredential }
            _ = try await api.create(entry: entry, accessToken: accessToken)
            pendingEntryIDs.remove(entry.id)
            notice = "Registro recuperado"
        } catch {
            if SessionFailurePolicy.disposition(for: error, during: .create) == .invalidateSession {
                await invalidateSession(message: "Vuelve a iniciar sesión para acceder.")
                return
            }
            isOffline = true
            notice = "Registro recuperado. Se sincronizará cuando vuelva la conexión."
        }
        signalFeedback(.success)
        _ = await persist()
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
        let creationIsInFlight = inFlightRegistrationEntryIDs.values.contains(entry.id)
        pendingUpdatedEntryIDs.remove(entry.id)
        if !wasPendingCreation || creationIsInFlight {
            pendingDeletionIDs.insert(entry.id)
        }
        notice = "Registro deshecho"
        signalFeedback(.warning)
        guard await persist(removingEntryIDs: [entry.id]) else { return }

        guard !wasPendingCreation, !creationIsInFlight else { return }
        do {
            guard let accessToken else {
                throw APIError.missingCredential
            }
            try await api.delete(entryID: entry.id, accessToken: accessToken)
            pendingDeletionIDs.remove(entry.id)
            isOffline = false
        } catch {
            if SessionFailurePolicy.disposition(for: error, during: .delete) == .invalidateSession {
                await invalidateSession(message: "Vuelve a iniciar sesión para acceder.")
                return
            }
            isOffline = true
        }
        _ = await persist(removingEntryIDs: [entry.id])
    }

    func restoreBackup(_ backup: NidoBackup) async {
        guard let accessToken else {
            notice = "Necesitas acceso al espacio para restaurar una copia."
            return
        }
        let generation = sessionGeneration
        if currentCaregiver?.role == .owner, let backupProfile = backup.profile {
            do {
                let savedProfile = try await api.save(profile: backupProfile, accessToken: accessToken)
                guard sessionGeneration == generation, self.accessToken == accessToken else { return }
                profile = savedProfile
            }
            catch {
                guard sessionGeneration == generation, self.accessToken == accessToken else { return }
                if isUnauthorized(error) {
                    await invalidateSession(message: "Vuelve a iniciar sesión para acceder.")
                } else {
                    notice = error.localizedDescription
                }
                return
            }
        }
        guard sessionGeneration == generation, self.accessToken == accessToken else { return }

        let existingIDs = Set(entries.map(\.id))
        let missing = backup.entries.filter { !existingIDs.contains($0.id) }
        for var entry in missing {
            entry.caregiverID = currentCaregiver?.id
            entry.caregiverName = currentCaregiver?.name
            entries.append(entry)
            pendingEntryIDs.insert(entry.id)
        }
        if let importedBabyCare = backup.babyCareState {
            var measurementsByID: [String: GrowthMeasurement] = [:]
            for measurement in babyCareState.measurements { measurementsByID[measurement.id] = measurement }
            for measurement in importedBabyCare.measurements { measurementsByID[measurement.id] = measurement }
            var mergedGoals: [String: CareGoalVersion] = [:]
            for goal in babyCareState.goalVersions { mergedGoals[goal.effectiveDate] = goal }
            if canEditGoals {
                for goal in importedBabyCare.goalVersions { mergedGoals[goal.effectiveDate] = goal }
            }
            babyCareState = BabyCareState(
                revision: babyCareState.revision,
                timeZoneID: babyCareState.timeZoneID,
                goalVersions: mergedGoals.values.sorted { $0.effectiveDate < $1.effectiveDate },
                measurements: measurementsByID.values.sorted { $0.measuredAt < $1.measuredAt }
            )
            babyCareNeedsSync = true
            guard persistBabyCareCache() else { return }
        }
        entries.sort { $0.occurredAt > $1.occurredAt }
        guard await persist(), sessionGeneration == generation, self.accessToken == accessToken else { return }
        do {
            try await synchronizePendingChanges()
            guard sessionGeneration == generation, self.accessToken == accessToken else { return }
            await synchronizeBabyCare()
            guard sessionGeneration == generation, self.accessToken == accessToken else { return }
            isOffline = false
            notice = missing.isEmpty ? "La copia no contiene registros nuevos" : "Copia restaurada · \(missing.count) registros"
        } catch {
            guard sessionGeneration == generation, self.accessToken == accessToken else { return }
            if isUnauthorized(error) {
                await invalidateSession(message: "Vuelve a iniciar sesión para acceder.")
                return
            }
            isOffline = true
            notice = "Copia restaurada. Se sincronizará cuando vuelva la conexión."
        }
        signalFeedback(.success)
        _ = await persist()
    }

    func toggleSleep() async {
        if activeSleepStartedAt != nil {
            let result = await registrationService.finishSleep(
                caregiverID: currentCaregiver?.id,
                caregiverName: currentCaregiver?.name
            )
            await applySleepResult(result)
            if allowsExternalEffects { await NidoLiveActivity.end(kind: "sleep") }
        } else {
            let result = await registrationService.startSleep()
            await applySleepResult(result)
            if allowsExternalEffects, result.outcome == .sleepStarted, let startedAt = result.activeSleepStartedAt {
                _ = NidoLiveActivity.start(
                    kind: "sleep",
                    babyName: profile?.babyName ?? "Bebé",
                    startedAt: startedAt
                )
            }
        }
    }

    func updateActiveSleepStart(_ startedAt: Date) async {
        guard activeSleepStartedAt != nil else { return }

        guard let correctedStart = try? await registrationService.updateSleepStart(startedAt) else {
            notice = RegistrationMutationResult.dialog(for: .storageUnavailable, category: .sleep)
            return
        }
        activeSleepStartedAt = correctedStart
        if allowsExternalEffects {
            await NidoLiveActivity.reconcile(
                sleepStartedAt: correctedStart,
                feedStartedAt: activeFeedStartedAt,
                babyName: profile?.babyName ?? "Bebé"
            )
        }
        notice = "Hora de inicio actualizada"
        signalFeedback(.selection)
        updateWidgets()
    }

    func startFeed(side: BreastSide) {
        activeFeedStartedAt = .now
        activeFeedSide = side
        defaults.set(Date.now.timeIntervalSince1970, forKey: "activeFeedStartedAt")
        defaults.set(side.rawValue, forKey: "activeFeedSide")
        if allowsExternalEffects {
            _ = NidoLiveActivity.start(
                kind: "feed",
                babyName: profile?.babyName ?? "Bebé",
                startedAt: activeFeedStartedAt ?? .now
            )
        }
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
        if allowsExternalEffects { await NidoLiveActivity.end(kind: "feed") }
    }

    func refresh() async {
        #if DEBUG
        guard !isIsolatedUITestFixture else { return }
        #endif
        await load()
    }

    func refreshSharedSleep() async {
        guard phase == .ready, accessToken != nil, !isSynchronizingSharedSleep else { return }
        #if DEBUG
        guard !isIsolatedUITestFixture else { return }
        #endif
        isSynchronizingSharedSleep = true
        defer { isSynchronizingSharedSleep = false }
        let previousStart = activeSleepStartedAt
        do {
            let sharedStart = try await registrationService.synchronizeSleep()
            guard phase == .ready, accessToken != nil else { return }
            activeSleepStartedAt = sharedStart
            if previousStart != sharedStart {
                // Fetch the completed interval too when another family member ends sleep.
                await load()
            }
        } catch {
            if isUnauthorized(error) {
                await invalidateSession(message: "Vuelve a iniciar sesión para acceder.")
            } else {
                isOffline = true
            }
        }
    }

    func prepareAppleSignIn() async {
        isPreparingAppleSignIn = true
        defer { isPreparingAppleSignIn = false }
        do {
            appleSignInChallenge = try await api.appleSignInChallenge()
            if !preservesReauthenticationReason { notice = nil }
        } catch {
            appleSignInChallenge = nil
            preservesReauthenticationReason = false
            notice = error.localizedDescription
        }
    }

    func completeAppleSignIn(identityToken: Data, appleUserID: String) async throws {
        guard let challenge = appleSignInChallenge, challenge.expiresAt > now,
              let token = String(data: identityToken, encoding: .utf8), !token.isEmpty
        else { throw APIError.invalidData }
        let session = try await api.createAppleSession(
            identityToken: token,
            challengeID: challenge.challengeID
        )
        await clearHouseholdData()
        let credential = SessionCredential(
            accessToken: session.credential.accessToken,
            expiresAt: session.credential.expiresAt,
            appleUserID: appleUserID
        )
        try credentialStore.save(credential)
        sessionCredential = credential
        if preservesReauthenticationReason { notice = nil }
        preservesReauthenticationReason = false
        appleSignInChallenge = nil
        if session.hasMembership {
            await load()
        } else {
            phase = .onboarding
            isOffline = false
        }
    }

    func signOut() async {
        guard let accessToken else {
            await invalidateSession(message: nil)
            return
        }
        let generation = sessionGeneration
        try? await api.logout(accessToken: accessToken)
        guard generation == sessionGeneration, self.accessToken == accessToken else { return }
        await invalidateSession(message: nil)
    }

    func prepareAccountDeletionChallenge() async throws -> AppleSignInChallenge {
        guard let accessToken else { throw APIError.invalidResponse }
        let generation = sessionGeneration
        let challenge = try await api.appleSignInChallenge()
        guard generation == sessionGeneration, self.accessToken == accessToken else {
            throw APIError.invalidResponse
        }
        accountDeletionChallenge = challenge
        return challenge
    }

    func cancelAccountDeletionAuthorization() {
        accountDeletionChallenge = nil
    }

    func deleteAccount(proof: AppleAccountDeletionProof) async throws {
        guard let accessToken else { throw APIError.invalidResponse }
        let generation = sessionGeneration
        guard let challenge = accountDeletionChallenge,
              challenge.challengeID == proof.challengeID,
              challenge.expiresAt > now,
              !proof.identityToken.isEmpty,
              !proof.authorizationCode.isEmpty
        else {
            accountDeletionChallenge = nil
            throw APIError.invalidData
        }

        // Apple challenges are one-use. A failed request keeps the Nido session,
        // while the view asks for a fresh challenge before offering another try.
        accountDeletionChallenge = nil
        try await api.deleteAccount(
            accessToken: accessToken,
            challengeID: proof.challengeID,
            identityToken: proof.identityToken,
            authorizationCode: proof.authorizationCode
        )
        guard generation == sessionGeneration, self.accessToken == accessToken else { return }
        await invalidateSession(message: nil)
    }

    func inviteCaregiver(name: String) async throws -> Caregiver {
        guard let accessToken else { throw APIError.server(status: 401, message: "Necesitas una invitación para acceder") }
        do {
            let invitation = try await api.inviteCaregiver(name: name.trimmingCharacters(in: .whitespacesAndNewlines), accessToken: accessToken)
            caregivers.removeAll { $0.id == invitation.id }
            caregivers.append(invitation)
            notice = "Invitación creada"
            signalFeedback(.success)
            return invitation
        } catch {
            if isUnauthorized(error) { await invalidateSession(message: "Vuelve a iniciar sesión para acceder.") }
            throw error
        }
    }

    func removeCaregiver(_ caregiver: Caregiver) async {
        guard caregiver.id != currentCaregiver?.id, let accessToken else { return }
        do {
            try await api.removeCaregiver(id: caregiver.id, accessToken: accessToken)
            caregivers.removeAll { $0.id == caregiver.id }
            notice = caregiver.status == .pending ? "Invitación cancelada" : "Acceso retirado"
            signalFeedback(.warning)
        } catch {
            if isUnauthorized(error) {
                await invalidateSession(message: "Vuelve a iniciar sesión para acceder.")
                return
            }
            notice = error.localizedDescription
        }
    }

    func joinCaregiver(code: String) async throws {
        guard let accessToken else { throw APIError.server(status: 401, message: "Vuelve a iniciar sesión para acceder") }
        do {
            let caregiver = try await api.joinCaregiver(code: code, accessToken: accessToken)
            clearBabyCareData()
            caregivers.removeAll { $0.id == caregiver.id }
            caregivers.append(caregiver)
            selectCaregiver(caregiver)
            notice = "Ya puedes consultar y registrar la información de Nido"
            signalFeedback(.success)
            await refresh()
        } catch {
            if isUnauthorized(error) { await invalidateSession(message: "Vuelve a iniciar sesión para acceder.") }
            throw error
        }
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
        preservesReauthenticationReason = false
        recentlyDeletedEntry = nil
        recentlyCreatedEntry = nil
    }

    func registrationServiceDidCommit(_ commit: RegistrationLocalCommit) {
        profile = commit.snapshot.profile
        entries = commit.snapshot.entries.sorted { $0.occurredAt > $1.occurredAt }
        pendingEntryIDs = commit.snapshot.pendingEntryIDs
        activeSleepStartedAt = commit.activeSleepStartedAt
        updateWidgets()
    }

    func registrationServiceDidInvalidate() {
        accountDeletionChallenge = nil
        sessionCredential = nil
        clearInMemoryHouseholdData()
        try? babyCareCache.remove()
        phase = .authentication
        notice = "Vuelve a iniciar sesión para acceder."
        preservesReauthenticationReason = true
        isOffline = false
    }

    private func applySleepResult(_ result: RegistrationMutationResult) async {
        if result.outcome == .authenticationRequired { return }
        entries = result.snapshot.entries.sorted { $0.occurredAt > $1.occurredAt }
        pendingEntryIDs = result.snapshot.pendingEntryIDs
        activeSleepStartedAt = result.activeSleepStartedAt
        switch result.outcome {
        case .sleepStarted:
            notice = "Sueño iniciado"
            signalFeedback(.selection)
        case .sleepAlreadyActive:
            notice = "Ya hay un sueño en curso"
        case .sleepFinished:
            isOffline = false
            showFinishedSleepNotice(result.entry, offline: false)
            signalFeedback(.success)
        case .queued:
            isOffline = true
            if result.entry?.kind == .sleep {
                showFinishedSleepNotice(result.entry, offline: true)
            } else {
                notice = "Guardado. Se sincronizará cuando vuelva la conexión."
            }
            signalFeedback(.success)
        case .noActiveSleep:
            notice = "No hay un sueño activo"
        case .storageUnavailable:
            notice = result.dialog
            signalFeedback(.error)
        case .registered, .noReusableFeed, .authenticationRequired:
            break
        }
    }

    private func showFinishedSleepNotice(_ entry: Entry?, offline: Bool) {
        guard let entry, let minutes = entry.durationMinutes else { return }
        recentlyDeletedEntry = nil
        recentlyCreatedEntry = entry
        let summary = "Sueño guardado · \(DurationLabel.minutes(minutes))"
        notice = offline ? "\(summary). Se sincronizará cuando vuelva la conexión." : summary
    }

    private func signalFeedback(_ kind: NidoFeedbackKind) {
        feedbackKind = kind
        feedbackToken += 1
    }

    private func restoreCache() async {
        let generation = sessionGeneration
        do {
            let (snapshot, sleepStartedAt) = try await registrationService.snapshot()
            guard sessionGeneration == generation else { return }
            profile = snapshot.profile
            entries = snapshot.entries.sorted { $0.occurredAt > $1.occurredAt }
            pendingEntryIDs = snapshot.pendingEntryIDs
            profileNeedsSync = snapshot.profileNeedsSync
            activeSleepStartedAt = sleepStartedAt
        } catch {
            logger.error("Cache could not be read: \(error.localizedDescription, privacy: .private(mask: .hash))")
        }
        do {
            let cached = try babyCareCache.load()
            if let cachedBinding = cached.sessionBinding,
               let activeBinding = sessionBinding(for: accessToken),
               cachedBinding != activeBinding {
                clearBabyCareData()
                caregiverRoleIsConfirmed = false
                return
            }
            babyCareState = cached.state
            babyCareBaseState = cached.baseState
            conflictedBabyCareState = cached.conflictedRemoteState
            babyCareNeedsSync = cached.needsSync
            babyCareHasConflict = cached.hasConflict
            if cached.sessionBinding == sessionBinding(for: accessToken),
               let caregiver = cached.confirmedCaregiver,
               caregiver.status == .active {
                caregivers = [caregiver]
                currentCaregiver = caregiver
                caregiverRoleIsConfirmed = true
            } else {
                caregiverRoleIsConfirmed = false
            }
        } catch {
            logger.error("Baby-care cache could not be read: \(error.localizedDescription, privacy: .private(mask: .hash))")
        }
    }

    private func stageBabyCare(_ state: BabyCareState) async -> Bool {
        babyCareState = state
        babyCareNeedsSync = true
        babyCareError = nil
        babyCareHasConflict = false
        conflictedBabyCareState = nil
        guard persistBabyCareCache() else { return false }
        updateWidgets()
        await synchronizeBabyCare()
        return true
    }

    private func synchronizeBabyCare() async {
        guard let token = accessToken, babyCareNeedsSync, !babyCareHasConflict, !isSavingBabyCare else { return }
        let generation = sessionGeneration
        let submitted = babyCareState
        var scheduleFollowUp = false
        isSavingBabyCare = true
        defer {
            isSavingBabyCare = false
            if scheduleFollowUp {
                Task { @MainActor [weak self] in await self?.synchronizeBabyCare() }
            }
        }
        do {
            let result = try await api.saveBabyCare(
                babyCareState,
                expectedRevision: babyCareBaseState?.revision ?? babyCareState.revision,
                accessToken: token
            )
            guard generation == sessionGeneration, accessToken == token else { return }
            switch result {
            case .saved(let saved):
                scheduleFollowUp = acceptSavedBabyCare(saved, submitted: submitted)
            case .conflict(let remote):
                guard let base = babyCareBaseState,
                      let rebased = Self.rebaseBabyCare(local: babyCareState, base: base, remote: remote)
                else {
                    conflictedBabyCareState = remote
                    babyCareHasConflict = true
                    babyCareNeedsSync = true
                    babyCareError = "Hay cambios simultáneos. Revisa cuál quieres conservar."
                    _ = persistBabyCareCache()
                    return
                }
                babyCareBaseState = remote
                babyCareState = rebased
                babyCareNeedsSync = true
                guard persistBabyCareCache() else { return }
                let retry = try await api.saveBabyCare(rebased, expectedRevision: remote.revision, accessToken: token)
                guard generation == sessionGeneration, accessToken == token else { return }
                if case .saved(let saved) = retry {
                    scheduleFollowUp = acceptSavedBabyCare(saved, submitted: rebased)
                } else if case .conflict(let latest) = retry {
                    conflictedBabyCareState = latest
                    babyCareHasConflict = true
                    babyCareNeedsSync = true
                    babyCareError = "Hay cambios simultáneos. Revisa cuál quieres conservar."
                }
                _ = persistBabyCareCache()
            }
        } catch {
            guard generation == sessionGeneration, accessToken == token else { return }
            if isUnauthorized(error) {
                await invalidateSession(message: "Vuelve a iniciar sesión para acceder.")
                return
            }
            babyCareNeedsSync = true
            babyCareError = "Se guardó en este dispositivo. Se sincronizará cuando vuelva la conexión."
            _ = persistBabyCareCache()
        }
    }

    private func acceptSavedBabyCare(_ saved: BabyCareState, submitted: BabyCareState) -> Bool {
        if babyCareState == submitted {
            babyCareState = saved
            babyCareNeedsSync = false
        } else if let merged = Self.rebaseBabyCare(local: babyCareState, base: submitted, remote: saved) {
            babyCareState = merged
            babyCareNeedsSync = true
        } else {
            conflictedBabyCareState = saved
            babyCareHasConflict = true
            babyCareNeedsSync = true
            babyCareError = "Hay cambios simultáneos. Revisa cuál quieres conservar."
            _ = persistBabyCareCache()
            return false
        }
        babyCareBaseState = saved
        babyCareError = nil
        updateWidgets()
        _ = persistBabyCareCache()
        return babyCareNeedsSync
    }

    private func acceptRemoteBabyCare(_ remote: BabyCareState) async {
        if babyCareNeedsSync {
            if let base = babyCareBaseState,
               let rebased = Self.rebaseBabyCare(local: babyCareState, base: base, remote: remote) {
                babyCareState = rebased
                babyCareBaseState = remote
                babyCareNeedsSync = true
            } else {
                conflictedBabyCareState = remote
                babyCareHasConflict = true
                babyCareNeedsSync = true
                babyCareError = "Hay cambios simultáneos. Revisa cuál quieres conservar."
            }
        } else {
            babyCareState = remote
            babyCareBaseState = remote
            babyCareNeedsSync = false
            babyCareHasConflict = false
        }
        _ = persistBabyCareCache()
    }

    private func persistBabyCareCache() -> Bool {
        do {
            try babyCareCache.save(BabyCareCacheSnapshot(
                state: babyCareState,
                baseState: babyCareBaseState,
                conflictedRemoteState: conflictedBabyCareState,
                needsSync: babyCareNeedsSync,
                confirmedCaregiver: caregiverRoleIsConfirmed ? currentCaregiver : nil,
                sessionBinding: sessionBinding(for: accessToken)
            ))
            return true
        } catch {
            babyCareError = "No se pudieron guardar los cambios en este dispositivo."
            logger.error("Baby-care cache could not be saved: \(error.localizedDescription, privacy: .private(mask: .hash))")
            return false
        }
    }

    private static func rebaseBabyCare(local: BabyCareState, base: BabyCareState, remote: BabyCareState) -> BabyCareState? {
        BabyCareReconciliation.rebased(local: local, base: base, remote: remote)
    }

    private func sessionBinding(for token: String?) -> String? {
        guard let token else { return nil }
        return SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func familyDate(_ date: Date, timeZoneID: String) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private func isValidFamilyDate(_ value: String, timeZoneID: String) -> Bool {
        guard value.count == 10, let date = ISO8601DateFormatter().date(from: value + "T00:00:00Z") else { return false }
        return Self.familyDate(date, timeZoneID: "UTC") == value
    }

    private static func validGrowthMeasurement(_ item: GrowthMeasurement, now: Date) -> Bool {
        let earliest = Int64(Date(timeIntervalSince1970: 946_684_800).timeIntervalSince1970 * 1_000)
        return !item.id.isEmpty && item.measuredAt >= earliest
            && Double(item.measuredAt) <= now.timeIntervalSince1970 * 1_000
            && ((item.weightGrams.map { (1...200_000).contains($0) } ?? true)
                && (item.heightMillimeters.map { (1...2_500).contains($0) } ?? true))
            && (item.weightGrams != nil || item.heightMillimeters != nil)
            && item.note.count <= 500
    }

    private static func legacyGrowthDetail(for measurement: GrowthMeasurement) -> String {
        var parts = ["Medidas"]
        if let grams = measurement.weightGrams {
            parts.append("\(displayDecimal(Double(grams) / 1_000)) kg")
        }
        if let millimeters = measurement.heightMillimeters {
            parts.append("\(displayDecimal(Double(millimeters) / 10)) cm")
        }
        let note = measurement.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty { parts.append(note) }
        return parts.joined(separator: " · ")
    }

    private static func displayDecimal(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value)) }
        return String(format: "%.3f", value)
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: ".", with: ",")
    }

    private func restoreLiveActivities() async {
        guard allowsExternalEffects else { return }
        await NidoLiveActivity.reconcile(
            sleepStartedAt: activeSleepStartedAt,
            feedStartedAt: activeFeedStartedAt,
            babyName: profile?.babyName ?? "Bebé"
        )
    }

    private func synchronizePendingChanges() async throws {
        let generation = sessionGeneration
        guard let accessToken else { return }
        if profileNeedsSync, let profile {
            let savedProfile = try await api.save(profile: profile, accessToken: accessToken)
            guard sessionGeneration == generation else { return }
            self.profile = savedProfile
            profileNeedsSync = false
        }

        for entry in entries where pendingEntryIDs.contains(entry.id) {
            guard !inFlightRegistrationEntryIDs.values.contains(entry.id) else { continue }
            do {
                _ = try await api.create(entry: entry, accessToken: accessToken)
            } catch {
                guard sessionGeneration == generation else { return }
                let remote = try await api.load(accessToken: accessToken)
                guard sessionGeneration == generation else { return }
                guard remote.entries.contains(where: { $0.id == entry.id }) else {
                    throw error
                }
            }
            guard sessionGeneration == generation else { return }
            pendingEntryIDs.remove(entry.id)
            let persisted = await persist(acknowledgedEntryIDs: [entry.id])
            guard sessionGeneration == generation else { return }
            guard persisted else {
                pendingEntryIDs.insert(entry.id)
                throw NidoSyncCheckpointError.persistenceFailed
            }
        }
        for id in Array(pendingUpdatedEntryIDs) {
            guard let entry = entries.first(where: { $0.id == id }) else { continue }
            _ = try await api.update(entry: entry, accessToken: accessToken)
            guard sessionGeneration == generation else { return }
            pendingUpdatedEntryIDs.remove(id)
            let persisted = await persist()
            guard sessionGeneration == generation else { return }
            guard persisted else {
                pendingUpdatedEntryIDs.insert(id)
                throw NidoSyncCheckpointError.persistenceFailed
            }
        }
        for id in Array(pendingDeletionIDs) {
            guard !inFlightRegistrationEntryIDs.values.contains(id) else { continue }
            try await api.delete(entryID: id, accessToken: accessToken)
            guard sessionGeneration == generation else { return }
            pendingDeletionIDs.remove(id)
            let persisted = await persist()
            guard sessionGeneration == generation else { return }
            guard persisted else {
                pendingDeletionIDs.insert(id)
                throw NidoSyncCheckpointError.persistenceFailed
            }
        }
    }

    @discardableResult
    private func persist(
        removingEntryIDs: Set<String> = [],
        acknowledgedEntryIDs: Set<String> = []
    ) async -> Bool {
        let generation = sessionGeneration
        let token = accessToken
        defaults.set(Array(pendingUpdatedEntryIDs), forKey: "pendingUpdatedEntryIDs")
        defaults.set(Array(pendingDeletionIDs), forKey: "pendingDeletionIDs")
        do {
            let saved = try await registrationService.saveAppSnapshot(NidoSnapshot(
                profile: profile,
                entries: entries,
                pendingEntryIDs: pendingEntryIDs,
                profileNeedsSync: profileNeedsSync
            ), removingEntryIDs: removingEntryIDs, acknowledgedEntryIDs: acknowledgedEntryIDs,
               expectedAccessToken: token)
            guard sessionGeneration == generation else { return false }
            profile = saved.profile
            entries = saved.entries
            pendingEntryIDs = saved.pendingEntryIDs
        } catch {
            guard sessionGeneration == generation else { return false }
            logger.error("Cache could not be saved: \(error.localizedDescription, privacy: .private(mask: .hash))")
            notice = RegistrationMutationResult.dialog(for: .storageUnavailable)
            signalFeedback(.error)
            return false
        }
        updateWidgets()
        return true
    }

    private func updateWidgets() {
        guard allowsExternalEffects else { return }
        NidoWidgetBridge.update(
            profile: profile,
            entries: entries,
            activeSleepStartedAt: activeSleepStartedAt,
            activeFeedStartedAt: activeFeedStartedAt,
            babyCareState: babyCareState,
            now: now
        )
    }

    private func appleCredentialState(for userID: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }

    private func isUnauthorized(_ error: Error) -> Bool {
        if case APIError.server(status: 401, message: _) = error { return true }
        return false
    }

    private func invalidateSession(message: String?) async {
        credentialStore.delete()
        accountDeletionChallenge = nil
        sessionCredential = nil
        await registrationService.clearPrivateData()
        try? babyCareCache.remove()
        guard sessionCredential == nil else { return }
        phase = .authentication
        notice = message
        preservesReauthenticationReason = message != nil
        isOffline = false
    }

    private func clearHouseholdData() async {
        let generation = sessionGeneration
        await registrationService.clearPersistentHouseholdData()
        guard sessionGeneration == generation else { return }
        clearInMemoryHouseholdData()
        try? babyCareCache.remove()
        updateWidgets()
        if allowsExternalEffects { await NidoLiveActivity.endAll() }
    }

    private func clearInMemoryHouseholdData() {
        historySelectedDay = nil
        profile = nil
        entries = []
        caregivers = []
        currentCaregiver = nil
        activeSleepStartedAt = nil
        activeFeedStartedAt = nil
        activeFeedSide = nil
        pendingEntryIDs = []
        pendingUpdatedEntryIDs = []
        pendingDeletionIDs = []
        profileNeedsSync = false
        clearBabyCareData()
        recentlyDeletedEntry = nil
        recentlyCreatedEntry = nil
        editingEntry = nil
        latestRegistrationOperationID = nil
        inFlightRegistrationEntryIDs.removeAll()
        defaults.removeObject(forKey: caregiverIDKey)
        defaults.removeObject(forKey: "pendingUpdatedEntryIDs")
        defaults.removeObject(forKey: "pendingDeletionIDs")
        defaults.removeObject(forKey: "activeSleepStartedAt")
        defaults.removeObject(forKey: "activeFeedStartedAt")
        defaults.removeObject(forKey: "activeFeedSide")
    }

    private func clearBabyCareData() {
        babyCareState = BabyCareState()
        babyCareBaseState = nil
        conflictedBabyCareState = nil
        caregiverRoleIsConfirmed = false
        babyCareNeedsSync = false
        babyCareHasConflict = false
        babyCareError = nil
        isSavingBabyCare = false
        try? babyCareCache.remove()
    }

    private func selectCaregiver(_ caregiver: Caregiver) {
        currentCaregiver = caregiver
        caregiverRoleIsConfirmed = caregiver.status == .active
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
    nonisolated static let apiBaseURL: URL = {
        #if DEBUG && targetEnvironment(simulator)
        return UITestLaunchPolicy.apiBaseURL(
            isDebugSimulator: true,
            allowsProduction: ProcessInfo.processInfo.environment["NIDO_SIMULATOR_PRODUCTION_OPT_IN"] == "1"
        )
        #else
        return UITestLaunchPolicy.apiBaseURL(isDebugSimulator: false, allowsProduction: false)
        #endif
    }()
}
