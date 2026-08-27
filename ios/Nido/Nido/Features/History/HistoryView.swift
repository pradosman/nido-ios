import SwiftUI

struct HistoryView: View {
    @Environment(NidoStore.self) private var store
    @State private var filter: EntryKind?

    private var filteredEntries: [Entry] {
        guard let filter else { return store.entries }
        return store.entries.filter { $0.kind == filter }
    }

    private var sections: [(date: Date, entries: [Entry])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredEntries) { calendar.startOfDay(for: $0.date) }
        return groups.map { ($0.key, $0.value.sorted { $0.occurredAt > $1.occurredAt }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(alignment: .leading, pinnedViews: [.sectionHeaders]) {
                    filterBar
                        .padding(.bottom, 18)

                    if sections.isEmpty {
                        ContentUnavailableView(
                            "Todavía no hay historia",
                            systemImage: "book.closed",
                            description: Text("Los registros aparecerán aquí ordenados por día.")
                        )
                        .foregroundStyle(NidoTheme.secondaryInk)
                        .padding(.top, 80)
                    } else {
                        ForEach(sections, id: \.date) { section in
                            Section {
                                VStack(spacing: 0) {
                                    ForEach(section.entries) { entry in
                                        Button { store.editingEntry = entry } label: {
                                            HistoryRow(entry: entry)
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button { store.editingEntry = entry } label: { Label("Editar", systemImage: "pencil") }
                                            Button(role: .destructive) { Task { await store.deleteEntry(entry) } } label: { Label("Eliminar", systemImage: "trash") }
                                        }
                                        if entry.id != section.entries.last?.id {
                                            Divider().padding(.leading, 54)
                                        }
                                    }
                                }
                                .padding(.horizontal, 14)
                                .paperCard()
                                .padding(.bottom, 24)
                            } header: {
                                Text(section.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                    .font(.system(.headline, design: .serif))
                                    .foregroundStyle(NidoTheme.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .background(NidoTheme.paper.opacity(0.92))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .refreshable { await store.refresh() }
        }
        .navigationTitle("Historia")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
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

    private func filterButton(title: String, kind: EntryKind?) -> some View {
        let isSelected = filter == kind
        return Button { withAnimation(.snappy(duration: 0.16, extraBounce: 0)) { filter = kind } } label: {
            HStack(spacing: 6) {
                if let kind {
                    Image(systemName: kind.symbolName)
                        .symbolRenderingMode(.hierarchical)
                }
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? .white : NidoTheme.secondaryInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? NidoTheme.moss : .white.opacity(0.52), in: Capsule())
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

private struct HistoryRow: View {
    let entry: Entry

    var body: some View {
        HStack(spacing: 10) {
            EntryGlyph(kind: entry.kind, size: 19)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title).font(.headline)
                if !entry.summary.isEmpty {
                    Text(entry.summary)
                        .font(.subheadline)
                        .foregroundStyle(NidoTheme.secondaryInk)
                }
                if let caregiverName = entry.caregiverName {
                    Label("Registrado por \(caregiverName)", systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(NidoTheme.secondaryInk.opacity(0.82))
                }
            }
            Spacer()
            Text(entry.date.formatted(date: .omitted, time: .shortened))
                .font(.caption.monospacedDigit())
                .foregroundStyle(NidoTheme.secondaryInk)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityHint("Toca para editar este registro")
    }
}
