import Charts
import SwiftUI

struct GrowthSeriesDetailView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var environmentCalendar
    @Environment(\.timeZone) private var environmentTimeZone
    @Environment(\.locale) private var locale
    @Environment(\.floatingNavigationClearance) private var floatingNavigationClearance

    let metric: GrowthMetric
    let source: Source?

    struct Source {
        let measurements: [GrowthMeasurement]
        let now: Date
        let calendar: Calendar
    }

    init(metric: GrowthMetric, source: Source? = nil) {
        self.metric = metric
        self.source = source
    }

    @State private var range: GrowthRange = .sixMonths
    @State private var editingMeasurement: GrowthMeasurement?
    @State private var measurementToDelete: GrowthMeasurement?

    private var isReadOnly: Bool { source != nil }
    private var now: Date { source?.now ?? store.now }

    private var allMeasurements: [GrowthMeasurement] {
        (source?.measurements ?? BabyCareReconciliation.mergedMeasurements(state: store.babyCareState, entries: store.entries))
            .filter { metric.value(in: $0) != nil }
    }

    private var familyCalendar: Calendar {
        if let source { return source.calendar }
        var calendar = BabyCareMetrics.calendar(for: store.babyCareState)
        calendar.locale = locale
        calendar.firstWeekday = environmentCalendar.firstWeekday
        calendar.minimumDaysInFirstWeek = environmentCalendar.minimumDaysInFirstWeek
        if TimeZone(identifier: store.babyCareState.timeZoneID) == nil {
            calendar.timeZone = environmentTimeZone
        }
        return calendar
    }

    private var chartDateDomain: ClosedRange<Date> {
        let end = now
        let start = range.startDate(endingAt: end, calendar: familyCalendar) ?? end.addingTimeInterval(-86_400)
        return start...end
    }

    private var visibleMeasurements: [GrowthMeasurement] {
        guard let start = range.startDate(endingAt: now, calendar: familyCalendar) else { return allMeasurements }
        return allMeasurements.filter {
            let date = Date(timeIntervalSince1970: Double($0.measuredAt) / 1_000)
            return date >= start && date <= now
        }
    }

    private var latestMeasurement: GrowthMeasurement? { allMeasurements.last }

    private var periodDateRangeDescription: String {
        guard let start = range.startDate(endingAt: now, calendar: familyCalendar) else { return "" }
        let startLabel = GrowthOverviewView.dateLabel(start, calendar: familyCalendar, locale: locale)
        let endLabel = GrowthOverviewView.dateLabel(now, calendar: familyCalendar, locale: locale)
        return "\(startLabel) – \(endLabel)"
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    latest
                    chartCard
                    history
                    if !isReadOnly { GrowthSyncStatus(store: store) }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 20)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .contentMargins(.bottom, floatingNavigationClearance, for: .scrollContent)
        }
        .environment(\.calendar, familyCalendar)
        .environment(\.timeZone, familyCalendar.timeZone)
        .environment(\.locale, locale)
        .navigationTitle(metric.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if !isReadOnly {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingMeasurement = nil
                        isAddingMeasurement = true
                    } label: {
                        Label("Añadir", systemImage: "plus")
                    }
                    .accessibilityIdentifier("growth.add")
                }
            }
        }
        .sheet(isPresented: $isAddingMeasurement) {
            GrowthMeasurementEditorView(existing: nil)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingMeasurement) { measurement in
            GrowthMeasurementEditorView(existing: measurement)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "¿Eliminar esta medición?",
            isPresented: Binding(
                get: { measurementToDelete != nil },
                set: { if !$0 { measurementToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: measurementToDelete
        ) { measurement in
            Button("Eliminar medición", role: .destructive) {
                Task {
                    _ = await store.deleteGrowthMeasurement(id: measurement.id)
                    measurementToDelete = nil
                }
            }
            Button("Cancelar", role: .cancel) { measurementToDelete = nil }
        }
        .accessibilityIdentifier("growth.detail.\(metric.rawValue)")
    }

    @State private var isAddingMeasurement = false

    private var latest: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Última medida")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(NidoTheme.secondaryInk)
            if let latestMeasurement, let amount = metric.formattedAmount(in: latestMeasurement) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(amount)
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(NidoTheme.ink)
                    Text(metric.unit)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(NidoTheme.secondaryInk)
                }
                Text(GrowthOverviewView.dateLabel(for: latestMeasurement, calendar: familyCalendar, locale: locale))
                    .font(.subheadline)
                    .foregroundStyle(NidoTheme.secondaryInk)
            } else {
                Text("Aún no hay medidas de \(metric.title.lowercased())")
                    .font(.body)
                    .foregroundStyle(NidoTheme.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Historial de \(metric.title.lowercased())")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(NidoTheme.ink)
            }

            rangePicker
            Text(periodDateRangeDescription)
                .font(.caption)
                .foregroundStyle(NidoTheme.secondaryInk)
                .accessibilityIdentifier("growth.range.dates")

            if visibleMeasurements.isEmpty {
                ContentUnavailableView(
                    "Sin medidas en este periodo",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Elige un periodo más amplio o añade una medida con fecha.")
                )
                .frame(minHeight: 160)
                .accessibilityIdentifier("growth.chart.empty")
            } else {
                chart
                    .frame(height: 205)
                    .accessibilityLabel("Historial de \(metric.title.lowercased())")
                    .accessibilityValue(chartAccessibilityValue)

                Text(visibleMeasurements.count == 1
                     ? "1 medida · se muestra el valor registrado"
                     : "\(visibleMeasurements.count) medidas registradas")
                    .font(.caption)
                    .foregroundStyle(NidoTheme.secondaryInk)
                    .accessibilityIdentifier(visibleMeasurements.count == 1 ? "growth.singleSample" : "growth.chart.sampleCount")
            }
        }
        .padding(20)
        .paperCard()
    }

    private var rangePicker: some View {
        Picker("Periodo", selection: $range) {
            ForEach(GrowthRange.allCases) { option in
                Text(option.shortTitle)
                    .tag(option)
                    .accessibilityLabel(option.title)
                    .accessibilityIdentifier(option.accessibilityID)
            }
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 44)
        .accessibilityIdentifier("growth.range.selector")
    }

    private var chart: some View {
        Chart {
            if visibleMeasurements.count > 1 {
                ForEach(visibleMeasurements) { measurement in
                    if let value = metric.value(in: measurement) {
                        LineMark(
                            x: .value("Fecha", sampleDate(measurement)),
                            y: .value(metric.title, value)
                        )
                        .interpolationMethod(.linear)
                        .foregroundStyle(metric.color)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                }
            }

            ForEach(visibleMeasurements) { measurement in
                if let value = metric.value(in: measurement) {
                    PointMark(
                        x: .value("Fecha", sampleDate(measurement)),
                        y: .value(metric.title, value)
                    )
                    .symbolSize(78)
                    .foregroundStyle(metric.color)
                    .accessibilityLabel(GrowthOverviewView.dateLabel(for: measurement, calendar: familyCalendar, locale: locale))
                    .accessibilityValue("\(value.formatted(.number.precision(.fractionLength(0...2)).locale(.current))) \(metric.unit)")
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: textSize.isAccessibilitySize ? 2 : 4)) { value in
                AxisGridLine().foregroundStyle(NidoTheme.separator.opacity(0.55))
                AxisValueLabel(anchor: .topTrailing) {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.day().month(.abbreviated))
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
        }
        .chartXScale(domain: chartDateDomain)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(NidoTheme.separator.opacity(0.55))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(number.formatted(.number.precision(.fractionLength(0...1)).locale(.current)))
                    }
                }
            }
        }
        .environment(\.calendar, familyCalendar)
        .environment(\.timeZone, familyCalendar.timeZone)
        .environment(\.locale, locale)
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Medidas")
                .font(.title2.weight(.semibold))
                .foregroundStyle(NidoTheme.ink)
            if allMeasurements.isEmpty {
                Text("Las medidas que añadas aparecerán aquí con su fecha.")
                    .font(.body)
                    .foregroundStyle(NidoTheme.secondaryInk)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .paperCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(allMeasurements.reversed()) { measurement in
                        if isReadOnly {
                            GrowthReadOnlyRecordRow(measurement: measurement, calendar: familyCalendar)
                        } else {
                            GrowthRecordRow(measurement: measurement, calendar: familyCalendar) {
                                editingMeasurement = measurement
                            } onDelete: {
                                measurementToDelete = measurement
                            }
                        }
                        if measurement.id != allMeasurements.first?.id {
                            Divider().overlay(NidoTheme.separator.opacity(0.55)).padding(.leading, 16)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .paperCard()
                .accessibilityIdentifier("growth.history")
            }
        }
    }

    private var chartAccessibilityValue: String {
        visibleMeasurements.compactMap { measurement in
            metric.formattedValue(in: measurement).map {
                "\(GrowthOverviewView.dateLabel(for: measurement, calendar: familyCalendar, locale: locale)): \($0)"
            }
        }
        .joined(separator: ", ")
    }

    private func sampleDate(_ measurement: GrowthMeasurement) -> Date {
        Date(timeIntervalSince1970: Double(measurement.measuredAt) / 1_000)
    }
}

private struct GrowthReadOnlyRecordRow: View {
    let measurement: GrowthMeasurement
    let calendar: Calendar
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(GrowthOverviewView.dateLabel(for: measurement, calendar: calendar, locale: locale))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NidoTheme.ink)
            let values = GrowthMetric.allCases.compactMap { metric in
                metric.formattedValue(in: measurement).map { "\(metric.title) \($0)" }
            }
            Text(values.joined(separator: " · "))
                .font(.footnote)
                .foregroundStyle(NidoTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            if !measurement.note.isEmpty {
                Text(measurement.note)
                    .font(.footnote)
                    .foregroundStyle(NidoTheme.secondaryInk)
                    .lineLimit(3)
            }
        }
        .accessibilityElement(children: .combine)
        .padding(.vertical, 14)
    }
}
