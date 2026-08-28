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
            let defaultsSuite = "com.momentumia.nido.uitests.\(runID)"
            let defaults = UserDefaults(suiteName: defaultsSuite) ?? .standard
            defaults.removePersistentDomain(forName: defaultsSuite)
            let cacheURL = FileManager.default.temporaryDirectory
                .appending(path: "NidoUITests", directoryHint: .isDirectory)
                .appending(path: runID, directoryHint: .isDirectory)
                .appending(path: "snapshot.json")
            let store = NidoStore(
                cache: LocalCache(fileURL: cacheURL),
                defaults: defaults
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
