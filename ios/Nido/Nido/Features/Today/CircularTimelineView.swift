import SwiftUI

struct CircularTimelineDayView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let day: CircularTimeline.Day
    @Binding var selectedEntryID: String?
    @Binding var expandedClusterID: String?

    private var selectedItem: CircularTimeline.Item? {
        if let selectedEntryID, let selected = day.items.first(where: { $0.entry.id == selectedEntryID }) {
            return selected
        }
        if day.activeSleep != nil { return nil }
        return day.items.last
    }

    private var expandedCluster: CircularTimeline.MarkerGroup? {
        guard let expandedClusterID else { return nil }
        return day.markerGroups.first { $0.id == expandedClusterID }
    }

    var body: some View {
        VStack(spacing: 10) {
            dial
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 300 : 334)
                .aspectRatio(1, contentMode: .fit)
            if dynamicTypeSize.isAccessibilitySize {
                AccessibilityTimelineDetail(
                    item: selectedItem,
                    isSleeping: day.activeSleep != nil && selectedItem == nil
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var dial: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let eventRadius = side * 0.27

            ZStack {
                dialFace(side: side)

                ForEach(day.items.filter { $0.presentation == .sleepSegment }) { item in
                    SleepArc(item: item)
                        .padding(side * 0.075)
                }

                if let activeSleep = day.activeSleep {
                    SleepArc(
                        startMinute: activeSleep.startMinute,
                        endMinute: activeSleep.endMinute,
                        color: NidoTheme.sleep.opacity(0.62),
                        dashed: true
                    )
                    .padding(side * 0.075)
                    .accessibilityLabel("Sueño en curso")
                }

                if expandedCluster == nil {
                    DialCenterContent(
                        item: selectedItem,
                        isSleeping: day.activeSleep != nil && selectedItem == nil,
                        compact: dynamicTypeSize.isAccessibilitySize
                    )
                }

                ForEach(day.markerGroups) { group in
                    let position = markerPosition(group: group, center: center, radius: eventRadius)
                    if group.isCluster {
                        clusterMarker(for: group)
                            .position(position)
                    } else if let item = group.items.first {
                        eventMarker(for: item)
                            .position(position)
                    }
                }

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

    private func dialFace(side: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(NidoTheme.surface.opacity(0.72))
            Circle()
                .stroke(NidoTheme.separator.opacity(0.55), lineWidth: 0.75)

            ForEach(0..<24, id: \.self) { hour in
                Capsule()
                    .fill(hour.isMultiple(of: 6) ? NidoTheme.secondaryInk.opacity(0.72) : NidoTheme.secondaryInk.opacity(0.28))
                    .frame(width: hour.isMultiple(of: 6) ? 1.5 : 1, height: hour.isMultiple(of: 6) ? 10 : 5)
                    .offset(y: -side * 0.445)
                    .rotationEffect(.degrees(Double(hour) * 15))
            }

            cardinalLabel("00", x: 0, y: -side * 0.35)
            cardinalLabel("06", x: side * 0.35, y: 0)
            cardinalLabel("12", x: 0, y: side * 0.35)
            cardinalLabel("18", x: -side * 0.35, y: 0)

        }
        .accessibilityHidden(true)
    }

    private func cardinalLabel(_ label: String, x: CGFloat, y: CGFloat) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(NidoTheme.secondaryInk)
            .offset(x: x, y: y)
    }

    private func markerPosition(
        group: CircularTimeline.MarkerGroup,
        center: CGPoint,
        radius: CGFloat
    ) -> CGPoint {
        let radians = group.angle * .pi / 180
        return CGPoint(
            x: center.x + sin(radians) * radius,
            y: center.y - cos(radians) * radius
        )
    }

    private func eventMarker(for item: CircularTimeline.Item) -> some View {
        Button {
            selectedEntryID = item.entry.id
        } label: {
            Image(systemName: item.entry.kind.symbolName)
                .font(.system(size: 17, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(NidoTheme.color(for: item.entry.kind))
                .frame(width: 34, height: 34)
                .background(NidoTheme.surface, in: Circle())
                .overlay {
                    Circle()
                        .stroke(
                            selectedEntryID == item.entry.id ? NidoTheme.color(for: item.entry.kind) : NidoTheme.separator.opacity(0.55),
                            lineWidth: selectedEntryID == item.entry.id ? 1.5 : 0.5
                        )
                }
                .shadow(color: NidoTheme.ink.opacity(0.09), radius: 6, y: 2)
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

    private func clusterMarker(for group: CircularTimeline.MarkerGroup) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) {
                expandedClusterID = group.id
            }
        } label: {
            ZStack {
                Circle()
                    .fill(NidoTheme.surface)
                Circle()
                    .stroke(NidoTheme.moss.opacity(0.7), lineWidth: 1)
                Text("\(group.items.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NidoTheme.moss)
            }
            .frame(width: 36, height: 36)
            .shadow(color: NidoTheme.ink.opacity(0.09), radius: 6, y: 2)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(clusterAccessibilityLabel(for: group))
        .accessibilityHint("Toca para ver todos los registros.")
        .accessibilityIdentifier("timeline-cluster-\(group.minute)")
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
        return "\(group.items.count) registros, \(range)"
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

private struct SleepArc: View {
    let startMinute: Int
    let endMinute: Int
    let color: Color
    var dashed = false

    init(item: CircularTimeline.Item) {
        startMinute = item.startMinute
        endMinute = item.endMinute
        color = NidoTheme.sleep
    }

    init(startMinute: Int, endMinute: Int, color: Color, dashed: Bool) {
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.color = color
        self.dashed = dashed
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
                    lineWidth: 9,
                    lineCap: .round,
                    dash: dashed ? [4, 4] : []
                )
            )
            .rotationEffect(.degrees(-90))
            .accessibilityHidden(true)
    }
}

private struct DialCenterContent: View {
    let item: CircularTimeline.Item?
    let isSleeping: Bool
    let compact: Bool

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
                        Text("Ahora")
                            .font(.caption2)
                            .foregroundStyle(NidoTheme.secondaryInk)
                    }
                } else {
                    VStack(spacing: 3) {
                        Text("Sin registros")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(NidoTheme.ink)
                        Text("Este día")
                            .font(.caption2)
                            .foregroundStyle(NidoTheme.secondaryInk)
                    }
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
        return isSleeping ? "Sueño en curso" : "Sin registros en este día"
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
    let item: CircularTimeline.Item?
    let isSleeping: Bool

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
        return isSleeping ? "Sueño en curso" : "Sin registros"
    }

    private var detail: String? {
        guard let item else { return isSleeping ? "Ahora" : "Este día" }
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
