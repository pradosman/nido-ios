import Charts
import SwiftUI

struct SleepEvolutionPreviewSource {
    let entries: [Entry]
    let activeSleepStartedAt: Date?
    let now: Date
    let calendar: Calendar
}

struct SleepEvolutionDetailView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.floatingNavigationClearance) private var floatingNavigationClearance
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @State private var range: SleepEvolutionRange = .week
    @State private var anchor: Date?
    @State private var selectedBucketKey: String?
    private let previewSource: SleepEvolutionPreviewSource?
    private let suppliedNow: Date?

    init(now: Date? = nil) {
        previewSource = nil
        suppliedNow = now
    }

    init(previewSource: SleepEvolutionPreviewSource) {
        self.previewSource = previewSource
        suppliedNow = nil
    }

    #if DEBUG
    init(isEmpty: Bool) {
        previewSource = SleepEvolutionPreviewSource(
            entries: isEmpty ? [] : EvolutionDesignFixture.sleepEntries,
            activeSleepStartedAt: isEmpty ? nil : EvolutionDesignFixture.activeSleepStartedAt,
            now: EvolutionDesignFixture.now,
            calendar: EvolutionDesignFixture.sleepCalendar
        )
        suppliedNow = nil
    }
    #endif

    private var isPreview: Bool { previewSource != nil }

    private var now: Date { previewSource?.now ?? suppliedNow ?? store.now }

    private var calendar: Calendar {
        previewSource?.calendar ?? BabyCareMetrics.calendar(for: store.babyCareState, locale: locale)
    }

    private var entries: [Entry] {
        previewSource?.entries ?? store.entries.filter { $0.kind == .sleep }
    }

    private var activeSleepStartedAt: Date? {
        guard let previewSource else { return store.activeSleepStartedAt }
        return previewSource.activeSleepStartedAt
    }

    private var anchorDate: Date { anchor ?? now }

    private var period: SleepEvolutionPeriod {
        SleepEvolutionPeriod.period(containing: anchorDate, range: range, calendar: calendar)
    }
    private var snapshot: SleepEvolutionSnapshot {
        SleepEvolutionSnapshot.build(
            entries: entries,
            activeSleepStartedAt: activeSleepStartedAt,
            range: range,
            anchor: anchorDate,
            now: now,
            calendar: calendar
        )
    }
    private var selectedBucket: SleepEvolutionBucket? {
        snapshot.buckets.first { bucketKey($0) == selectedBucketKey }
    }
    private var currentPeriod: Bool { period.isCurrent(now: now, calendar: calendar) }
    private var bucketKeys: [String] { snapshot.buckets.map(bucketKey) }
    private var axisBucketKeys: [String] {
        EvolutionChartAxis.visibleIndices(
            bucketCount: snapshot.buckets.count,
            maximumLabels: range == .day ? 6 : 7
        ).map { bucketKey(snapshot.buckets[$0]) }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    rangePicker
                    periodControls
                    mainCard
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
        .navigationTitle("Sueño")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.automatic, for: .navigationBar)
        .accessibilityIdentifier("sleep-evolution-detail")
    }

    private var rangePicker: some View {
        Picker("Periodo", selection: $range) {
            ForEach(SleepEvolutionRange.allCases, id: \.self) { item in
                Text(item.title)
                    .tag(item)
                    .accessibilityLabel(rangeName(item))
                    .accessibilityIdentifier("sleep-evolution-range-\(item.rawValue)")
            }
        }
        .pickerStyle(.segmented)
        .tint(NidoTheme.moss)
        .accessibilityIdentifier("sleep-evolution-range-picker")
        .onChange(of: range) { _, next in changeRange(to: next) }
    }

    @ViewBuilder
    private var periodControls: some View {
        HStack(spacing: 12) {
            Button("Anterior", systemImage: "chevron.left") { shiftPeriod(by: -1) }
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
                .background(NidoTheme.surface, in: Circle())
                .accessibilityLabel("Periodo anterior")
                .accessibilityIdentifier("sleep-evolution-previous")
            VStack(spacing: 3) {
                Text(periodLabel(period))
                    .font(.headline)
                    .foregroundStyle(NidoTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("sleep-evolution-period")
            Button("Siguiente", systemImage: "chevron.right") { shiftPeriod(by: 1) }
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
                .background(NidoTheme.surface, in: Circle())
                .disabled(currentPeriod)
                .accessibilityLabel("Periodo siguiente")
                .accessibilityIdentifier("sleep-evolution-next")
        }
        .buttonStyle(.plain)
        if !currentPeriod {
            Button("Volver al actual") { goToCurrentPeriod() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NidoTheme.moss)
                .frame(minHeight: 44)
                .accessibilityIdentifier("sleep-evolution-current")
        }
    }

    private var mainCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            summaryContent
            chartContent
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 26))
    }

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let selectedBucket {
                Text(selectedIntervalLabel(selectedBucket))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NidoTheme.readableSupportingInk)
                    .accessibilityIdentifier("sleep-evolution-selected-interval")
            }
            Text(displayedSummaryLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(NidoTheme.readableSupportingInk)
                .accessibilityIdentifier("sleep-evolution-summary-label")
            displayedDuration
            Text(displayedCoverage)
                .font(.subheadline)
                .foregroundStyle(NidoTheme.readableSupportingInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("sleep-evolution-coverage")
            if snapshot.includesActiveSleep && range == .day && selectedBucket == nil {
                Label("Sueño en curso · hasta ahora", systemImage: "moon.zzz.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(NidoTheme.sleep)
                    .accessibilityIdentifier("sleep-evolution-active-sleep")
            }
            if selectedBucket != nil {
                Button("Volver al resumen del periodo", systemImage: "arrow.uturn.backward") {
                    clearSelection()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NidoTheme.moss)
                .frame(minHeight: 44)
                .accessibilityIdentifier("sleep-evolution-chart-reset")
            }
        }
    }

    private var chartContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Sueño registrado")
                    .font(.headline)
                    .foregroundStyle(NidoTheme.ink)
                Spacer()
                if snapshot.buckets.contains(where: { $0.valueSeconds != nil }) {
                    Menu {
                        ForEach(snapshot.buckets, id: \.start) { bucket in
                            Button(bucketAccessibilityLabel(bucket)) {
                                select(bucket)
                            }
                            .accessibilityIdentifier("sleep-evolution-bucket-\(Int(bucket.start.timeIntervalSince1970))")
                        }
                    } label: {
                        Label("Explorar valores", systemImage: "ellipsis.circle")
                            .labelStyle(.iconOnly)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .accessibilityLabel("Explorar valores de la gráfica")
                    .accessibilityIdentifier("sleep-evolution-explore-values")
                }
            }
            if snapshot.buckets.contains(where: { $0.valueSeconds != nil }) {
                Chart(snapshot.buckets, id: \.start) { bucket in
                    if let value = bucket.valueSeconds {
                        BarMark(
                            x: .value("Intervalo", bucketKey(bucket)),
                            y: .value(chartValueLabel, value),
                            width: .ratio(range == .day ? 0.72 : 0.68)
                        )
                        .foregroundStyle(bucketKey(bucket) == selectedBucketKey || selectedBucketKey == nil
                            ? NidoTheme.chartAccent(for: .sleep)
                            : NidoTheme.chartAccent(for: .sleep).opacity(0.28))
                        .cornerRadius(4)
                    }
                }
                .chartXScale(domain: bucketKeys)
                .chartYScale(domain: 0...chartMaximumSeconds)
                .chartXAxis {
                    AxisMarks(values: axisBucketKeys) { value in
                        AxisValueLabel(
                            anchor: value.as(String.self) == axisBucketKeys.first ? .topLeading : .top
                        ) {
                            if let key = value.as(String.self), let bucket = snapshot.buckets.first(where: { bucketKey($0) == key }) {
                                Text(axisLabel(bucket)).fixedSize(horizontal: true, vertical: false)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: chartTickValues) { value in
                        AxisGridLine().foregroundStyle(NidoTheme.separator.opacity(0.5))
                        AxisValueLabel {
                            if let seconds = value.as(Double.self) {
                                Text(axisDuration(seconds))
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedBucketKey)
                .chartGesture { proxy in
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            proxy.selectXValue(at: value.location.x)
                        }
                }
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 250 : 210)
                .accessibilityLabel("Gráfica de sueño registrado")
                .accessibilityValue(chartAccessibilityValue)
                .accessibilityIdentifier("sleep-evolution-chart")
            } else {
                ContentUnavailableView("Sin datos", systemImage: "moon.zzz", description: Text("No hay registros de sueño en este periodo."))
                    .frame(height: 190)
                    .accessibilityIdentifier("sleep-evolution-chart")
            }

        }
    }

    private var recordsLink: some View {
        NavigationLink {
            if isPreview {
                SleepEvolutionRecordsView(entries: entries, recordIDs: snapshot.periodRecordIDs, period: period, calendar: calendar)
            } else {
                SleepEvolutionRecordsView(recordIDs: snapshot.periodRecordIDs, period: period)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(NidoTheme.moss)
                Text("Mostrar todos los registros")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(NidoTheme.ink)
                Spacer()
                Text("\(snapshot.periodRecordIDs.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(NidoTheme.readableSupportingInk)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NidoTheme.secondaryInk)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 58)
            .background(NidoTheme.surface, in: .rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sleep-evolution-records-link")
    }

    private var displayedSummaryLabel: String {
        if selectedBucket == nil && (range == .day ? snapshot.totalSeconds == nil : snapshot.meanSeconds == nil) {
            return "Sin datos"
        }
        if selectedBucket != nil {
            return range == .sixMonths || range == .year ? "Promedio diario" : "Total registrado"
        }
        return range == .day ? "Total registrado" : "Promedio diario"
    }

    private var displayedSeconds: Double? {
        if let selectedBucket { return selectedBucket.valueSeconds }
        if range == .day { return snapshot.totalSeconds.map(Double.init) }
        return snapshot.meanSeconds
    }

    @ViewBuilder
    private var displayedDuration: some View {
        if let seconds = displayedSeconds {
            durationValue(seconds)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(DurationLabel.minutes(Int((seconds / 60).rounded())))
                .accessibilityIdentifier("sleep-evolution-summary-value")
        } else {
            Text("Sin datos")
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .foregroundStyle(NidoTheme.ink)
                .accessibilityIdentifier("sleep-evolution-summary-value")
        }
    }

    private var displayedCoverage: String {
        if let selectedBucket {
            if range == .day {
                if bucketIncludesActiveSleep(selectedBucket) {
                    return selectedBucket.recordIDs.isEmpty
                        ? "Incluye sueño en curso hasta ahora"
                        : "Incluye registros guardados y sueño en curso"
                }
                if selectedBucket.valueSeconds != nil && selectedBucket.recordIDs.isEmpty {
                    return "Incluye sueño en curso hasta ahora"
                }
                return selectedBucket.recordedDayCount == 0 ? "Sin registros en esta hora" : "Registro guardado en este día"
            }
            return coverageText(recorded: selectedBucket.recordedDayCount, eligible: selectedBucket.eligibleDayCount)
        }
        if range == .day {
            if snapshot.totalSeconds == nil { return currentPeriod ? "Sin registros de sueño hoy" : "Sin registros de este día" }
            return snapshot.includesActiveSleep
                ? "Incluye registros guardados y sueño en curso hasta ahora"
                : "Incluye los registros guardados de este día"
        }
        return coverageText(recorded: snapshot.recordedDayCount, eligible: snapshot.eligibleDayCount)
    }

    private var chartValueLabel: String {
        range == .sixMonths || range == .year ? "Promedio diario, segundos" : "Sueño, segundos"
    }

    private var chartAccessibilityValue: String {
        if let selectedBucket {
            return "\(bucketAccessibilityLabel(selectedBucket)); \(displayedCoverage)"
        }
        let value = range == .day ? snapshot.totalSeconds.map(Double.init) : snapshot.meanSeconds
        guard let value else { return "Sin datos en este periodo" }
        return "\(displayedSummaryLabel): \(DurationLabel.minutes(Int((value / 60).rounded()))); \(displayedCoverage)"
    }

    private func rangeName(_ value: SleepEvolutionRange) -> String {
        switch value {
        case .day: "Día"
        case .week: "Semana"
        case .month: "Mes"
        case .sixMonths: "Seis meses"
        case .year: "Año"
        }
    }

    private func changeRange(to next: SleepEvolutionRange) {
        range = next
        selectedBucketKey = nil
        anchor = now
    }

    private func shiftPeriod(by amount: Int) {
        selectedBucketKey = nil
        anchor = period.shifted(by: amount, now: now, calendar: calendar).start
    }

    private func goToCurrentPeriod() {
        selectedBucketKey = nil
        anchor = now
    }

    private func clearSelection() { selectedBucketKey = nil }

    private func select(_ bucket: SleepEvolutionBucket) {
        selectedBucketKey = bucketKey(bucket)
    }

    private func bucketKey(_ bucket: SleepEvolutionBucket) -> String {
        String(Int(bucket.start.timeIntervalSince1970))
    }

    private func bucketIncludesActiveSleep(_ bucket: SleepEvolutionBucket) -> Bool {
        guard let activeSleepStartedAt else { return false }
        return activeSleepStartedAt < bucket.end && now > bucket.start
    }

    private func periodLabel(_ value: SleepEvolutionPeriod) -> String {
        let first = value.start
        let last = value.end.addingTimeInterval(-1)
        let dateStyle = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        let firstParts = calendar.dateComponents([.year, .month], from: first)
        let lastParts = calendar.dateComponents([.year, .month], from: last)
        if firstParts.year == lastParts.year, firstParts.month == lastParts.month {
            return "\(first.formatted(dateStyle.day()))–\(last.formatted(dateStyle.day())) \(last.formatted(dateStyle.month(.abbreviated).year()))"
        }
        if firstParts.year == lastParts.year {
            return "\(first.formatted(dateStyle.day().month(.abbreviated))) – \(last.formatted(dateStyle.day().month(.abbreviated).year()))"
        }
        return "\(SleepEvolutionDateFormatting.recordDate(for: first, calendar: calendar, locale: locale)) – \(SleepEvolutionDateFormatting.recordDate(for: last, calendar: calendar, locale: locale))"
    }

    private func axisLabel(_ bucket: SleepEvolutionBucket) -> String {
        let label = SleepEvolutionDateFormatting.axisLabel(for: bucket.start, range: range, calendar: calendar, locale: locale)
        guard range == .day else { return label }
        let duplicate = snapshot.buckets.filter {
            SleepEvolutionDateFormatting.axisLabel(for: $0.start, range: range, calendar: calendar, locale: locale) == label
        }.count > 1
        guard duplicate, let zone = calendar.timeZone.abbreviation(for: bucket.start) else { return label }
        return "\(label) \(zone)"
    }

    private func selectedIntervalLabel(_ bucket: SleepEvolutionBucket) -> String {
        switch range {
        case .day:
            let start = SleepEvolutionDateFormatting.time(for: bucket.start, calendar: calendar, locale: locale)
            let end = SleepEvolutionDateFormatting.time(for: bucket.end, calendar: calendar, locale: locale)
            let label = SleepEvolutionDateFormatting.axisLabel(for: bucket.start, range: .day, calendar: calendar, locale: locale)
            let repeated = snapshot.buckets.filter {
                SleepEvolutionDateFormatting.axisLabel(for: $0.start, range: .day, calendar: calendar, locale: locale) == label
            }.count > 1
            let zone = repeated ? " \(calendar.timeZone.abbreviation(for: bucket.start) ?? "")" : ""
            return "\(start)–\(end)\(zone)"
        case .week, .month:
            return SleepEvolutionDateFormatting.recordDate(for: bucket.start, calendar: calendar, locale: locale)
        case .sixMonths, .year:
            let style = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            return bucket.start.formatted(style.month(.abbreviated).year())
        }
    }

    private var chartMaximumSeconds: Double {
        let maximum = snapshot.buckets.compactMap(\.valueSeconds).max() ?? 3_600
        let maximumHours = max(1, Int(ceil(maximum / 3_600)))
        let step = max(1, Int(ceil(Double(maximumHours) / 4)))
        let upperHours = ((maximumHours + step - 1) / step) * step
        return Double(upperHours) * 3_600
    }

    private var chartTickValues: [Double] {
        let maximumHours = Int(chartMaximumSeconds / 3_600)
        let step = max(1, Int(ceil(Double(maximumHours) / 4)))
        var values = stride(from: 0, through: maximumHours, by: step).map { Double($0) * 3_600 }
        return values
    }

    @ViewBuilder
    private func durationValue(_ seconds: Double) -> some View {
        let totalMinutes = Int((seconds / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("\(hours)")
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(NidoTheme.ink)
            Text("h")
                .font(.title3)
                .foregroundStyle(NidoTheme.readableSupportingInk)
            if minutes > 0 {
                Text("\(minutes)")
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(NidoTheme.ink)
                Text("min")
                    .font(.title3)
                    .foregroundStyle(NidoTheme.readableSupportingInk)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func axisDuration(_ seconds: Double) -> String {
        "\(Int((seconds / 3_600).rounded())) h"
    }

    private func coverageText(recorded: Int, eligible: Int) -> String {
        guard eligible > 0 else { return "Todavía no hay días terminados en este intervalo" }
        let noun = eligible == 1 ? "día terminado" : "días terminados"
        return "\(recorded) de \(eligible) \(noun) con registros"
    }

    private func bucketAccessibilityLabel(_ bucket: SleepEvolutionBucket) -> String {
        let interval = selectedIntervalLabel(bucket)
        let value = bucket.valueSeconds.map { DurationLabel.minutes(Int(($0 / 60).rounded())) } ?? "Sin registros"
        return "\(interval), \(value)"
    }
}
