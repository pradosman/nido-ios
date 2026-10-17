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

    static func calendarWeekDates(containing date: Date, calendar: Calendar = .current) -> [Date] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
    }

    static func calendarMonths(
        from earliest: Date,
        through today: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        func monthStart(_ date: Date) -> Date {
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components) ?? calendar.startOfDay(for: date)
        }

        let currentMonth = monthStart(today)
        let firstMonth = min(monthStart(earliest), currentMonth)
        guard let finalMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) else { return [] }

        var months: [Date] = []
        var cursor = firstMonth
        while cursor <= finalMonth {
            months.append(cursor)
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: cursor), nextMonth > cursor else {
                break
            }
            cursor = nextMonth
        }
        return months
    }

    static func readingAnchor(
        for sections: [EntryKind: ClosedRange<Double>],
        threshold: Double = 150
    ) -> String {
        if let earliestSection = sections.values.map(\.lowerBound).min(), earliestSection > threshold {
            return "history-detail-top"
        }

        let visibleSection = sections
            .filter { $0.value.lowerBound <= threshold && $0.value.upperBound > 0 }
            .max { lhs, rhs in
                if lhs.value.lowerBound == rhs.value.lowerBound {
                    return lhs.key.rawValue < rhs.key.rawValue
                }
                return lhs.value.lowerBound < rhs.value.lowerBound
            }
        if let visibleSection {
            return "history-section-\(visibleSection.key.rawValue)"
        }

        if !sections.isEmpty && sections.values.allSatisfy({ $0.upperBound <= 0 }) {
            return "history-records"
        }
        return "history-detail-top"
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
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return entries.compactMap { entry -> (entry: Entry, sortDate: Date)? in
            guard filter == nil || entry.kind == filter else { return nil }
            if entry.kind == .sleep, let duration = entry.durationMinutes, duration > 0 {
                let intervalStart = entry.date.addingTimeInterval(-TimeInterval(duration * 60))
                guard intervalStart < end, entry.date > start else { return nil }
                return (entry, max(intervalStart, start))
            }
            guard entry.date >= start, entry.date < end else { return nil }
            return (entry, entry.date)
        }
        .sorted {
            if $0.sortDate == $1.sortDate { return $0.entry.id < $1.entry.id }
            return $0.sortDate < $1.sortDate
        }
        .map(\.entry)
    }
}
