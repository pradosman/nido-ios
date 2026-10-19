import AppIntents
import SwiftUI

@main
struct NidoApp: App {
    @State private var store: NidoStore
    @State private var demoCoordinator = NidoDemoSessionCoordinator()
    @Environment(\.scenePhase) private var scenePhase
    private let shouldLoadOnLaunch: Bool
    private let uiTestScenario: String?

#if DEBUG
    static func makeLocalUITestStore(runID: String, referenceNow: Date, isSimulator: Bool) -> NidoStore {
        let defaultsSuite = "com.momentumia.nido.uitests.\(runID)"
        let defaults = UserDefaults(suiteName: defaultsSuite) ?? .standard
        defaults.removePersistentDomain(forName: defaultsSuite)
        let cacheURL = FileManager.default.temporaryDirectory
            .appending(path: "NidoUITests", directoryHint: .isDirectory)
            .appending(path: runID, directoryHint: .isDirectory)
            .appending(path: "snapshot.json")
        let cache = LocalCache(fileURL: cacheURL)
        let babyCareCache = BabyCareCache(fileURL: cacheURL.deletingLastPathComponent().appending(path: "baby-care.json"))
        let credentialStore = CredentialStore(service: "com.momentumia.nido.uitests.\(runID)")
        let localCredential = SessionCredential(
            accessToken: "local-ui-test-session",
            expiresAt: referenceNow.addingTimeInterval(86_400),
            appleUserID: nil
        )
        let eventHub = RegistrationMutationEventHub()
        let registrationService = NidoRegistrationServices.make(
            cache: cache,
            credentialStore: credentialStore,
            stateDefaults: defaults,
            legacyDefaults: defaults,
            stateStore: RegistrationStateFileStore(
                fileURL: cacheURL.deletingLastPathComponent().appending(path: "registration-state.json")
            ),
            eventHub: eventHub,
            credentialOverride: localCredential,
            now: { referenceNow },
            createEntry: { _, _ in throw URLError(.notConnectedToInternet) },
            syncSleep: { _, _, _ in throw URLError(.notConnectedToInternet) },
            loadSleep: { _ in throw URLError(.notConnectedToInternet) },
            allowsExternalEffects: isSimulator
        )
        let fixtureAPI = NidoAPI(baseURL: URL(string: "https://nido-ui-fixture.invalid")!) { _ in
            throw URLError(.notConnectedToInternet)
        }
        let store = NidoStore(
            api: fixtureAPI,
            babyCareCache: babyCareCache,
            credentialStore: credentialStore,
            defaults: defaults,
            now: { referenceNow },
            shouldLoadCredential: false,
            initialAccessToken: localCredential.accessToken,
            registrationService: registrationService,
            registrationEventHub: eventHub,
            allowsExternalEffects: isSimulator
        )
        return store
    }
#endif

    init() {
        NidoRegistrationShortcuts.updateAppShortcutParameters()
        #if DEBUG
        let launchInfo = ProcessInfo.processInfo
        let resolvedScenario: String?
        do {
            resolvedScenario = try UITestLaunchPolicy.scenario(
                arguments: launchInfo.arguments,
                environment: launchInfo.environment
            )
        } catch {
            fatalError("Malformed Nido UI-test launch marker")
        }
        if let scenario = resolvedScenario {
            let runID = ProcessInfo.processInfo.environment["NIDO_UI_TEST_RUN_ID"] ?? UUID().uuidString
#if targetEnvironment(simulator)
            let isSimulator = true
#else
            let isSimulator = false
#endif
            let requiresBackend = scenario == "multi-household"
                || scenario == "history-pagination"
                || scenario == "caregiver-permissions"
                || scenario == "account-deletion-onboarding"
                || scenario == "account-deletion-caregiver-access"
            if requiresBackend {
                guard let rawBaseURL = launchInfo.environment["NIDO_UI_TEST_API_BASE_URL"],
                      let baseURL = URL(string: rawBaseURL),
                      baseURL.host == "127.0.0.1" || baseURL.host == "localhost" else {
                    fatalError("Nido UI-test backend must use a loopback URL")
                }
                let defaultsSuite = "com.momentumia.nido.uitests.\(runID)"
                let defaults = UserDefaults(suiteName: defaultsSuite) ?? .standard
                defaults.removePersistentDomain(forName: defaultsSuite)
                let cacheURL = FileManager.default.temporaryDirectory
                    .appending(path: "NidoUITests", directoryHint: .isDirectory)
                    .appending(path: runID, directoryHint: .isDirectory)
                    .appending(path: "snapshot.json")
                let credentialStore = CredentialStore(service: "com.momentumia.nido.uitests.\(runID)")
                let initialAccessToken = launchInfo.environment["NIDO_UI_TEST_ACCESS_TOKEN"]
                let cache = LocalCache(fileURL: cacheURL)
                let babyCareCache = BabyCareCache(fileURL: cacheURL.deletingLastPathComponent().appending(path: "baby-care.json"))
                let eventHub = RegistrationMutationEventHub()
                let registrationService = NidoRegistrationServices.make(
                    api: NidoAPI(baseURL: baseURL),
                    cache: cache,
                    credentialStore: credentialStore,
                    stateDefaults: defaults,
                    legacyDefaults: defaults,
                    stateStore: RegistrationStateFileStore(
                        fileURL: cacheURL.deletingLastPathComponent().appending(path: "registration-state.json")
                    ),
                    eventHub: eventHub,
                    credentialOverride: initialAccessToken.map {
                        SessionCredential(accessToken: $0, expiresAt: .now.addingTimeInterval(3_600), appleUserID: nil)
                    },
                    allowsExternalEffects: isSimulator
                )
                let store = NidoStore(
                    api: NidoAPI(baseURL: baseURL),
                    babyCareCache: babyCareCache,
                    credentialStore: credentialStore,
                    defaults: defaults,
                    shouldLoadCredential: false,
                    initialAccessToken: initialAccessToken,
                    registrationService: registrationService,
                    registrationEventHub: eventHub,
                    allowsExternalEffects: isSimulator
                )
                _store = State(initialValue: store)
                let usesPreparedAccountDeletionFixture = scenario == "account-deletion-onboarding"
                    || scenario == "account-deletion-caregiver-access"
                shouldLoadOnLaunch = !usesPreparedAccountDeletionFixture
                uiTestScenario = usesPreparedAccountDeletionFixture ? scenario : nil
                return
            }
            let referenceNow: Date
            if scenario == "feed-create" || scenario == "diaper-edit" || scenario == "circular-timeline" || scenario == "circular-timeline-dense" || scenario == "history-calendar" || scenario == "baby-care" || scenario == "baby-care-empty" {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
                referenceNow = calendar.date(from: DateComponents(
                    year: 2026,
                    month: scenario == "baby-care" || scenario == "baby-care-empty" ? 10 : 8,
                    day: scenario == "baby-care" || scenario == "baby-care-empty" ? 17 : 28,
                    hour: scenario == "baby-care" || scenario == "baby-care-empty" ? 14 : scenario == "feed-create" ? 17 : scenario == "diaper-edit" ? 18 : scenario == "history-calendar" ? 12 : 22,
                    minute: scenario == "baby-care" || scenario == "baby-care-empty" ? 24 : scenario == "feed-create" ? 50 : scenario == "diaper-edit" ? 0 : scenario == "history-calendar" ? 0 : 40
                ))!
            } else {
                referenceNow = .now
            }
            let store = Self.makeLocalUITestStore(
                runID: runID,
                referenceNow: referenceNow,
                isSimulator: isSimulator
            )
            _store = State(initialValue: store)
            shouldLoadOnLaunch = false
            uiTestScenario = scenario
            return
        }
        #endif
        let store = NidoStore()
        _store = State(initialValue: store)
        shouldLoadOnLaunch = true
        uiTestScenario = nil
    }

#if DEBUG
    private var uiTestColorScheme: ColorScheme? {
        guard uiTestScenario != nil else { return nil }
        switch ProcessInfo.processInfo.environment["NIDO_UI_TEST_APPEARANCE"] {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
#endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(demoCoordinator)
                .modifier(UITestDynamicTypeOverride())
#if DEBUG
                .preferredColorScheme(uiTestColorScheme)
#endif
                .task {
                    #if DEBUG
                    if let uiTestScenario {
                        if uiTestScenario == "live-activity-cleanup" {
                            if store.allowsExternalEffects {
                                await NidoLiveActivity.endAll()
                            }
                            return
                        }
                        await store.prepareForUITesting(scenario: uiTestScenario)
                        if uiTestScenario == "live-activity-ten-hour-sleep" {
                            if store.allowsExternalEffects {
                                await NidoLiveActivity.endAll()
                                NidoLiveActivity.start(
                                    kind: "sleep",
                                    babyName: "Test",
                                    startedAt: .now.addingTimeInterval(-10 * 60 * 60)
                                )
                            }
                        } else if uiTestScenario == "live-activity-ten-minute-feed" {
                            if store.allowsExternalEffects {
                                await NidoLiveActivity.endAll()
                                NidoLiveActivity.start(
                                    kind: "feed",
                                    babyName: "Test",
                                    startedAt: .now.addingTimeInterval(-600)
                                )
                            }
                        }
                        return
                    }
                    #endif
                    guard shouldLoadOnLaunch else { return }
                    await store.load()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard shouldLoadOnLaunch, !demoCoordinator.isActive, phase == .active, store.phase == .ready else { return }
                    Task { await store.refresh() }
                }
                .task(id: "\(scenePhase):\(demoCoordinator.isActive)") {
                    guard shouldLoadOnLaunch, !demoCoordinator.isActive, scenePhase == .active else { return }
                    while !Task.isCancelled {
                        do {
                            try await Task.sleep(for: .seconds(5))
                        } catch {
                            return
                        }
                        guard !Task.isCancelled else { return }
                        guard !demoCoordinator.isActive else { return }
                        await store.refreshSharedSleep()
                    }
                }
        }
    }
}

struct UITestDynamicTypeOverride: ViewModifier {
    let requestedSize: String?

    init(requestedSize: String? = ProcessInfo.processInfo.environment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"]) {
        self.requestedSize = requestedSize
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        #if DEBUG
        if requestedSize == "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge" {
            content.environment(\.dynamicTypeSize, .accessibility5)
        } else if requestedSize == "UICTContentSizeCategoryLarge" {
            content.environment(\.dynamicTypeSize, .large)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
