import Foundation

nonisolated enum SleepEvolutionDateFormatting {
    static func axisLabel(
        for date: Date,
        range: SleepEvolutionRange,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        let style = dateStyle(calendar: calendar, locale: locale)
        switch range {
        case .day:
            return date.formatted(style.hour(.twoDigits(amPM: .abbreviated)))
        case .week, .month:
            return date.formatted(style.day())
        case .sixMonths, .year:
            return date.formatted(style.month(.abbreviated))
        }
    }

    static func recordDate(for date: Date, calendar: Calendar, locale: Locale) -> String {
        date.formatted(
            dateStyle(calendar: calendar, locale: locale)
                .day()
                .month(.abbreviated)
                .year()
        )
    }

    static func time(for date: Date, calendar: Calendar, locale: Locale) -> String {
        date.formatted(
            dateStyle(calendar: calendar, locale: locale)
                .hour(.twoDigits(amPM: .abbreviated))
                .minute(.twoDigits)
        )
    }

    private static func dateStyle(calendar: Calendar, locale: Locale) -> Date.FormatStyle {
        Date.FormatStyle(
            date: .omitted,
            time: .omitted,
            locale: locale,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
    }
}
