import SwiftUI

@main
struct NidoApp: App {
    @State private var store: NidoStore
    @Environment(\.scenePhase) private var scenePhase
    private let shouldLoadOnLaunch: Bool

    init() {
        let store = NidoStore()
        #if DEBUG
        if let scenario = ProcessInfo.processInfo.environment["NIDO_UI_TEST_SCENARIO"] {
            store.prepareForUITesting(scenario: scenario)
            _store = State(initialValue: store)
            shouldLoadOnLaunch = false
            return
        }
        #endif
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
