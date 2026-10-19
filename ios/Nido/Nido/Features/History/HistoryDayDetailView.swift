import SwiftUI

struct HistoryDayDetailView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.calendar) private var calendar
    @Binding var filter: EntryKind?

    let snapshot: HistoryAnalytics.Snapshot
    let isCommitted: Bool
    let availableRingWidth: CGFloat
    let readingAnchor: () -> String
    let onReadingAnchorChange: (String) -> Void

    @State private var selectedBins: [EntryKind: Date] = [:]

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    dayClock(snapshot.day) { kind in
                        guard isCommitted else { return }
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
                            scrollProxy.scrollTo("history-section-\(kind.rawValue)", anchor: .top)
                        }
                    }
                    HistoryDayCharts(snapshot: snapshot, selectedBins: $selectedBins)
                    filterBar
                    records(snapshot.entries)
                        .id("history-records")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .coordinateSpace(name: "history-detail-scroll")
            .accessibilityIdentifier("history-detail-scroll")
            .onPreferenceChange(HistoryVisibleSectionPreferenceKey.self) { positions in
                guard isCommitted else { return }
                let frames = Dictionary(
                    positions.map { ($0.kind, Double($0.minY)...Double($0.maxY)) },
                    uniquingKeysWith: { _, latest in latest }
                )
                onReadingAnchorChange(HistoryPresentation.readingAnchor(for: frames))
            }
            .onAppear {
                // Position an incoming day before it finishes sliding into view.
                scrollProxy.scrollTo(readingAnchor(), anchor: .top)
            }
            .onChange(of: isCommitted) { _, committed in
                guard committed else { return }
                selectedBins = [:]
                scrollProxy.scrollTo(readingAnchor(), anchor: .top)
            }
            .refreshable {
                guard isCommitted else { return }
                await store.refresh()
            }
        }
    }

    private func dayClock(_ day: CircularTimeline.Day, onSelect: @escaping (EntryKind) -> Void) -> some View {
        VStack(spacing: 12) {
            GoalDayPanel(
                date: day.date,
                size: min(availableRingWidth, 294),
                onSelect: onSelect
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("history-goal-rings")
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history-detail-day-\(localDateIdentifier(day.date, calendar: calendar))")
        .id("history-detail-top")
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterButton(title: "Todo", kind: nil)
                ForEach(EntryKind.allCases) { kind in
                    filterButton(title: kind.title, kind: kind)
                }
            }
        }
    }

    private func records(_ dayEntries: [Entry]) -> some View {
        let rows = dayEntries.filter { filter == nil || $0.kind == filter }
        let lastID = rows.last?.id
        let emptyTitle = filter == nil
            ? (store.isOffline ? "Sin registros guardados este día" : "Sin registros este día")
            : (store.isOffline ? "Sin registros guardados de este tipo" : "Sin registros de \(filter?.title.lowercased() ?? "este tipo")")
        let emptyDescription = store.isOffline
            ? "Al volver a conectar comprobaremos si hay más registros."
            : "Los registros guardados para este día aparecerán aquí."
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Registros del día").font(.system(.title3, design: .serif, weight: .semibold))
                Spacer()
                Text("\(rows.count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(NidoTheme.secondaryInk)
            }
            if rows.isEmpty {
                ContentUnavailableView(emptyTitle, systemImage: "book.closed", description: Text(emptyDescription))
                    .foregroundStyle(NidoTheme.secondaryInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 38)
                    .paperCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(rows) { entry in
                        Button {
                            guard isCommitted else { return }
                            store.editingEntry = entry
                        } label: {
                            HistoryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("history-entry-\(entry.id)")
                        .contextMenu {
                            Button {
                                guard isCommitted else { return }
                                store.editingEntry = entry
                            } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                guard isCommitted else { return }
                                Task { await store.deleteEntry(entry) }
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                        if entry.id != lastID {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .paperCard()
            }
        }
    }

    private func filterButton(title: String, kind: EntryKind?) -> some View {
        HistoryFilterButton(title: title, kind: kind, isSelected: filter == kind) {
            guard isCommitted else { return }
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.16, extraBounce: 0)) {
                filter = kind
            }
        }
    }
}
