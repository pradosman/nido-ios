import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.floatingNavigationClearance) private var floatingNavigationClearance
    @Environment(NidoDemoSessionCoordinator.self) private var demoCoordinator
    @State private var isInvitingCaregiver = false
    @State private var reportPreparation = ReportPreparation()
    @State private var backupURL: URL?
    @State private var reminderMessage: String?
    @State private var isImportingBackup = false
    @State private var pendingBackup: NidoBackup?
    @State private var backupError: String?
    @State private var caregiverPendingRemoval: Caregiver?
    @AppStorage("dailySummaryReminder") private var dailySummaryReminder = false
    @AppStorage("feedCheckReminder") private var feedCheckReminder = false

    private var isOwner: Bool { store.currentCaregiver?.role == .owner }

    var body: some View {
        ZStack {
            PaperBackground()
            List {
                if let profile = store.profile {
                    Section {
                        Button { store.isEditingProfile = true } label: {
                            HStack(spacing: 14) {
                                Text(profile.initials)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(NidoTheme.textOnMoss)
                                    .frame(width: 52, height: 52)
                                    .background(NidoTheme.moss, in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(profile.babyName)
                                        .font(.headline)
                                        .foregroundStyle(NidoTheme.ink)
                                    Text("Con \(profile.caregiverName) · \(ageLabel(profile))")
                                        .font(.subheadline)
                                        .foregroundStyle(NidoTheme.secondaryInk)
                                }
                                Spacer()
                                if isOwner {
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .disabled(!isOwner)
                        .accessibilityIdentifier("settings-profile-button")
                        NavigationLink {
                            GrowthOverviewView()
                        } label: {
                            Label("Crecimiento de \(profile.babyName)", systemImage: "chart.xyaxis.line")
                        }
                        .accessibilityIdentifier("open-baby-growth")
                    }
                }

                Section {
                    ForEach(store.caregivers.sorted { lhs, rhs in
                        if lhs.status != rhs.status { return lhs.status == .active }
                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    }) { caregiver in
                        CaregiverRow(
                            caregiver: caregiver,
                            isCurrent: caregiver.id == store.currentCaregiver?.id,
                            isDemo: !store.allowsExternalEffects,
                            onRemove: isOwner && caregiver.id != store.currentCaregiver?.id
                                ? { caregiverPendingRemoval = caregiver }
                                : nil
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if isOwner && caregiver.id != store.currentCaregiver?.id {
                                Button(role: .destructive) {
                                    caregiverPendingRemoval = caregiver
                                } label: {
                                    Label(caregiver.status == .pending ? "Cancelar" : "Retirar", systemImage: "person.badge.minus")
                                }
                            }
                        }
                    }

                    if isOwner {
                        Button { isInvitingCaregiver = true } label: {
                            Label("Invitar familiar", systemImage: "person.badge.plus")
                        }
                        .accessibilityIdentifier("settings-invite-caregiver")
                    }
                } header: {
                    Text("Familiares")
                } footer: {
                    Text("Solo el administrador del hogar puede gestionar familiares y editar el perfil. Los familiares comparten el mismo historial.")
                }

                Section("Estado") {
                    Label(store.isOffline ? "Sin conexión" : "Actualizado", systemImage: store.isOffline ? "wifi.slash" : "checkmark.icloud.fill")
                        .foregroundStyle(store.isOffline ? NidoTheme.warning : NidoTheme.moss)
                    Button("Actualizar") { Task { await store.refresh() } }
                }

                Section("Recordatorios") {
                    Toggle("Resumen diario a las 20:00", isOn: $dailySummaryReminder)
                        .onChange(of: dailySummaryReminder) { _, enabled in
                            guard store.allowsExternalEffects else {
                                reminderMessage = "Preferencia guardada solo en esta demostración."
                                return
                            }
                            Task {
                                if enabled {
                                    do { try await ReminderManager.enableDailySummary() }
                                    catch { dailySummaryReminder = false; reminderMessage = error.localizedDescription }
                                }
                                else { ReminderManager.disableDailySummary() }
                            }
                        }
                    Toggle("Avisar 3 h después de una toma", isOn: $feedCheckReminder)
                        .onChange(of: feedCheckReminder) { _, enabled in
                            guard store.allowsExternalEffects else {
                                reminderMessage = "Preferencia guardada solo en esta demostración."
                                return
                            }
                            Task {
                                if enabled {
                                    do { _ = try await ReminderManager.requestAccess() }
                                    catch { feedCheckReminder = false; reminderMessage = error.localizedDescription }
                                }
                                else { ReminderManager.disableFeedCheck() }
                            }
                        }
                    if let reminderMessage {
                        Text(reminderMessage).font(.footnote).foregroundStyle(NidoTheme.error)
                    }
                }

                Section {
                    if let reportURL = reportPreparation.url {
                        ShareLink(item: reportURL) {
                            Label("Compartir informe de 30 días", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            guard let profile = store.profile else { return }
                            let entries = store.entries
                            Task {
                                await reportPreparation.prepare {
                                    try await PediatricReport.prepare(profile: profile, entries: entries)
                                }
                            }
                        } label: {
                            if reportPreparation.isPreparing {
                                ProgressView("Preparando informe…")
                            } else {
                                Label("Preparar informe de 30 días", systemImage: "doc.text.fill")
                            }
                        }
                        .disabled(reportPreparation.isPreparing)
                    }
                    Button {
                        isImportingBackup = true
                    } label: {
                        Label("Restaurar desde un archivo", systemImage: "arrow.clockwise.icloud")
                    }
                    if let backupError {
                        Text(backupError).font(.footnote).foregroundStyle(NidoTheme.error)
                    }
                    if let reportError = reportPreparation.errorMessage {
                        Text(reportError).foregroundStyle(NidoTheme.error)
                    }
                } header: {
                    Text("Pediatra")
                } footer: {
                    Text("Genera un resumen de los últimos 30 días para la consulta.")
                }

                Section {
                    if let backupURL {
                        ShareLink(item: backupURL) {
                            Label("Compartir copia completa", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            backupURL = try? NidoBackup.make(profile: store.profile, caregivers: store.caregivers, entries: store.entries, babyCareState: store.babyCareState)
                        } label: {
                            Label("Preparar copia de seguridad", systemImage: "externaldrive.fill")
                        }
                    }
                } header: {
                    Text("Tus datos")
                } footer: {
                    Text("Exporta una copia del perfil, los familiares y los registros.")
                }

                Section("Privacidad") {
                    Label("Sin publicidad ni seguimiento", systemImage: "hand.raised.fill")
                    Label("Acceso solo para familiares invitados", systemImage: "lock.shield.fill")
                    Link("Política de privacidad", destination: URL(string: "https://nido.momentumia.com/api/nido/legal/privacy")!)
                        .accessibilityIdentifier("privacy-policy-link")
                    Link("Ayuda y contacto", destination: URL(string: "https://nido.momentumia.com/api/nido/legal/support")!)
                        .accessibilityIdentifier("support-link")
                }

                Section("Cuenta") {
                    if store.allowsExternalEffects {
                        Button("Cerrar sesión") {
                            Task { await store.signOut() }
                        }
                        AccountDeletionEntryPoint(style: .settings)
                    } else {
                        Button("Salir de la demostración") {
                            demoCoordinator.exit()
                        }
                        .disabled(demoCoordinator.isTransitioning)
                    }
                }

                Section {
                    HStack {
                        Text("Versión")
                        Spacer()
                        Text(AppVersion.current?.displayString ?? "No disponible")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("app-version-value")
                    }
                } footer: {
                    Text("Nido acompaña el cuidado diario, pero no sustituye el consejo de un profesional sanitario.")
                }
            }
            .contentMargins(.bottom, floatingNavigationClearance, for: .scrollContent)
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("settings-list")
        }
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            guard store.allowsExternalEffects else { return }
            let hasEnabledReminder = dailySummaryReminder || feedCheckReminder
            guard hasEnabledReminder else { return }

            let isAuthorized = await ReminderManager.isAuthorized()
            if !isAuthorized {
                dailySummaryReminder = false
                feedCheckReminder = false
                reminderMessage = "Las notificaciones están desactivadas en los Ajustes del iPhone."
            }
        }
        .fileImporter(isPresented: $isImportingBackup, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { throw CocoaError(.fileNoSuchFile) }
                let hasAccess = url.startAccessingSecurityScopedResource()
                defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
                pendingBackup = try NidoBackup.load(from: url)
            } catch {
                backupError = "No hemos podido leer esta copia."
            }
        }
        .alert(
            "¿Restaurar esta copia?",
            isPresented: Binding(
                get: { pendingBackup != nil },
                set: { if !$0 { pendingBackup = nil } }
            )
        ) {
            Button("Restaurar registros") {
                guard let backup = pendingBackup else { return }
                pendingBackup = nil
                Task { await store.restoreBackup(backup) }
            }
            Button("Cancelar", role: .cancel) { pendingBackup = nil }
        } message: {
            Text("Se añadirán únicamente los registros que todavía no existan. Los actuales no se sobrescribirán.")
        }
        .alert(
            caregiverRemovalTitle,
            isPresented: Binding(
                get: { caregiverPendingRemoval != nil },
                set: { if !$0 { caregiverPendingRemoval = nil } }
            )
        ) {
            if let caregiver = caregiverPendingRemoval {
                Button(caregiver.status == .pending ? "Cancelar invitación" : "Retirar acceso", role: .destructive) {
                    caregiverPendingRemoval = nil
                    Task { await store.removeCaregiver(caregiver) }
                }
            }
            Button("Cancelar", role: .cancel) { caregiverPendingRemoval = nil }
        } message: {
            if let caregiver = caregiverPendingRemoval {
                Text(caregiver.status == .pending
                    ? "La invitación de \(caregiver.name) dejará de ser válida."
                    : "\(caregiver.name) dejará de poder consultar y registrar información en Nido.")
            }
        }
        .sheet(isPresented: $isInvitingCaregiver) {
            InviteCaregiverView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onDisappear {
            reportPreparation.reset()
            removeGeneratedFile(backupURL)
            backupURL = nil
        }
    }

    private func ageLabel(_ profile: Profile) -> String {
        let months = NidoMetrics.ageInMonths(birthDate: profile.birthDate)
        return months == 0 ? "Recién nacido" : "\(months) \(months == 1 ? "mes" : "meses")"
    }

    private var caregiverRemovalTitle: String {
        guard let caregiver = caregiverPendingRemoval else { return "Gestionar familiar" }
        return caregiver.status == .pending
            ? "¿Cancelar la invitación de \(caregiver.name)?"
            : "¿Retirar el acceso de \(caregiver.name)?"
    }

    private func removeGeneratedFile(_ url: URL?) {
        guard let url, url.isFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

private struct CaregiverRow: View {
    let caregiver: Caregiver
    let isCurrent: Bool
    let isDemo: Bool
    let onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 13) {
            Text(caregiver.initials)
                .font(.caption.weight(.bold))
                .foregroundStyle(caregiver.status == .active ? NidoTheme.textOnMoss : NidoTheme.secondaryInk)
                .frame(width: 38, height: 38)
                .background(
                    caregiver.status == .active ? NidoTheme.moss : NidoTheme.secondaryInk.opacity(0.12),
                    in: Circle()
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(caregiver.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(NidoTheme.ink)
                Text(caregiver.status == .active ? caregiver.role.displayName : "Invitación pendiente")
                    .font(.caption)
                    .foregroundStyle(NidoTheme.secondaryInk)
            }
            Spacer()
            if isCurrent {
                Text("Tú")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NidoTheme.moss)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(NidoTheme.moss.opacity(0.1), in: Capsule())
            } else if caregiver.status == .pending, let invitationText = caregiver.invitationText {
                let shareText = isDemo
                    ? "Código ficticio de demostración: solo funciona dentro de esta demostración de Nido.\n\n\(invitationText)"
                    : invitationText
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(NidoTheme.moss)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Volver a compartir la invitación de \(caregiver.name)")
            }
            if let onRemove {
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "person.badge.minus")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    caregiver.status == .pending
                        ? "Cancelar invitación de \(caregiver.name)"
                        : "Retirar a \(caregiver.name)"
                )
            }
        }
        .accessibilityIdentifier("caregiver-row-\(caregiver.id)")
    }
}

private struct InviteCaregiverView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var invitation: Caregiver?
    @State private var isCreating = false
    @State private var errorMessage: String?
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                Form {
                    if let invitation, let invitationText = invitation.invitationText {
                        Section {
                            VStack(spacing: 15) {
                                Image(systemName: "person.2.badge.plus.fill")
                                    .font(.system(size: 34, weight: .semibold))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(NidoTheme.moss)
                                Text("Invitación para \(invitation.name)")
                                    .font(.headline)
                                Text(invitation.inviteCode ?? "")
                                    .font(.system(.title, design: .monospaced, weight: .semibold))
                                    .tracking(2)
                                    .foregroundStyle(NidoTheme.ink)
                                Text("El código se puede utilizar una sola vez.")
                                    .font(.footnote)
                                    .foregroundStyle(NidoTheme.secondaryInk)
                                if !store.allowsExternalEffects {
                                    Text("Código ficticio: solo funciona dentro de esta demostración.")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(NidoTheme.secondaryInk)
                                        .accessibilityIdentifier("demo-invitation-notice")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }

                        Section {
                            ShareLink(item: store.allowsExternalEffects
                                ? invitationText
                                : invitationText + "\n\nCódigo ficticio: solo funciona dentro de la demostración de Nido.") {
                                Label("Compartir invitación", systemImage: "square.and.arrow.up")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    } else {
                        Section {
                            TextField("Nombre del familiar", text: $name)
                                .textContentType(.name)
                                .textInputAutocapitalization(.words)
                                .focused($isNameFocused)
                        } header: {
                            Text("¿A quién quieres invitar?")
                        } footer: {
                            Text("Crearemos un código de invitación para compartir.")
                        }

                        if let errorMessage {
                            Section {
                                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                                    .foregroundStyle(NidoTheme.error)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(invitation == nil ? "Invitar familiar" : "Invitación lista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(invitation == nil ? "Cancelar" : "Cerrar") { dismiss() }
                }
                if invitation == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Crear") {
                            isNameFocused = false
                            isCreating = true
                            errorMessage = nil
                            Task {
                                do {
                                    invitation = try await store.inviteCaregiver(name: name)
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                                isCreating = false
                            }
                        }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                    }
                }
            }
        }
        .tint(NidoTheme.moss)
        .onAppear { isNameFocused = true }
    }
}

struct ProfileEditorView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var caregiverName = ""
    @State private var babyName = ""
    @State private var birthDate = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section("Familia") {
                    TextField("Tu nombre", text: $caregiverName)
                        .textContentType(.name)
                    TextField("Nombre del bebé", text: $babyName)
                    DatePicker("Fecha de nacimiento", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
                }
            }
            .navigationTitle("Editar perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            await store.saveProfile(Profile(
                                caregiverName: caregiverName,
                                babyName: babyName,
                                birthDate: birthDate.formatted(.iso8601.year().month().day())
                            ))
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(caregiverName.isEmpty || babyName.isEmpty)
                }
            }
            .onAppear {
                guard let profile = store.profile else { return }
                caregiverName = profile.caregiverName
                babyName = profile.babyName
                birthDate = ISO8601DateFormatter.nidoDay.date(from: profile.birthDate) ?? .now
            }
        }
        .tint(NidoTheme.moss)
    }
}

extension ISO8601DateFormatter {
    static let nidoDay: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
}
