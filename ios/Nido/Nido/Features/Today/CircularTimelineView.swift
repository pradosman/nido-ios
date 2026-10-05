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

    private var selectedItem: CircularTimeline.Item? {
        guard let selectedEntryID else { return nil }
        return day.items.first(where: { $0.entry.id == selectedEntryID })
    }

    private var expandedCluster: CircularTimeline.MarkerGroup? {
        guard let expandedClusterID else { return nil }
        return day.markerGroups.first { $0.id == expandedClusterID }
    }

    var body: some View {
        VStack(spacing: 10) {
            dial
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 280 : 360)
                .aspectRatio(1, contentMode: .fit)
            if dynamicTypeSize.isAccessibilitySize {
                TimelineCategoryLegend(day: day)
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

            ZStack {
                dialFace(geometry: geometry)

                ForEach(day.sleepSegments) { segment in
                    SleepArc(segment: segment, strokeWidth: geometry.trackStroke)
                        .frame(width: geometry.ringDiameter, height: geometry.ringDiameter)
                }

                if expandedCluster == nil {
                    if dynamicTypeSize.isAccessibilitySize || selectedItem != nil {
                        DialCenterContent(
                            day: day,
                            item: selectedItem,
                            compact: dynamicTypeSize.isAccessibilitySize
                        )
                    } else {
                        DashboardCenterSummary(day: day, geometry: geometry)
                    }
                }

                if let nowMarker = day.nowMarker {
                    nowMarkerView(nowMarker, center: center, geometry: geometry)
                        .zIndex(2.5)
                }

                markerLayer(kind: .feed, center: center, geometry: geometry)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Tomas, marcadores fuera del anillo")
                    .accessibilityIdentifier("timeline-feed-markers")

                markerLayer(kind: .diaper, center: center, geometry: geometry)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Pañales, marcadores dentro del anillo")
                    .accessibilityIdentifier("timeline-diaper-markers")

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

    private func dialFace(geometry: CircularTimeline.Geometry) -> some View {
        ZStack {
            Circle()
                .fill(NidoTheme.paperLight.opacity(0.88))
                .padding(geometry.faceInset)
                .overlay {
                    Circle()
                        .stroke(NidoTheme.separator.opacity(0.24), lineWidth: 1)
                        .padding(geometry.faceInset)
                }
                .shadow(color: NidoTheme.ink.opacity(0.07), radius: 12, y: 5)

            Circle()
                .stroke(NidoTheme.feed.opacity(0.20), lineWidth: geometry.trackStroke)
                .frame(width: geometry.feedRadius * 2, height: geometry.feedRadius * 2)

            Circle()
                .stroke(
                    NidoTheme.sleep.opacity(0.12),
                    style: StrokeStyle(lineWidth: geometry.trackStroke, lineCap: .round)
                )
                .overlay {
                    Circle()
                        .stroke(NidoTheme.sleep.opacity(0.10), lineWidth: 1)
                }
                .frame(width: geometry.ringDiameter, height: geometry.ringDiameter)
                .accessibilityElement()
                .accessibilityLabel("Anillo civil de 24 horas")
                .accessibilityIdentifier("timeline-day-ring")

            Circle()
                .stroke(NidoTheme.diaper.opacity(0.20), lineWidth: geometry.trackStroke)
                .frame(width: geometry.diaperRadius * 2, height: geometry.diaperRadius * 2)

            ClockTickDots(geometry: geometry)
                .frame(width: geometry.side, height: geometry.side)
        }
    }

    private func markerLayer(
        kind: EntryKind,
        center: CGPoint,
        geometry: CircularTimeline.Geometry
    ) -> some View {
        let radius = kind == .feed ? geometry.feedRadius : geometry.diaperRadius
        return ZStack {
            ForEach(day.markerGroups.filter { $0.kind == kind }) { group in
                Group {
                    if group.isCluster {
                        clusterMarker(for: group, visualDiameter: geometry.clusterVisualDiameter)
                    } else if let item = group.items.first {
                        eventMarker(
                            for: item,
                            visualDiameter: kind == .feed
                                ? geometry.feedVisualDiameter
                                : geometry.diaperVisualDiameter
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
        return cardinalTime(String(hour))
            .foregroundStyle(NidoTheme.secondaryInk.opacity(0.88))
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
            .font(.system(size: 12.5, weight: .bold, design: .monospaced))
            .tracking(0.1)
    }

    private func nowMarkerView(
        _ marker: CircularTimeline.NowMarker,
        center: CGPoint,
        geometry: CircularTimeline.Geometry
    ) -> some View {
        Circle()
            .fill(NidoTheme.surface)
            .frame(width: geometry.nowVisualDiameter, height: geometry.nowVisualDiameter)
            .overlay { Circle().stroke(Color.white.opacity(0.95), lineWidth: 1.5) }
            .shadow(color: NidoTheme.sleep.opacity(0.24), radius: 5, y: 2)
            .frame(width: geometry.interactionDiameter, height: geometry.interactionDiameter)
            .position(position(angle: marker.angle, center: center, radius: geometry.trackRadius))
            .accessibilityElement()
            .accessibilityLabel("Ahora, \(clockLabel(marker.minute))")
            .accessibilityIdentifier("timeline-now-marker")
            .accessibilitySortPriority(1_500)
    }

    private func eventMarker(for item: CircularTimeline.Item, visualDiameter: CGFloat) -> some View {
        Button {
            selectedEntryID = item.entry.id
        } label: {
            ZStack {
                Color.clear
                Circle()
                    .fill(item.entry.kind == .feed ? NidoTheme.feed : NidoTheme.surface)
                    .frame(width: visualDiameter, height: visualDiameter)
                    .overlay {
                        if item.entry.kind == .diaper {
                            DiaperGlyph(color: NidoTheme.diaper, size: 20)
                        } else {
                            Image(systemName: item.entry.kind.symbolName)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .overlay {
                        Circle().stroke(
                            item.entry.kind == .feed
                                ? Color.white.opacity(0.92)
                                : NidoTheme.diaper.opacity(selectedEntryID == item.entry.id ? 0.80 : 0.42),
                            lineWidth: selectedEntryID == item.entry.id ? 2 : 1.5
                        )
                    }
                    .shadow(
                        color: NidoTheme.ink.opacity(item.entry.kind == .feed ? 0.14 : 0.08),
                        radius: 3,
                        y: 2
                    )
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
        Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                expandedClusterID = group.id
            }
        } label: {
            ZStack {
                Circle()
                    .fill(group.kind == .feed ? NidoTheme.feed : NidoTheme.surface)
                Circle()
                    .stroke(
                        group.kind == .feed ? Color.white.opacity(0.92) : NidoTheme.diaper.opacity(0.55),
                        lineWidth: group.kind == .feed ? 1.75 : 1
                    )
                Text("\(group.items.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(group.kind == .feed ? .white : NidoTheme.diaper)
            }
            .frame(width: visualDiameter, height: visualDiameter)
            .shadow(color: NidoTheme.ink.opacity(group.kind == .feed ? 0.14 : 0.08), radius: 3, y: 2)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(clusterAccessibilityLabel(for: group))
        .accessibilityHint("Toca para ver todos los registros.")
        .accessibilityIdentifier("timeline-cluster-\(group.kind.rawValue)-\(group.minute)")
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
        let noun = group.kind == .feed ? "tomas" : "pañales"
        return "\(group.items.count) \(noun), \(range)"
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
                let diameter = geometry.clockDotDiameter(for: kind)
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
                    with: .color(NidoTheme.secondaryInk.opacity(0.24))
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
    let startMinute: Int
    let endMinute: Int
    let color: Color
    let strokeWidth: CGFloat

    init(segment: CircularTimeline.SleepSegment, strokeWidth: CGFloat) {
        startMinute = segment.startMinute
        endMinute = segment.endMinute
        color = NidoTheme.sleep.opacity(segment.isActive ? 0.68 : 0.92)
        self.strokeWidth = strokeWidth
    }

    var body: some View {
        Circle()
            .trim(
                from: CGFloat(startMinute) / 1_440,
                to: CGFloat(endMinute) / 1_440
            )
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: strokeWidth,
                    lineCap: .round
                )
            )
            .rotationEffect(.degrees(-90))
            .accessibilityHidden(true)
    }
}

private struct DashboardCenterSummary: View {
    let day: CircularTimeline.Day
    let geometry: CircularTimeline.Geometry

    var body: some View {
        ZStack {
            VStack(spacing: 1) {
                Text(CircularTimeline.dashboardDurationLabel(day.totalSleepSeconds))
                    .font(.system(size: geometry.centerDurationFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(NidoTheme.sleep)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)

                Text("Sueño")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NidoTheme.sleep)

                if geometry.centerContentDiameter >= 60 {
                    Rectangle()
                        .fill(NidoTheme.sleep.opacity(0.16))
                        .frame(height: 1)

                    Text("\(feedCountLabel)\n\(diaperCountLabel)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(NidoTheme.secondaryInk)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(width: geometry.centerContentDiameter)
            .accessibilityHidden(true)

            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityLabel(summaryLabel)
                .accessibilityIdentifier("timeline-category-legend")

            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityLabel(defaultStateLabel)
                .accessibilityIdentifier("timeline-dial-default-summary")
        }
        .frame(width: geometry.centerContentDiameter, height: geometry.centerContentDiameter)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(summaryLabel)
        .accessibilityIdentifier("timeline-center-summary")
    }

    private var summaryLabel: String {
        "Sueño, duración \(CircularTimeline.dashboardDurationAccessibilityLabel(day.totalSleepSeconds)). \(feedCountLabel). \(diaperCountLabel)"
    }

    private var feedCountLabel: String {
        day.feedCount == 1 ? "1 toma" : "\(day.feedCount) tomas"
    }

    private var diaperCountLabel: String {
        day.diaperCount == 1 ? "1 pañal" : "\(day.diaperCount) pañales"
    }

    private var defaultStateLabel: String {
        let count = day.items.count
        let noun = count == 1 ? "registro" : "registros"
        let dayLabel = day.nowMarker == nil ? "ese día" : "hoy"
        let timeLabel = day.nowMarker.map { ", Ahora, \(clockLabel($0.minute))" } ?? ""
        return "\(count) \(noun) \(dayLabel)\(timeLabel)"
    }

    private func clockLabel(_ minute: Int) -> String {
        let normalized = min(max(minute, 0), 1_440)
        return String(format: "%02d:%02d", normalized / 60, normalized % 60)
    }
}

private struct TimelineCategoryLegend: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let day: CircularTimeline.Day

    private let ringLanes: [TimelineLane] = [.sleep, .feeds, .diapers]

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    legendItems
                }
            } else {
                HStack(spacing: 4) {
                    legendItems
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("timeline-category-legend")
        .accessibilitySortPriority(1_450)
    }

    @ViewBuilder
    private var legendItems: some View {
        ForEach(ringLanes) { lane in
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
    }

    private var accessibilityLabel: String {
        ringLanes
            .map { "\($0.title), \(summary(for: $0))" }
            .joined(separator: ". ")
    }

    private func summary(for lane: TimelineLane) -> String {
        if lane == .sleep {
            return durationLabel(day.totalSleepSeconds)
        }
        let count = lane == .feeds ? day.feedCount : day.diaperCount
        return "\(count)"
    }

    private func durationLabel(_ seconds: Int) -> String {
        guard seconds > 0 else { return "0 min" }
        let hours = seconds / 3_600
        let remainingMinutes = (seconds % 3_600) / 60
        if hours == 0 { return "\(remainingMinutes) min" }
        if remainingMinutes == 0 { return "\(hours) h" }
        return "\(hours) h \(remainingMinutes) min"
    }
}

private struct DialCenterContent: View {
    let day: CircularTimeline.Day
    let item: CircularTimeline.Item?
    let compact: Bool

    private var isSleeping: Bool { day.activeSleep != nil && item == nil }

    var body: some View {
        ZStack {
            Color.clear
                .frame(width: 126, height: 92)
                .contentShape(Rectangle())
                .accessibilityElement()
                .accessibilityLabel(accessibilityLabel)
                .accessibilityIdentifier("timeline-dial-center-detail")

            Group {
                if compact {
                    Image(systemName: compactSymbolName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(compactColor)
                } else if let item {
                    VStack(spacing: 3) {
                        Image(systemName: item.entry.kind.symbolName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(NidoTheme.color(for: item.entry.kind))
                        Text(item.entry.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(NidoTheme.ink)
                        Text(timeLabel(for: item))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(NidoTheme.secondaryInk)
                        if !item.entry.summary.isEmpty {
                            Text(item.entry.summary)
                                .font(.caption2)
                                .foregroundStyle(NidoTheme.secondaryInk)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                    }
                } else if isSleeping {
                    VStack(spacing: 4) {
                        Image(systemName: EntryKind.sleep.symbolName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(NidoTheme.sleep)
                        Text("Sueño en curso")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(NidoTheme.ink)
                        Text("Ahora · \(day.items.count) registros hoy")
                            .font(.caption2)
                            .foregroundStyle(NidoTheme.secondaryInk)
                    }
                } else {
                    VStack(spacing: 4) {
                        Text(primaryDefaultLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(NidoTheme.ink)
                        Text(recordSummary)
                            .font(.caption2)
                            .foregroundStyle(NidoTheme.secondaryInk)
                        HStack(spacing: 8) {
                            Label("Sueño", systemImage: EntryKind.sleep.symbolName)
                                .foregroundStyle(NidoTheme.sleep)
                            if day.nowMarker != nil {
                                Label("Ahora", systemImage: "circle.fill")
                                    .foregroundStyle(NidoTheme.moss)
                            }
                        }
                        .font(.system(size: 8.5, weight: .medium))
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel)
                    .accessibilityIdentifier("timeline-dial-default-summary")
                }
            }
            .frame(maxWidth: 122)
            .multilineTextAlignment(.center)
        }
        .animation(.easeOut(duration: 0.16), value: item?.entry.id)
    }

    private var accessibilityLabel: String {
        if let item {
            return [item.entry.title, timeLabel(for: item), item.entry.summary]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        }
        if isSleeping {
            return "Sueño en curso, \(recordSummary)"
        }
        return "\(recordSummary), \(primaryDefaultLabel)"
    }

    private var compactSymbolName: String {
        if let item { return item.entry.kind.symbolName }
        if isSleeping { return EntryKind.sleep.symbolName }
        return "ellipsis"
    }

    private var compactColor: Color {
        if let item { return NidoTheme.color(for: item.entry.kind) }
        return isSleeping ? NidoTheme.sleep : NidoTheme.secondaryInk
    }

    private var primaryDefaultLabel: String {
        if let nowMarker = day.nowMarker {
            return "Ahora · \(clockLabel(nowMarker.minute))"
        }
        return day.date.formatted(.dateTime.day().month(.abbreviated))
    }

    private var recordSummary: String {
        let count = day.items.count
        let noun = count == 1 ? "registro" : "registros"
        return day.nowMarker == nil ? "\(count) \(noun) ese día" : "\(count) \(noun) hoy"
    }

    private func timeLabel(for item: CircularTimeline.Item) -> String {
        if item.presentation == .sleepSegment {
            return "\(clockLabel(item.startMinute))–\(clockLabel(item.endMinute))"
        }
        return item.entry.date.formatted(date: .omitted, time: .shortened)
    }

    private func clockLabel(_ minute: Int) -> String {
        let normalized = min(max(minute, 0), 1_440)
        if normalized == 1_440 { return "24:00" }
        return String(format: "%02d:%02d", normalized / 60, normalized % 60)
    }
}

private struct AccessibilityTimelineDetail: View {
    let day: CircularTimeline.Day
    let item: CircularTimeline.Item?

    private var isSleeping: Bool { day.activeSleep != nil && item == nil }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .foregroundStyle(color)
                .frame(width: 32, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(NidoTheme.ink)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.body)
                        .foregroundStyle(NidoTheme.secondaryInk)
                }
            }
            Spacer(minLength: 0)
        }
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
