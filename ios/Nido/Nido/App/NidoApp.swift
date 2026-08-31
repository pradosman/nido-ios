import SwiftUI

@main
struct NidoApp: App {
    @State private var store: NidoStore
    @Environment(\.scenePhase) private var scenePhase
    private let shouldLoadOnLaunch: Bool

    init() {
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
                let store = NidoStore(
                    api: NidoAPI(baseURL: baseURL),
                    cache: LocalCache(fileURL: cacheURL),
                    credentialStore: credentialStore,
                    defaults: defaults,
                    shouldLoadCredential: false,
                    initialAccessToken: scenario == "history-pagination" || scenario == "caregiver-permissions"
                        ? ProcessInfo.processInfo.environment["NIDO_UI_TEST_ACCESS_TOKEN"]
                        : nil
                )
                _store = State(initialValue: store)
                shouldLoadOnLaunch = true
                return
            }
            let referenceNow: Date
            if scenario == "feed-create" || scenario == "circular-timeline" || scenario == "circular-timeline-dense" || scenario == "history-calendar" {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
                referenceNow = calendar.date(from: DateComponents(
                    year: 2026,
                    month: 8,
                    day: 28,
                    hour: scenario == "feed-create" ? 17 : scenario == "history-calendar" ? 12 : 22,
                    minute: scenario == "feed-create" ? 50 : scenario == "history-calendar" ? 0 : 40
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
            let store = NidoStore(
                cache: LocalCache(fileURL: cacheURL),
                defaults: defaults,
                now: { referenceNow }
            )
            store.prepareForUITesting(scenario: scenario)
            _store = State(initialValue: store)
            shouldLoadOnLaunch = false
            return
        }
        #endif
        let store = NidoStore()
        _store = State(initialValue: store)
        shouldLoadOnLaunch = true
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .modifier(UITestDynamicTypeOverride())
                .task {
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
