import Foundation
import Testing
@testable import NidoCore

struct CircularTimelineTests {
    @Test
    func mapsTheFourCardinalHoursAroundA24HourDial() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))

        #expect(CircularTimeline.angle(for: day, calendar: calendar) == 0)
        #expect(CircularTimeline.angle(for: day.addingTimeInterval(6 * 3_600), calendar: calendar) == 90)
        #expect(CircularTimeline.angle(for: day.addingTimeInterval(12 * 3_600), calendar: calendar) == 180)
        #expect(CircularTimeline.angle(for: day.addingTimeInterval(18 * 3_600), calendar: calendar) == 270)
    }

    @Test
    func dividesTheDialIntoSemanticDayAndNightSegments() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))

        let timeline = CircularTimeline.day(on: day, entries: [], now: day, calendar: calendar)

        let expected: [CircularTimeline.PeriodSegment] = [
            CircularTimeline.PeriodSegment(period: .night, startMinute: 0, endMinute: 6 * 60),
            CircularTimeline.PeriodSegment(period: .day, startMinute: 6 * 60, endMinute: 18 * 60),
            CircularTimeline.PeriodSegment(period: .night, startMinute: 18 * 60, endMinute: 24 * 60),
        ]
        #expect(timeline.periodSegments == expected)
    }

    @Test
    func showsTheNowMarkerOnlyOnTodayAtItsCivilClockPosition() throws {
        let calendar = utcCalendar
        let today = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 28,
            hour: 9,
            minute: 30
        )))
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))

        let todayTimeline = CircularTimeline.day(on: today, entries: [], now: today, calendar: calendar)
        let pastTimeline = CircularTimeline.day(on: yesterday, entries: [], now: today, calendar: calendar)

        #expect(todayTimeline.nowMarker?.minute == 9 * 60 + 30)
        #expect(todayTimeline.nowMarker?.angle == 142.5)
        #expect(pastTimeline.nowMarker == nil)
    }

    @Test
    func clipsASleepThatCrossesMidnightIntoEachDay() throws {
        let calendar = utcCalendar
        let firstDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 27)))
        let secondDay = try #require(calendar.date(byAdding: .day, value: 1, to: firstDay))
        let sleepEnd = secondDay.addingTimeInterval(60 * 60)
        let sleep = entry(id: "overnight", kind: .sleep, date: sleepEnd, duration: 120)

        let first = CircularTimeline.day(on: firstDay, entries: [sleep], now: secondDay, calendar: calendar)
        let second = CircularTimeline.day(on: secondDay, entries: [sleep], now: secondDay, calendar: calendar)

        #expect(first.items.count == 1)
        #expect(first.items[0].startMinute == 23 * 60)
        #expect(first.items[0].endMinute == 24 * 60)
        #expect(second.items.count == 1)
        #expect(second.items[0].startMinute == 0)
        #expect(second.items[0].endMinute == 60)
        #expect(first.items[0].entry.id == second.items[0].entry.id)
    }

    @Test
    func filtersPointEventsByDayAndOrdersEverythingChronologically() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let values = [
            entry(id: "later", kind: .diaper, date: day.addingTimeInterval(15 * 3_600)),
            entry(id: "previous", kind: .feed, date: day.addingTimeInterval(-60)),
            entry(id: "earlier", kind: .feed, date: day.addingTimeInterval(8 * 3_600)),
        ]

        let timeline = CircularTimeline.day(on: day, entries: values, now: day, calendar: calendar)

        #expect(timeline.items.map(\.entry.id) == ["earlier", "later"])
    }

    @Test
    func groupsASleepAndAPointEventThatStartAtTheSameMinute() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let values = [
            entry(id: "sleep", kind: .sleep, date: day.addingTimeInterval(9 * 3_600), duration: 60),
            entry(id: "feed", kind: .feed, date: day.addingTimeInterval(8 * 3_600)),
        ]

        let timeline = CircularTimeline.day(on: day, entries: values, now: day, calendar: calendar)

        #expect(timeline.markerGroups.count == 1)
        #expect(timeline.markerGroups[0].isCluster)
        #expect(timeline.markerGroups[0].items.map(\.entry.id) == ["feed", "sleep"])
    }

    @Test
    func clustersSixDenseEventsWithoutDroppingAnyRecord() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let values = (0..<6).map { index in
            entry(
                id: "dense-\(index)",
                kind: index.isMultiple(of: 2) ? .feed : .diaper,
                date: day.addingTimeInterval(8 * 3_600 + TimeInterval(index * 60))
            )
        }

        let timeline = CircularTimeline.day(on: day, entries: values, now: day, calendar: calendar)

        #expect(timeline.markerGroups.count == 1)
        #expect(timeline.markerGroups[0].isCluster)
        #expect(timeline.markerGroups[0].items.map(\.entry.id) == (0..<6).map { "dense-\($0)" })
    }

    @Test
    func boundsDayPagesAndClampsFutureSelectionToToday() throws {
        let calendar = utcCalendar
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 12)))
        let earliest = try #require(calendar.date(byAdding: .day, value: -500, to: today))
        let dates = CircularTimeline.availableDates(earliest: earliest, through: today, maximumDayCount: 90, calendar: calendar)

        #expect(dates.count == 90)
        #expect(dates.last == calendar.startOfDay(for: today))
        #expect(CircularTimeline.clampedDay(today.addingTimeInterval(86_400), through: today, calendar: calendar) == calendar.startOfDay(for: today))
    }

    @Test
    func routesDirectlyBackToTodayFromADistantPastPage() throws {
        let calendar = utcCalendar
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 12)))
        let earliest = try #require(calendar.date(byAdding: .day, value: -30, to: today))
        let dates = CircularTimeline.availableDates(earliest: earliest, through: today, calendar: calendar)
        let selected = try #require(dates.first)

        let destination = CircularTimeline.destination(
            for: .today,
            from: selected,
            availableDates: dates,
            through: today,
            calendar: calendar
        )

        #expect(destination == calendar.startOfDay(for: today))
    }

    @Test
    func keepsCivilClockPositionsOnADaylightSavingDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Madrid"))
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 29)))
        let threeOClock = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 3)))

        let timeline = CircularTimeline.day(
            on: day,
            entries: [entry(id: "dst", kind: .feed, date: threeOClock)],
            now: threeOClock,
            calendar: calendar
        )

        #expect(timeline.items.first?.startMinute == 180)
    }

    private func entry(id: String, kind: EntryKind, date: Date, duration: Int? = nil) -> Entry {
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
