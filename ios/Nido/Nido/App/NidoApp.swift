import AppIntents
import SwiftUI

@main
struct NidoApp: App {
    @State private var store: NidoStore
    @Environment(\.scenePhase) private var scenePhase
    private let shouldLoadOnLaunch: Bool
    private let uiTestScenario: String?

    init() {
        NidoRegistrationShortcuts.updateAppShortcutParameters()
        #if DEBUG
        if let scenario = ProcessInfo.processInfo.environment["NIDO_UI_TEST_SCENARIO"] {
            let runID = ProcessInfo.processInfo.environment["NIDO_UI_TEST_RUN_ID"] ?? UUID().uuidString
            if (scenario == "multi-household" || scenario == "history-pagination" || scenario == "caregiver-permissions"),
               let rawBaseURL = ProcessInfo.processInfo.environment["NIDO_UI_TEST_API_BASE_URL"],
               let baseURL = URL(string: rawBaseURL) {
                let defaultsSuite = "com.momentumia.nido.uitests.\(runID)"
                let defaults = UserDefaults(suiteName: defaultsSuite) ?? .standard
                defaults.removePersistentDomain(forName: defaultsSuite)
                let cacheURL = FileManager.default.temporaryDirectory
                    .appending(path: "NidoUITests", directoryHint: .isDirectory)
                    .appending(path: runID, directoryHint: .isDirectory)
                    .appending(path: "snapshot.json")
                let credentialStore = CredentialStore(service: "com.momentumia.nido.uitests.\(runID)")
                let initialAccessToken = ProcessInfo.processInfo.environment["NIDO_UI_TEST_ACCESS_TOKEN"]
                let cache = LocalCache(fileURL: cacheURL)
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
                    }
                )
                let store = NidoStore(
                    api: NidoAPI(baseURL: baseURL),
                    credentialStore: credentialStore,
                    defaults: defaults,
                    shouldLoadCredential: false,
                    initialAccessToken: initialAccessToken,
                    registrationService: registrationService,
                    registrationEventHub: eventHub
                )
                _store = State(initialValue: store)
                shouldLoadOnLaunch = true
                uiTestScenario = nil
                return
            }
            let referenceNow: Date
            if scenario == "feed-create" || scenario == "diaper-edit" || scenario == "circular-timeline" || scenario == "circular-timeline-dense" || scenario == "history-calendar" {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
                referenceNow = calendar.date(from: DateComponents(
                    year: 2026,
                    month: 8,
                    day: 28,
                    hour: scenario == "feed-create" ? 17 : scenario == "diaper-edit" ? 18 : scenario == "history-calendar" ? 12 : 22,
                    minute: scenario == "feed-create" ? 50 : scenario == "diaper-edit" ? 0 : scenario == "history-calendar" ? 0 : 40
                ))!
            } else {
                referenceNow = .now
            }
            let defaultsSuite = "com.momentumia.nido.uitests.\(runID)"
            let defaults = UserDefaults(suiteName: defaultsSuite) ?? .standard
            defaults.removePersistentDomain(forName: defaultsSuite)
            let cacheURL = FileManager.default.temporaryDirectory
                .appending(path: "NidoUITests", directoryHint: .isDirectory)
                .appending(path: runID, directoryHint: .isDirectory)
                .appending(path: "snapshot.json")
            let cache = LocalCache(fileURL: cacheURL)
            let localCredential = SessionCredential(
                accessToken: "local-ui-test-session",
                expiresAt: referenceNow.addingTimeInterval(86_400),
                appleUserID: nil
            )
            let eventHub = RegistrationMutationEventHub()
            let registrationService = NidoRegistrationServices.make(
                cache: cache,
                stateDefaults: defaults,
                legacyDefaults: defaults,
                stateStore: RegistrationStateFileStore(
                    fileURL: cacheURL.deletingLastPathComponent().appending(path: "registration-state.json")
                ),
                eventHub: eventHub,
                credentialOverride: localCredential,
                now: { referenceNow },
                createEntry: { _, _ in throw URLError(.notConnectedToInternet) }
            )
            let store = NidoStore(
                defaults: defaults,
                now: { referenceNow },
                registrationService: registrationService,
                registrationEventHub: eventHub
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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .modifier(UITestDynamicTypeOverride())
                .task {
                    #if DEBUG
                    if let uiTestScenario {
                        await store.prepareForUITesting(scenario: uiTestScenario)
                        if uiTestScenario == "live-activity-ten-hour-sleep" {
                            await NidoLiveActivity.endAll()
                            NidoLiveActivity.start(
                                kind: "sleep",
                                babyName: "Test",
                                startedAt: .now.addingTimeInterval(-10 * 60 * 60)
                            )
                        }
                        return
                    }
                    #endif
                    guard shouldLoadOnLaunch else { return }
                    await store.load()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard shouldLoadOnLaunch, phase == .active, store.phase == .ready else { return }
                    Task { await store.refresh() }
                }
        }
    }
}

private struct UITestDynamicTypeOverride: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if DEBUG
        let requestedSize = ProcessInfo.processInfo.environment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"]
        if requestedSize == "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge" {
            content.environment(\.dynamicTypeSize, .accessibility3)
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
