import SwiftUI

@main
struct NidoApp: App {
    @State private var store = NidoStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task { await store.load() }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active, store.phase == .ready else { return }
                    Task { await store.refresh() }
                }
        }
    }
}
