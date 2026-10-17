import Foundation
import Testing
@testable import NidoCore

struct HistoryAnalyticsTests {
    @Test(arguments: [(3, 29, 92), (10, 25, 100)])
    func createsElapsedQuarterHourBinsAcrossMadridDST(month: Int, dayOfMonth: Int, expectedCount: Int) throws {
        let calendar = madridCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: dayOfMonth)))

        let result = HistoryAnalytics.snapshot(on: day, entries: [], now: day, calendar: calendar)

        #expect(result.bins.count == expectedCount)
        #expect(result.bins.first?.start == calendar.startOfDay(for: day))
        #expect(result.bins.last?.end == calendar.date(byAdding: .day, value: 1, to: day))
        #expect(result.bins.allSatisfy { $0.end.timeIntervalSince($0.start) == 900 })
    }

    @Test
    func splitsAnOvernightSleepAndKeepsOriginalEntryForEditing() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let sleep = entry(
            id: "overnight", kind: .sleep,
            date: day.addingTimeInterval(24 * 3_600 + 45 * 60), duration: 135
        )

        let result = HistoryAnalytics.snapshot(on: day, entries: [sleep], now: day, calendar: calendar)
        let nextDay = HistoryAnalytics.snapshot(
            on: day.addingTimeInterval(86_400), entries: [sleep], now: day, calendar: calendar
        )

        #expect(result.day.totalSleepSeconds == 90 * 60)
        #expect(nextDay.day.totalSleepSeconds == 45 * 60)
        #expect(result.entries.map(\.id) == ["overnight"])
        #expect(nextDay.entries.map(\.id) == ["overnight"])
        #expect(result.bins.reduce(0) { $0 + $1.sleepSeconds } == 90 * 60)
        #expect(nextDay.bins.reduce(0) { $0 + $1.sleepSeconds } == 45 * 60)
        #expect(result.bins[90].entryIDs(for: .sleep) == ["overnight"])
        #expect(nextDay.bins[0].entryIDs(for: .sleep) == ["overnight"])
    }

    @Test
    func fractionalSleepBoundariesConserveRoundedDayTotalAcrossBins() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let sleep = entry(
            id: "fractional", kind: .sleep,
            date: day.addingTimeInterval(3_600.5), duration: 60
        )

        let result = HistoryAnalytics.snapshot(on: day, entries: [sleep], now: day, calendar: calendar)

        #expect(result.day.totalSleepSeconds == 3_600)
        #expect(result.bins.reduce(0) { $0 + $1.sleepSeconds } == result.day.totalSleepSeconds)
    }

    @Test
    func fractionalActiveSleepBoundariesConserveRoundedDayTotalAcrossBins() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let now = day.addingTimeInterval(3_600.5)

        let result = HistoryAnalytics.snapshot(
            on: day, entries: [], activeSleepStartedAt: day, now: now, calendar: calendar
        )

        #expect(result.day.totalSleepSeconds == 3_600)
        #expect(result.bins.reduce(0) { $0 + $1.sleepSeconds } == result.day.totalSleepSeconds)
    }

    @Test(arguments: [(3, 29, 4, 0, 90), (10, 25, 3, 30, 120)])
    func distributesRealSleepAcrossMadridDSTBoundaries(
        month: Int,
        dayOfMonth: Int,
        endHour: Int,
        endMinute: Int,
        durationMinutes: Int
    ) throws {
        let calendar = madridCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: dayOfMonth)))
        let end = try #require(calendar.date(from: DateComponents(
            year: 2026, month: month, day: dayOfMonth, hour: endHour, minute: endMinute
        )))
        let sleep = entry(id: "dst-sleep", kind: .sleep, date: end, duration: durationMinutes)

        let result = HistoryAnalytics.snapshot(on: day, entries: [sleep], now: day, calendar: calendar)

        #expect(result.day.totalSleepSeconds == durationMinutes * 60)
        #expect(result.bins.reduce(0) { $0 + $1.sleepSeconds } == result.day.totalSleepSeconds)
    }

    @Test
    func eventExactlyAtMidnightBelongsOnlyToTheFollowingDay() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let midnight = try #require(calendar.date(byAdding: .day, value: 1, to: day))
        let feed = entry(id: "midnight-feed", kind: .feed, date: midnight)

        let previousDay = HistoryAnalytics.snapshot(on: day, entries: [feed], now: midnight, calendar: calendar)
        let nextDay = HistoryAnalytics.snapshot(on: midnight, entries: [feed], now: midnight, calendar: calendar)

        #expect(previousDay.day.feedCount == 0)
        #expect(previousDay.bins.reduce(0) { $0 + $1.feedCount } == 0)
        #expect(nextDay.day.feedCount == 1)
        #expect(nextDay.bins.reduce(0) { $0 + $1.feedCount } == 1)
    }

    @Test
    func activeSleepIsClippedIntoSelectedPastDayWithoutCreatingAnEntry() throws {
        let calendar = utcCalendar
        let yesterday = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let today = try #require(calendar.date(byAdding: .day, value: 1, to: yesterday))
        let start = yesterday.addingTimeInterval(23 * 3_600 + 30 * 60)
        let now = today.addingTimeInterval(45 * 60)

        let result = HistoryAnalytics.snapshot(
            on: yesterday, entries: [], activeSleepStartedAt: start, now: now, calendar: calendar
        )

        #expect(result.day.totalSleepSeconds == 30 * 60)
        #expect(result.day.activeSleep != nil)
        #expect(result.entries.isEmpty)
        #expect(result.bins.reduce(0) { $0 + $1.sleepSeconds } == 30 * 60)
    }

    @Test
    func simultaneousAndOverlappingEventsConserveTheExistingSummedTotals() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let entries = [
            entry(id: "sleep-a", kind: .sleep, date: day.addingTimeInterval(2 * 3_600), duration: 90),
            entry(id: "sleep-b", kind: .sleep, date: day.addingTimeInterval(2 * 3_600), duration: 30),
            entry(id: "feed", kind: .feed, date: day.addingTimeInterval(2 * 3_600)),
            entry(id: "diaper", kind: .diaper, date: day.addingTimeInterval(2 * 3_600)),
            entry(id: "care", kind: .health, date: day.addingTimeInterval(2 * 3_600)),
        ]

        let result = HistoryAnalytics.snapshot(on: day, entries: entries, now: day, calendar: calendar)

        #expect(result.bins.reduce(0) { $0 + $1.sleepSeconds } == result.day.totalSleepSeconds)
        #expect(result.bins.reduce(0) { $0 + $1.feedCount } == result.day.feedCount)
        #expect(result.bins.reduce(0) { $0 + $1.diaperCount } == result.day.diaperCount)
        #expect(result.bins[8].entryIDs(for: .feed) == ["feed"])
        #expect(result.bins[8].entryIDs(for: .diaper) == ["diaper"])
        #expect(result.bins[8].entryIDs(for: .health) == ["care"])
    }

    @Test
    func flagsBriefOverlappingSleepEvenWhenTheBinTotalsUnderFifteenMinutes() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let entries = [
            entry(id: "sleep-a", kind: .sleep, date: day.addingTimeInterval(7 * 3_600 + 58 * 60), duration: 8),
            entry(id: "sleep-b", kind: .sleep, date: day.addingTimeInterval(8 * 3_600), duration: 5),
        ]

        let result = HistoryAnalytics.snapshot(on: day, entries: entries, now: day, calendar: calendar)

        #expect(result.bins[31].sleepSeconds == 10 * 60)
        #expect(result.bins[31].hasOverlappingSleep)
    }

    @Test
    func adjacentSleepIntervalsDoNotCountAsOverlapping() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let entries = [
            entry(id: "sleep-a", kind: .sleep, date: day.addingTimeInterval(7 * 3_600 + 50 * 60), duration: 5),
            entry(id: "sleep-b", kind: .sleep, date: day.addingTimeInterval(7 * 3_600 + 55 * 60), duration: 5),
        ]

        let result = HistoryAnalytics.snapshot(on: day, entries: entries, now: day, calendar: calendar)

        #expect(result.bins[31].hasOverlappingSleep == false)
    }

    @Test
    func overlappingSleepIsFlaggedOnlyInBinsWhereTheIntervalsIntersect() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let entries = [
            entry(id: "sleep-a", kind: .sleep, date: day.addingTimeInterval(8 * 3_600 + 5 * 60), duration: 10),
            entry(id: "sleep-b", kind: .sleep, date: day.addingTimeInterval(8 * 3_600 + 10 * 60), duration: 10),
        ]

        let result = HistoryAnalytics.snapshot(on: day, entries: entries, now: day, calendar: calendar)

        #expect(result.bins[31].hasOverlappingSleep == false)
        #expect(result.bins[32].hasOverlappingSleep)
    }

    @Test
    func activeSleepOverlapIsFlaggedAlongsideSavedSleep() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let saved = entry(
            id: "saved-sleep", kind: .sleep,
            date: day.addingTimeInterval(7 * 3_600 + 58 * 60), duration: 6
        )
        let activeStart = day.addingTimeInterval(7 * 3_600 + 55 * 60)
        let now = day.addingTimeInterval(8 * 3_600)

        let result = HistoryAnalytics.snapshot(
            on: day, entries: [saved], activeSleepStartedAt: activeStart, now: now, calendar: calendar
        )

        #expect(result.bins[31].sleepSeconds == 8 * 60)
        #expect(result.bins[31].hasOverlappingSleep)
    }

    @Test(arguments: [(3, 29), (10, 25)])
    func sleepBinUnionClipsSavedAndActiveOverlapAcrossMadridDSTMidnight(month: Int, dayOfMonth: Int) throws {
        let calendar = madridCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: dayOfMonth)))
        let dayEnd = try #require(calendar.date(byAdding: .day, value: 1, to: day))
        let activeStart = dayEnd.addingTimeInterval(-30 * 60)
        let now = dayEnd.addingTimeInterval(45 * 60)
        let saved = entry(
            id: "saved-dst-midnight", kind: .sleep,
            date: dayEnd.addingTimeInterval(30 * 60), duration: 90
        )

        let previous = HistoryAnalytics.snapshot(
            on: day, entries: [saved], activeSleepStartedAt: activeStart, now: now, calendar: calendar
        )
        let next = HistoryAnalytics.snapshot(
            on: dayEnd, entries: [saved], activeSleepStartedAt: activeStart, now: now, calendar: calendar
        )

        #expect(previous.bins.reduce(0) { $0 + $1.sleepSeconds } == 60 * 60)
        #expect(next.bins.reduce(0) { $0 + $1.sleepSeconds } == 45 * 60)
        #expect(previous.day.totalSleepSeconds == 60 * 60)
        #expect(next.day.totalSleepSeconds == 45 * 60)
    }

    @Test
    func calendarWeekUsesFirstWeekdayAndIncludesDaysAfterSelection() throws {
        let calendar = utcCalendar
        let selected = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))

        let dates = HistoryPresentation.calendarWeekDates(containing: selected, calendar: calendar)

        #expect(dates.count == 7)
        #expect(calendar.component(.weekday, from: dates[0]) == calendar.firstWeekday)
        #expect(dates.contains { calendar.isDate($0, inSameDayAs: selected) })
        #expect(dates.last! > selected)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private var madridCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        calendar.firstWeekday = 2
        return calendar
    }

    private func entry(id: String, kind: EntryKind, date: Date, duration: Int? = nil) -> Entry {
        Entry(
            id: id, kind: kind, title: kind.title, detail: "",
            occurredAt: Int64(date.timeIntervalSince1970 * 1_000), durationMinutes: duration, amountMl: nil
        )
    }
}
