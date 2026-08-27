import SwiftUI

struct EntryEditorView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let entry: Entry

    @State private var date: Date
    @State private var detail: String
    @State private var durationMinutes: Int
    @State private var amountMl: Int
    @State private var isSaving = false

    init(entry: Entry) {
        self.entry = entry
        _date = State(initialValue: entry.date)
        _detail = State(initialValue: entry.detail)
        _durationMinutes = State(initialValue: entry.durationMinutes ?? 15)
        _amountMl = State(initialValue: entry.amountMl ?? 90)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        EntryGlyph(kind: entry.kind, size: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title).font(.headline)
                            Text("Corrige solo lo necesario")
                                .font(.caption)
                                .foregroundStyle(NidoTheme.secondaryInk)
                        }
                    }
                }
                Section("Momento") {
                    DatePicker("Fecha y hora", selection: $date, in: ...Date.now)
                }
                if entry.durationMinutes != nil {
                    Section("Duración") {
                        Stepper("\(durationMinutes) min", value: $durationMinutes, in: 1...720)
                    }
                }
                if entry.amountMl != nil {
                    Section("Cantidad") {
                        Stepper("\(amountMl) ml", value: $amountMl, in: 0...500, step: 5)
                    }
                }
                Section("Detalle") {
                    TextField("Detalle del registro", text: $detail, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PaperBackground())
            .navigationTitle("Editar registro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        isSaving = true
                        let updated = Entry(
                            id: entry.id,
                            kind: entry.kind,
                            title: entry.title,
                            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
                            occurredAt: Int64(date.timeIntervalSince1970 * 1_000),
                            durationMinutes: entry.durationMinutes == nil ? nil : durationMinutes,
                            amountMl: entry.amountMl == nil ? nil : amountMl,
                            caregiverID: entry.caregiverID,
                            caregiverName: entry.caregiverName
                        )
                        Task {
                            await store.updateEntry(updated)
                            isSaving = false
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
        }
    }
}
