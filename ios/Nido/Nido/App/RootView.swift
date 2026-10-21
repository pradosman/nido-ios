import SwiftUI
import UIKit
#if DEBUG
import os

private enum RegistrationRoutingDiagnostics {
    static let logger = Logger(subsystem: "com.momentumia.nido", category: "RegistrationRouting")
}
#endif

struct RootView: View {
    @Environment(NidoStore.self) private var store
    @Environment(NidoDemoSessionCoordinator.self) private var demoCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let activeStore = demoCoordinator.store ?? store
        Group {
            switch activeStore.phase {
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
        .environment(activeStore)
        .defaultAppStorage(demoCoordinator.defaults ?? .standard)
        .id(ObjectIdentifier(activeStore))
        .safeAreaInset(edge: .top, spacing: 0) {
            if demoCoordinator.isActive {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 8) {
                            demoStatusLabel
                            HStack(spacing: 12) {
                                Spacer(minLength: 0)
                                demoResetButton
                                demoExitButton
                            }
                        }
                    } else {
                        HStack(spacing: 12) {
                            demoStatusLabel
                            Spacer(minLength: 4)
                            demoResetButton
                            demoExitButton
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .foregroundStyle(NidoTheme.ink)
                .background(NidoTheme.surface.opacity(0.95))
                .overlay(alignment: .bottom) { Rectangle().fill(NidoTheme.separator).frame(height: 1) }
            } else if activeStore.hasAccountSession, (activeStore.phase == .onboarding || activeStore.phase == .caregiverAccess) {
                HStack {
                    Spacer(minLength: 0)
                    AccountDeletionEntryPoint(style: .accountMenu)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: activeStore.phase)
        .sensoryFeedback(trigger: activeStore.feedbackToken) { _, _ in
            switch activeStore.feedbackKind {
            case .selection: .selection
            case .success: .success
            case .warning: .warning
            case .error: .error
            }
        }
    }

    private var demoStatusLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "play.rectangle.fill")
                .accessibilityHidden(true)
            Text("Demostración con datos de ejemplo")
                .font(.caption.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("demo-status")
        }
        .layoutPriority(1)
    }

    private var demoResetButton: some View {
        Button("Reiniciar") {
            Task { await demoCoordinator.reset() }
        }
        .font(.caption.weight(.semibold))
        .frame(minWidth: 44, minHeight: 44)
        .disabled(demoCoordinator.isTransitioning)
        .accessibilityLabel("Reiniciar demostración")
        .accessibilityIdentifier("demo-reset")
    }

    private var demoExitButton: some View {
        Button("Salir") {
            demoCoordinator.exit()
        }
        .font(.caption.weight(.semibold))
        .frame(minWidth: 44, minHeight: 44)
        .disabled(demoCoordinator.isTransitioning)
        .accessibilityLabel("Salir de la demostración")
        .accessibilityIdentifier("demo-exit")
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
    @State private var quickRegistrationKind: EntryKind?
    @State private var floatingNavigationClearance: CGFloat = 12

    private let trendsTitle = "Evolución"

    var body: some View {
        @Bindable var store = store

        ZStack {
            TabView(selection: $store.selectedTab) {
                tabScreen { TodayView() }
                    .tabItem { Label("Hoy", systemImage: "house.fill") }
                    .tag(AppTab.today)

                tabScreen { HistoryView() }
                    .tabItem { Label("Historia", systemImage: "clock.arrow.circlepath") }
                    .tag(AppTab.history)

                tabScreen { TrendsView() }
                    .tabItem { Label(trendsTitle, systemImage: "chart.bar.xaxis") }
                    .tag(AppTab.trends)

                tabScreen { SettingsView() }
                    .tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
                    .tag(AppTab.settings)
            }
            .toolbar(.hidden, for: .tabBar)
            .tint(NidoTheme.tabSelection)
        }
        .ignoresSafeArea(edges: .bottom)
        .overlay {
            FloatingNavigationDock(
                selection: $store.selectedTab,
                clearanceChanged: { floatingNavigationClearance = $0 },
                trendsTitle: trendsTitle,
                action: { registrationMenu(store: store) },
                notice: {
                    if let notice = store.notice {
                        noticeView(notice: notice, store: store)
                    } else {
                        EmptyView()
                    }
                }
            )
            .ignoresSafeArea(edges: .bottom)
        }
        .environment(\.floatingNavigationClearance, floatingNavigationClearance)
        .onChange(of: store.evolutionPreferenceScope) { _, _ in
            store.isEditingEvolutionPins = false
        }
        .background { PaperBackground() }
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
            guard let expectedNotice = store.notice,
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
                store.dismissNoticeAutomatically(matching: expectedNotice)
            }
        }
        .sheet(item: $store.presentedEntryKind) { kind in
            EntrySheet(kind: kind)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .onAppear {
                    #if DEBUG
                    RegistrationRoutingDiagnostics.logger.debug(
                        "sheet_appeared destination=detailed kind=\(kind.rawValue, privacy: .public)"
                    )
                    #endif
                }
        }
        .sheet(item: $quickRegistrationKind) { kind in
            QuickRegistrationSheet(kind: kind)
                .presentationDragIndicator(.visible)
                .onAppear {
                    #if DEBUG
                    RegistrationRoutingDiagnostics.logger.debug(
                        "sheet_appeared destination=quick kind=\(kind.rawValue, privacy: .public)"
                    )
                    #endif
                }
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
        .sheet(isPresented: $store.isEditingEvolutionPins) {
            EvolutionPinnedEditorView(preferences: store.evolutionPinnedPreferences) { preferences in
                store.saveEvolutionPinnedPreferences(preferences)
            }
        }
    }

    private func tabScreen<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar(.hidden, for: .tabBar)
        }
    }

    private func registrationMenu(store: NidoStore) -> some View {
        Menu {
            ForEach(EntryKind.allCases) { kind in
                Button {
                    let presentsQuickRegistration = kind == .diaper
                        || (kind == .feed
                            && RegistrationQuickAction.feed(entries: store.entries, at: store.now) != nil)
                    #if DEBUG
                    RegistrationRoutingDiagnostics.logger.debug(
                        "menu_action kind=\(kind.rawValue, privacy: .public) destination=\(presentsQuickRegistration ? "quick" : "detailed", privacy: .public)"
                    )
                    #endif
                    if presentsQuickRegistration {
                        quickRegistrationKind = kind
                    } else {
                        store.presentedEntryKind = kind
                    }
                } label: {
                    Label {
                        Text(kind.title)
                    } icon: {
                        CareCategoryIcon.menuImage(for: kind.careCategory, size: 17)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(NidoTheme.color(for: kind))
                    }
                    .accessibilityLabel("Registrar \(kind.title.lowercased())")
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 21, weight: .semibold))
                .frame(width: 54, height: 54)
                .foregroundStyle(.white)
                .background(NidoTheme.prominentActionFill, in: Circle())
                .contentShape(Circle())
        }
        .menuOrder(.fixed)
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Registrar una actividad")
        .accessibilityHint("Abre las opciones de registro")
        .accessibilityIdentifier("registration-action-button")
    }

    private func noticeView(notice: String, store: NidoStore) -> some View {
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
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.2, extraBounce: 0)) {
                    store.dismissNotice()
                }
            }
        }
    }
}

private struct QuickRegistrationSheet: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var detailedDraft: RegistrationDraft?
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var dismissedAfterLocalCommit = false
    let kind: EntryKind

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
        Group {
            if let detailedDraft {
                EntrySheet(kind: kind, initialDraft: detailedDraft)
            } else {
                quickForm
            }
        }
        .presentationDetents(detailedDraft == nil ? [.medium] : [.large])
        .onChange(of: store.recentlyCreatedEntry?.id) { _, entryID in
            if isSaving, entryID != nil {
                dismissedAfterLocalCommit = true
                dismiss()
            }
        }
    }

    private var quickForm: some View {
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
                                guard !isSaving else { return }
                                isSaving = true
                                saveError = nil
                                Task {
                                    let saved = await store.addQuickEntry(choice)
                                    guard !dismissedAfterLocalCommit else { return }
                                    isSaving = false
                                    if saved { dismiss() }
                                    else { saveError = store.notice ?? "No se ha podido guardar. Vuelve a intentarlo." }
                                }
                            }
                            .disabled(isSaving)
                            .fontWeight(.semibold)
                            .frame(minHeight: 44)
                            .accessibilityHint("Guarda un registro nuevo con la hora actual")
                        }
                    } header: {
                        Text("Registro rápido")
                    } footer: {
                        Text("Se guardará exactamente como aparece arriba.")
                    }

                    if isSaving {
                        Section { ProgressView("Guardando…") }
                    }
                    if let saveError {
                        Section {
                            Label(saveError, systemImage: "exclamationmark.circle")
                                .foregroundStyle(.red)
                        }
                    }

                    Section {
                        Button("Añadir detalles") {
                            guard let choice else { return }
                            withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
                                detailedDraft = choice.draft
                            }
                        }
                            .disabled(isSaving)
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
                        .disabled(isSaving)
                }
            }
        }
        .tint(NidoTheme.moss)
        .interactiveDismissDisabled(isSaving)
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
