import SwiftUI

struct RootView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch store.phase {
            case .loading:
                LoadingView()
            case .authentication:
                AppleSignInView()
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
    @State private var isPresentingEntryKindMenu = false
    @State private var quickRegistrationKind: EntryKind?
    @State private var pendingDetailKind: EntryKind?

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.selectedTab) {
            tabScreen { TodayView() }
                .tabItem { Label("Hoy", systemImage: "house.fill") }
                .tag(AppTab.today)

            tabScreen { HistoryView() }
                .tabItem { Label("Historia", systemImage: "clock.arrow.circlepath") }
                .tag(AppTab.history)

            tabScreen { TrendsView() }
                .tabItem { Label("Ritmos", systemImage: "chart.bar.xaxis") }
                .tag(AppTab.trends)

            tabScreen { SettingsView() }
                .tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .tint(NidoTheme.moss)
        .confirmationDialog("Registrar una actividad", isPresented: $isPresentingEntryKindMenu) {
            ForEach(EntryKind.allCases) { kind in
                Button("Registrar \(kind.title.lowercased())") {
                    if kind == .diaper || (kind == .feed && RegistrationQuickAction.feed(entries: store.entries, at: store.now) != nil) {
                        quickRegistrationKind = kind
                    } else {
                        store.presentedEntryKind = kind
                    }
                }
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(45))
                guard !Task.isCancelled else { return }
                await store.refresh()
            }
        }
        .task(id: NoticeDismissID(
            message: store.notice,
            deletedEntryID: store.recentlyDeletedEntry?.id,
            createdEntryID: store.recentlyCreatedEntry?.id
        )) {
            guard store.notice != nil,
                  store.recentlyDeletedEntry == nil,
                  store.recentlyCreatedEntry == nil
            else { return }

            do {
                try await Task.sleep(for: .seconds(3))
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
        .sheet(item: $quickRegistrationKind, onDismiss: {
            if let pendingDetailKind {
                store.presentedEntryKind = pendingDetailKind
                self.pendingDetailKind = nil
            }
        }) { kind in
            QuickRegistrationSheet(kind: kind) {
                pendingDetailKind = kind
                quickRegistrationKind = nil
            }
                .presentationDetents([.medium])
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
    }

    private func tabScreen<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                bottomActionArea
            }
        }
    }

    private var bottomActionArea: some View {
        VStack(spacing: 8) {
            if let notice = store.notice {
                NoticeView(
                    message: notice,
                    isOffline: store.isOffline,
                    canEdit: store.recentlyCreatedEntry != nil,
                    canUndo: store.recentlyDeletedEntry != nil || store.recentlyCreatedEntry != nil,
                    edit: store.editRecentlyCreatedEntry,
                    undo: {
                        Task {
                            if store.recentlyCreatedEntry != nil {
                                await store.undoCreatedEntry()
                            } else {
                                await store.undoDelete()
                            }
                        }
                    },
                    dismiss: {
                        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2, extraBounce: 0)) {
                            store.dismissNotice()
                        }
                    }
                )
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .onTapGesture {
                    if store.recentlyDeletedEntry == nil, store.recentlyCreatedEntry == nil {
                        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2, extraBounce: 0)) { store.dismissNotice() }
                    }
                }
            }

            Button {
                isPresentingEntryKindMenu = true
            } label: {
                Label("Registrar una actividad", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(.white)
                    .background(NidoTheme.moss, in: Capsule())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityHint("Abre las opciones de registro")
            .accessibilityIdentifier("registration-action-button")
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }
}

private struct QuickRegistrationSheet: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let kind: EntryKind
    let addDetails: () -> Void

    private var choice: RegistrationQuickAction.Choice? {
        switch kind {
        case .diaper:
            RegistrationQuickAction.diaper(entries: store.entries, at: store.now)
        case .feed:
            RegistrationQuickAction.feed(entries: store.entries, at: store.now)
        case .sleep, .health:
            nil
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                Form {
                    Section {
                        if kind == .feed, let choice {
                            Text(choice.summary)
                                .font(.subheadline)
                                .foregroundStyle(NidoTheme.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let choice {
                            Button(choice.label) {
                                Task { await store.addQuickEntry(choice) }
                                dismiss()
                            }
                            .fontWeight(.semibold)
                            .frame(minHeight: 44)
                            .accessibilityHint("Guarda un registro nuevo con la hora actual")
                        }
                    } header: {
                        Text("Registro rápido")
                    } footer: {
                        Text("Se guardará exactamente como aparece arriba.")
                    }

                    Section {
                        Button("Añadir detalles", action: addDetails)
                            .frame(minHeight: 44)
                            .accessibilityHint("Abre el formulario completo de \(kind.title.lowercased())")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .tint(NidoTheme.moss)
    }
}

private struct NoticeDismissID: Equatable {
    let message: String?
    let deletedEntryID: String?
    let createdEntryID: String?
}

private struct NoticeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let message: String
    let isOffline: Bool
    let canEdit: Bool
    let canUndo: Bool
    let edit: () -> Void
    let undo: () -> Void
    let dismiss: () -> Void

    var body: some View {
        adaptiveLayout {
            Label(message, systemImage: isOffline ? "wifi.slash" : "checkmark.circle.fill")
                .fixedSize(horizontal: false, vertical: true)
            if canEdit {
                Button("Editar", action: edit)
                    .fontWeight(.bold)
                    .foregroundStyle(NidoTheme.moss)
                    .frame(minHeight: 44)
                    .accessibilityHint("Abre el registro que acabas de crear")
            }
            if canUndo {
                Button("Deshacer", action: undo)
                    .fontWeight(.bold)
                    .foregroundStyle(NidoTheme.moss)
                    .frame(minHeight: 44)
                    .accessibilityHint("Revierte la acción más reciente")
            }
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Cerrar aviso")
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
            .accessibilityElement(children: .contain)
    }

    private var adaptiveLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 10))
    }
}
