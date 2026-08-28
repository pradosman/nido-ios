import Foundation

nonisolated enum CircularTimeline {
    struct Day: Equatable, Sendable {
        let date: Date
        let items: [Item]
        let activeSleep: ActiveSleep?
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
        let lane: Int

        var id: String { entry.id }
        var angle: Double { CircularTimeline.angle(forMinute: startMinute) }
    }

    struct ActiveSleep: Equatable, Sendable {
        let startMinute: Int
        let endMinute: Int
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
            return Day(date: dayStart, items: [], activeSleep: nil)
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
                    endMinute: minute(clippedEnd, dayEnd: dayEnd, calendar: calendar),
                    lane: 0
                ))
            } else if entry.date >= dayStart, entry.date < dayEnd {
                pointEntries.append((entry, minute(entry.date, dayEnd: dayEnd, calendar: calendar)))
            }
        }

        pointEntries.sort {
            if $0.minute == $1.minute { return $0.entry.id < $1.entry.id }
            return $0.minute < $1.minute
        }
        var latestMinuteByLane: [Int] = []
        for point in pointEntries {
            let lane = latestMinuteByLane.firstIndex { point.minute - $0 >= 30 } ?? latestMinuteByLane.count
            if lane == latestMinuteByLane.count {
                latestMinuteByLane.append(point.minute)
            } else {
                latestMinuteByLane[lane] = point.minute
            }
            values.append(Item(
                entry: point.entry,
                presentation: .point,
                startMinute: point.minute,
                endMinute: point.minute,
                lane: lane
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

        return Day(date: dayStart, items: values, activeSleep: activeSleep)
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

    private static func minute(_ date: Date, dayEnd: Date, calendar: Calendar) -> Int {
        if date >= dayEnd { return 1_440 }
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let value = (components.hour ?? 0) * 60
            + (components.minute ?? 0)
            + (components.second ?? 0) / 60
        return min(max(value, 0), 1_440)
    }
}
