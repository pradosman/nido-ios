import Charts
import SwiftUI

struct EvolutionCareDetailView: View {
    let metric: EvolutionMetric

    @Environment(NidoStore.self) private var store
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.floatingNavigationClearance) private var floatingNavigationClearance
    @State private var range: SleepEvolutionRange = .week
    @State private var anchor: Date?
    @State private var selectedBucketStart: Date?

    init(metric: EvolutionMetric) {
        precondition([.sleep, .feeds, .diapers].contains(metric))
        self.metric = metric
    }

    private var now: Date { store.now }
    private var calendar: Calendar { BabyCareMetrics.calendar(for: store.babyCareState, locale: locale) }
    private var familyDateStyle: Date.FormatStyle {
        Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    }
    private var anchorDate: Date { anchor ?? now }
    private var period: SleepEvolutionPeriod {
        SleepEvolutionPeriod.period(containing: anchorDate, range: range, calendar: calendar)
    }
    private var snapshot: EvolutionCareSnapshot {
        EvolutionCareSnapshot.build(
            metric: metric,
            entries: store.entries,
            activeSleepStartedAt: store.activeSleepStartedAt,
            range: range,
            anchor: anchorDate,
            now: now,
            calendar: calendar
        )
    }
    private var selectedBucket: EvolutionCareBucket? {
        snapshot.buckets.first { $0.start == selectedBucketStart }
    }
    private var currentPeriod: Bool { period.isCurrent(now: now, calendar: calendar) }
    private var title: String { metric == .feeds ? "Tomas" : "Pañales" }
    private var entries: [Entry] {
        let ids = Set(snapshot.periodRecordIDs)
        let kind: EntryKind = metric == .feeds ? .feed : .diaper
        return store.entries
            .filter { ids.contains($0.id) && $0.kind == kind && $0.date <= now }
            .sorted { $0.date > $1.date }
    }
    private var aggregateEntries: [Entry] {
        let ids = Set(selectedBucket?.recordIDs ?? snapshot.recordIDs)
        let kind: EntryKind = metric == .feeds ? .feed : .diaper
        return store.entries.filter { ids.contains($0.id) && $0.kind == kind }
    }
    @ViewBuilder
    var body: some View {
        if metric == .sleep {
            TimelineView(.everyMinute) { context in
                SleepEvolutionDetailView(now: store.currentDate(for: context.date))
            }
        } else {
            careDetail
        }
    }

    private var careDetail: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    rangePicker
                    periodControls
                    summaryCard
                    chartCard
                    recordsLink
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .contentMargins(.bottom, floatingNavigationClearance, for: .scrollContent)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.automatic, for: .navigationBar)
        .accessibilityIdentifier("evolution-care-detail-\(metric.rawValue)")
    }

    private var rangePicker: some View {
        Picker("Periodo", selection: $range) {
            ForEach(SleepEvolutionRange.allCases, id: \.self) { item in
                Text(item.title)
                    .tag(item)
                    .accessibilityIdentifier("evolution-care-range-\(item.rawValue)")
            }
        }
        .pickerStyle(.segmented)
        .tint(NidoTheme.moss)
        .accessibilityIdentifier("evolution-care-range-picker")
        .onChange(of: range) { _, _ in
            anchor = now
            selectedBucketStart = nil
        }
    }

    private var periodControls: some View {
        VStack(spacing: 6) {
            if dynamicTypeSize.isAccessibilitySize {
                periodDate
            }
            HStack(spacing: 12) {
                Button("Periodo anterior", systemImage: "chevron.left") { shiftPeriod(by: -1) }
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
                    .background(NidoTheme.surface, in: Circle())
                    .accessibilityIdentifier("evolution-care-previous")
                if dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 0)
                } else {
                    periodDate
                }
                Button("Periodo siguiente", systemImage: "chevron.right") { shiftPeriod(by: 1) }
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
                    .background(NidoTheme.surface, in: Circle())
                    .disabled(currentPeriod)
                    .accessibilityIdentifier("evolution-care-next")
            }
            Button("Periodo actual") {
                anchor = now
                selectedBucketStart = nil
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(NidoTheme.moss)
            .disabled(currentPeriod)
            .accessibilityIdentifier("evolution-care-current")
        }
    }

    private var periodDate: some View {
        Text(periodLabel)
            .font(.headline)
            .foregroundStyle(NidoTheme.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("evolution-care-period")
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(summaryLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(NidoTheme.secondaryInk)
                .accessibilityIdentifier("evolution-care-summary-label")
            if let selectedBucket {
                Text(bucketDescription(selectedBucket))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NidoTheme.readableSupportingInk)
                    .accessibilityIdentifier("evolution-care-selected-interval")
            }
            Text(summaryValue)
                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                .foregroundStyle(NidoTheme.ink)
                .contentTransition(.numericText())
                .accessibilityIdentifier("evolution-care-summary-value")
            Text(summaryDetail)
                .font(.subheadline)
                .foregroundStyle(NidoTheme.readableSupportingInk)
                .accessibilityIdentifier("evolution-care-summary-detail")
            Text(coverageLabel)
                .font(.caption)
                .foregroundStyle(NidoTheme.readableSupportingInk)
                .accessibilityIdentifier("evolution-care-coverage")
            if selectedBucket != nil {
                Button("Volver al resumen del periodo", systemImage: "arrow.uturn.backward") {
                    selectedBucketStart = nil
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NidoTheme.moss)
                .frame(minHeight: 44)
                .accessibilityIdentifier("evolution-care-chart-reset")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .paperCard()
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                EntryGlyph(kind: metric == .feeds ? .feed : .diaper, size: 19)
                Text(selectedBucket.map(bucketDescription) ?? chartTitle)
                    .font(.headline)
                    .foregroundStyle(NidoTheme.ink)
                    .accessibilityIdentifier("evolution-care-chart-title")
                Spacer(minLength: 0)
                if snapshot.buckets.contains(where: { $0.value != nil }) {
                    Menu {
                        ForEach(snapshot.buckets.filter { $0.value != nil }, id: \.start) { bucket in
                            Button(bucketAccessibilityLabel(bucket)) {
                                selectedBucketStart = bucket.start
                            }
                            .accessibilityIdentifier("evolution-care-bucket-\(Int(bucket.start.timeIntervalSince1970))")
                        }
                    } label: {
                        Label("Explorar valores", systemImage: "ellipsis.circle")
                            .labelStyle(.iconOnly)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .accessibilityLabel("Explorar valores de la gráfica")
                    .accessibilityIdentifier("evolution-care-explore-values")
                }
            }
            Chart(snapshot.buckets, id: \.start) { bucket in
                if let value = bucket.value {
                    BarMark(
                        x: .value("Fecha", bucket.start),
                        y: .value(title, value)
                    )
                    .foregroundStyle(selectedBucketStart == nil || bucket.start == selectedBucketStart
                        ? chartAccent.gradient
                        : chartAccent.opacity(0.28).gradient)
                    .cornerRadius(5)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine().foregroundStyle(NidoTheme.separator)
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(axisLabel(for: date))
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartXScale(domain: period.start...period.end)
            .chartOverlay { chartProxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onEnded { gesture in
                            guard let plotFrame = chartProxy.plotFrame else { return }
                            let plot = geometry[plotFrame]
                            let position = gesture.location.x - plot.origin.x
                            guard let date = chartProxy.value(atX: position, as: Date.self) else { return }
                            selectedBucketStart = snapshot.buckets.min {
                                abs($0.start.timeIntervalSince(date)) < abs($1.start.timeIntervalSince(date))
                            }?.start
                        })
                }
            }
            .frame(height: 200)
            .accessibilityLabel(chartAccessibilityLabel)
            .accessibilityIdentifier("evolution-care-chart")
            Text(chartFootnote)
                .font(.caption)
                .foregroundStyle(NidoTheme.readableSupportingInk)
        }
        .padding(20)
        .paperCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("evolution-care-chart-card")
    }

    private var recordsLink: some View {
        NavigationLink {
            EvolutionCareRecordsView(metric: metric, period: period, recordIDs: snapshot.periodRecordIDs)
        } label: {
            HStack(spacing: 10) {
                Label("Ver registros", systemImage: "list.bullet")
                Spacer()
                Text("\(entries.count)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(NidoTheme.secondaryInk)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(NidoTheme.moss)
            .padding(16)
            .background(NidoTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .accessibilityIdentifier("evolution-care-records-link")
    }

    private var summaryLabel: String {
        if selectedBucketStart != nil {
            return range == .sixMonths || range == .year ? "Promedio diario" : "Total registrado"
        }
        return range == .day ? "Total registrado" : "Total del periodo"
    }

    private var coverageLabel: String {
        EvolutionCareCoverage.label(
            range: range,
            recordedDayCount: selectedBucket?.recordedDayCount ?? snapshot.recordedDayCount,
            eligibleDayCount: selectedBucket?.eligibleDayCount ?? snapshot.eligibleDayCount,
            currentPeriod: currentPeriod,
            selectedBucket: selectedBucket != nil
        )
    }

    private var summaryValue: String {
        let value = selectedBucketStart != nil ? selectedBucket?.value : snapshot.totalValue
        guard let value else { return "Sin registros" }
        if range == .sixMonths || range == .year {
            return "\(value.formatted(.number.precision(.fractionLength(1)).locale(locale))) \(unit(for: 2))"
        }
        let amount = Int(value.rounded())
        return "\(amount) \(unit(for: amount))"
    }

    private var summaryDetail: String {
        if metric == .feeds {
            let amount = aggregateEntries.compactMap(\.amountMl).reduce(0, +)
            return amount > 0 ? "\(amount) ml" : "Cantidad no registrada"
        }
        if selectedBucket != nil { return "Registros del intervalo" }
        if range == .day { return "Registros en el día" }
        guard let mean = snapshot.meanValue else { return "Sin registros en días terminados" }
        return "Media de \(mean.formatted(.number.precision(.fractionLength(1)).locale(locale))) \(unit(for: 2)) al día registrado"
    }

    private var periodLabel: String {
        if range == .day {
            return period.start.formatted(familyDateStyle.weekday(.wide).day().month(.wide))
        }
        if range == .month {
            return period.start.formatted(familyDateStyle.month(.wide).year())
        }
        if range == .year {
            return period.start.formatted(familyDateStyle.year())
        }
        return "\(shortDate(period.start)) – \(shortDate(period.end.addingTimeInterval(-1)))"
    }

    private var chartTitle: String { range == .day ? "Registros por hora" : "Registros por día" }
    private var chartAccent: Color {
        metric == .feeds ? NidoTheme.chartAccent(for: .feed) : NidoTheme.chartAccent(for: .diaper)
    }
    private var chartFootnote: String {
        EvolutionCareCoverage.chartFootnote(range: range)
    }
    private var chartAccessibilityLabel: String {
        snapshot.buckets.map { "\(shortDate($0.start)): \($0.value.map { Int($0.rounded()).formatted(.number.locale(locale)) } ?? "sin registros")" }.joined(separator: ", ")
    }

    private func unit(for amount: Int) -> String {
        if metric == .feeds { return amount == 1 ? "toma" : "tomas" }
        return amount == 1 ? "pañal" : "pañales"
    }

    private func shortDate(_ date: Date) -> String {
        SleepEvolutionDateFormatting.recordDate(for: date, calendar: calendar, locale: locale)
    }

    private func axisLabel(for date: Date) -> String {
        SleepEvolutionDateFormatting.axisLabel(for: date, range: range, calendar: calendar, locale: locale)
    }

    private func bucketDescription(_ bucket: EvolutionCareBucket) -> String {
        guard let value = bucket.value else { return "\(shortDate(bucket.start)): Sin registros" }
        if range == .sixMonths || range == .year {
            return "\(shortDate(bucket.start)): media de \(value.formatted(.number.precision(.fractionLength(1)).locale(locale))) \(unit(for: 2))"
        }
        let count = Int(value.rounded())
        return "\(shortDate(bucket.start)): \(count) \(unit(for: count))"
    }

    private func bucketAccessibilityLabel(_ bucket: EvolutionCareBucket) -> String {
        "\(bucketDescription(bucket)), \(bucket.recordedDayCount) día con registros"
    }

    private func shiftPeriod(by amount: Int) {
        let shifted = period.shifted(by: amount, now: now, calendar: calendar)
        anchor = shifted.start
        selectedBucketStart = nil
    }
}

private struct EvolutionCareRecordsView: View {
    let metric: EvolutionMetric
    let period: SleepEvolutionPeriod
    let recordIDs: [String]

    @Environment(NidoStore.self) private var store
    @Environment(\.locale) private var locale
    @Environment(\.floatingNavigationClearance) private var floatingNavigationClearance
    @State private var deleteCandidate: Entry?

    private var kind: EntryKind { metric == .feeds ? .feed : .diaper }
    private var calendar: Calendar { BabyCareMetrics.calendar(for: store.babyCareState, locale: locale) }
    private var canEditRecords: Bool {
        store.phase == .ready && store.currentCaregiver?.status == .active
    }
    private var records: [Entry] {
        let ids = Set(recordIDs)
        return store.entries
            .filter { ids.contains($0.id) && $0.kind == kind && $0.date >= period.start && $0.date < period.end && $0.date <= store.now }
            .sorted { $0.date > $1.date }
    }
    private var title: String { metric == .feeds ? "Registros de tomas" : "Registros de pañales" }

    var body: some View {
        ZStack {
            PaperBackground()
            List {
                Section {
                    if records.isEmpty {
                        ContentUnavailableView(
                            "Sin registros",
                            systemImage: metric == .feeds ? "fork.knife" : "drop",
                            description: Text("No hay registros guardados en este intervalo.")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(records) { entry in recordRow(entry) }
                    }
                } header: {
                    Text("\(shortDate(period.start)) – \(shortDate(period.end.addingTimeInterval(-1)))")
                        .textCase(nil)
                }
            }
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, floatingNavigationClearance, for: .scrollContent)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("evolution-care-records-\(metric.rawValue)")
        .alert("Eliminar registro", isPresented: Binding(
            get: { deleteCandidate != nil },
            set: { if !$0 { deleteCandidate = nil } }
        )) {
            Button("Cancelar", role: .cancel) { deleteCandidate = nil }
            Button("Eliminar", role: .destructive) {
                guard let candidate = deleteCandidate else { return }
                deleteCandidate = nil
                Task { await store.deleteEntry(candidate) }
            }
        } message: {
            Text("¿Quieres eliminar este registro? Esta acción no se puede deshacer.")
        }
    }

    @ViewBuilder
    private func recordRow(_ entry: Entry) -> some View {
        let identifier = entry.id
        if canEditRecords {
            recordContent(entry)
                .accessibilityElement(children: .combine)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { deleteCandidate = entry } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                .accessibilityIdentifier("evolution-care-delete-\(identifier)")
                    Button { store.editingEntry = entry } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    .tint(NidoTheme.moss)
                    .accessibilityIdentifier("evolution-care-edit-\(identifier)")
                }
                .accessibilityIdentifier("evolution-care-record-\(identifier)")
        } else {
            recordContent(entry)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("evolution-care-record-\(identifier)")
        }
    }

    private func recordContent(_ entry: Entry) -> some View {
        HStack(spacing: 14) {
            Image(systemName: metric == .feeds ? "fork.knife" : "drop.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(NidoTheme.moss)
                .frame(width: 42, height: 42)
                .background(NidoTheme.surface, in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(entry.title)
                    .font(.headline)
                    .foregroundStyle(NidoTheme.ink)
                Text(entry.detail.isEmpty ? entry.kind.title : entry.detail)
                    .font(.subheadline)
                    .foregroundStyle(NidoTheme.readableSupportingInk)
                Text(SleepEvolutionDateFormatting.recordDate(for: entry.date, calendar: calendar, locale: locale))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NidoTheme.readableSupportingInk)
                    .accessibilityIdentifier("evolution-care-record-date-\(entry.id)")
                Text(SleepEvolutionDateFormatting.time(for: entry.date, calendar: calendar, locale: locale))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(NidoTheme.readableSupportingInk)
                    .accessibilityIdentifier("evolution-care-record-time-\(entry.id)")
            }
            Spacer(minLength: 4)
            if let amount = entry.amountMl {
                Text("\(amount) ml")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(NidoTheme.moss)
            }
        }
        .padding(.vertical, 5)
        .listRowBackground(NidoTheme.surface.opacity(0.72))
    }

    private func shortDate(_ date: Date) -> String {
        SleepEvolutionDateFormatting.recordDate(for: date, calendar: calendar, locale: locale)
    }
}
