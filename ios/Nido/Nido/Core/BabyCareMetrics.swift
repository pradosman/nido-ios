import Foundation

nonisolated enum BabyCareMetrics {
    struct Summary: Equatable, Sendable {
        let sleepSeconds: Int
        let feedCount: Int
        let diaperCount: Int
    }

    static func calendar(for state: BabyCareState, locale: Locale = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = TimeZone(identifier: state.timeZoneID) ?? .current
        return calendar
    }

    static func goals(on date: Date, state: BabyCareState) -> CareGoalVersion? {
        goals(on: date, state: state, calendar: calendar(for: state))
    }

    static func goals(on date: Date, state: BabyCareState, calendar: Calendar) -> CareGoalVersion? {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else { return nil }
        let key = String(format: "%04d-%02d-%02d", year, month, day)
        return state.goalVersions
            .filter { $0.effectiveDate <= key }
            .max { $0.effectiveDate < $1.effectiveDate }
    }

    static func summary(
        on date: Date,
        entries: [Entry],
        activeSleepStartedAt: Date? = nil,
        now: Date,
        calendar: Calendar
    ) -> Summary {
        let day = CircularTimeline.day(on: date, entries: entries, activeSleepStartedAt: activeSleepStartedAt, now: now, calendar: calendar)
        return Summary(sleepSeconds: day.totalSleepSeconds, feedCount: day.feedCount, diaperCount: day.diaperCount)
    }
}
