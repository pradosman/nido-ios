import SwiftUI

struct GrowthMeasurementEditorView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var environmentCalendar
    @Environment(\.timeZone) private var environmentTimeZone
    @Environment(\.locale) private var locale

    let existing: GrowthMeasurement?

    @State private var measuredAt: Date
    @State private var weightText: String
    @State private var heightText: String
    @State private var note: String
    @State private var isSaving = false
    @State private var saveError: String?

    init(existing: GrowthMeasurement?) {
        self.existing = existing
        _measuredAt = State(initialValue: existing.map { Date(timeIntervalSince1970: Double($0.measuredAt) / 1_000) } ?? .now)
        _weightText = State(initialValue: existing?.weightGrams.map { Self.numberText(Double($0) / 1_000) } ?? "")
        _heightText = State(initialValue: existing?.heightMillimeters.map { Self.numberText(Double($0) / 10) } ?? "")
        _note = State(initialValue: existing?.note ?? "")
    }

    private var parsedWeightGrams: Int? {
        GrowthInput.weightGrams(from: weightText, locale: locale)
    }

    private var parsedHeightMillimeters: Int? {
        GrowthInput.heightMillimeters(from: heightText, locale: locale)
    }

    private var familyCalendar: Calendar {
        var calendar = BabyCareMetrics.calendar(for: store.babyCareState)
        calendar.locale = locale
        calendar.firstWeekday = environmentCalendar.firstWeekday
        calendar.minimumDaysInFirstWeek = environmentCalendar.minimumDaysInFirstWeek
        if TimeZone(identifier: store.babyCareState.timeZoneID) == nil {
            calendar.timeZone = environmentTimeZone
        }
        return calendar
    }

    private var canSave: Bool {
        let hasWeightText = !weightText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasHeightText = !heightText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard (!hasWeightText || parsedWeightGrams != nil),
              (!hasHeightText || parsedHeightMillimeters != nil)
        else { return false }
        guard parsedWeightGrams != nil || parsedHeightMillimeters != nil else { return false }
        return note.count <= 500
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medición") {
                    DatePicker("Fecha y hora", selection: $measuredAt, in: ...store.now)
                        .environment(\.calendar, familyCalendar)
                        .environment(\.timeZone, familyCalendar.timeZone)
                        .accessibilityIdentifier("growth.measurement.date")
                    measurementField(title: "Peso", text: $weightText, unit: "kg", id: "growth.measurement.weight")
                    if invalidWeight {
                        Text("Introduce un peso válido en kg.")
                            .font(.footnote)
                            .foregroundStyle(NidoTheme.error)
                    }
                    measurementField(title: "Talla", text: $heightText, unit: "cm", id: "growth.measurement.height")
                    if invalidHeight {
                        Text("Introduce una talla válida en cm.")
                            .font(.footnote)
                            .foregroundStyle(NidoTheme.error)
                    }
                }

                Section("Nota") {
                    TextField("Añade una nota (opcional)", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("growth.measurement.note")
                }

                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(NidoTheme.error)
                            .accessibilityIdentifier("growth.measurement.saveError")
                    }
                }

                if store.babyCareNeedsSync || store.babyCareHasConflict || store.babyCareError != nil {
                    Section {
                        GrowthSyncStatus(store: store)
                    }
                }
            }
            .onAppear {
                if existing == nil { measuredAt = store.now }
            }
            .navigationTitle(existing == nil ? "Añadir medición" : "Editar medición")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existing == nil ? "Añadir" : "Guardar") {
                        Task { await save() }
                    }
                    .disabled(!canSave || isSaving)
                    .accessibilityIdentifier("growth.measurement.save")
                }
            }
            .environment(\.calendar, familyCalendar)
            .environment(\.timeZone, familyCalendar.timeZone)
            .environment(\.locale, locale)
        }
    }

    private func measurementField(title: String, text: Binding<String>, unit: String, id: String) -> some View {
        HStack {
            TextField(title, text: text)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier(id)
            Text(unit).foregroundStyle(NidoTheme.secondaryInk)
        }
    }

    private var invalidWeight: Bool {
        !weightText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parsedWeightGrams == nil
    }

    private var invalidHeight: Bool {
        !heightText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parsedHeightMillimeters == nil
    }

    @MainActor
    private func save() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }

        let measurement = GrowthMeasurement(
            id: existing?.id ?? UUID().uuidString.lowercased(),
            measuredAt: Int64((measuredAt.timeIntervalSince1970 * 1_000).rounded()),
            weightGrams: parsedWeightGrams,
            heightMillimeters: parsedHeightMillimeters,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        if await store.saveGrowthMeasurement(measurement) {
            dismiss()
        } else {
            saveError = store.babyCareError ?? "No se pudo guardar. Revisa la fecha y los valores e inténtalo de nuevo."
        }
    }

    private static func numberText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...3)).locale(.current))
    }

}
