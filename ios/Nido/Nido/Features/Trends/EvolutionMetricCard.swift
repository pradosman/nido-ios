import Charts
import SwiftUI

struct EvolutionMetricCard: View {
    let snapshot: EvolutionMetricSnapshot
    let calendar: Calendar
    var dateLabelOverride: String? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .largeTitle) private var valueSize: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    metricHeading
                    metricDate
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    metricHeading
                    Spacer(minLength: 6)
                    metricDate
                }
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 14) {
                    metricValue
                    if hasValue { miniatureChart }
                }
            } else {
                HStack(alignment: .bottom, spacing: 14) {
                    metricValue
                    Spacer(minLength: 0)
                    if hasValue { miniatureChart }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 26))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("evolution-card-\(snapshot.metric.rawValue)")
    }

    private var metricHeading: some View {
        HStack(spacing: 7) {
            metricIcon
            Text(title)
                .font(.headline)
                .foregroundStyle(labelColor)
        }
    }

    private var metricDate: some View {
        HStack(spacing: 6) {
            if !dateLabel.isEmpty {
                Text(dateLabel)
                    .font(.subheadline)
                    .foregroundStyle(NidoTheme.readableSupportingInk)
                    .accessibilityIdentifier("evolution-date-\(snapshot.metric.rawValue)")
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NidoTheme.secondaryInk.opacity(0.65))
                .accessibilityHidden(true)
        }
    }

    private var metricValue: some View {
        VStack(alignment: .leading, spacing: 6) {
            if hasValue {
                if !isGrowth {
                    Text("Promedio diario")
                        .font(.caption2)
                        .foregroundStyle(NidoTheme.readableSupportingInk)
                        .accessibilityIdentifier("evolution-average-label-\(snapshot.metric.rawValue)")
                }
                valueLine
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(formattedValue)
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityIdentifier("evolution-value-\(snapshot.metric.rawValue)")
                Text(coverageLabel)
                    .font(.caption)
                    .foregroundStyle(NidoTheme.readableSupportingInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("evolution-coverage-\(snapshot.metric.rawValue)")
            } else {
                Text(isGrowth ? "Sin mediciones" : "Sin registros")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(NidoTheme.ink)
                    .accessibilityIdentifier("evolution-value-\(snapshot.metric.rawValue)")
                Text(isGrowth ? "Su crecimiento, con perspectiva" : "Su semana aparecerá aquí")
                    .font(.caption)
                    .foregroundStyle(NidoTheme.readableSupportingInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var valueLine: some View {
        if snapshot.metric == .sleep, let value = snapshot.meanValue {
            let minutes = Int((value / 60).rounded())
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                numberText("\(minutes / 60)")
                unitText("h")
                numberText("\(minutes % 60)")
                unitText("min")
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                numberText(number)
                unitText(unit)
            }
        }
    }

    private func numberText(_ value: String) -> some View {
        Text(value)
            .font(.system(size: valueSize, weight: .semibold, design: .rounded))
            .tracking(-0.7)
            .foregroundStyle(NidoTheme.ink)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func unitText(_ value: String) -> some View {
        Text(value)
            .font(.body)
            .foregroundStyle(NidoTheme.readableSupportingInk)
    }

    private var miniatureChart: some View {
        Group {
            if isGrowth {
                Chart(Array(snapshot.samples.enumerated()), id: \.offset) { _, sample in
                    if let value = sample.value {
                        LineMark(x: .value("Fecha", sample.date), y: .value("Medición", value))
                            .foregroundStyle(labelColor)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                        PointMark(x: .value("Fecha", sample.date), y: .value("Medición", value))
                            .foregroundStyle(labelColor)
                            .symbolSize(14)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
            } else {
                Chart(Array(snapshot.samples.enumerated()), id: \.offset) { index, sample in
                    if let value = sample.value {
                        BarMark(x: .value("Día", String(index)), y: .value("Registro", value), width: .ratio(0.68))
                            .foregroundStyle(index == snapshot.samples.lastIndex(where: { $0.value != nil })
                                ? chartColor : NidoTheme.secondaryInk.opacity(0.16))
                            .cornerRadius(2)
                    }
                }
.chartXScale(domain: snapshot.samples.indices.map { String($0) })
                .chartYScale(domain: 0...max(1, snapshot.samples.compactMap(\.value).max() ?? 1))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(width: 92, height: 46)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var metricIcon: some View {
        switch snapshot.metric {
        case .sleep: EntryGlyph(kind: .sleep, size: 19)
        case .feeds: EntryGlyph(kind: .feed, size: 19)
        case .diapers: EntryGlyph(kind: .diaper, size: 19)
        case .weight: Image(systemName: "scalemass.fill").foregroundStyle(NidoTheme.moss)
        case .height: Image(systemName: "ruler").foregroundStyle(NidoTheme.moss)
        }
    }

    private var title: String {
        switch snapshot.metric {
        case .sleep: "Sueño"
        case .feeds: "Tomas"
        case .diapers: "Pañales"
        case .weight: "Peso"
        case .height: "Talla"
        }
    }

    private var labelColor: Color {
        switch snapshot.metric {
        case .sleep: NidoTheme.sleep
        case .feeds: NidoTheme.feed
        case .diapers: NidoTheme.diaper
        case .weight, .height: NidoTheme.moss
        }
    }

    private var chartColor: Color {
        switch snapshot.metric {
        case .sleep: NidoTheme.chartAccent(for: .sleep)
        case .feeds: NidoTheme.chartAccent(for: .feed)
        case .diapers: NidoTheme.chartAccent(for: .diaper)
        case .weight, .height: NidoTheme.moss
        }
    }

    private var isGrowth: Bool { snapshot.metric == .weight || snapshot.metric == .height }
    private var hasValue: Bool { isGrowth ? snapshot.latestValue != nil : snapshot.meanValue != nil }

    private var number: String {
        let value = snapshot.latestValue ?? 0
        let resolved = isGrowth ? value : (snapshot.meanValue ?? 0)
        let digits = snapshot.metric == .weight ? 2 : 1
        return resolved.formatted(.number.locale(locale).precision(.fractionLength(0...digits)))
    }

    private var unit: String {
        switch snapshot.metric {
        case .sleep: ""
        case .feeds: "tomas"
        case .diapers: "pañales"
        case .weight: "kg"
        case .height: "cm"
        }
    }

    private var formattedValue: String {
        if snapshot.metric == .sleep, let value = snapshot.meanValue {
            let minutes = Int((value / 60).rounded())
            return "\(minutes / 60) h \(minutes % 60) min"
        }
        return "\(number) \(unit)"
    }

    private var coverageLabel: String {
        isGrowth ? "Última medición" : "\(snapshot.daysWithRecords) de \(snapshot.periodDays) días con registros"
    }

    private var dateLabel: String {
        if let dateLabelOverride { return dateLabelOverride }
        if isGrowth {
            guard let date = snapshot.latestMeasurementDate else { return "" }
            return date.formatted(.dateTime.locale(locale).day().month(.abbreviated))
        }
        let end = calendar.date(byAdding: .day, value: -1, to: snapshot.periodEnd) ?? snapshot.periodEnd
        let startMonth = snapshot.periodStart.formatted(.dateTime.locale(locale).month(.abbreviated))
        let endMonth = end.formatted(.dateTime.locale(locale).month(.abbreviated))
        let startDay = snapshot.periodStart.formatted(.dateTime.locale(locale).day())
        let endDay = end.formatted(.dateTime.locale(locale).day())
        return startMonth == endMonth ? "\(startDay)–\(endDay) \(endMonth)" : "\(startDay) \(startMonth)–\(endDay) \(endMonth)"
    }
}
