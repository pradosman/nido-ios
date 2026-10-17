import SwiftUI

enum TimelineLane: CaseIterable, Identifiable {
    case sleep
    case feeds
    case diapers
    case care

    var id: Self { self }

    var kind: EntryKind {
        switch self {
        case .sleep: .sleep
        case .feeds: .feed
        case .diapers: .diaper
        case .care: .health
        }
    }

    var title: String {
        switch self {
        case .sleep: "Sueño"
        case .feeds: "Tomas"
        case .diapers: "Pañales"
        case .care: "Cuidados"
        }
    }

}

struct CircularTimelineDayView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let day: CircularTimeline.Day
    @Binding var selectedEntryID: String?
    @Binding var expandedClusterID: String?
    var onSelectCategory: ((EntryKind) -> Void)? = nil

    private var selectedItem: CircularTimeline.Item? {
        guard let selectedEntryID else { return nil }
        return day.items.first(where: { $0.entry.id == selectedEntryID })
    }

    private var expandedCluster: CircularTimeline.MarkerGroup? {
        guard let expandedClusterID else { return nil }
        return day.unifiedMarkerGroups.first { $0.id == expandedClusterID }
    }

    var body: some View {
        VStack(spacing: 8) {
            dial
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 280 : 306)
            if !dynamicTypeSize.isAccessibilitySize {
                TimelineDayTotals(day: day, onSelectCategory: onSelectCategory)
                    .frame(maxWidth: 340)
            }
            if dynamicTypeSize.isAccessibilitySize {
                TimelineCategoryLegend(day: day, onSelectCategory: onSelectCategory)
                AccessibilityTimelineDetail(
                    day: day,
                    item: selectedItem
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var dial: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let geometry = CircularTimeline.Geometry(side: side)
            let sleepStroke = geometry.trackStroke
            let markerDiameter = 22 * side / 340

            ZStack {
                dialFace(geometry: geometry, sleepStroke: sleepStroke)

                ForEach(day.sleepSegments) { segment in
                    SleepArc(segment: segment, strokeWidth: sleepStroke)
                        .frame(width: geometry.feedRadius * 2, height: geometry.feedRadius * 2)
                }

                if expandedCluster == nil {
                    DialCenterContent(day: day, item: selectedItem, diameter: geometry.unifiedCenterDiameter)
                }

                if let nowMarker = day.nowMarker {
                    nowMarkerView(nowMarker, center: center, geometry: geometry)
                        .zIndex(2.5)
                }

                markerLayer(center: center, geometry: geometry, markerDiameter: markerDiameter)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Tomas, pañales y cuidados sobre el mismo anillo de 24 horas")
                    .accessibilityIdentifier("timeline-point-markers")

                clockNumberOverlay(geometry: geometry)
                    .allowsHitTesting(false)
                    .zIndex(2)

                if let expandedCluster {
                    ExpandedTimelineCluster(
                        group: expandedCluster,
                        selectedEntryID: $selectedEntryID,
                        onClose: { expandedClusterID = nil }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(3)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Cronología circular de 24 horas")
            .accessibilityIdentifier("timeline-circular-dial")
        }
    }

    private func dialFace(
        geometry: CircularTimeline.Geometry,
        sleepStroke: CGFloat
    ) -> some View {
        ZStack {
            Circle()
                .stroke(
                    NidoTheme.chartAccent(for: .sleep).opacity(0.12),
                    style: StrokeStyle(lineWidth: sleepStroke, lineCap: .round)
                )
                .frame(width: geometry.feedRadius * 2, height: geometry.feedRadius * 2)
                .accessibilityElement()
                .accessibilityLabel("Anillo civil de 24 horas")
                .accessibilityIdentifier("timeline-day-ring")

            ClockTickDots(geometry: geometry)
                .frame(width: geometry.side, height: geometry.side)
        }
    }

    private func markerLayer(
        center: CGPoint,
        geometry: CircularTimeline.Geometry,
        markerDiameter: CGFloat
    ) -> some View {
        let radius = geometry.unifiedEventRadius
        return ZStack {
            ForEach(day.unifiedMarkerGroups) { group in
                Group {
                    if group.isCluster {
                        clusterMarker(for: group, visualDiameter: markerDiameter)
                    } else if let item = group.items.first {
                        eventMarker(
                            for: item,
                            visualDiameter: markerDiameter
                        )
                    }
                }
                .position(position(angle: group.angle, center: center, radius: radius))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func position(angle: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let radians = angle * .pi / 180
        return CGPoint(
            x: center.x + sin(radians) * radius,
            y: center.y - cos(radians) * radius
        )
    }

    private func clockNumberOverlay(geometry: CircularTimeline.Geometry) -> some View {
        ZStack {
            ForEach(CircularTimeline.clockScale) { position in
                if case let .number(hour) = position.mark {
                    cardinalLabel(
                        hour: hour,
                        meaning: clockNumberMeaning(hour),
                        minute: position.minute,
                        geometry: geometry
                    )
                }
            }
        }
    }

    private func cardinalLabel(
        hour: Int,
        meaning: String,
        minute: Int,
        geometry: CircularTimeline.Geometry
    ) -> some View {
        let frame = geometry.cardinalFrame(atMinute: minute)
        let size = geometry.cardinalSize(atMinute: minute)
        return cardinalTime(String(format: "%02d", hour))
            .foregroundStyle(NidoTheme.readableSupportingInk)
            .frame(width: size.width, height: size.height)
            .position(x: frame.midX, y: frame.midY)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(format: "%02d:00, %@", hour, meaning))
            .accessibilityIdentifier("timeline-cardinal-\(minute)")
    }

    private func clockNumberMeaning(_ hour: Int) -> String {
        switch hour {
        case 0: "Medianoche"
        case 3: "Tres de la madrugada"
        case 6: "Seis de la mañana"
        case 9: "Nueve de la mañana"
        case 12: "Mediodía"
        case 15: "Tres de la tarde"
        case 18: "Seis de la tarde"
        case 21: "Nueve de la noche"
        default: "Hora"
        }
    }

    private func cardinalTime(_ hour: String) -> some View {
        Text(hour)
            .font(.system(size: 12, weight: .semibold))
            .monospacedDigit()
            .tracking(0.1)
    }

    private func nowMarkerView(
        _ marker: CircularTimeline.NowMarker,
        center: CGPoint,
        geometry: CircularTimeline.Geometry
    ) -> some View {
        Circle()
            .fill(NidoTheme.moss)
            .frame(width: min(10, geometry.nowVisualDiameter), height: min(10, geometry.nowVisualDiameter))
            .frame(width: geometry.interactionDiameter, height: geometry.interactionDiameter)
            .position(position(angle: marker.angle, center: center, radius: geometry.feedRadius))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func eventMarker(for item: CircularTimeline.Item, visualDiameter: CGFloat) -> some View {
        Button {
            selectedEntryID = item.entry.id
        } label: {
            ZStack {
                Color.clear
                Circle()
                    .fill(NidoTheme.chartAccent(for: item.entry.kind))
                    .frame(
                        width: selectedEntryID == item.entry.id ? visualDiameter + 4 : visualDiameter,
                        height: selectedEntryID == item.entry.id ? visualDiameter + 4 : visualDiameter
                    )
                    .overlay {
                        Image(systemName: item.entry.kind.symbolName)
                            .font(.system(size: visualDiameter * 0.48, weight: .semibold))
                            .foregroundStyle(NidoTheme.textOnEvent)
                    }
                    .overlay {
                        Circle().stroke(
                            Color.white.opacity(selectedEntryID == item.entry.id ? 1 : 0.8),
                            lineWidth: selectedEntryID == item.entry.id ? 2 : 1
                        )
                    }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in store.editingEntry = item.entry }
        )
        .accessibilityLabel(accessibilityLabel(for: item))
        .accessibilityHint("Toca para ver el detalle. Mantén pulsado para editar.")
        .accessibilityIdentifier("timeline-event-\(item.entry.id)")
        .accessibilitySortPriority(Double(1_440 - item.startMinute))
        .accessibilityAction(named: Text("Editar")) {
            store.editingEntry = item.entry
        }
    }

    private func clusterMarker(
        for group: CircularTimeline.MarkerGroup,
        visualDiameter: CGFloat
    ) -> some View {
        let markerKinds = [EntryKind.feed, .diaper, .health].filter { kind in
            group.items.contains { $0.entry.kind == kind }
        }
        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                expandedClusterID = group.id
            }
        } label: {
            ZStack {
                Circle()
                    .fill(group.isMixedCategory ? NidoTheme.paperLight : NidoTheme.chartAccent(for: group.kind))
                if group.isMixedCategory {
                    ForEach(markerKinds.indices, id: \.self) { index in
                        Circle()
                            .trim(
                                from: CGFloat(index) / CGFloat(markerKinds.count),
                                to: CGFloat(index + 1) / CGFloat(markerKinds.count)
                            )
                            .stroke(NidoTheme.chartAccent(for: markerKinds[index]), lineWidth: 2)
                            .rotationEffect(.degrees(-90))
                    }
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 1.1)
                }
                Text("\(group.items.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(group.isMixedCategory ? NidoTheme.ink : NidoTheme.textOnEvent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: max(21, visualDiameter), height: max(21, visualDiameter))
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(clusterAccessibilityLabel(for: group))
        .accessibilityHint("Toca para ver todos los registros.")
        .accessibilityIdentifier("timeline-cluster-\(group.isMixedCategory ? "all" : group.kind.rawValue)-\(group.minute)")
        .accessibilitySortPriority(Double(1_440 - group.minute))
    }

    private func clusterAccessibilityLabel(for group: CircularTimeline.MarkerGroup) -> String {
        guard let first = group.items.first, let last = group.items.last else { return "Grupo de registros" }
        let range: String
        if first.startMinute == last.startMinute {
            range = "a las \(clockLabel(first.startMinute))"
        } else {
            range = "de \(clockLabel(first.startMinute)) a \(clockLabel(last.startMinute))"
        }
        let categories = [EntryKind.feed, .diaper, .health].compactMap { kind -> String? in
            let count = group.items.count { $0.entry.kind == kind }
            guard count > 0 else { return nil }
            let noun: String
            switch kind {
            case .feed: noun = count == 1 ? "toma" : "tomas"
            case .diaper: noun = count == 1 ? "pañal" : "pañales"
            default: noun = count == 1 ? "cuidado" : "cuidados"
            }
            return "\(count) \(noun)"
        }.joined(separator: ", ")
        return "\(group.items.count) registros, \(categories), \(range)"
    }

    private func accessibilityLabel(for item: CircularTimeline.Item) -> String {
        let moment: String
        if item.presentation == .sleepSegment {
            moment = "de \(clockLabel(item.startMinute)) a \(clockLabel(item.endMinute))"
        } else {
            moment = item.entry.date.formatted(date: .omitted, time: .shortened)
        }
        return [item.entry.title, moment, item.entry.summary]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func clockLabel(_ minute: Int) -> String {
        let normalized = min(max(minute, 0), 1_440)
        if normalized == 1_440 { return "24:00" }
        return String(format: "%02d:%02d", normalized / 60, normalized % 60)
    }

}

private struct ExpandedTimelineCluster: View {
    @Environment(NidoStore.self) private var store

    let group: CircularTimeline.MarkerGroup
    @Binding var selectedEntryID: String?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(group.items.count) registros")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NidoTheme.ink)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Cerrar registros")
            }
            .padding(.leading, 16)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(group.items) { item in
                        Button {
                            selectedEntryID = item.entry.id
                            onClose()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: item.entry.kind.symbolName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(NidoTheme.color(for: item.entry.kind))
                                    .frame(width: 24)
                                Text(item.entry.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(NidoTheme.ink)
                                Spacer(minLength: 8)
                                Text(clockLabel(item.startMinute))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(NidoTheme.secondaryInk)
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in store.editingEntry = item.entry }
                        )
                        .accessibilityLabel(accessibilityLabel(for: item))
                        .accessibilityHint("Toca para ver el detalle. Mantén pulsado para editar.")
                        .accessibilityIdentifier("timeline-expanded-\(item.entry.id)")
                        .accessibilitySortPriority(Double(1_440 - item.startMinute))
                        .accessibilityAction(named: Text("Editar")) {
                            store.editingEntry = item.entry
                        }
                    }
                }
            }
        }
        .frame(width: 252, height: min(CGFloat(group.items.count * 44 + 45), 296))
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(NidoTheme.separator.opacity(0.5), lineWidth: 0.5)
        }
        .shadow(color: NidoTheme.ink.opacity(0.14), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(group.items.count) registros agrupados")
        .accessibilityIdentifier("timeline-cluster-expanded")
    }

    private func accessibilityLabel(for item: CircularTimeline.Item) -> String {
        [item.entry.title, clockLabel(item.startMinute), item.entry.summary]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func clockLabel(_ minute: Int) -> String {
        let normalized = min(max(minute, 0), 1_440)
        if normalized == 1_440 { return "24:00" }
        return String(format: "%02d:%02d", normalized / 60, normalized % 60)
    }
}

private struct ClockTickDots: View {
    let geometry: CircularTimeline.Geometry

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = geometry.tickRadius

            for position in CircularTimeline.clockScale {
                guard case let .dot(kind) = position.mark else { continue }
                let angle = Double(position.minute) / 1_440 * 2 * Double.pi - Double.pi / 2
                let diameter = geometry.clockDotDiameter(for: kind) * 0.62
                let point = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                let rect = CGRect(
                    x: point.x - diameter / 2,
                    y: point.y - diameter / 2,
                    width: diameter,
                    height: diameter
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(NidoTheme.secondaryInk.opacity(kind == .wholeHour ? 0.32 : 0.22))
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("Escala de 24 horas con marcas cada 30 minutos")
        .accessibilityIdentifier("timeline-clock-ticks")
    }
}

private struct SleepArc: View {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme

    let startMinute: Int
    let endMinute: Int
    let isActive: Bool
    let strokeWidth: CGFloat

    init(segment: CircularTimeline.SleepSegment, strokeWidth: CGFloat) {
        startMinute = segment.startMinute
        endMinute = segment.endMinute
        isActive = segment.isActive
        self.strokeWidth = strokeWidth
    }

    var body: some View {
        GeometryReader { proxy in
            let radius = min(proxy.size.width, proxy.size.height) / 2
            let arc = CircularTimeline.RoundedArcGeometry(
                startMinute: startMinute,
                endMinute: endMinute,
                radius: radius,
                strokeWidth: strokeWidth
            )
            let endAngle = Double(arc.endFraction) * 2 * .pi - .pi / 2
            let highlight = contrast == .increased ? NidoTheme.sleep : endColor

            ZStack {
                Circle()
                    .trim(from: arc.startFraction, to: arc.endFraction)
                    .stroke(
                        AngularGradient(
                            colors: contrast == .increased
                                ? [NidoTheme.sleep, NidoTheme.sleep]
                                : [startColor, endColor],
                            center: .center,
                            startAngle: .degrees(Double(arc.startFraction) * 360),
                            endAngle: .degrees(Double(arc.endFraction) * 360)
                        ),
                        style: StrokeStyle(lineWidth: arc.strokeWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                if arc.strokeWidth > 0, arc.endFraction - arc.startFraction < 0.0001 {
                    Circle()
                        .fill(highlight)
                        .frame(width: arc.strokeWidth, height: arc.strokeWidth)
                        .position(
                            x: proxy.size.width / 2 + radius * cos(endAngle),
                            y: proxy.size.height / 2 + radius * sin(endAngle)
                        )
                        .mask {
                            Circle().stroke(lineWidth: strokeWidth)
                        }
                }
            }
            .compositingGroup()
            .opacity(isActive ? 0.9 : 1)
        }
        .accessibilityHidden(true)
    }

    private var startColor: Color {
        Color(.displayP3, red: 224.0 / 255, green: 58.0 / 255, blue: 94.0 / 255)
    }

    private var endColor: Color {
        Color(.displayP3, red: 233.0 / 255, green: 71.0 / 255, blue: 131.0 / 255)
    }
}

private func timelineDurationLabel(_ seconds: Int) -> String {
    let totalMinutes = max(0, seconds) / 60
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours == 0 { return "\(minutes) min" }
    if minutes == 0 { return "\(hours) h" }
    return "\(hours) h \(minutes) min"
}

private struct TimelineDayTotals: View {
    let day: CircularTimeline.Day
    var onSelectCategory: ((EntryKind) -> Void)? = nil

    var body: some View {
        VStack(spacing: 7) {
            HStack(alignment: .top, spacing: 0) {
                totalColumn(
                    title: "Sueño",
                    value: timelineDurationLabel(day.totalSleepSeconds),
                    kind: .sleep
                )
                totalColumn(title: "Tomas", value: "\(day.feedCount)", kind: .feed)
                totalColumn(title: "Pañales", value: "\(day.diaperCount)", kind: .diaper)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeline-day-totals")
    }

    @ViewBuilder
    private func totalColumn(title: String, value: String, kind: EntryKind) -> some View {
        if let onSelectCategory {
            Button { onSelectCategory(kind) } label: {
                totalContent(title: title, value: value, kind: kind)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Muestra el gráfico horario")
            .accessibilityIdentifier("history-summary-\(kind.rawValue)")
        } else {
            totalContent(title: title, value: value, kind: kind)
        }
    }

    private func totalContent(title: String, value: String, kind: EntryKind) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: kind.symbolName)
                    .foregroundStyle(NidoTheme.chartAccent(for: kind))
            }
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(NidoTheme.ink)
            Text(styledValue(value))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(NidoTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }

    private func styledValue(_ value: String) -> AttributedString {
        var result = AttributedString()
        for (index, part) in value.split(separator: " ").enumerated() {
            if index > 0 { result.append(AttributedString(" ")) }
            var run = AttributedString(String(part))
            run.font = .system(
                size: Int(part) == nil ? 12 : 22,
                weight: Int(part) == nil ? .medium : .semibold,
                design: .rounded
            )
            result.append(run)
        }
        return result
    }
}

struct TimelineCareSummary: View {
    let count: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: EntryKind.health.symbolName)
                .font(.caption.weight(.semibold))
            Text(count == 1 ? "1 cuidado" : "\(count) cuidados")
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(NidoTheme.color(for: .health))
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("timeline-care-summary")
    }
}

private struct TimelineCategoryLegend: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let day: CircularTimeline.Day
    var onSelectCategory: ((EntryKind) -> Void)? = nil

    private let ringLanes: [TimelineLane] = [.sleep, .feeds, .diapers]

    var body: some View {
        if let onSelectCategory, dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(ringLanes) { lane in
                    Button { onSelectCategory(lane.kind) } label: {
                        accessibilityLegendRow(lane)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Muestra el gráfico horario")
                    .accessibilityIdentifier("history-summary-\(lane.kind.rawValue)")
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
        } else {
            staticLegend
        }
    }

    private var staticLegend: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(ringLanes) { lane in
                        accessibilityLegendRow(lane)
                    }
                }
            } else {
                HStack(spacing: 4) {
                    ForEach(ringLanes) { lane in
                        compactLegendColumn(lane)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("timeline-category-legend")
        .accessibilitySortPriority(1_450)
    }

    private func compactLegendColumn(_ lane: TimelineLane) -> some View {
        VStack(spacing: 2) {
            Image(systemName: lane.kind.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(NidoTheme.color(for: lane.kind))
            Text(lane.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NidoTheme.ink)
                .lineLimit(1)
            Text(summary(for: lane))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(NidoTheme.secondaryInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }

    private func accessibilityLegendRow(_ lane: TimelineLane) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(lane.title, systemImage: lane.kind.symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(NidoTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(summary(for: lane))
                .font(.body.monospacedDigit())
                .foregroundStyle(NidoTheme.readableSupportingInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    private var accessibilityLabel: String {
        ringLanes
            .map { "\($0.title), \(summary(for: $0))" }
            .joined(separator: ". ")
    }

    private func summary(for lane: TimelineLane) -> String {
        if lane == .sleep {
            return timelineDurationLabel(day.totalSleepSeconds)
        }
        let count = lane == .feeds ? day.feedCount : day.diaperCount
        return "\(count)"
    }

}

private struct DialCenterContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let day: CircularTimeline.Day
    let item: CircularTimeline.Item?
    let diameter: CGFloat

    var body: some View {
        ZStack {
            VStack(spacing: 5) {
                TimelineNestMark()
                    .frame(width: 22, height: 22)
                Text(clockTime)
                    .font(.system(size: min(30, diameter * 0.22), weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(NidoTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.opacity)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: item?.entry.id)
                Text(item == nil ? (day.nowMarker == nil ? "Ese día" : "Ahora") : "Seleccionado")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NidoTheme.readableSupportingInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: min(126, diameter * 0.84))
            .accessibilityHidden(true)

            Color.clear
                .frame(width: 126, height: 92)
                .accessibilityElement()
                .accessibilityLabel(accessibilityLabel)
                .accessibilityIdentifier(item == nil ? "timeline-dial-default-summary" : "timeline-dial-center-detail")
        }
        .frame(width: 126, height: 92)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sueño, duración \(CircularTimeline.dashboardDurationAccessibilityLabel(day.totalSleepSeconds)), \(day.feedCount) tomas, \(day.diaperCount) pañales")
        .accessibilityIdentifier("timeline-center-summary")
    }

    private var accessibilityLabel: String {
        if let item {
            return [item.entry.title, clockTime, item.entry.summary]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        }
        let count = day.items.count
        let noun = count == 1 ? "registro" : "registros"
        let dayLabel = day.nowMarker == nil ? "ese día" : "hoy"
        let timeLabel = day.nowMarker == nil ? "" : ", Ahora, \(clockTime)"
        return "\(count) \(noun) \(dayLabel)\(timeLabel)"
    }

    private var clockTime: String {
        if let item { return clockLabel(item.startMinute) }
        if let nowMarker = day.nowMarker { return clockLabel(nowMarker.minute) }
        return day.date.formatted(.dateTime.day().month(.abbreviated))
    }

    private func clockLabel(_ minute: Int) -> String {
        let normalized = min(max(minute, 0), 1_440)
        if normalized == 1_440 { return "24:00" }
        return String(format: "%02d:%02d", normalized / 60, normalized % 60)
    }
}

private struct TimelineNestMark: View {
    var body: some View {
        Canvas { context, size in
            let unit = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            var crescent = Path()
            crescent.addEllipse(in: CGRect(x: center.x - unit * 0.19, y: center.y - unit * 0.27, width: unit * 0.40, height: unit * 0.40))
            crescent.addEllipse(in: CGRect(x: center.x - unit * 0.07, y: center.y - unit * 0.32, width: unit * 0.36, height: unit * 0.36))
            context.fill(crescent, with: .color(NidoTheme.moss), style: FillStyle(eoFill: true))

            for radius in [unit * 0.24, unit * 0.34] {
                var nest = Path()
                nest.addArc(
                    center: CGPoint(x: center.x, y: center.y + unit * 0.03),
                    radius: radius,
                    startAngle: .degrees(28),
                    endAngle: .degrees(152),
                    clockwise: false
                )
                context.stroke(
                    nest,
                    with: .color(NidoTheme.moss.opacity(radius > unit * 0.3 ? 0.58 : 0.82)),
                    style: StrokeStyle(lineWidth: max(1, unit * 0.05), lineCap: .round)
                )
            }
        }
        .accessibilityHidden(true)
    }
}

private struct AccessibilityTimelineDetail: View {
    let day: CircularTimeline.Day
    let item: CircularTimeline.Item?

    private var isSleeping: Bool { day.activeSleep != nil && item == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: symbolName)
                    .foregroundStyle(color)
                    .frame(width: 32, height: 44)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(NidoTheme.ink)
            }
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.body)
                    .foregroundStyle(NidoTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(NidoTheme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("timeline-accessibility-detail")
    }

    private var title: String {
        if let item { return item.entry.title }
        if isSleeping { return "Sueño en curso" }
        if let nowMarker = day.nowMarker { return "Ahora · \(clockLabel(nowMarker.minute))" }
        return day.date.formatted(.dateTime.day().month(.abbreviated))
    }

    private var detail: String? {
        guard let item else {
            let count = day.items.count
            let noun = count == 1 ? "registro" : "registros"
            if isSleeping { return "Ahora · \(count) \(noun) hoy · Arcos azules: sueño" }
            let suffix = day.nowMarker == nil ? "ese día" : "hoy"
            return "\(count) \(noun) \(suffix) · Arcos azules: sueño"
        }
        let moment: String
        if item.presentation == .sleepSegment {
            moment = "\(clockLabel(item.startMinute))–\(clockLabel(item.endMinute))"
        } else {
            moment = item.entry.date.formatted(date: .omitted, time: .shortened)
        }
        return [moment, item.entry.summary].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var symbolName: String {
        if let item { return item.entry.kind.symbolName }
        return isSleeping ? EntryKind.sleep.symbolName : "ellipsis"
    }

    private var color: Color {
        if let item { return NidoTheme.color(for: item.entry.kind) }
        return isSleeping ? NidoTheme.sleep : NidoTheme.secondaryInk
    }

    private func clockLabel(_ minute: Int) -> String {
        let normalized = min(max(minute, 0), 1_440)
        if normalized == 1_440 { return "24:00" }
        return String(format: "%02d:%02d", normalized / 60, normalized % 60)
    }
}
