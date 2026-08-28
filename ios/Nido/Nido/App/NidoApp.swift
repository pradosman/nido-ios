import SwiftUI

@main
struct NidoApp: App {
    @State private var store: NidoStore
    @Environment(\.scenePhase) private var scenePhase
    private let shouldLoadOnLaunch: Bool

    init() {
        #if DEBUG
        if let scenario = ProcessInfo.processInfo.environment["NIDO_UI_TEST_SCENARIO"] {
            let referenceNow: Date
            if scenario == "feed-create" || scenario == "circular-timeline" || scenario == "circular-timeline-dense" {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
                referenceNow = calendar.date(from: DateComponents(
                    year: 2026,
                    month: 8,
                    day: 28,
                    hour: 17,
                    minute: 50
                ))!
            } else {
                referenceNow = .now
            }
            let runID = ProcessInfo.processInfo.environment["NIDO_UI_TEST_RUN_ID"] ?? UUID().uuidString
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
        if ProcessInfo.processInfo.environment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"] == "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge" {
            content.environment(\.dynamicTypeSize, .accessibility3)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
