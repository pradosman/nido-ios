import SwiftUI

struct EvolutionLiveSummaryView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.calendar) private var environmentCalendar
    @Environment(\.timeZone) private var environmentTimeZone
    @Environment(\.locale) private var locale
    @Environment(\.floatingNavigationClearance) private var floatingNavigationClearance
    @State private var pinnedPreferences = EvolutionPinnedPreferences()
    @State private var isShowingAllMetrics = false
    @State private var syncStatus = EvolutionSyncStatus(
        isLoading: true,
        hasRecords: false,
        isOffline: false,
        hasPendingChanges: false
    )

    private var calendar: Calendar {
        var calendar = BabyCareMetrics.calendar(for: store.babyCareState)
        calendar.locale = locale
        calendar.firstWeekday = environmentCalendar.firstWeekday
        calendar.minimumDaysInFirstWeek = environmentCalendar.minimumDaysInFirstWeek
        if TimeZone(identifier: store.babyCareState.timeZoneID) == nil {
            calendar.timeZone = environmentTimeZone
        }
        return calendar
    }

    private var summary: EvolutionSummary {
        EvolutionSummary.build(
            entries: store.entries,
            measurements: BabyCareReconciliation.mergedMeasurements(state: store.babyCareState, entries: store.entries),
            now: store.now,
            calendar: calendar
        )
    }

    private var hasEvolutionRecords: Bool {
        summary.metrics.contains { $0.daysWithRecords > 0 || $0.latestValue != nil }
    }

    private var syncStatusTaskID: String {
        "\(store.evolutionSyncRefreshKey)|\(hasEvolutionRecords)"
    }

    @ViewBuilder
    private var syncStatusRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            if syncStatus.availability == .loading {
                syncStatusLabel("Cargando datos", systemImage: "arrow.clockwise", identifier: "evolution-loading-status")
            }
            if syncStatus.availability == .noRecords {
                syncStatusLabel("Aún no hay registros guardados", systemImage: "tray", identifier: "evolution-no-records-status")
            }
            if syncStatus.isOffline {
                syncStatusLabel("Sin conexión. Datos guardados.", systemImage: "wifi.slash", identifier: "evolution-offline-status")
            }
            if syncStatus.hasPendingChanges {
                syncStatusLabel("Cambios pendientes de sincronización", systemImage: "arrow.triangle.2.circlepath", identifier: "evolution-pending-status")
            }
        }
        .font(.footnote)
        .foregroundStyle(NidoTheme.ink)
    }

    private var visibleMetrics: [EvolutionMetricSnapshot] {
        if isShowingAllMetrics { return summary.metrics }
        let snapshots = Dictionary(uniqueKeysWithValues: summary.metrics.map { ($0.metric, $0) })
        return pinnedPreferences.pinnedMetrics.compactMap { snapshots[$0] }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(isShowingAllMetrics ? "Todos los datos" : "Datos fijados")
                                .font(.title3.bold())
                                .foregroundStyle(NidoTheme.ink)
                            Spacer(minLength: 12)
                            Button("Editar") { store.isEditingEvolutionPins = true }
                                .font(.body)
                                .foregroundStyle(NidoTheme.moss)
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("evolution-edit")
                        }
                        .padding(.horizontal, 4)

                        syncStatusRow

                        if visibleMetrics.isEmpty {
                            ContentUnavailableView(
                                "No hay datos fijados",
                                systemImage: "pin.slash",
                                description: Text("Elige datos para verlos aquí.")
                            )
                            .accessibilityIdentifier("evolution-empty-pins")
                        }

                        ForEach(visibleMetrics, id: \.metric) { snapshot in
                            NavigationLink {
                                destination(snapshot.metric)
                            } label: {
                                metricCard(snapshot)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("evolution-card-\(snapshot.metric.rawValue)")
                        }

                        if !isShowingAllMetrics {
                            Button("Ver todos los datos") { isShowingAllMetrics = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(NidoTheme.moss)
                                .frame(minHeight: 44)
                                .accessibilityIdentifier("evolution-all-data")
                        } else {
                            Button("Volver a datos fijados") { isShowingAllMetrics = false }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(NidoTheme.moss)
                                .frame(minHeight: 44)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 20)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .contentMargins(.bottom, floatingNavigationClearance, for: .scrollContent)
        }
        .navigationTitle("Evolución")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.automatic, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.selectedTab = .settings } label: {
                    Text(caregiverMonogram)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(NidoTheme.moss)
                        .frame(width: 44, height: 44)
                        .background(NidoTheme.surface, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ajustes de \(store.currentCaregiver?.name ?? "cuidador")")
                .accessibilityIdentifier("evolution-account")
            }
        }
        .accessibilityIdentifier("evolution-summary-live")
        .onAppear { pinnedPreferences = store.evolutionPinnedPreferences }
        .task(id: syncStatusTaskID) {
            let requestKey = syncStatusTaskID
            let refreshedStatus = await store.evolutionSyncStatus(hasRecords: hasEvolutionRecords)
            guard !Task.isCancelled, requestKey == syncStatusTaskID else { return }
            syncStatus = refreshedStatus
        }
        .onChange(of: store.evolutionPreferenceScope) { _, _ in
            pinnedPreferences = store.evolutionPinnedPreferences
        }
        .onChange(of: store.evolutionPreferencesRevision) { _, _ in
            pinnedPreferences = store.evolutionPinnedPreferences
        }
    }

    @ViewBuilder
    private func destination(_ metric: EvolutionMetric) -> some View {
        switch metric {
        case .sleep, .feeds, .diapers:
            EvolutionCareDetailView(metric: metric)
        case .weight:
            GrowthSeriesDetailView(metric: .weight)
        case .height:
            GrowthSeriesDetailView(metric: .height)
        }
    }

    private func metricCard(_ snapshot: EvolutionMetricSnapshot) -> some View {
        EvolutionMetricCard(snapshot: snapshot, calendar: calendar)
    }

    private func syncStatusLabel(_ title: String, systemImage: String, identifier: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(NidoTheme.ink)
            .accessibilityIdentifier(identifier)
    }

    private var caregiverMonogram: String {
        let name = store.currentCaregiver?.name ?? "C"
        let initials = name.split(whereSeparator: \.isWhitespace).prefix(2).compactMap { $0.first }
        return initials.isEmpty ? "C" : initials.map { String($0) }.joined().uppercased()
    }
}
