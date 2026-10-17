import Foundation
import Testing
@testable import NidoCore

struct HistoryPresentationTests {
    @Test
    func summarizesSleepFeedsAndDiapersWithoutTreatingVisualScalingAsGoals() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let entries = [
            entry(id: "sleep", kind: .sleep, date: day.addingTimeInterval(8 * 3_600), duration: 90),
            entry(id: "feed-1", kind: .feed, date: day.addingTimeInterval(9 * 3_600)),
            entry(id: "feed-2", kind: .feed, date: day.addingTimeInterval(12 * 3_600)),
            entry(id: "diaper", kind: .diaper, date: day.addingTimeInterval(10 * 3_600)),
            entry(id: "care", kind: .health, date: day.addingTimeInterval(11 * 3_600)),
        ]

        let summary = HistoryPresentation.summary(on: day, entries: entries, now: day, calendar: calendar)

        #expect(summary.sleepMinutes == 90)
        #expect(summary.feedCount == 2)
        #expect(summary.diaperCount == 1)
        #expect(summary.sleepFillFraction == 0.125)
        #expect(summary.feedFillFraction == 0.2)
        #expect(summary.diaperFillFraction == 0.125)
    }

    @Test
    func clampsFutureSelectionAndBuildsASevenDayStripEndingAtToday() throws {
        let calendar = utcCalendar
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 12)))
        let future = try #require(calendar.date(byAdding: .day, value: 3, to: today))

        #expect(HistoryPresentation.select(future, through: today, calendar: calendar) == calendar.startOfDay(for: today))
        let dates = HistoryPresentation.sevenDayDates(around: today, through: today, calendar: calendar)
        #expect(dates.count == 7)
        #expect(dates.last == calendar.startOfDay(for: today))
        #expect(dates.allSatisfy { $0 <= calendar.startOfDay(for: today) })
    }

    @Test
    func monthGridIncludesEmptyDaysAndMarksFutureDatesUnavailable() throws {
        let calendar = utcCalendar
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 12)))

        let grid = HistoryPresentation.month(containing: today, through: today, calendar: calendar)

        #expect(grid.cells.count.isMultiple(of: 7))
        #expect(grid.cells.compactMap(\.date).count == 31)
        #expect(grid.cells.first?.date == nil)
        let august29 = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 29)))
        #expect(grid.cells.first(where: { $0.date == august29 })?.isSelectable == false)
    }

    @Test
    func selectedDayRecordsRemainChronologicalAndRespectTheFilter() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let entries = [
            entry(id: "later", kind: .feed, date: day.addingTimeInterval(12 * 3_600)),
            entry(id: "other", kind: .diaper, date: day.addingTimeInterval(11 * 3_600)),
            entry(id: "earlier", kind: .feed, date: day.addingTimeInterval(8 * 3_600)),
        ]

        let records = HistoryPresentation.entries(on: day, entries: entries, filter: .feed, calendar: calendar)

        #expect(records.map(\.id) == ["earlier", "later"])
    }

    @Test
    func overnightSleepAppearsOnEveryDayItContributesTo() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let overnight = entry(
            id: "overnight", kind: .sleep,
            date: day.addingTimeInterval(24 * 3_600 + 45 * 60), duration: 135
        )

        let previousDayEntries = HistoryPresentation.entries(
            on: day, entries: [overnight], filter: .sleep, calendar: calendar
        )

        #expect(previousDayEntries.map(\.id) == ["overnight"])
    }

    @Test
    func readingAnchorTracksVisibleSectionAndRetainsRecordsAtTheBottom() {
        let empty: [EntryKind: ClosedRange<Double>] = [:]
        let aboveThreshold: [EntryKind: ClosedRange<Double>] = [.diaper: 151...320]
        let visible: [EntryKind: ClosedRange<Double>] = [
            .feed: 20...310,
            .diaper: 0...100,
        ]
        let records: [EntryKind: ClosedRange<Double>] = [
            .feed: -80...0,
            .diaper: (-200)...(-1),
        ]
        let thresholdBoundary: [EntryKind: ClosedRange<Double>] = [.sleep: 150...220]

        #expect(HistoryPresentation.readingAnchor(for: empty) == "history-detail-top")
        #expect(HistoryPresentation.readingAnchor(for: aboveThreshold) == "history-detail-top")
        #expect(HistoryPresentation.readingAnchor(for: visible) == "history-section-feed")
        #expect(HistoryPresentation.readingAnchor(for: records) == "history-records")
        #expect(HistoryPresentation.readingAnchor(for: thresholdBoundary) == "history-section-sleep")
    }

    @Test
    func calendarMonthsIncludeTheMonthAfterTodayAndClampFutureEarliestMonth() throws {
        let calendar = utcCalendar
        let earliest = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 19)))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let june = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))
        let july = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 1)))
        let august = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 1)))
        let september = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)))

        let months = HistoryPresentation.calendarMonths(from: earliest, through: today, calendar: calendar)

        #expect(months == [june, july, august, september])
    }

    @Test
    func calendarMonthsRollOverYearAndClampFutureEarliestToCurrentMonth() throws {
        let calendar = utcCalendar
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 20)))
        let earliestFuture = try #require(calendar.date(from: DateComponents(year: 2027, month: 4, day: 5)))
        let december = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 1)))
        let january = try #require(calendar.date(from: DateComponents(year: 2027, month: 1, day: 1)))

        let months = HistoryPresentation.calendarMonths(from: earliestFuture, through: today, calendar: calendar)

        #expect(months == [december, january])
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
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
}
