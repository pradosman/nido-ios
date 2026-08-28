import SwiftUI

struct EntrySheet: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let kind: EntryKind

    @State private var date = Date.now
    @State private var detail = ""
    @State private var amountMl = 90
    @State private var durationMinutes = 45
    @State private var feedDurationMinutes = 15
    @State private var feedType = FeedType.bottle
    @State private var breastSide = BreastSide.left
    @State private var milkType = "Leche materna"
    @State private var diaperContents: DiaperContents = []
    @State private var careActivity: CareActivity?
    @State private var temperatureCelsius = 36.5
    @State private var medicationName = ""
    @State private var medicationDose = ""
    @State private var weightKilograms = 4.0
    @State private var heightCentimeters = 52.0
    @State private var isSaving = false
    @State private var didLoadSharedDefaults = false

    private var canSave: Bool {
        guard !isSaving else { return false }
        if kind == .sleep { return durationMinutes > 0 }
        if kind == .feed, feedType == .solids {
            return !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if kind == .diaper { return !diaperContents.isEmpty }
        guard kind == .health else { return true }
        guard let careActivity else { return false }
        return switch careActivity {
        case .medication:
            !medicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .symptom, .other:
            !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .bath, .temperature, .measurements:
            true
        }
    }

    private var savedDetail: String {
        if kind == .diaper {
            return diaperContents.detail(note: detail)
        }
        if kind == .feed {
            let cleanNote = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            let parts: [String] = switch feedType {
            case .nursing: ["Lactancia", "Pecho \(breastSide.title.lowercased())", cleanNote]
            case .bottle: ["Biberón", milkType, cleanNote]
            case .pumping: ["Extracción", cleanNote]
            case .solids: ["Sólidos", cleanNote]
            }
            return parts.filter { !$0.isEmpty }.joined(separator: " · ")
        }
        if kind == .health, let careActivity {
            return careActivity.detail(
                note: detail,
                temperatureCelsius: temperatureCelsius,
                medicationName: medicationName,
                medicationDose: medicationDose,
                weightKilograms: weightKilograms,
                heightCentimeters: heightCentimeters
            )
        }
        return detail
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                Form {
                    Section {
                        HStack(spacing: 14) {
                            EntryGlyph(kind: kind, size: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Registrar \(kind.title.lowercased())")
                                    .font(.system(.title2, design: .serif, weight: .semibold))
                                Text("Un gesto breve. El momento queda guardado.")
                                    .font(.footnote)
                                    .foregroundStyle(NidoTheme.secondaryInk)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }

                    Section("Momento") {
                        DatePicker("Fecha y hora", selection: $date, in: ...Date.now)
                    }

                    if kind == .feed {
                        feedFields
                    }

                    if kind == .sleep {
                        Section {
                            SleepDurationPicker(totalMinutes: $durationMinutes)
                        } header: {
                            Text("Duración")
                        } footer: {
                            Text(sleepDurationFooter)
                        }
                    }

                    if kind == .diaper {
                        Section {
                            HStack(spacing: 12) {
                                DiaperChoiceButton(
                                    title: "Pis",
                                    symbol: "drop.fill",
                                    isSelected: diaperContents.contains(.urine)
                                ) {
                                    diaperContents.formSymmetricDifference(.urine)
                                }
                                DiaperChoiceButton(
                                    title: "Caca",
                                    symbol: "circle.grid.2x2.fill",
                                    isSelected: diaperContents.contains(.stool)
                                ) {
                                    diaperContents.formSymmetricDifference(.stool)
                                }
                            }
                            .padding(.vertical, 4)
                        } header: {
                            Text("¿Qué había en el pañal?")
                        } footer: {
                            Text("Puedes seleccionar una opción o las dos.")
                        }

                        Section("Un detalle, si quieres") {
                            TextField("Color, consistencia…", text: $detail, axis: .vertical)
                                .lineLimit(2...4)
                        }
                    } else if kind == .health {
                        Section {
                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())],
                                spacing: 12
                            ) {
                                ForEach(CareActivity.allCases) { activity in
                                    CareActivityButton(
                                        activity: activity,
                                        isSelected: careActivity == activity
                                    ) {
                                        withAnimation(.snappy(duration: 0.18, extraBounce: 0)) {
                                            careActivity = activity
                                            detail = ""
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        } header: {
                            Text("¿Qué quieres registrar?")
                        } footer: {
                            if careActivity == nil {
                                Text("Elige una opción para continuar.")
                            }
                        }

                        careFields
                    } else if kind != .feed {
                        Section("Un detalle, si quieres") {
                            TextField("Añadir una nota", text: $detail, axis: .vertical)
                                .lineLimit(2...4)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        isSaving = true
                        Task {
                            await store.addEntry(
                                kind: kind,
                                detail: savedDetail,
                                date: date,
                                durationMinutes: kind == .sleep ? durationMinutes : (kind == .feed && feedType != .bottle && feedType != .solids ? feedDurationMinutes : nil),
                                amountMl: kind == .feed && (feedType == .bottle || feedType == .pumping) && amountMl > 0 ? amountMl : nil
                            )
                            isSaving = false
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
        .tint(NidoTheme.moss)
        .onAppear(perform: loadSharedDefaults)
    }

    private func loadSharedDefaults() {
        guard !didLoadSharedDefaults else { return }
        didLoadSharedDefaults = true

        let defaults = EntryFormDefaults(entries: store.entries)
        switch kind {
        case .sleep:
            durationMinutes = defaults.sleepDurationMinutes
        case .feed:
            feedType = defaults.feed.type
            amountMl = defaults.feed.amountMl
            feedDurationMinutes = defaults.feed.durationMinutes
            breastSide = defaults.feed.breastSide
            milkType = defaults.feed.milkType
        case .diaper, .health:
            break
        }
    }

    private var sleepDurationFooter: String {
        guard durationMinutes > 0 else {
            return "Elige una duración mayor que cero."
        }

        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if hours == 0 { return "Duración total: \(minutes) min" }
        if minutes == 0 { return "Duración total: \(hours) h" }
        return "Duración total: \(hours) h \(minutes) min"
    }

    @ViewBuilder
    private var feedFields: some View {
        Section("Tipo de toma") {
            Picker("Tipo", selection: $feedType) {
                ForEach(FeedType.allCases) { type in
                    Label(type.title, systemImage: type.symbolName).tag(type)
                }
            }
            .pickerStyle(.menu)
        }

        switch feedType {
        case .nursing:
            Section("Lactancia") {
                Picker("Pecho", selection: $breastSide) {
                    ForEach(BreastSide.allCases) { side in Text(side.title).tag(side) }
                }
                .pickerStyle(.segmented)
                Stepper("\(feedDurationMinutes) min", value: $feedDurationMinutes, in: 1...180, step: 1)
                if let start = store.activeFeedStartedAt {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        LabeledContent("En curso", value: context.date.timeIntervalSince(start).feedTimerLabel)
                            .monospacedDigit()
                            .foregroundStyle(NidoTheme.moss)
                    }
                    Button(role: .destructive) {
                        Task {
                            await store.finishFeed()
                            dismiss()
                        }
                    } label: {
                        Label("Terminar y guardar", systemImage: "stop.circle.fill")
                    }
                } else {
                    Button {
                        store.startFeed(side: breastSide)
                        dismiss()
                    } label: {
                        Label("Empezar temporizador", systemImage: "play.circle.fill")
                    }
                }
            }
            optionalCareNote(placeholder: "Agarre, reacción…")
        case .bottle:
            Section("Biberón") {
                Picker("Contenido", selection: $milkType) {
                    Text("Leche materna").tag("Leche materna")
                    Text("Fórmula").tag("Fórmula")
                }
                Stepper("\(amountMl) ml", value: $amountMl, in: 0...400, step: 10)
            }
            optionalCareNote(placeholder: "Cómo ha ido la toma…")
        case .pumping:
            Section("Extracción") {
                Stepper("\(amountMl) ml", value: $amountMl, in: 0...500, step: 10)
                Stepper("\(feedDurationMinutes) min", value: $feedDurationMinutes, in: 1...120, step: 1)
            }
            optionalCareNote(placeholder: "Un pecho o ambos…")
        case .solids:
            Section("Alimento") {
                TextField("Qué ha comido", text: $detail, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }

    @ViewBuilder
    private var careFields: some View {
        switch careActivity {
        case .bath:
            optionalCareNote(placeholder: "Productos, reacción de la piel…")
        case .temperature:
            Section("Temperatura") {
                Stepper(value: $temperatureCelsius, in: 34...42, step: 0.1) {
                    measurementRow("Medición", value: temperatureCelsius, unit: "°C")
                }
            }
            optionalCareNote(placeholder: "Dónde se tomó, observaciones…")
        case .medication:
            Section("Medicación") {
                TextField("Nombre del medicamento", text: $medicationName)
                TextField("Dosis, si la conoces", text: $medicationDose)
            }
            optionalCareNote(placeholder: "Motivo u observaciones…")
        case .symptom:
            Section("¿Qué has observado?") {
                TextField("Describe el síntoma", text: $detail, axis: .vertical)
                    .lineLimit(2...4)
            }
        case .measurements:
            Section("Crecimiento") {
                Stepper(value: $weightKilograms, in: 1.5...30, step: 0.1) {
                    measurementRow("Peso", value: weightKilograms, unit: "kg")
                }
                Stepper(value: $heightCentimeters, in: 35...120, step: 0.5) {
                    measurementRow("Altura", value: heightCentimeters, unit: "cm")
                }
            }
            optionalCareNote(placeholder: "Perímetro craneal u observaciones…")
        case .other:
            Section("¿Qué ha ocurrido?") {
                TextField("Añade un detalle", text: $detail, axis: .vertical)
                    .lineLimit(2...4)
            }
        case nil:
            EmptyView()
        }
    }

    private func optionalCareNote(placeholder: String) -> some View {
        Section("Un detalle, si quieres") {
            TextField(placeholder, text: $detail, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    private func measurementRow(_ title: String, value: Double, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value, format: .number.precision(.fractionLength(1)))
                .foregroundStyle(NidoTheme.care)
            Text(unit)
                .foregroundStyle(NidoTheme.secondaryInk)
        }
    }
}

private extension TimeInterval {
    var feedTimerLabel: String {
        let total = max(0, Int(self))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private struct DiaperChoiceButton: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: symbol)
                        .font(.system(size: 24, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isSelected ? NidoTheme.diaper : NidoTheme.secondaryInk)
                        .frame(width: 42, height: 34)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(NidoTheme.moss)
                            .background(.white, in: Circle())
                            .offset(x: 10, y: -7)
                    }
                }
                Text(title)
                    .font(.headline)
                    .foregroundStyle(NidoTheme.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(
                isSelected ? NidoTheme.diaper.opacity(0.13) : Color.clear,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? NidoTheme.diaper.opacity(0.7) : NidoTheme.secondaryInk.opacity(0.18), lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "Toca para desmarcar" : "Toca para seleccionar")
    }
}

private struct CareActivityButton: View {
    let activity: CareActivity
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: activity.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? NidoTheme.care : NidoTheme.secondaryInk)
                    .frame(width: 25)
                Text(activity.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NidoTheme.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NidoTheme.care)
                }
            }
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                isSelected ? NidoTheme.care.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? NidoTheme.care.opacity(0.7) : NidoTheme.secondaryInk.opacity(0.18),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "Seleccionado" : "Toca para seleccionar")
    }
}
