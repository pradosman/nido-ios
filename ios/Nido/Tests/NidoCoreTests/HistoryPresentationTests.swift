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
