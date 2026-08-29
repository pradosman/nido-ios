import Foundation

nonisolated enum CircularTimeline {
    struct Day: Equatable, Sendable {
        let date: Date
        let items: [Item]
        let markerGroups: [MarkerGroup]
        let periodSegments: [PeriodSegment]
        let nowMarker: NowMarker?
        let activeSleep: ActiveSleep?
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
        let minute: Int
        let items: [Item]

        var id: String { items.map(\.entry.id).joined(separator: "|") }
        var isCluster: Bool { items.count > 1 }
        var angle: Double { CircularTimeline.angle(forMinute: minute) }
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
                markerGroups: [],
                periodSegments: defaultPeriodSegments,
                nowMarker: nil,
                activeSleep: nil
            )
        }

        var values: [Item] = []
        var pointEntries: [(entry: Entry, minute: Int)] = []

        for entry in entries {
            if entry.kind == .sleep, let duration = entry.durationMinutes, duration > 0 {
                let intervalEnd = entry.date
                let intervalStart = intervalEnd.addingTimeInterval(-TimeInterval(duration * 60))
                let clippedStart = max(intervalStart, dayStart)
                let clippedEnd = min(intervalEnd, dayEnd)
                guard clippedStart < clippedEnd else { continue }
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

        let activeSleep: ActiveSleep? = {
            guard calendar.isDate(dayStart, inSameDayAs: now), let activeSleepStartedAt else { return nil }
            let clippedStart = max(activeSleepStartedAt, dayStart)
            guard clippedStart < now else { return nil }
            return ActiveSleep(
                startMinute: minute(clippedStart, dayEnd: dayEnd, calendar: calendar),
                endMinute: minute(min(now, dayEnd), dayEnd: dayEnd, calendar: calendar)
            )
        }()

        return Day(
            date: dayStart,
            items: values,
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
            MarkerGroup(minute: group[0].startMinute, items: group)
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
