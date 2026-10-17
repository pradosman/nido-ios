import SwiftUI

struct EntryEditorView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let entry: Entry

    @State private var date: Date
    @State private var detail: String
    @State private var legacyDetail: String
    @State private var usesLegacyDetail: Bool
    @State private var durationMinutes: Int
    @State private var sleepStart: Date
    @State private var sleepEnd: Date
    @State private var amountMl: Int
    @State private var feedType: FeedType
    @State private var breastSide: BreastSide
    @State private var milkType: String
    @State private var diaperContents: DiaperContents
    @State private var careActivity: CareActivity?
    @State private var temperatureCelsius: Double
    @State private var medicationName: String
    @State private var medicationDose: String
    @State private var weightKilograms: Double
    @State private var heightCentimeters: Double
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var initialDraft: Entry?
    @State private var isConfirmingDiscard = false

    init(entry: Entry) {
        self.entry = entry
        _date = State(initialValue: entry.date)
        _durationMinutes = State(initialValue: entry.durationMinutes ?? 15)
        _sleepEnd = State(initialValue: entry.date)
        _sleepStart = State(initialValue: entry.date.addingTimeInterval(TimeInterval(-(entry.durationMinutes ?? 15) * 60)))
        _amountMl = State(initialValue: entry.amountMl ?? 90)
        _feedType = State(initialValue: .bottle)
        _breastSide = State(initialValue: .left)
        _milkType = State(initialValue: "Leche materna")
        _diaperContents = State(initialValue: [])
        _careActivity = State(initialValue: nil)
        _temperatureCelsius = State(initialValue: 36.5)
        _medicationName = State(initialValue: "")
        _medicationDose = State(initialValue: "")
        _weightKilograms = State(initialValue: 4)
        _heightCentimeters = State(initialValue: 52)
        _legacyDetail = State(initialValue: entry.detail)

        var initialDetail = entry.kind == .sleep ? SleepInterval.note(from: entry.detail) : ""
        var isLegacy = false
        switch entry.kind {
        case .sleep:
            break
        case .feed:
            if let parsed = FeedEntryDetails.parse(entry.detail) {
                _feedType = State(initialValue: parsed.type)
                _breastSide = State(initialValue: parsed.breastSide)
                _milkType = State(initialValue: parsed.milkType)
                initialDetail = parsed.note
            } else {
                isLegacy = true
            }
        case .diaper:
            if let parsed = DiaperEntryDetails.parse(entry.detail) {
                _diaperContents = State(initialValue: parsed.contents)
                initialDetail = parsed.note
            } else {
                isLegacy = true
            }
        case .health:
            if let parsed = CareEntryDetails.parse(entry.detail) {
                _careActivity = State(initialValue: parsed.activity)
                _temperatureCelsius = State(initialValue: parsed.temperatureCelsius)
                _medicationName = State(initialValue: parsed.medicationName)
                _medicationDose = State(initialValue: parsed.medicationDose)
                _weightKilograms = State(initialValue: parsed.weightKilograms)
                _heightCentimeters = State(initialValue: parsed.heightCentimeters)
                initialDetail = parsed.note
            } else {
                isLegacy = true
            }
        }
        _detail = State(initialValue: initialDetail)
        _usesLegacyDetail = State(initialValue: isLegacy)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.primary)
                            .accessibilityIdentifier("entry-editor-save-error")
                    }
                }
                Section {
                    HStack(spacing: 12) {
                        EntryGlyph(kind: entry.kind, size: 24)
                        Text(entry.title).font(.headline)
                    }
                }

                if entry.kind != .sleep {
                    Section("Momento") {
                        DatePicker("Fecha y hora", selection: $date, in: ...store.now)
                    }
                }

                switch entry.kind {
                case .sleep:
                    sleepFields
                case .feed:
                    feedFields
                case .diaper:
                    diaperFields
                case .health:
                    careFields
                }

                if usesLegacyDetail {
                    Section {
                        TextField("Detalle del registro", text: $legacyDetail, axis: .vertical)
                            .lineLimit(2...6)
                    } header: {
                        Text("Detalle original")
                    } footer: {
                        Text("Se conserva sin cambios hasta que selecciones nuevos campos semánticos.")
                    }
                }
            }
            .disabled(isSaving)
            .scrollContentBackground(.hidden)
            .background(PaperBackground())
            .navigationTitle("Editar registro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        if hasChanges {
                            isConfirmingDiscard = true
                        } else {
                            dismiss()
                        }
                    }
                        .disabled(isSaving)
                        .confirmationDialog("¿Descartar los cambios?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
                            Button("Descartar cambios", role: .destructive) { dismiss() }
                            Button("Seguir editando") { isConfirmingDiscard = false }
                        }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        .tint(NidoTheme.moss)
        .interactiveDismissDisabled(hasChanges || isSaving)
        .onAppear {
            if initialDraft == nil { initialDraft = entryToSave }
        }
    }

    private var canSave: Bool {
        guard !isSaving else { return false }
        if entry.kind == .sleep { return sleepInterval != nil }
        if usesLegacyDetail { return !legacyDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if entry.kind == .feed, feedType == .solids {
            return !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if entry.kind == .diaper { return !diaperContents.isEmpty }
        guard entry.kind == .health else { return true }
        guard let careActivity else { return false }
        return switch careActivity {
        case .medication: !medicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .symptom, .other: !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .bath, .temperature, .measurements: true
        }
    }

    @ViewBuilder
    private var sleepFields: some View {
        Section {
            DatePicker("Desde", selection: $sleepStart, in: ...sleepEnd)
            DatePicker("Hasta", selection: $sleepEnd, in: sleepStart...store.now)
        } header: {
            Text("Horario")
        } footer: {
            if let sleepInterval {
                Text("Duración: \(sleepInterval.durationLabel)")
            } else {
                Text("La fecha de finalización debe ser posterior a la de inicio.")
            }
        }
        noteField("Nota opcional", placeholder: "Añadir una nota")
    }

    @ViewBuilder
    private var feedFields: some View {
        Section("Tipo de toma") {
            Picker("Tipo", selection: $feedType) {
                ForEach(FeedType.allCases) { type in
                    Label(type.title, systemImage: type.symbolName).tag(type)
                }
            }
        }
        .onChange(of: feedType) { _, _ in usesLegacyDetail = false }

        switch feedType {
        case .nursing:
            Section("Lactancia") {
                Picker("Pecho", selection: $breastSide) {
                    ForEach(BreastSide.allCases) { side in Text(side.title).tag(side) }
                }
                .pickerStyle(.segmented)
                NidoDurationInput(title: "Duración", totalMinutes: $durationMinutes, range: 1...180)
            }
            .onChange(of: breastSide) { _, _ in usesLegacyDetail = false }
            noteField("Nota opcional", placeholder: "Agarre, reacción…")
        case .bottle:
            Section("Biberón") {
                Picker("Contenido", selection: $milkType) {
                    Text("Leche materna").tag("Leche materna")
                    Text("Fórmula").tag("Fórmula")
                }
                .accessibilityIdentifier("entry-editor-feed-content-picker")
                NidoIntegerInput(title: "Cantidad", unit: "ml", value: $amountMl, range: 0...400, step: 10)
            }
            .onChange(of: milkType) { _, _ in usesLegacyDetail = false }
            noteField("Nota opcional", placeholder: "Cómo ha ido la toma…")
        case .pumping:
            Section("Extracción") {
                NidoIntegerInput(title: "Cantidad", unit: "ml", value: $amountMl, range: 0...500, step: 10)
                NidoDurationInput(title: "Duración", totalMinutes: $durationMinutes, range: 1...120)
            }
            noteField("Nota opcional", placeholder: "Un pecho o ambos…")
        case .solids:
            noteField("Alimento", placeholder: "Qué ha comido")
        }
    }

    @ViewBuilder
    private var diaperFields: some View {
        Section {
            HStack(spacing: 12) {
                semanticChoice("Pis", isSelected: diaperContents.contains(.urine)) {
                    diaperContents.formSymmetricDifference(.urine)
                    usesLegacyDetail = false
                }
                semanticChoice("Caca", isSelected: diaperContents.contains(.stool)) {
                    diaperContents.formSymmetricDifference(.stool)
                    usesLegacyDetail = false
                }
            }
        } header: {
            Text("¿Qué había en el pañal?")
        } footer: {
            Text("Selecciona una o ambas opciones.")
        }
        noteField("Nota opcional", placeholder: "Color, consistencia…")
    }

    @ViewBuilder
    private var careFields: some View {
        Section("¿Qué quieres registrar?") {
            ForEach(CareActivity.allCases) { activity in
                semanticChoice(activity.title, isSelected: careActivity == activity) {
                    careActivity = activity
                    usesLegacyDetail = false
                }
            }
        }

        switch careActivity {
        case .bath:
            noteField("Nota opcional", placeholder: "Productos, reacción de la piel…")
        case .temperature:
            Section("Temperatura") {
                Stepper(value: $temperatureCelsius, in: 34...42, step: 0.1) {
                    LabeledContent("Medición", value: temperatureCelsius.formatted(.number.precision(.fractionLength(1))) + " °C")
                }
            }
            noteField("Nota opcional", placeholder: "Dónde se tomó, observaciones…")
        case .medication:
            Section("Medicación") {
                TextField("Nombre del medicamento", text: $medicationName)
                TextField("Dosis, si la conoces", text: $medicationDose)
            }
            noteField("Nota opcional", placeholder: "Motivo u observaciones…")
        case .symptom:
            noteField("¿Qué has observado?", placeholder: "Describe el síntoma")
        case .measurements:
            Section("Crecimiento") {
                Stepper(value: $weightKilograms, in: 1.5...30, step: 0.1) {
                    LabeledContent("Peso", value: weightKilograms.formatted(.number.precision(.fractionLength(1))) + " kg")
                }
                Stepper(value: $heightCentimeters, in: 35...120, step: 0.5) {
                    LabeledContent("Altura", value: heightCentimeters.formatted(.number.precision(.fractionLength(1))) + " cm")
                }
            }
            noteField("Nota opcional", placeholder: "Perímetro craneal u observaciones…")
        case .other:
            noteField("¿Qué ha ocurrido?", placeholder: "Añade un detalle")
        case nil:
            EmptyView()
        }
    }

    private func noteField(_ title: String, placeholder: String) -> some View {
        Section(title) {
            TextField(placeholder, text: $detail, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    private func semanticChoice(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if isSelected { Image(systemName: "checkmark") }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var sleepInterval: SleepInterval? {
        SleepInterval.validated(start: sleepStart, end: sleepEnd, notAfter: store.now)
    }

    private var savedDetail: String {
        if entry.kind == .sleep {
            return sleepInterval?.detail(note: detail) ?? detail
        }
        let semanticDetail: String? = if usesLegacyDetail {
            nil
        } else {
            switch entry.kind {
            case .feed:
                FeedEntryDetails(
                    type: feedType,
                    breastSide: breastSide,
                    milkType: milkType,
                    note: detail
                ).formatted
            case .diaper:
                DiaperEntryDetails(contents: diaperContents, note: detail).formatted
            case .health:
                careActivity.map {
                    CareEntryDetails(
                        activity: $0,
                        note: detail,
                        temperatureCelsius: temperatureCelsius,
                        medicationName: medicationName,
                        medicationDose: medicationDose,
                        weightKilograms: weightKilograms,
                        heightCentimeters: heightCentimeters
                    ).formatted
                } ?? legacyDetail
            case .sleep:
                detail
            }
        }
        return EntryDetailPersistence.preserved(legacyDetail, semanticDetail: semanticDetail)
    }

    private var hasChanges: Bool {
        initialDraft.map { entryToSave != $0 } ?? false
    }

    private var entryToSave: Entry {
        let savedDate = EntryMoment.resolve(
            kind: entry.kind,
            selectedDate: date,
            sleepInterval: sleepInterval
        )
        let savedDuration: Int? = switch entry.kind {
        case .sleep: sleepInterval?.durationMinutes
        case .feed: feedType == .nursing || feedType == .pumping ? durationMinutes : nil
        case .diaper, .health: nil
        }
        let savedAmount = entry.kind == .feed && (feedType == .bottle || feedType == .pumping) && amountMl > 0
            ? amountMl
            : nil
        return entry.edited(
            detail: savedDetail,
            occurredAt: savedDate,
            durationMinutes: savedDuration,
            amountMl: savedAmount
        )
    }

    private func save() {
        guard canSave else { return }
        let updated = entryToSave
        isSaving = true
        saveError = nil
        Task {
            let saved = await store.updateEntry(updated)
            isSaving = false
            if saved {
                dismiss()
            } else {
                saveError = "No se han podido guardar los cambios. Tu borrador sigue aquí; vuelve a intentarlo."
            }
        }
    }
}
