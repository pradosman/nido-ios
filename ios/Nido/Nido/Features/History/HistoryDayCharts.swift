import Charts
import SwiftUI

struct HistoryDayCharts: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let snapshot: HistoryAnalytics.Snapshot
    @Binding var selectedBins: [EntryKind: Date]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            section(.sleep)
            section(.feed)
            section(.diaper)
        }
    }

    @ViewBuilder
    private func section(_ kind: EntryKind) -> some View {
        let total = totalText(for: kind)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title(for: kind)).font(.system(.title3, design: .serif, weight: .semibold)).foregroundStyle(NidoTheme.ink)
                Spacer()
                Text(total).font(.system(.title3, design: .rounded, weight: .semibold).monospacedDigit()).foregroundStyle(NidoTheme.ink)
            }
            if kind == .sleep && snapshot.bins.contains(where: \.hasOverlappingSleep) {
                Text("Algunos registros de sueño se solapan; sus duraciones se suman.")
                    .font(.caption)
                    .foregroundStyle(NidoTheme.secondaryInk)
            }
            hourlyChart(kind)
                .frame(height: 136)
            if selectedBins[kind] != nil {
                selectedInterval(kind)
                    .accessibilityIdentifier("history-chart-selection")
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history-section-\(kind.rawValue)")
        .id("history-section-\(kind.rawValue)")
        .background {
            GeometryReader { geometry in
                let frame = geometry.frame(in: .named("history-detail-scroll"))
                Color.clear.preference(
                    key: HistoryVisibleSectionPreferenceKey.self,
                    value: [HistorySectionPosition(
                        kind: kind,
                        minY: frame.minY,
                        maxY: frame.maxY
                    )]
                )
            }
        }
    }

    private func hourlyChart(_ kind: EntryKind) -> some View {
        Chart {
            ForEach(snapshot.bins) { bin in
                if kind != .sleep && value(for: bin, kind: kind) == 0 {
                    PointMark(x: .value("Intervalo sin registro", bin.start.addingTimeInterval(bin.end.timeIntervalSince(bin.start) / 2)), y: .value("Base", 0.04))
                        .foregroundStyle(NidoTheme.chartAccent(for: kind).opacity(0.28))
                        .symbolSize(2)
                }
                BarMark(
                    x: .value("Hora", bin.start.addingTimeInterval(bin.end.timeIntervalSince(bin.start) / 2)),
                    yStart: .value("Base", 0),
                    yEnd: .value(axisTitle(for: kind), value(for: bin, kind: kind)),
                    width: .fixed(2.2)
                )
                .foregroundStyle(NidoTheme.chartAccent(for: kind))
                .cornerRadius(2)
                if selectedBins[kind] == bin.start {
                    RuleMark(x: .value("Intervalo seleccionado", bin.start))
                        .foregroundStyle(NidoTheme.ink.opacity(0.65))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
        }
        .chartXScale(domain: chartDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                AxisTick().foregroundStyle(NidoTheme.separator)
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                    .foregroundStyle(NidoTheme.secondaryInk)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(NidoTheme.separator.opacity(0.24))
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(axisLabel(amount, kind: kind)).font(.caption2).foregroundStyle(NidoTheme.secondaryInk)
                    }
                }
            }
        }
        .chartYScale(domain: 0...axisMaximum(for: kind))
        .chartXSelection(value: Binding<Date?>(
            get: { selectedBins[kind] },
            set: { date in
                guard let date else { return }
                selectBin(containing: date, kind: kind)
            }
        ))
        .chartGesture { proxy in
            SpatialTapGesture().onEnded { tap in
                proxy.selectXValue(at: tap.location.x)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gráfico horario de \(title(for: kind).lowercased())")
        .accessibilityValue(accessibleSelection(for: kind))
        .accessibilityHint("Toca una franja de quince minutos. Desliza arriba o abajo para recorrer los intervalos")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("history-chart-\(kind.rawValue)")
        .accessibilityAdjustableAction { direction in adjustSelection(kind, direction: direction) }
        .accessibilityAction {
            if selectedBins[kind] == nil, let first = snapshot.bins.first {
                selectedBins[kind] = first.start
            }
        }
    }

    private var chartDomain: ClosedRange<Date> {
        guard let first = snapshot.bins.first, let last = snapshot.bins.last else {
            let start = snapshot.day.date
            return start...start.addingTimeInterval(86_400)
        }
        return first.start...last.end
    }

    private func selectedInterval(_ kind: EntryKind) -> some View {
        let bin = selectedBins[kind].flatMap { start in snapshot.bins.first { $0.start == start } }
        let entries = bin.map { relatedEntries(for: $0, kind: kind) } ?? []
        return VStack(alignment: .leading, spacing: 7) {
            if let bin {
                HStack {
                    Text(timeRangeLabel(bin))
                        .font(.caption.weight(.semibold).monospacedDigit()).foregroundStyle(NidoTheme.secondaryInk)
                    Spacer()
                    Text(valueLabel(for: bin, kind: kind)).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(NidoTheme.ink)
                }
                if entries.isEmpty {
                    Text(kind == .sleep && snapshot.day.activeSleep != nil && bin.sleepSeconds > 0
                         ? "Sueño en curso en este intervalo"
                         : "Sin registros en este intervalo")
                        .font(.caption).foregroundStyle(NidoTheme.secondaryInk)
                } else {
                    ForEach(entries) { entry in
                        Button { store.editingEntry = entry } label: {
                            HStack(spacing: 7) {
                                Circle().fill(NidoTheme.chartAccent(for: kind)).frame(width: 6, height: 6)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.title).font(.subheadline.weight(.medium)).foregroundStyle(NidoTheme.ink)
                                    if !entry.summary.isEmpty {
                                        Text(entry.summary).font(.subheadline).foregroundStyle(NidoTheme.secondaryInk)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                Spacer(minLength: 4)
                                Text(entry.date.formatted(date: .omitted, time: .shortened)).font(.caption2.monospacedDigit()).foregroundStyle(NidoTheme.secondaryInk)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(entry.title), \(entry.summary), \(entry.date.formatted(date: .omitted, time: .shortened))")
                    }
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NidoTheme.surface.opacity(0.75), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func relatedEntries(for bin: HistoryAnalytics.Bin, kind: EntryKind) -> [Entry] {
        let ids = Set(bin.entryIDs(for: kind))
        return snapshot.entries.filter { ids.contains($0.id) }
    }

    private func selectBin(containing date: Date, kind: EntryKind) {
        guard let bin = snapshot.bins.first(where: { date >= $0.start && date < $0.end }) ?? snapshot.bins.last(where: { $0.start <= date }) else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) { selectedBins[kind] = bin.start }
    }

    private func accessibleSelection(for kind: EntryKind) -> String {
        guard let start = selectedBins[kind], let bin = snapshot.bins.first(where: { $0.start == start }) else {
            return "Sin intervalo seleccionado"
        }
        return "\(timeRangeLabel(bin)), \(valueLabel(for: bin, kind: kind))"
    }

    private func value(for bin: HistoryAnalytics.Bin, kind: EntryKind) -> Double {
        switch kind {
        case .sleep: Double(bin.sleepSeconds) / 60
        case .feed: Double(bin.feedCount)
        case .diaper: Double(bin.diaperCount)
        case .health: 0
        }
    }

    private func axisMaximum(for kind: EntryKind) -> Double {
        let maximum = snapshot.bins.map { value(for: $0, kind: kind) }.max() ?? 0
        let step: Double = kind == .sleep ? 15 : 3
        return max(step, ceil(maximum / step) * step)
    }

    private func adjustSelection(_ kind: EntryKind, direction: AccessibilityAdjustmentDirection) {
        guard !snapshot.bins.isEmpty else { return }
        let current = selectedBins[kind].flatMap { date in snapshot.bins.firstIndex { $0.start == date } } ?? 0
        let next = direction == .increment ? min(current + 1, snapshot.bins.count - 1) : max(current - 1, 0)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) { selectedBins[kind] = snapshot.bins[next].start }
    }

    private func timeRangeLabel(_ bin: HistoryAnalytics.Bin) -> String {
        let startOffset = TimeZone.current.secondsFromGMT(for: bin.start)
        let endOffset = TimeZone.current.secondsFromGMT(for: bin.end)
        let offsets = startOffset == endOffset ? utcOffset(startOffset) : "\(utcOffset(startOffset)) → \(utcOffset(endOffset))"
        return "\(bin.start.formatted(date: .omitted, time: .shortened))–\(bin.end.formatted(date: .omitted, time: .shortened)) · \(offsets)"
    }

    private func utcOffset(_ seconds: Int) -> String {
        let sign = seconds >= 0 ? "+" : "−"
        let minutes = abs(seconds) / 60
        return "UTC\(sign)\(String(format: "%02d:%02d", minutes / 60, minutes % 60))"
    }

    private func totalText(for kind: EntryKind) -> String {
        switch kind {
        case .sleep: DurationLabel.minutes(snapshot.day.totalSleepSeconds / 60)
        case .feed: "\(snapshot.day.feedCount)"
        case .diaper: "\(snapshot.day.diaperCount)"
        case .health: "0"
        }
    }

    private func valueLabel(for bin: HistoryAnalytics.Bin, kind: EntryKind) -> String {
        switch kind {
        case .sleep: DurationLabel.minutes(bin.sleepSeconds / 60)
        case .feed: bin.feedCount == 1 ? "1 toma" : "\(bin.feedCount) tomas"
        case .diaper: bin.diaperCount == 1 ? "1 pañal" : "\(bin.diaperCount) pañales"
        case .health: ""
        }
    }

    private func axisTitle(for kind: EntryKind) -> String {
        kind == .sleep ? "Minutos" : "Registros"
    }

    private func axisLabel(_ value: Double, kind: EntryKind) -> String {
        kind == .sleep ? "\(Int(value)) min" : "\(Int(value))"
    }

    private func title(for kind: EntryKind) -> String {
        switch kind { case .sleep: "Sueño"; case .feed: "Tomas"; case .diaper: "Pañales"; case .health: "Cuidados" }
    }
}

struct HistorySectionPosition: Equatable {
    let kind: EntryKind
    let minY: CGFloat
    let maxY: CGFloat
}

struct HistoryVisibleSectionPreferenceKey: PreferenceKey {
    static let defaultValue: [HistorySectionPosition] = []
    static func reduce(value: inout [HistorySectionPosition], nextValue: () -> [HistorySectionPosition]) {
        value.append(contentsOf: nextValue())
    }
}
