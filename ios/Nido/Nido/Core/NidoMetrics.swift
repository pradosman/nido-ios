import Foundation

nonisolated enum NidoMetrics {
    static func entries(on date: Date, from entries: [Entry], calendar: Calendar = .current) -> [Entry] {
        entries
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    static func day(_ date: Date, entries: [Entry], calendar: Calendar = .current) -> DayMetrics {
        let values = self.entries(on: date, from: entries, calendar: calendar)
        return DayMetrics(
            sleepMinutes: values.compactMap(\.durationMinutes).reduce(0, +),
            feeds: values.count { $0.kind == .feed },
            feedMl: values.compactMap(\.amountMl).reduce(0, +),
            diapers: values.count { $0.kind == .diaper }
        )
    }

    static func sleepByDay(endingOn endDate: Date, days: Int, entries: [Entry], calendar: Calendar = .current) -> [(date: Date, minutes: Int)] {
        guard days > 0 else { return [] }
        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endDate) else { return nil }
            return (calendar.startOfDay(for: date), day(date, entries: entries, calendar: calendar).sleepMinutes)
        }
    }

    static func ageInMonths(birthDate: String, now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let date = birthDateFormatter.date(from: birthDate) else { return 0 }
        return max(0, calendar.dateComponents([.month], from: date, to: now).month ?? 0)
    }

    static func wakeWindowMinutes(ageInMonths: Int) -> Int {
        switch ageInMonths {
        case ...1: 60
        case 2...3: 90
        case 4...5: 120
        case 6...8: 150
        default: 180
        }
    }

    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
