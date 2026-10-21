import SwiftUI

struct EvolutionPinnedEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var orderedMetrics: [EvolutionMetric]
    @State private var selectedMetrics: Set<EvolutionMetric>

    let onSave: (EvolutionPinnedPreferences) -> Void

    init(preferences: EvolutionPinnedPreferences, onSave: @escaping (EvolutionPinnedPreferences) -> Void) {
        let pinned = preferences.pinnedMetrics
        let unpinned = EvolutionMetric.allCases.filter { !pinned.contains($0) }
        _orderedMetrics = State(initialValue: pinned + unpinned)
        _selectedMetrics = State(initialValue: Set(pinned))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(orderedMetrics, id: \.self) { metric in
                        toggleRow(metric)
                    }
                    .onMove { source, destination in
                        orderedMetrics.move(fromOffsets: source, toOffset: destination)
                    }
                } header: {
                    Text("Todos los datos")
                } footer: {
                    Text("Activa los datos que quieras fijar. Puedes ordenar los fijados con Editar.")
                }
            }
            .navigationTitle("Editar datos fijados")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        onSave(EvolutionPinnedPreferences(
                            pinnedMetrics: orderedMetrics.filter { selectedMetrics.contains($0) }
                        ))
                        dismiss()
                    }
                    .accessibilityIdentifier("evolution-pin-done")
                }
            }
        }
        .accessibilityIdentifier("evolution-pinning-editor")
    }

    private func toggleRow(_ metric: EvolutionMetric) -> some View {
        Toggle(title(for: metric), isOn: Binding(
            get: { selectedMetrics.contains(metric) },
            set: { isPinned in
                if isPinned {
                    selectedMetrics.insert(metric)
                } else {
                    selectedMetrics.remove(metric)
                }
            }
        ))
        .accessibilityIdentifier("evolution-pin-\(metric.rawValue)")
    }

    private func title(for metric: EvolutionMetric) -> String {
        switch metric {
        case .sleep: "Sueño"
        case .feeds: "Tomas"
        case .diapers: "Pañales"
        case .weight: "Peso"
        case .height: "Talla"
        }
    }
}
