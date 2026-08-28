import SwiftUI

struct RootView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch store.phase {
            case .loading:
                LoadingView()
            case .onboarding:
                OnboardingView()
            case .caregiverAccess:
                CaregiverAccessView()
            case .ready:
                MainTabView()
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: store.phase)
        .sensoryFeedback(.success, trigger: store.feedbackToken)
    }
}

private struct LoadingView: View {
    var body: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 18) {
                NidoMark()
                    .frame(width: 52, height: 52)
                    .foregroundStyle(NidoTheme.moss)
                Text("Preparando vuestro espacio…")
                    .font(.callout)
                    .foregroundStyle(NidoTheme.secondaryInk)
                ProgressView()
                    .tint(NidoTheme.moss)
            }
        }
    }
}

private struct MainTabView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.selectedTab) {
            NavigationStack { TodayView() }
                .tag(AppTab.today)
                .tabItem { Label("Hoy", systemImage: "house.fill") }

            NavigationStack { HistoryView() }
                .tag(AppTab.history)
                .tabItem { Label("Historia", systemImage: "book.pages.fill") }

            NavigationStack { TrendsView() }
                .tag(AppTab.trends)
                .tabItem { Label("Ritmos", systemImage: "chart.xyaxis.line") }

            NavigationStack { SettingsView() }
                .tag(AppTab.settings)
                .tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
        }
        .tint(NidoTheme.moss)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(45))
                guard !Task.isCancelled else { return }
                await store.refresh()
            }
        }
        .task(id: NoticeDismissID(
            message: store.notice,
            deletedEntryID: store.recentlyDeletedEntry?.id
        )) {
            guard store.notice != nil else { return }

            do {
                try await Task.sleep(for: .seconds(store.recentlyDeletedEntry == nil ? 3 : 5))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }

            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2, extraBounce: 0)) {
                store.dismissNotice()
            }
        }
        .sheet(item: $store.presentedEntryKind) { kind in
            EntrySheet(kind: kind)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
        }
        .sheet(isPresented: $store.isEditingProfile) {
            ProfileEditorView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
        }
        .sheet(item: $store.editingEntry) { entry in
            EntryEditorView(entry: entry)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
        }
        .overlay(alignment: .top) {
            if let notice = store.notice {
                NoticeView(
                    message: notice,
                    isOffline: store.isOffline,
                    canUndo: store.recentlyDeletedEntry != nil,
                    undo: { Task { await store.undoDelete() } }
                )
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .onTapGesture {
                        if store.recentlyDeletedEntry == nil {
                            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2, extraBounce: 0)) { store.dismissNotice() }
                        }
                    }
            }
        }
    }
}

private struct NoticeDismissID: Equatable {
    let message: String?
    let deletedEntryID: String?
}

private struct NoticeView: View {
    let message: String
    let isOffline: Bool
    let canUndo: Bool
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Label(message, systemImage: isOffline ? "wifi.slash" : "checkmark.circle.fill")
            if canUndo {
                Button("Deshacer", action: undo)
                    .fontWeight(.bold)
                    .foregroundStyle(NidoTheme.moss)
            }
        }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(NidoTheme.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.65), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
            .padding(.top, 8)
            .padding(.horizontal)
    }
}
