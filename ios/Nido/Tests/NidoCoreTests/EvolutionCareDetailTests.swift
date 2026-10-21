import Foundation
import Testing
@testable import NidoCore

struct EvolutionCareDetailTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Madrid")!
        value.firstWeekday = 2
        return value
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func entry(_ id: String, _ kind: EntryKind, at date: Date, duration: Int? = nil) -> Entry {
        Entry(id: id, kind: kind, title: kind.title, detail: "", occurredAt: Int64(date.timeIntervalSince1970 * 1_000), durationMinutes: duration, amountMl: nil)
    }

    @Test func weekKeepsFullCalendarSlotsButAveragesOnlyCompletedRecordedDays() {
        let now = date(2026, 10, 20, 10)
        let yesterday = entry("yesterday", .feed, at: date(2026, 10, 19, 8))
        let today = entry("today", .feed, at: date(2026, 10, 20, 9))
        let future = entry("future", .feed, at: date(2026, 10, 20, 11))
        let snapshot = EvolutionCareSnapshot.build(
            metric: .feeds, entries: [yesterday, today, today, future], activeSleepStartedAt: nil,
            range: .week, anchor: now, now: now, calendar: calendar
        )

        #expect(snapshot.buckets.count == 7)
        #expect(snapshot.totalValue == 1)
        #expect(snapshot.meanValue == 1)
        #expect(snapshot.recordedDayCount == 1)
        #expect(snapshot.eligibleDayCount == 1)
        #expect(snapshot.recordIDs == ["yesterday"])
        #expect(snapshot.periodRecordIDs == ["today", "yesterday"])
        #expect(snapshot.buckets.dropFirst().allSatisfy { $0.value == nil })
    }

    @Test func currentDayUsesHourlyFeedAndDiaperCountsWithoutTurningEmptyHoursIntoZero() {
        let now = date(2026, 10, 20, 10)
        let entries = [
            entry("feed-a", .feed, at: date(2026, 10, 20, 9, 5)),
            entry("feed-b", .feed, at: date(2026, 10, 20, 9, 50)),
            entry("feed-a", .feed, at: date(2026, 10, 20, 9, 5)),
            entry("diaper", .diaper, at: date(2026, 10, 20, 9, 30)),
        ]
        let feeds = EvolutionCareSnapshot.build(
            metric: .feeds, entries: entries, activeSleepStartedAt: nil,
            range: .day, anchor: now, now: now, calendar: calendar
        )
        let diapers = EvolutionCareSnapshot.build(
            metric: .diapers, entries: entries, activeSleepStartedAt: nil,
            range: .day, anchor: now, now: now, calendar: calendar
        )

        #expect(feeds.buckets.count == 24)
        #expect(feeds.buckets[9].value == 2)
        #expect(feeds.buckets[8].value == nil)
        #expect(feeds.totalValue == 2)
        #expect(feeds.recordIDs == ["feed-a", "feed-b"])
        #expect(feeds.eligibleDayCount == 0)
        #expect(diapers.buckets[9].value == 1)
        #expect(diapers.totalValue == 1)
        #expect(diapers.recordIDs == ["diaper"])
    }

    @Test func halfYearUsesMonthlyRecordedDayMeansAndLeavesMissingDaysNil() {
        let now = date(2026, 10, 20)
        let entries = [
            entry("feed-jul-1", .feed, at: date(2026, 7, 1, 9)),
            entry("feed-jul-3", .feed, at: date(2026, 7, 3, 9)),
            entry("feed-aug-1", .feed, at: date(2026, 8, 1, 9)),
            entry("diaper-jul-2", .diaper, at: date(2026, 7, 2, 9)),
        ]
        let feeds = EvolutionCareSnapshot.build(
            metric: .feeds, entries: entries, activeSleepStartedAt: nil,
            range: .sixMonths, anchor: date(2026, 7, 1), now: now, calendar: calendar
        )

        #expect(feeds.buckets.count == 6)
        #expect(feeds.buckets[0].recordedDayCount == 2)
        #expect(feeds.buckets[0].value == 1)
        #expect(feeds.buckets[1].value == 1)
        #expect(feeds.buckets.dropFirst(2).allSatisfy { $0.value == nil })
        #expect(feeds.totalValue == 3)
        #expect(feeds.meanValue == 1)
        #expect(feeds.periodRecordIDs == ["feed-aug-1", "feed-jul-1", "feed-jul-3"])
    }

    @Test func sleepDetailDelegatesExistingSleepTruthAndUnits() {
        let now = date(2026, 10, 20, 10)
        let started = date(2026, 10, 20, 9)
        let saved = entry("sleep", .sleep, at: date(2026, 10, 19, 8), duration: 60)
        let detail = EvolutionCareSnapshot.build(
            metric: .sleep, entries: [saved], activeSleepStartedAt: started,
            range: .day, anchor: now, now: now, calendar: calendar
        )
        let existing = SleepEvolutionSnapshot.build(
            entries: [saved], activeSleepStartedAt: started,
            range: .day, anchor: now, now: now, calendar: calendar
        )

        #expect(detail.period == existing.period)
        #expect(detail.buckets.map(\.value) == existing.buckets.map(\.valueSeconds))
        #expect(detail.totalValue == existing.totalSeconds.map(Double.init))
        #expect(detail.recordIDs == existing.recordIDs)
        #expect(detail.periodRecordIDs == existing.periodRecordIDs)
        #expect(detail.includesActiveSleep == existing.includesActiveSleep)
    }
}
