import Foundation

nonisolated enum CircularTimeline {
    enum ClockDotKind: Equatable, Sendable {
        case wholeHour
        case halfHour
    }

    enum ClockScaleMark: Equatable, Sendable {
        case number(hour: Int)
        case dot(ClockDotKind)
    }

    struct ClockScalePosition: Equatable, Identifiable, Sendable {
        let minute: Int
        let mark: ClockScaleMark

        var id: Int { minute }
    }

    static let clockScale: [ClockScalePosition] = (0..<48).map { slot in
        let minute = slot * 30
        if minute % 180 == 0 {
            return ClockScalePosition(minute: minute, mark: .number(hour: minute / 60))
        } else {
            return ClockScalePosition(
                minute: minute,
                mark: .dot(minute % 60 == 0 ? .wholeHour : .halfHour)
            )
        }
    }

    struct Geometry: Equatable, Sendable {
        let side: CGFloat

        let faceInset: CGFloat
        let trackStroke: CGFloat
        let trackRadius: CGFloat
        let feedRadius: CGFloat
        let diaperRadius: CGFloat
        let tickRadius: CGFloat
        let scaleRadius: CGFloat
        let cardinalTopBottomSize: CGSize
        let cardinalSideSize: CGSize
        let cardinalTangentialOffset: CGFloat
        let cardinalEdgeInset: CGFloat
        let feedVisualDiameter: CGFloat
        let diaperVisualDiameter: CGFloat
        let clusterVisualDiameter: CGFloat
        let nowVisualDiameter: CGFloat
        let interactionDiameter: CGFloat
        let bandGap: CGFloat

        var dialBounds: CGRect { CGRect(origin: .zero, size: CGSize(width: side, height: side)) }
        var center: CGPoint { CGPoint(x: side / 2, y: side / 2) }
        var ringDiameter: CGFloat { trackRadius * 2 }
        var centerInnerDiameter: CGFloat { max(0, diaperRadius * 2 - trackStroke) }
        var centerSafetyInset: CGFloat { Self.clamp(side * 6 / 350, minimum: 4, maximum: 7) }
        var centerContentDiameter: CGFloat { max(0, centerInnerDiameter - centerSafetyInset * 2) }
        var centerDurationFontSize: CGFloat { centerContentDiameter * 0.31 }

        init(side requestedSide: CGFloat) {
            let side = max(0, requestedSide)
            let bandGap = Self.clamp(side * 2 / 350, minimum: 1.5, maximum: 2.5)
            let markerVisualDiameter = Self.clamp(side * 30 / 350, minimum: 26, maximum: 34)
            let trackStroke = markerVisualDiameter
            let cardinalSize = CGSize(
                width: Self.clamp(side * 20 / 350, minimum: 18, maximum: 22),
                height: Self.clamp(side * 18 / 350, minimum: 16, maximum: 20)
            )
            let interactionDiameter: CGFloat = 44
            let cardinalFaceGap = Self.clamp(side / 350, minimum: 1, maximum: 2)
            let faceRadius = max(0, side / 2 - max(cardinalSize.width, cardinalSize.height) - cardinalFaceGap)
            let faceInset = max(0, side / 2 - faceRadius)
            let feedRadius = max(0, faceRadius - trackStroke / 2 - bandGap)
            let laneCenterSpacing = trackStroke + bandGap

            self.side = side
            self.faceInset = faceInset
            self.trackStroke = trackStroke
            self.trackRadius = feedRadius - laneCenterSpacing
            self.feedRadius = feedRadius
            self.diaperRadius = feedRadius - laneCenterSpacing * 2
            self.scaleRadius = side / 2 - max(cardinalSize.width, cardinalSize.height) / 2
            self.tickRadius = self.scaleRadius
            self.cardinalTopBottomSize = cardinalSize
            self.cardinalSideSize = cardinalSize
            self.cardinalTangentialOffset = 0
            self.cardinalEdgeInset = 0
            self.feedVisualDiameter = markerVisualDiameter
            self.diaperVisualDiameter = markerVisualDiameter
            self.clusterVisualDiameter = markerVisualDiameter
            self.nowVisualDiameter = Self.clamp(side * 0.051_428_571, minimum: 16, maximum: 22)
            self.interactionDiameter = interactionDiameter
            self.bandGap = bandGap
        }

        func point(atMinute minute: Int, radius: CGFloat) -> CGPoint {
            let radians = CircularTimeline.angle(forMinute: minute) * .pi / 180
            return CGPoint(
                x: center.x + sin(radians) * radius,
                y: center.y - cos(radians) * radius
            )
        }

        func cardinalFrame(atMinute minute: Int) -> CGRect {
            let normalized = min(max(minute, 0), 1_440)
            let size = cardinalSize(atMinute: normalized)
            let point = self.point(atMinute: normalized, radius: scaleRadius)
            return frame(centeredAt: point, size: size)
        }

        func cardinalSize(atMinute _: Int) -> CGSize {
            cardinalTopBottomSize
        }

        func clockDotDiameter(for kind: ClockDotKind) -> CGFloat {
            switch kind {
            case .wholeHour:
                Self.clamp(side * 4 / 350, minimum: 3.5, maximum: 5)
            case .halfHour:
                Self.clamp(side * 2 / 350, minimum: 1.5, maximum: 2.5)
            }
        }

        func eventVisualFrame(kind: EntryKind, atMinute minute: Int) -> CGRect {
            let diameter = kind == .feed ? feedVisualDiameter : diaperVisualDiameter
            let radius = kind == .feed ? feedRadius : diaperRadius
            return frame(
                centeredAt: point(atMinute: minute, radius: radius),
                size: CGSize(width: diameter, height: diameter)
            )
        }

        func eventHitFrame(kind: EntryKind, atMinute minute: Int) -> CGRect {
            let radius = kind == .feed ? feedRadius : diaperRadius
            return frame(
                centeredAt: point(atMinute: minute, radius: radius),
                size: CGSize(width: interactionDiameter, height: interactionDiameter)
            )
        }

        private func frame(centeredAt point: CGPoint, size: CGSize) -> CGRect {
            CGRect(
                x: point.x - size.width / 2,
                y: point.y - size.height / 2,
                width: size.width,
                height: size.height
            )
        }

        private static func clamp(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
            min(max(value, minimum), maximum)
        }
    }

    struct Day: Equatable, Sendable {
        let date: Date
        let items: [Item]
        let sleepSegments: [SleepSegment]
        let markerGroups: [MarkerGroup]
        let periodSegments: [PeriodSegment]
        let nowMarker: NowMarker?
        let activeSleep: ActiveSleep?

        var totalSleepSeconds: Int { sleepSegments.reduce(0) { $0 + $1.elapsedSeconds } }
        var feedCount: Int { items.count { $0.presentation == .point && $0.entry.kind == .feed } }
        var diaperCount: Int { items.count { $0.presentation == .point && $0.entry.kind == .diaper } }
    }

    struct PeriodSegment: Equatable, Sendable {
        enum Period: Equatable, Sendable {
            case day
            case night
        }

        let period: Period
        let startMinute: Int
        let endMinute: Int
    }

    struct NowMarker: Equatable, Sendable {
        let minute: Int

        var angle: Double { CircularTimeline.angle(forMinute: minute) }
    }

    struct Item: Equatable, Identifiable, Sendable {
        enum Presentation: Equatable, Sendable {
            case point
            case sleepSegment
        }

        let entry: Entry
        let presentation: Presentation
        let startMinute: Int
        let endMinute: Int

        var id: String { entry.id }
        var angle: Double { CircularTimeline.angle(forMinute: startMinute) }
    }

    struct MarkerGroup: Equatable, Identifiable, Sendable {
        let kind: EntryKind
        let minute: Int
        let items: [Item]

        var id: String {
            "\(kind.rawValue)|\(minute)|\(items.map(\.entry.id).joined(separator: "|"))"
        }
        var isCluster: Bool { items.count > 1 }
        var angle: Double { CircularTimeline.angle(forMinute: minute) }
    }

    struct SleepSegment: Equatable, Identifiable, Sendable {
        let sourceEntryID: String?
        let startMinute: Int
        let endMinute: Int
        let elapsedSeconds: Int
        let isActive: Bool

        var id: String { sourceEntryID ?? "active-sleep" }
    }

    struct ActiveSleep: Equatable, Sendable {
        let startMinute: Int
        let endMinute: Int
    }

    enum Navigation: Equatable, Sendable {
        case previous
        case next
        case today
    }

    static func angle(for date: Date, calendar: Calendar = .current) -> Double {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let seconds = (components.hour ?? 0) * 3_600
            + (components.minute ?? 0) * 60
            + (components.second ?? 0)
        return Double(seconds) / 86_400 * 360
    }

    static func angle(forMinute minute: Int) -> Double {
        Double(min(max(minute, 0), 1_440)) / 1_440 * 360
    }

    static func dashboardDurationLabel(_ seconds: Int) -> String {
        let (hours, minutes) = dashboardDurationComponents(seconds)
        return String(format: "%d:%02d", hours, minutes)
    }

    static func dashboardDurationAccessibilityLabel(_ seconds: Int) -> String {
        let (hours, minutes) = dashboardDurationComponents(seconds)
        let hourLabel = hours == 1 ? "hora" : "horas"
        let minuteLabel = minutes == 1 ? "minuto" : "minutos"

        if hours == 0 { return "\(minutes) \(minuteLabel)" }
        if minutes == 0 { return "\(hours) \(hourLabel)" }
        return "\(hours) \(hourLabel) y \(minutes) \(minuteLabel)"
    }

    private static func dashboardDurationComponents(_ seconds: Int) -> (hours: Int, minutes: Int) {
        let totalMinutes = max(0, seconds) / 60
        return (totalMinutes / 60, totalMinutes % 60)
    }

    static func day(
        on date: Date,
        entries: [Entry],
        activeSleepStartedAt: Date? = nil,
        now: Date,
        calendar: Calendar = .current
    ) -> Day {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return Day(
                date: dayStart,
                items: [],
                sleepSegments: [],
                markerGroups: [],
                periodSegments: defaultPeriodSegments,
                nowMarker: nil,
                activeSleep: nil
            )
        }

        var values: [Item] = []
        var sleepSegments: [SleepSegment] = []
        var pointEntries: [(entry: Entry, minute: Int)] = []

        for entry in entries {
            if entry.kind == .sleep, let duration = entry.durationMinutes, duration > 0 {
                let intervalEnd = entry.date
                let intervalStart = intervalEnd.addingTimeInterval(-TimeInterval(duration * 60))
                let clippedStart = max(intervalStart, dayStart)
                let clippedEnd = min(intervalEnd, dayEnd)
                guard clippedStart < clippedEnd else { continue }
                sleepSegments.append(SleepSegment(
                    sourceEntryID: entry.id,
                    startMinute: minute(clippedStart, dayEnd: dayEnd, calendar: calendar),
                    endMinute: minute(clippedEnd, dayEnd: dayEnd, calendar: calendar),
                    elapsedSeconds: Int(clippedEnd.timeIntervalSince(clippedStart)),
                    isActive: false
                ))
                values.append(Item(
                    entry: entry,
                    presentation: .sleepSegment,
                    startMinute: minute(clippedStart, dayEnd: dayEnd, calendar: calendar),
                    endMinute: minute(clippedEnd, dayEnd: dayEnd, calendar: calendar)
                ))
            } else if entry.date >= dayStart, entry.date < dayEnd {
                pointEntries.append((entry, minute(entry.date, dayEnd: dayEnd, calendar: calendar)))
            }
        }

        pointEntries.sort {
            if $0.minute == $1.minute { return $0.entry.id < $1.entry.id }
            return $0.minute < $1.minute
        }
        for point in pointEntries {
            values.append(Item(
                entry: point.entry,
                presentation: .point,
                startMinute: point.minute,
                endMinute: point.minute
            ))
        }

        values.sort {
            if $0.startMinute == $1.startMinute { return $0.entry.id < $1.entry.id }
            return $0.startMinute < $1.startMinute
        }

        let activeSegment: SleepSegment? = {
            guard calendar.isDate(dayStart, inSameDayAs: now), let activeSleepStartedAt else { return nil }
            let clippedStart = max(activeSleepStartedAt, dayStart)
            let clippedEnd = min(now, dayEnd)
            guard clippedStart < clippedEnd else { return nil }
            return SleepSegment(
                sourceEntryID: nil,
                startMinute: minute(clippedStart, dayEnd: dayEnd, calendar: calendar),
                endMinute: minute(clippedEnd, dayEnd: dayEnd, calendar: calendar),
                elapsedSeconds: Int(clippedEnd.timeIntervalSince(clippedStart)),
                isActive: true
            )
        }()
        if let activeSegment { sleepSegments.append(activeSegment) }
        sleepSegments.sort {
            if $0.startMinute == $1.startMinute { return $0.id < $1.id }
            return $0.startMinute < $1.startMinute
        }

        let activeSleep = activeSegment.map {
            ActiveSleep(startMinute: $0.startMinute, endMinute: $0.endMinute)
        }

        return Day(
            date: dayStart,
            items: values,
            sleepSegments: sleepSegments,
            markerGroups: markerGroups(for: values),
            periodSegments: defaultPeriodSegments,
            nowMarker: calendar.isDate(dayStart, inSameDayAs: now)
                ? NowMarker(minute: minute(now, dayEnd: dayEnd, calendar: calendar))
                : nil,
            activeSleep: activeSleep
        )
    }

    static func availableDates(
        earliest: Date,
        through today: Date,
        maximumDayCount: Int = 366,
        calendar: Calendar = .current
    ) -> [Date] {
        guard maximumDayCount > 0 else { return [] }
        let todayStart = calendar.startOfDay(for: today)
        let requestedStart = min(calendar.startOfDay(for: earliest), todayStart)
        let boundedStart = calendar.date(byAdding: .day, value: -(maximumDayCount - 1), to: todayStart) ?? todayStart
        let start = max(requestedStart, boundedStart)
        let dayCount = (calendar.dateComponents([.day], from: start, to: todayStart).day ?? 0) + 1
        return (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func clampedDay(_ requested: Date, through today: Date, calendar: Calendar = .current) -> Date {
        min(calendar.startOfDay(for: requested), calendar.startOfDay(for: today))
    }

    static func destination(
        for navigation: Navigation,
        from selectedDay: Date,
        availableDates: [Date],
        through today: Date,
        calendar: Calendar = .current
    ) -> Date {
        let todayStart = calendar.startOfDay(for: today)
        guard !availableDates.isEmpty else { return min(calendar.startOfDay(for: selectedDay), todayStart) }
        if navigation == .today { return min(availableDates.last ?? todayStart, todayStart) }

        let selected = calendar.startOfDay(for: selectedDay)
        let index = availableDates.firstIndex(of: selected) ?? availableDates.startIndex
        let offset = navigation == .previous ? -1 : 1
        let destinationIndex = min(
            max(index + offset, availableDates.startIndex),
            availableDates.index(before: availableDates.endIndex)
        )
        return min(availableDates[destinationIndex], todayStart)
    }

    private static func markerGroups(for items: [Item], minimumSeparationMinutes: Int = 140) -> [MarkerGroup] {
        [EntryKind.feed, .diaper].flatMap { kind in
            markerGroups(
                for: items.filter { $0.presentation == .point && $0.entry.kind == kind },
                kind: kind,
                minimumSeparationMinutes: minimumSeparationMinutes
            )
        }
    }

    private static func markerGroups(
        for items: [Item],
        kind: EntryKind,
        minimumSeparationMinutes: Int
    ) -> [MarkerGroup] {
        guard let first = items.first else { return [] }
        var groups: [[Item]] = [[first]]
        var anchorMinute = first.startMinute

        for item in items.dropFirst() {
            if item.startMinute - anchorMinute < minimumSeparationMinutes {
                groups[groups.index(before: groups.endIndex)].append(item)
            } else {
                groups.append([item])
                anchorMinute = item.startMinute
            }
        }

        if groups.count > 1,
           let firstMinute = groups.first?.first?.startMinute,
           let lastMinute = groups.last?.first?.startMinute,
           1_440 - lastMinute + firstMinute < minimumSeparationMinutes {
            let last = groups.removeLast()
            groups[0].append(contentsOf: last)
            groups[0].sort {
                if $0.startMinute == $1.startMinute { return $0.entry.id < $1.entry.id }
                return $0.startMinute < $1.startMinute
            }
        }

        return groups.map { group in
            MarkerGroup(kind: kind, minute: group[0].startMinute, items: group)
        }
    }

    private static let defaultPeriodSegments = [
        PeriodSegment(period: .night, startMinute: 0, endMinute: 6 * 60),
        PeriodSegment(period: .day, startMinute: 6 * 60, endMinute: 18 * 60),
        PeriodSegment(period: .night, startMinute: 18 * 60, endMinute: 24 * 60),
    ]

    private static func minute(_ date: Date, dayEnd: Date, calendar: Calendar) -> Int {
        if date >= dayEnd { return 1_440 }
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let value = (components.hour ?? 0) * 60
            + (components.minute ?? 0)
            + (components.second ?? 0) / 60
        return min(max(value, 0), 1_440)
    }
}
