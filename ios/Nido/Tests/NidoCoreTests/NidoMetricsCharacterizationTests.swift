import Foundation
import Testing
@testable import NidoCore

struct NidoMetricsCharacterizationTests {
    @Test
    func feedDurationDoesNotCountAsSleep() {
        let date = Date(timeIntervalSince1970: 1_787_918_400)
        let nursing = Entry(
            id: "feed",
            kind: .feed,
            title: "Toma",
            detail: "Lactancia · Pecho izquierdo",
            occurredAt: Int64(date.timeIntervalSince1970 * 1_000),
            durationMinutes: 25,
            amountMl: nil
        )

        let metrics = NidoMetrics.day(date, entries: [nursing], calendar: utcCalendar)

        #expect(metrics.sleepMinutes == 0)
        #expect(metrics.feeds == 1)
    }

    @Test
    func duplicateEventIDsDoNotInflateDailyCountsOrFeedVolume() throws {
        let date = try #require(utcCalendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let feed = Entry(id: "duplicate-feed", kind: .feed, title: "Toma", detail: "", occurredAt: Int64(date.timeIntervalSince1970 * 1_000), durationMinutes: nil, amountMl: 75)
        let diaper = Entry(id: "duplicate-diaper", kind: .diaper, title: "Pañal", detail: "", occurredAt: Int64(date.timeIntervalSince1970 * 1_000), durationMinutes: nil, amountMl: nil)

        let metrics = NidoMetrics.day(date, entries: [feed, feed, diaper, diaper], calendar: utcCalendar)

        #expect(metrics.feeds == 1)
        #expect(metrics.feedMl == 75)
        #expect(metrics.diapers == 1)
    }

    @Test
    func entriesForADayAreFilteredAndNewestFirst() {
        let target = Date(timeIntervalSince1970: 1_787_918_400)
        let previousDay = target.addingTimeInterval(-86_400)
        let entries = [
            entry(id: "older", kind: .feed, date: target.addingTimeInterval(60)),
            entry(id: "previous", kind: .sleep, date: previousDay),
            entry(id: "newer", kind: .diaper, date: target.addingTimeInterval(120)),
        ]

        #expect(NidoMetrics.entries(on: target, from: entries, calendar: utcCalendar).map(\.id) == ["newer", "older"])
    }

    @Test
    func sleepByDayIncludesEmptyDaysInChronologicalOrder() throws {
        let calendar = utcCalendar
        let end = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 12)))
        let previous = try #require(calendar.date(byAdding: .day, value: -1, to: end))
        let values = NidoMetrics.sleepByDay(
            endingOn: end,
            days: 3,
            entries: [
                entry(id: "one", kind: .sleep, date: previous, duration: 90),
                entry(id: "two", kind: .sleep, date: end, duration: 45),
            ],
            calendar: calendar
        )

        #expect(values.map(\.minutes) == [0, 90, 45])
        #expect(values.map(\.date) == values.map(\.date).sorted())
        #expect(NidoMetrics.sleepByDay(endingOn: end, days: 0, entries: [], calendar: calendar).isEmpty)
    }

    @Test
    func ageInMonthsHandlesInvalidAndFutureBirthDates() throws {
        let calendar = utcCalendar
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 12)))

        #expect(NidoMetrics.ageInMonths(birthDate: "2026-04-28", now: now, calendar: calendar) == 4)
        #expect(NidoMetrics.ageInMonths(birthDate: "fecha incorrecta", now: now, calendar: calendar) == 0)
        #expect(NidoMetrics.ageInMonths(birthDate: "2027-01-01", now: now, calendar: calendar) == 0)
    }

    private func entry(
        id: String,
        kind: EntryKind,
        date: Date,
        duration: Int? = nil
    ) -> Entry {
        Entry(
            id: id,
            kind: kind,
            title: kind.title,
            detail: "",
            occurredAt: Int64(date.timeIntervalSince1970 * 1_000),
            durationMinutes: duration,
            amountMl: nil
        )
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
