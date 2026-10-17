import Foundation
import Testing
@testable import NidoCore

struct BabyCareMetricsTests {
    @Test func stateCalendarAndEffectiveGoalLookupUsePersistedFamilyZone() throws {
        let goal1 = CareGoalVersion(id: "g1", effectiveDate: "2026-01-01", sleepMinutes: 600, feedCount: nil, diaperCount: nil)
        let goal2 = CareGoalVersion(id: "g2", effectiveDate: "2026-01-03", sleepMinutes: nil, feedCount: 8, diaperCount: nil)
        let state = BabyCareState(revision: 2, timeZoneID: "Europe/Madrid", goalVersions: [goal1, goal2], measurements: [])
        let day = try #require(ISO8601DateFormatter().date(from: "2026-01-02T23:30:00Z"))
        #expect(BabyCareMetrics.calendar(for: state).timeZone.identifier == "Europe/Madrid")
        #expect(BabyCareMetrics.goals(on: day, state: state)?.id == "g2")
    }

    @Test func summaryClipsSleepToCivilDayAndCountsActiveSleepOnlyOnce() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Madrid"))
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 29)))
        let start = day.addingTimeInterval(3_600)
        let now = start.addingTimeInterval(3_600)
        let active = Entry(id: "active", kind: .sleep, title: "Sueño", detail: "", occurredAt: Int64(now.timeIntervalSince1970 * 1000), durationMinutes: 60, amountMl: nil)
        let result = BabyCareMetrics.summary(on: day, entries: [active], activeSleepStartedAt: start, now: now, calendar: calendar)
        #expect(result.sleepSeconds == 3_600)
    }

    @Test(arguments: [(3, 29), (10, 25)])
    func savedAndActiveSleepUnionAcrossMidnightOnMadridDSTDays(month: Int, dayOfMonth: Int) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Madrid"))
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: dayOfMonth)))
        let dayEnd = try #require(calendar.date(byAdding: .day, value: 1, to: day))
        let now = dayEnd.addingTimeInterval(45 * 60)
        let saved = Entry(
            id: "saved-over-midnight", kind: .sleep, title: "Sueño", detail: "",
            occurredAt: Int64(dayEnd.addingTimeInterval(30 * 60).timeIntervalSince1970 * 1_000),
            durationMinutes: 90, amountMl: nil
        )

        let firstDay = BabyCareMetrics.summary(
            on: day, entries: [saved], activeSleepStartedAt: dayEnd.addingTimeInterval(-30 * 60),
            now: now, calendar: calendar
        )
        let nextDay = BabyCareMetrics.summary(
            on: dayEnd, entries: [saved], activeSleepStartedAt: dayEnd.addingTimeInterval(-30 * 60),
            now: now, calendar: calendar
        )

        #expect(firstDay.sleepSeconds == 60 * 60)
        #expect(nextDay.sleepSeconds == 45 * 60)
    }

    @Test func summaryCountsRepeatedFeedAndDiaperIDsOnlyOnce() throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let timestamp = Int64(day.addingTimeInterval(3_600).timeIntervalSince1970 * 1_000)
        let feed = Entry(id: "same-feed", kind: .feed, title: "Toma", detail: "", occurredAt: timestamp, durationMinutes: nil, amountMl: 90)
        let diaper = Entry(id: "same-diaper", kind: .diaper, title: "Pañal", detail: "", occurredAt: timestamp, durationMinutes: nil, amountMl: nil)

        let result = BabyCareMetrics.summary(
            on: day, entries: [feed, feed, diaper, diaper], now: day, calendar: calendar
        )

        #expect(result.feedCount == 1)
        #expect(result.diaperCount == 1)
    }
}
