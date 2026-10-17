import Charts
import SwiftUI

struct TrendsView: View {
    @Environment(NidoStore.self) private var store
    private var calendar: Calendar { BabyCareMetrics.calendar(for: store.babyCareState) }

    private var week: [(date: Date, minutes: Int)] {
        (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: store.now) else { return nil }
            let summary = BabyCareMetrics.summary(on: date, entries: store.entries,
                activeSleepStartedAt: store.activeSleepStartedAt, now: store.now, calendar: calendar)
            return (calendar.startOfDay(for: date), summary.sleepSeconds / 60)
        }
    }

    private var today: DayMetrics {
        let summary = BabyCareMetrics.summary(on: store.now, entries: store.entries,
            activeSleepStartedAt: store.activeSleepStartedAt, now: store.now, calendar: calendar)
        return DayMetrics(sleepMinutes: summary.sleepSeconds / 60, feeds: summary.feedCount,
            feedMl: NidoMetrics.day(store.now, entries: store.entries, calendar: calendar).feedMl,
            diapers: summary.diaperCount)
    }

    private var growth: [GrowthMeasurement] {
        BabyCareReconciliation.mergedMeasurements(state: store.babyCareState, entries: store.entries)
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Estas tendencias se basan en vuestros registros y no son recomendaciones médicas.")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(NidoTheme.secondaryInk)
                        .lineSpacing(4)

                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Sueño · últimos 7 días")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(NidoTheme.secondaryInk)
                            Text(DurationLabel.minutes(week.reduce(0) { $0 + $1.minutes }))
                                .font(.system(.title, design: .serif, weight: .semibold))
                                .foregroundStyle(NidoTheme.ink)
                        }

                        Chart(week, id: \.date) { value in
                            BarMark(
                                x: .value("Día", value.date, unit: .day),
                                y: .value("Minutos", value.minutes)
                            )
                            .foregroundStyle(NidoTheme.sleep.gradient)
                            .cornerRadius(5)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(NidoTheme.separator)
                                AxisValueLabel {
                                    if let minutes = value.as(Int.self) {
                                        Text(DurationLabel.minutes(minutes))
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { _ in
                                AxisValueLabel(format: .dateTime.weekday(.narrow))
                            }
                        }
                        .frame(height: 190)
                        .accessibilityLabel("Sueño de los últimos siete días")
                        .accessibilityValue(weekAccessibilityValue)
                    }
                    .padding(20)
                    .paperCard()

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            metricCard(kind: .feed, value: "\(today.feeds)", note: today.feedMl > 0 ? "\(today.feedMl) ml hoy" : "tomas hoy")
                            metricCard(kind: .diaper, value: "\(today.diapers)", note: "cambios hoy")
                        }
                        VStack(spacing: 12) {
                            metricCard(kind: .feed, value: "\(today.feeds)", note: today.feedMl > 0 ? "\(today.feedMl) ml hoy" : "tomas hoy")
                            metricCard(kind: .diaper, value: "\(today.diapers)", note: "cambios hoy")
                        }
                    }


                    if !growth.isEmpty {
                        growthCard
                    }
                    NavigationLink("Ver crecimiento", destination: GrowthOverviewView())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NidoTheme.moss)
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Ritmos")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var growthCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Crecimiento")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NidoTheme.secondaryInk)
                Text("Evolución")
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(NidoTheme.ink)
            }

            if growth.contains(where: { $0.weightKilograms != nil }) {
                growthChart(title: "Peso", unit: "kg", color: NidoTheme.care) { $0.weightKilograms }
            }
            if growth.contains(where: { $0.heightCentimeters != nil }) {
                growthChart(title: "Altura", unit: "cm", color: NidoTheme.moss) { $0.heightCentimeters }
            }

            Text("Estas mediciones no sustituyen una evaluación clínica. Puedes incluirlas en el informe para el pediatra.")
                .font(.caption)
                .foregroundStyle(NidoTheme.secondaryInk)
                .lineSpacing(3)
        }
        .padding(20)
        .paperCard()
    }

    private func growthChart(
        title: String,
        unit: String,
        color: Color,
        value: @escaping (GrowthMeasurement) -> Double?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                if let latest = growth.reversed().compactMap(value).first {
                    Text("\(latest.formatted(.number.precision(.fractionLength(1)))) \(unit)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(color)
                }
            }
            Chart(growth) { item in
                if let measurement = value(item) {
                    LineMark(x: .value("Fecha", item.date), y: .value(title, measurement))
                        .interpolationMethod(.linear)
                        .foregroundStyle(color)
                    PointMark(x: .value("Fecha", item.date), y: .value(title, measurement))
                        .foregroundStyle(color)
                }
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 130)
            .accessibilityLabel("Evolución de \(title.lowercased())")
            .accessibilityValue(growthAccessibilityValue(unit: unit, value: value))
        }
    }

    private var weekAccessibilityValue: String {
        week.map { item in
            "\(item.date.formatted(.dateTime.weekday(.wide))): \(DurationLabel.minutes(item.minutes))"
        }
        .joined(separator: ", ")
    }

    private func growthAccessibilityValue(
        unit: String,
        value: (GrowthMeasurement) -> Double?
    ) -> String {
        growth.compactMap { measurement in
            value(measurement).map {
                "\(measurement.date.formatted(date: .abbreviated, time: .omitted)): \($0.formatted(.number.precision(.fractionLength(1)))) \(unit)"
            }
        }
        .joined(separator: ", ")
    }

    private func metricCard(kind: EntryKind, value: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            EntryGlyph(kind: kind, size: 22)
                .frame(width: 32, height: 32)
            Text(value)
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .foregroundStyle(NidoTheme.ink)
            Text(note)
                .font(.caption)
                .foregroundStyle(NidoTheme.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .paperCard()
    }
}

private extension GrowthMeasurement {
    var date: Date { Date(timeIntervalSince1970: Double(measuredAt) / 1_000) }
    var weightKilograms: Double? { weightGrams.map { Double($0) / 1_000 } }
    var heightCentimeters: Double? { heightMillimeters.map { Double($0) / 10 } }
}
