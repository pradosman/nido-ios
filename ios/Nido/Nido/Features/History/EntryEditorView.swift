import SwiftUI

struct EntryEditorView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let entry: Entry

    @State private var date: Date
    @State private var detail: String
    @State private var durationMinutes: Int
    @State private var sleepStart: Date
    @State private var sleepEnd: Date
    @State private var amountMl: Int
    @State private var isSaving = false

    init(entry: Entry) {
        self.entry = entry
        _date = State(initialValue: entry.date)
        _detail = State(initialValue: entry.kind == .sleep ? SleepInterval.note(from: entry.detail) : entry.detail)
        _durationMinutes = State(initialValue: entry.durationMinutes ?? 15)
        _sleepEnd = State(initialValue: entry.date)
        _sleepStart = State(initialValue: entry.date.addingTimeInterval(TimeInterval(-(entry.durationMinutes ?? 15) * 60)))
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
                if entry.kind != .sleep {
                    Section("Momento") {
                        DatePicker("Fecha y hora", selection: $date, in: ...Date.now)
                    }
                }
                if entry.kind == .sleep {
                    Section {
                        DatePicker("Desde", selection: $sleepStart, in: ...sleepEnd)
                        DatePicker("Hasta", selection: $sleepEnd, in: sleepStart...Date.now)
                    } header: {
                        Text("Horario")
                    } footer: {
                        if let sleepInterval {
                            Text("Duración: \(sleepInterval.durationLabel)")
                        } else {
                            Text("La fecha de finalización debe ser posterior a la de inicio.")
                        }
                    }
                } else if entry.durationMinutes != nil {
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
                        let savedDate = sleepInterval?.end ?? date
                        let savedDuration = entry.kind == .sleep ? sleepInterval?.durationMinutes : (entry.durationMinutes == nil ? nil : durationMinutes)
                        let savedDetail = entry.kind == .sleep
                            ? sleepInterval?.detail(note: detail) ?? detail
                            : detail.trimmingCharacters(in: .whitespacesAndNewlines)
                        let updated = Entry(
                            id: entry.id,
                            kind: entry.kind,
                            title: entry.title,
                            detail: savedDetail,
                            occurredAt: Int64(savedDate.timeIntervalSince1970 * 1_000),
                            durationMinutes: savedDuration,
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
                    .disabled(isSaving || (entry.kind == .sleep && sleepInterval == nil))
                }
            }
        }
    }

    private var sleepInterval: SleepInterval? {
        SleepInterval.validated(start: sleepStart, end: sleepEnd)
    }
}
