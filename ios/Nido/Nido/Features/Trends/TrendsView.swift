import Charts
import SwiftUI

struct TrendsView: View {
    @Environment(NidoStore.self) private var store

    private var week: [(date: Date, minutes: Int)] {
        NidoMetrics.sleepByDay(endingOn: .now, days: 7, entries: store.entries)
    }

    private var today: DayMetrics {
        NidoMetrics.day(.now, entries: store.entries)
    }

    private var growth: [GrowthMeasurement] {
        store.entries.compactMap(GrowthMeasurement.init(entry:)).sorted { $0.date < $1.date }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Los ritmos se calculan a partir de los registros y no representan objetivos.")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(NidoTheme.secondaryInk)
                        .lineSpacing(4)

                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Sueño · últimos 7 días")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(NidoTheme.secondaryInk)
                            Text(week.reduce(0) { $0 + $1.minutes }.minutesLabel)
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
                        .chartYAxis(.hidden)
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { _ in
                                AxisValueLabel(format: .dateTime.weekday(.narrow))
                            }
                        }
                        .frame(height: 190)
                    }
                    .padding(20)
                    .paperCard()

                    HStack(spacing: 12) {
                        metricCard(kind: .feed, value: "\(today.feeds)", note: today.feedMl > 0 ? "\(today.feedMl) ml hoy" : "tomas hoy")
                        metricCard(kind: .diaper, value: "\(today.diapers)", note: "cambios hoy")
                    }


                    if !growth.isEmpty {
                        growthCard
                    }
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
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(color)
                    PointMark(x: .value("Fecha", item.date), y: .value(title, measurement))
                        .foregroundStyle(color)
                }
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 130)
        }
    }

    private func metricCard(kind: EntryKind, value: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            EntryGlyph(kind: kind, size: 22)
                .frame(width: 32, height: 32)
            Text(value)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
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

private extension Int {
    var minutesLabel: String {
        let hours = self / 60
        let minutes = self % 60
        if hours == 0 { return "\(minutes) min" }
        return minutes == 0 ? "\(hours) h" : "\(hours) h \(minutes) min"
    }
}
