import Foundation

nonisolated enum HistoryPresentation {
    struct DaySummary: Equatable, Sendable {
        let sleepMinutes: Int
        let feedCount: Int
        let diaperCount: Int

        var sleepFillFraction: Double { visualFraction(sleepMinutes, scale: 12 * 60) }
        var feedFillFraction: Double { visualFraction(feedCount, scale: 10) }
        var diaperFillFraction: Double { visualFraction(diaperCount, scale: 8) }

        private func visualFraction(_ value: Int, scale: Int) -> Double {
            min(max(Double(value) / Double(scale), 0), 1)
        }
    }

    struct Month: Equatable, Sendable {
        let monthStart: Date
        let cells: [DayCell]
    }

    struct DayCell: Equatable, Identifiable, Sendable {
        let position: Int
        let date: Date?
        let isSelectable: Bool

        var id: Int { position }
    }

    static func summary(
        on date: Date,
        entries: [Entry],
        now: Date,
        calendar: Calendar = .current
    ) -> DaySummary {
        let day = CircularTimeline.day(on: date, entries: entries, now: now, calendar: calendar)
        return DaySummary(
            sleepMinutes: day.totalSleepSeconds / 60,
            feedCount: day.feedCount,
            diaperCount: day.diaperCount
        )
    }

    static func select(_ requested: Date, through today: Date, calendar: Calendar = .current) -> Date {
        min(calendar.startOfDay(for: requested), calendar.startOfDay(for: today))
    }

    static func sevenDayDates(
        around selectedDay: Date,
        through today: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        let end = select(selectedDay, through: today, calendar: calendar)
        return (-6...0).compactMap { calendar.date(byAdding: .day, value: $0, to: end) }
    }

    static func month(
        containing date: Date,
        through today: Date,
        calendar: Calendar = .current
    ) -> Month {
        let components = calendar.dateComponents([.year, .month], from: date)
        let monthStart = calendar.date(from: components) ?? calendar.startOfDay(for: date)
        let dayRange = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<2
        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingCount = (weekday - calendar.firstWeekday + 7) % 7
        let todayStart = calendar.startOfDay(for: today)
        let populated = dayRange.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: monthStart)
        }
        let populatedCount = leadingCount + populated.count
        let trailingCount = (7 - populatedCount % 7) % 7
        let dates = Array<Date?>(repeating: nil, count: leadingCount)
            + populated.map(Optional.some)
            + Array<Date?>(repeating: nil, count: trailingCount)

        return Month(
            monthStart: monthStart,
            cells: dates.enumerated().map { position, date in
                DayCell(
                    position: position,
                    date: date,
                    isSelectable: date.map { calendar.startOfDay(for: $0) <= todayStart } ?? false
                )
            }
        )
    }

    static func entries(
        on date: Date,
        entries: [Entry],
        filter: EntryKind?,
        calendar: Calendar = .current
    ) -> [Entry] {
        entries
            .filter { calendar.isDate($0.date, inSameDayAs: date) && (filter == nil || $0.kind == filter) }
            .sorted { $0.occurredAt < $1.occurredAt }
    }
}
