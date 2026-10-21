import Foundation
import Testing
@testable import NidoCore

struct SleepEvolutionTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Madrid")!
        value.firstWeekday = 2
        return value
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func sleep(_ id: String, end: Date, minutes: Int) -> Entry {
        Entry(id: id, kind: .sleep, title: "Sueño", detail: "", occurredAt: Int64(end.timeIntervalSince1970 * 1_000), durationMinutes: minutes, amountMl: nil)
    }

    @Test func rangesUseCalendarBoundariesAndShiftWithoutMovingOffCurrentPeriod() throws {
        let anchor = date(2026, 7, 1)
        let halfYear = SleepEvolutionPeriod.period(containing: anchor, range: .sixMonths, calendar: calendar)
        #expect(halfYear.start == date(2026, 7, 1, 0))
        #expect(halfYear.end == date(2027, 1, 1, 0))
        let current = SleepEvolutionPeriod.period(containing: date(2026, 10, 20), range: .month, calendar: calendar)
        let now = date(2026, 10, 20)
        #expect(current.shifted(by: 1, now: now, calendar: calendar) == current)
        #expect(current.shifted(by: -1, now: now, calendar: calendar).start == date(2026, 9, 1, 0))
        let old = SleepEvolutionPeriod.period(containing: date(2020, 1, 1), range: .month, calendar: calendar)
        #expect(old.shifted(by: 1, now: date(2020, 1, 10), calendar: calendar) == old)
    }

    @Test func dayBucketsFollowCivilHoursAcrossSpringDSTAndDeduplicateOverlappingSleep() throws {
        let day = date(2026, 3, 29, 0)
        let now = date(2026, 3, 30, 0)
        let values = [
            sleep("overlap", end: date(2026, 3, 29, 4), minutes: 120),
            sleep("overlap", end: date(2026, 3, 29, 4), minutes: 120),
            sleep("second", end: date(2026, 3, 29, 5), minutes: 120),
            sleep("future", end: date(2026, 3, 30, 1), minutes: 120),
        ]
        let snapshot = SleepEvolutionSnapshot.build(entries: values, activeSleepStartedAt: nil, range: .day, anchor: day, now: now, calendar: calendar)
        #expect(snapshot.buckets.count == 23)
        #expect(snapshot.totalSeconds == 10_800)
        #expect(snapshot.recordIDs == ["overlap", "second"])
    }

    @Test func multiDayMeansUseRecordedCompletedDaysAndExcludeTodayAndFuture() throws {
        let now = date(2026, 8, 28, 10)
        let entries = [
            sleep("yesterday", end: date(2026, 8, 27, 8), minutes: 480),
            sleep("today", end: date(2026, 8, 28, 9), minutes: 60),
            sleep("future", end: date(2026, 8, 29, 8), minutes: 1_440),
        ]
        let snapshot = SleepEvolutionSnapshot.build(entries: entries, activeSleepStartedAt: nil, range: .week, anchor: now, now: now, calendar: calendar)
        #expect(snapshot.recordedDayCount == 1)
        #expect(snapshot.eligibleDayCount == 4)
        #expect(snapshot.totalSeconds == 28_800)
        #expect(snapshot.meanSeconds == 28_800)
        #expect(snapshot.recordIDs == ["yesterday"])
    }

    @Test func weekKeepsAllSevenCalendarSlotsAndLeavesIncompleteDaysEmpty() {
        let now = date(2026, 10, 20, 10)
        let snapshot = SleepEvolutionSnapshot.build(
            entries: [sleep("monday", end: date(2026, 10, 19, 8), minutes: 60)],
            activeSleepStartedAt: nil, range: .week, anchor: now, now: now, calendar: calendar
        )
        #expect(snapshot.buckets.count == 7)
        #expect(snapshot.buckets.first?.valueSeconds == 3_600)
        #expect(snapshot.buckets.dropFirst().allSatisfy { $0.valueSeconds == nil && $0.eligibleDayCount == 0 })
        #expect(snapshot.buckets.last?.end == snapshot.period.end)
    }

    @Test func weekExposesFullPeriodRecordIDsWhileAggregateIDsStayCompletedOnly() {
        let now = date(2026, 10, 20, 10)
        let yesterday = sleep("yesterday", end: date(2026, 10, 19, 8), minutes: 60)
        let today = sleep("today", end: date(2026, 10, 20, 9), minutes: 60)
        let future = sleep("future", end: date(2026, 10, 20, 11), minutes: 60)
        let snapshot = SleepEvolutionSnapshot.build(
            entries: [yesterday, today, today, future],
            activeSleepStartedAt: nil, range: .week, anchor: now, now: now, calendar: calendar
        )

        #expect(snapshot.recordIDs == ["yesterday"])
        #expect(snapshot.periodRecordIDs == ["today", "yesterday"])
    }

    @Test func todayIncludesActiveSleepButMultiDayViewsExcludeIt() throws {
        let now = date(2026, 10, 20, 10)
        let saved = sleep("morning", end: date(2026, 10, 20, 8), minutes: 60)
        let activeStart = date(2026, 10, 20, 9)
        let day = SleepEvolutionSnapshot.build(
            entries: [saved], activeSleepStartedAt: activeStart, range: .day, anchor: now, now: now, calendar: calendar
        )
        #expect(day.totalSeconds == 7_200)
        #expect(day.recordedDayCount == 1)
        #expect(day.eligibleDayCount == 0)
        #expect(day.includesActiveSleep)
        #expect(day.buckets[9].valueSeconds == 3_600)
        let week = SleepEvolutionSnapshot.build(
            entries: [saved], activeSleepStartedAt: activeStart, range: .week, anchor: now, now: now, calendar: calendar
        )
        #expect(week.totalSeconds == nil)
        #expect(!week.includesActiveSleep)
        #expect(week.recordIDs.isEmpty)
    }

    @Test func completedDaySleepAppearsInItsHourlyBuckets() throws {
        let now = date(2026, 8, 28, 10)
        let pastDay = date(2026, 8, 27, 0)
        let snapshot = SleepEvolutionSnapshot.build(
            entries: [sleep("three-hours", end: date(2026, 8, 27, 6), minutes: 180)],
            activeSleepStartedAt: nil, range: .day, anchor: pastDay, now: now, calendar: calendar
        )
        #expect(snapshot.buckets[3].valueSeconds == 3_600)
        #expect(snapshot.buckets[4].valueSeconds == 3_600)
        #expect(snapshot.buckets[5].valueSeconds == 3_600)
        #expect(snapshot.buckets[2].valueSeconds == nil)
    }

    @Test func fallDSTDayHasTwentyFiveHourlyBuckets() {
        let day = date(2026, 10, 25, 0)
        let now = date(2026, 10, 26, 0)
        let snapshot = SleepEvolutionSnapshot.build(
            entries: [], activeSleepStartedAt: nil, range: .day, anchor: day, now: now, calendar: calendar
        )
        #expect(snapshot.buckets.count == 25)
        #expect(snapshot.buckets.first?.start == day)
        #expect(snapshot.buckets.last?.end == now)
    }

    @Test func halfYearMonthlyMeansAverageRecordedDaysAndLeaveEmptyMonthsNil() {
        let now = date(2026, 10, 20)
        let anchor = date(2026, 7, 1)
        let snapshot = SleepEvolutionSnapshot.build(
            entries: [
                sleep("july-one", end: date(2026, 7, 1, 8), minutes: 120),
                sleep("july-two", end: date(2026, 7, 3, 8), minutes: 240),
            ],
            activeSleepStartedAt: nil, range: .sixMonths, anchor: anchor, now: now, calendar: calendar
        )
        #expect(snapshot.buckets.first?.recordedDayCount == 2)
        #expect(snapshot.buckets.first?.valueSeconds == 10_800)
        #expect(snapshot.buckets.dropFirst().allSatisfy { $0.valueSeconds == nil })
        #expect(snapshot.recordedDayCount == 2)
        #expect(snapshot.meanSeconds == 10_800)
    }

    @Test func activeOnlyDayHasPositiveHourlyValuesWithoutInventingRecords() {
        let now = date(2026, 10, 20, 13).addingTimeInterval(10 * 60)
        let start = date(2026, 10, 20, 10).addingTimeInterval(10 * 60)
        let snapshot = SleepEvolutionSnapshot.build(
            entries: [], activeSleepStartedAt: start, range: .day, anchor: now, now: now, calendar: calendar
        )
        #expect(snapshot.totalSeconds == 10_800)
        #expect(snapshot.includesActiveSleep)
        #expect(snapshot.recordIDs.isEmpty)
        #expect(snapshot.recordedDayCount == 0)
        #expect(snapshot.eligibleDayCount == 0)
        #expect(snapshot.buckets[10].valueSeconds == 3_000)
        #expect(snapshot.buckets[11].valueSeconds == 3_600)
        #expect(snapshot.buckets[12].valueSeconds == 3_600)
        #expect(snapshot.buckets[13].valueSeconds == 600)
    }

    @Test func emptyFutureDayHasNilValuesAndMidnightSleepEndBelongsToPreviousDay() {
        let today = date(2026, 10, 20, 10)
        let tomorrow = date(2026, 10, 21, 0)
        let future = SleepEvolutionSnapshot.build(
            entries: [], activeSleepStartedAt: nil, range: .day, anchor: tomorrow, now: today, calendar: calendar
        )
        #expect(future.totalSeconds == nil)
        #expect(future.recordIDs.isEmpty)
        #expect(future.buckets.allSatisfy { $0.valueSeconds == nil })

        let midnightEntry = sleep("midnight", end: tomorrow, minutes: 60)
        let previousDay = SleepEvolutionSnapshot.build(
            entries: [midnightEntry], activeSleepStartedAt: nil, range: .day,
            anchor: date(2026, 10, 20, 0), now: tomorrow, calendar: calendar
        )
        let nextDay = SleepEvolutionSnapshot.build(
            entries: [midnightEntry], activeSleepStartedAt: nil, range: .day,
            anchor: tomorrow, now: tomorrow, calendar: calendar
        )
        #expect(previousDay.buckets[23].valueSeconds == 3_600)
        #expect(nextDay.totalSeconds == nil)
        #expect(nextDay.buckets[0].valueSeconds == nil)
    }

    @Test func halfYearMeanWeightsEachRecordedDayAndLeapFebruaryHasTwentyNineDays() {
        let now = date(2026, 10, 20)
        let snapshot = SleepEvolutionSnapshot.build(
            entries: [
                sleep("july-one", end: date(2026, 7, 1, 8), minutes: 120),
                sleep("july-two", end: date(2026, 7, 3, 8), minutes: 240),
                sleep("august", end: date(2026, 8, 2), minutes: 540),
            ],
            activeSleepStartedAt: nil, range: .sixMonths, anchor: date(2026, 7, 1), now: now, calendar: calendar
        )
        #expect(snapshot.buckets[0].valueSeconds == 10_800)
        #expect(snapshot.buckets[1].valueSeconds == 32_400)
        #expect(snapshot.meanSeconds == 18_000)
        let february = SleepEvolutionPeriod.period(containing: date(2024, 2, 29), range: .month, calendar: calendar)
        #expect(february.end == date(2024, 3, 1, 0))
        #expect(february.end.timeIntervalSince(february.start) == 29 * 24 * 3_600)
    }
}
