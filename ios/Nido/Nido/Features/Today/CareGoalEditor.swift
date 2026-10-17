import SwiftUI

struct CareGoalEditor: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var sleepHours: String
    @State private var feeds: String
    @State private var diapers: String
    @State private var error: String?

    init(state: BabyCareState, now: Date) {
        let calendar = BabyCareMetrics.calendar(for: state)
        let first = state.goalVersions.isEmpty
        let date = first ? calendar.startOfDay(for: now) : calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let goal = BabyCareMetrics.goals(on: date, state: state)
        _date = State(initialValue: date)
        _sleepHours = State(initialValue: goal?.sleepMinutes.map { (Double($0) / 60).formatted(.number.precision(.fractionLength(0...2))) } ?? "")
        _feeds = State(initialValue: goal?.feedCount.map(String.init) ?? "")
        _diapers = State(initialValue: goal?.diaperCount.map(String.init) ?? "")
    }

    private var calendar: Calendar { BabyCareMetrics.calendar(for: store.babyCareState) }
    private func decimal(_ text: String) -> Double? { Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) }
    private var sleep: Int? {
        guard let value = decimal(sleepHours), value.isFinite, value > 0, value <= 24 else { return nil }
        return Int((value * 60).rounded())
    }
    private var isValid: Bool {
        (sleepHours.isEmpty || (decimal(sleepHours).map { $0.isFinite && $0 > 0 && $0 <= 24 } ?? false))
            && (feeds.isEmpty || Int(feeds).map { (1...100).contains($0) } == true)
            && (diapers.isEmpty || Int(diapers).map { (1...100).contains($0) } == true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    field("Sueño", symbol: "moon.fill", text: $sleepHours, unit: "horas", id: "sleep", kind: .sleep)
                    field("Tomas", symbol: "waterbottle.fill", text: $feeds, unit: "al día", id: "feed", kind: .feed)
                    field("Pañales", symbol: "drop.fill", text: $diapers, unit: "al día", id: "diaper", kind: .diaper)
                } header: { Text("A vuestro ritmo") } footer: {
                    Text("Elige vuestras propias referencias. Deja una casilla vacía para no fijar ese objetivo. No son recomendaciones médicas.")
                }
                Section {
                    DatePicker("Aplicar desde", selection: $date, in: calendar.startOfDay(for: store.now)..., displayedComponents: .date)
                        .accessibilityIdentifier("goals-effective-date")
                } footer: {
                    Text("Los días anteriores conservarán sus objetivos. Estos cambios se comparten con los cuidadores de \(store.profile?.babyName ?? "tu bebé").")
                }
                if !store.babyCareState.goalVersions.isEmpty {
                    Section("Historial de objetivos") {
                        ForEach(store.babyCareState.goalVersions.sorted { $0.effectiveDate > $1.effectiveDate }, id: \.id) { goal in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(effectiveDateLabel(goal.effectiveDate)).font(.subheadline.weight(.semibold))
                                Text(goal.sleepMinutes == nil && goal.feedCount == nil && goal.diaperCount == nil ? "Sin objetivos" : [goal.sleepMinutes.map { "Sueño \(DurationLabel.minutes($0))" }, goal.feedCount.map { "\($0) tomas" }, goal.diaperCount.map { "\($0) pañales" }].compactMap { $0 }.joined(separator: " · "))
                                    .font(.footnote).foregroundStyle(NidoTheme.readableSupportingInk)
                            }
                        }
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
                BabyCareSyncStatus()
            }
            .scrollContentBackground(.hidden)
            .background { PaperBackground() }
            .navigationTitle("Objetivos de \(store.profile?.babyName ?? "tu bebé")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            let parts = calendar.dateComponents([.year, .month, .day], from: date)
                            let key = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
                            if await store.saveGoals(sleepMinutes: sleep, feedCount: Int(feeds), diaperCount: Int(diapers), effectiveDate: key) { dismiss() }
                            else { error = store.babyCareError ?? "No se han podido guardar los objetivos." }
                        }
                    }
                    .disabled(!isValid || !store.canEditGoals || store.isSavingBabyCare)
                    .accessibilityIdentifier("goals-save")
                }
            }
        }
        .environment(\.calendar, calendar)
        .environment(\.timeZone, calendar.timeZone)
        .tint(NidoTheme.moss)
    }

    private func effectiveDateLabel(_ key: String) -> String {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return key }
        var style = Date.FormatStyle(date: .long, time: .omitted)
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        style.locale = calendar.locale ?? .current
        return date.formatted(style)
    }

    private func field(_ title: String, symbol: String, text: Binding<String>, unit: String, id: String, kind: EntryKind) -> some View {
        HStack {
            Label(title, systemImage: symbol).foregroundStyle(NidoTheme.ink)
            Spacer(minLength: 16)
            TextField("Sin objetivo", text: text)
                .multilineTextAlignment(.trailing)
                .keyboardType(kind == .sleep ? .decimalPad : .numberPad)
                .accessibilityLabel(title)
                .accessibilityIdentifier("goals-value-\(id)")
            Text(unit).font(.caption).foregroundStyle(NidoTheme.readableSupportingInk)
        }
    }
}
