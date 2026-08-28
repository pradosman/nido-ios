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
        .sensoryFeedback(trigger: store.feedbackToken) { _, _ in
            switch store.feedbackKind {
            case .selection: .selection
            case .success: .success
            case .warning: .warning
            case .error: .error
            }
        }
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
                Text("Preparando Nido…")
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
                .tabItem { Label("Hoy", systemImage: "house") }

            NavigationStack { HistoryView() }
                .tag(AppTab.history)
                .tabItem { Label("Historia", systemImage: "clock.arrow.circlepath") }

            NavigationStack { TrendsView() }
                .tag(AppTab.trends)
                .tabItem { Label("Ritmos", systemImage: "chart.bar.xaxis") }

            NavigationStack { SettingsView() }
                .tag(AppTab.settings)
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
        }
        .tint(NidoTheme.moss)
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
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $store.isEditingProfile) {
            ProfileEditorView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $store.editingEntry) { entry in
            EntryEditorView(entry: entry)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .safeAreaInset(edge: .bottom, spacing: 8) {
            if let notice = store.notice {
                NoticeView(
                    message: notice,
                    isOffline: store.isOffline,
                    canUndo: store.recentlyDeletedEntry != nil,
                    undo: { Task { await store.undoDelete() } }
                )
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let message: String
    let isOffline: Bool
    let canUndo: Bool
    let undo: () -> Void

    var body: some View {
        adaptiveLayout {
            Label(message, systemImage: isOffline ? "wifi.slash" : "checkmark.circle.fill")
                .fixedSize(horizontal: false, vertical: true)
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
            .frame(maxWidth: 560)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(NidoTheme.separator.opacity(0.55), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
            .padding(.horizontal)
    }

    private var adaptiveLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 10))
    }
}
