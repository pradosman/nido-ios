import Foundation
import Testing
@testable import NidoCore

struct EvolutionSummaryTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return value
    }

    private func date(_ dayOffset: Int, hour: Int = 12) -> Date {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        return calendar.date(byAdding: .day, value: dayOffset, to: today)!
            .addingTimeInterval(TimeInterval(hour * 3_600))
    }

    private func entry(_ id: String, _ kind: EntryKind, at date: Date, duration: Int? = nil) -> Entry {
        Entry(id: id, kind: kind, title: kind.title, detail: "", occurredAt: Int64(date.timeIntervalSince1970 * 1_000), durationMinutes: duration, amountMl: nil)
    }

    @Test func careMetricsUseSevenCompletedCalendarDaysAndLeaveMissingDaysNil() {
        let now = date(0, hour: 10)
        let startOfToday = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let entries = [
            entry("feed", .feed, at: yesterday.addingTimeInterval(3_600)),
            entry("diaper", .diaper, at: yesterday.addingTimeInterval(7_200)),
            entry("today", .feed, at: now),
            entry("future", .diaper, at: date(1)),
        ]
        let result = EvolutionSummary.build(entries: entries, measurements: [], now: now, calendar: calendar)

        let feeds = result[.feeds]
        #expect(feeds.samples.count == 7)
        #expect(feeds.samples.last?.date == yesterday)
        #expect(feeds.samples.last?.value == 1)
        #expect(feeds.samples.dropLast().allSatisfy { $0.value == nil })
        #expect(feeds.daysWithRecords == 1)
        #expect(feeds.meanValue == 1)
        #expect(result[.diapers].latestValue == 1)
    }

    @Test func sleepIntervalsAreSplitAcrossMidnightAndUseElapsedSecondsOnDST() {
        let end = calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 5))!
        let now = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end))!.addingTimeInterval(3_600)
        let sleep = entry("sleep", .sleep, at: end, duration: 300)
        let result = EvolutionSummary.build(entries: [sleep], measurements: [], now: now, calendar: calendar)[.sleep]

        #expect(abs((result.samples.last?.value ?? 0) - 14_400) < 1)
        #expect(result.daysWithRecords == 2)
        #expect(result.meanValue == 9_000)
    }

    @Test func futureSleepIntervalCannotInflateACompletedDay() {
        let now = date(0, hour: 12)
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let entries = [
            entry("valid", .sleep, at: yesterday.addingTimeInterval(10 * 3_600), duration: 60),
            entry("future-long", .sleep, at: today.addingTimeInterval(13 * 3_600), duration: 48 * 60),
        ]

        let result = EvolutionSummary.build(entries: entries, measurements: [], now: now, calendar: calendar)[.sleep]

        #expect(result.samples.last?.value == 3_600)
        #expect(result.meanValue == 3_600)
    }

    @Test func growthKeepsIndependentLatestValuesAndRealDatedObservations() {
        let now = date(0)
        let measurements = [
            GrowthMeasurement(id: "both", measuredAt: Int64(date(-5).timeIntervalSince1970 * 1_000), weightGrams: 5_200, heightMillimeters: 580),
            GrowthMeasurement(id: "weight", measuredAt: Int64(date(-2).timeIntervalSince1970 * 1_000), weightGrams: 5_500),
            GrowthMeasurement(id: "future", measuredAt: Int64(date(1).timeIntervalSince1970 * 1_000), weightGrams: 9_000, heightMillimeters: 900),
        ]
        let result = EvolutionSummary.build(entries: [], measurements: measurements, now: now, calendar: calendar)

        #expect(result[.weight].latestValue == 5.5)
        #expect(result[.weight].latestMeasurementDate == date(-2))
        #expect(result[.height].latestValue == 58)
        #expect(result[.height].latestMeasurementDate == date(-5))
        #expect(result[.height].samples.count == 1)
    }

    @Test func noDataAndFutureOnlyDataDoNotCreateAveragesOrZeros() {
        let now = date(0)
        let result = EvolutionSummary.build(
            entries: [entry("future", .feed, at: date(1))],
            measurements: [GrowthMeasurement(id: "future", measuredAt: Int64(date(1).timeIntervalSince1970 * 1_000), weightGrams: 7_000)],
            now: now,
            calendar: calendar
        )

        #expect(result[.feeds].meanValue == nil)
        #expect(result[.feeds].daysWithRecords == 0)
        #expect(result[.weight].latestValue == nil)
        #expect(result[.height].samples.isEmpty)
    }
}
