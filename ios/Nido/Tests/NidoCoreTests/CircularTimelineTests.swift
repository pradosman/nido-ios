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
    func separatesFeedAndDiaperGroupsAndNeverGroupsSleep() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let values = [
            entry(id: "sleep", kind: .sleep, date: day.addingTimeInterval(9 * 3_600), duration: 60),
            entry(id: "feed", kind: .feed, date: day.addingTimeInterval(8 * 3_600)),
            entry(id: "diaper", kind: .diaper, date: day.addingTimeInterval(8 * 3_600)),
        ]

        let timeline = CircularTimeline.day(on: day, entries: values, now: day, calendar: calendar)

        #expect(timeline.markerGroups.count == 2)
        #expect(timeline.markerGroups.map(\.kind) == [.feed, .diaper])
        #expect(timeline.markerGroups.flatMap(\.items).map(\.entry.id) == ["feed", "diaper"])
        #expect(timeline.markerGroups[0].id.contains("feed"))
        #expect(timeline.markerGroups[1].id.contains("diaper"))
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

        #expect(timeline.markerGroups.count == 2)
        #expect(timeline.markerGroups.map(\.kind) == [.feed, .diaper])
        #expect(timeline.markerGroups[0].items.map(\.entry.id) == ["dense-0", "dense-2", "dense-4"])
        #expect(timeline.markerGroups[1].items.map(\.entry.id) == ["dense-1", "dense-3", "dense-5"])
        #expect(timeline.markerGroups.allSatisfy { $0.isCluster })
    }

    @Test
    func keepsHealthInDayItemsButExcludesItFromRingGroupsAndCounts() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let values = [
            entry(id: "feed", kind: .feed, date: day.addingTimeInterval(8 * 3_600)),
            entry(id: "health", kind: .health, date: day.addingTimeInterval(8 * 3_600)),
        ]

        let timeline = CircularTimeline.day(on: day, entries: values, now: day, calendar: calendar)

        #expect(timeline.items.map(\.entry.id) == ["feed", "health"])
        #expect(timeline.markerGroups.flatMap(\.items).map(\.entry.id) == ["feed"])
        #expect(timeline.feedCount == 1)
        #expect(timeline.diaperCount == 0)
    }

    @Test
    func activeSleepUsesOnePreparedSegmentAndContributesExactElapsedTime() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let now = day.addingTimeInterval(10 * 3_600)
        let activeStart = day.addingTimeInterval(8 * 3_600 + 30 * 60)

        let timeline = CircularTimeline.day(
            on: day,
            entries: [],
            activeSleepStartedAt: activeStart,
            now: now,
            calendar: calendar
        )

        let segment = try #require(timeline.sleepSegments.only)
        #expect(segment.isActive)
        #expect(segment.startMinute == 8 * 60 + 30)
        #expect(segment.endMinute == 10 * 60)
        #expect(segment.elapsedSeconds == 90 * 60)
        #expect(timeline.totalSleepSeconds == segment.elapsedSeconds)
    }

    @Test
    func midnightClippingAndCentralTotalShareTheSamePreparedSegments() throws {
        let calendar = utcCalendar
        let firstDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 27)))
        let secondDay = try #require(calendar.date(byAdding: .day, value: 1, to: firstDay))
        let sleep = entry(
            id: "overnight-total",
            kind: .sleep,
            date: secondDay.addingTimeInterval(60 * 60),
            duration: 120
        )

        let first = CircularTimeline.day(on: firstDay, entries: [sleep], now: secondDay, calendar: calendar)
        let second = CircularTimeline.day(on: secondDay, entries: [sleep], now: secondDay, calendar: calendar)

        #expect(first.sleepSegments.only?.startMinute == 23 * 60)
        #expect(first.sleepSegments.only?.endMinute == 24 * 60)
        #expect(first.totalSleepSeconds == first.sleepSegments.only?.elapsedSeconds)
        #expect(first.totalSleepSeconds == 60 * 60)
        #expect(second.sleepSegments.only?.startMinute == 0)
        #expect(second.sleepSegments.only?.endMinute == 60)
        #expect(second.totalSleepSeconds == second.sleepSegments.only?.elapsedSeconds)
        #expect(second.totalSleepSeconds == 60 * 60)
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

    @Test
    func daylightSavingUsesCivilArcPlacementAndRealElapsedSleepDuration() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Madrid"))
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 29)))
        let sleepEnd = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 3,
            day: 29,
            hour: 3,
            minute: 30
        )))
        let sleep = entry(id: "dst-sleep", kind: .sleep, date: sleepEnd, duration: 60)

        let timeline = CircularTimeline.day(on: day, entries: [sleep], now: sleepEnd, calendar: calendar)
        let segment = try #require(timeline.sleepSegments.only)

        // Civil placement spans 01:30–03:30, while the spring-forward elapsed time is one real hour.
        #expect(segment.startMinute == 90)
        #expect(segment.endMinute == 210)
        #expect(segment.elapsedSeconds == 60 * 60)
        #expect(timeline.totalSleepSeconds == 60 * 60)
    }

    @Test(arguments: [CGFloat(280), 320, 350, 390])
    func radialGeometryKeepsProportionalSeparatedBandsInsideTheDial(side: CGFloat) {
        let geometry = CircularTimeline.Geometry(side: side)
        let laneCenterSpacing = geometry.trackStroke + geometry.bandGap
        let expandedDialBounds = geometry.dialBounds.insetBy(dx: -0.001, dy: -0.001)

        #expect(geometry.trackStroke >= 26)
        #expect(geometry.trackStroke <= 34)
        #expect(geometry.bandGap >= 1.5)
        #expect(geometry.bandGap <= 2.5)
        #expect(geometry.diaperRadius < geometry.trackRadius)
        #expect(geometry.trackRadius < geometry.feedRadius)
        #expect(abs(geometry.feedRadius - geometry.trackRadius - laneCenterSpacing) < 0.001)
        #expect(abs(geometry.trackRadius - geometry.diaperRadius - laneCenterSpacing) < 0.001)
        #expect(geometry.feedVisualDiameter == geometry.trackStroke)
        #expect(geometry.diaperVisualDiameter == geometry.trackStroke)
        #expect(geometry.clusterVisualDiameter == geometry.trackStroke)
        #expect(geometry.interactionDiameter == 44)
        #expect(geometry.nowVisualDiameter <= geometry.trackStroke)
        #expect(geometry.centerContentDiameter < geometry.centerInnerDiameter)

        let cardinalNearCases = [
            (cardinalMinute: 0, eventMinute: 23),
            (cardinalMinute: 0, eventMinute: 1_417),
            (cardinalMinute: 360, eventMinute: 337),
            (cardinalMinute: 360, eventMinute: 383),
            (cardinalMinute: 720, eventMinute: 697),
            (cardinalMinute: 720, eventMinute: 743),
            (cardinalMinute: 1_080, eventMinute: 1_057),
            (cardinalMinute: 1_080, eventMinute: 1_103),
        ]
        for value in cardinalNearCases {
            let cardinalFrame = geometry.cardinalFrame(atMinute: value.cardinalMinute)
            #expect(expandedDialBounds.contains(cardinalFrame))
            #expect(geometry.dialBounds.contains(
                geometry.eventVisualFrame(kind: .feed, atMinute: value.eventMinute)
            ))
            #expect(!cardinalFrame.intersects(
                geometry.eventVisualFrame(kind: .feed, atMinute: value.eventMinute)
            ))
        }

        #expect(geometry.cardinalFrame(atMinute: 0).width > geometry.cardinalFrame(atMinute: 0).height)
        #expect(geometry.cardinalSize(atMinute: 0) == geometry.cardinalSize(atMinute: 360))
    }

    @Test
    func radialGeometryMatchesTheApproved350PointProportion() {
        let geometry = CircularTimeline.Geometry(side: 350)

        #expect(geometry.trackStroke == 30)
        #expect(geometry.bandGap == 2)
        #expect(geometry.feedRadius == 137)
        #expect(geometry.trackRadius == 105)
        #expect(geometry.diaperRadius == 73)
        #expect(geometry.ringDiameter == 210)
        #expect(geometry.faceInset == 21)
        #expect(350 / 2 - geometry.faceInset == 154)
        #expect(geometry.feedRadius - geometry.trackRadius == 32)
        #expect(geometry.trackRadius - geometry.diaperRadius == 32)
        #expect(geometry.feedVisualDiameter == 30)
        #expect(geometry.diaperVisualDiameter == 30)
        #expect(geometry.clusterVisualDiameter == 30)
        #expect(geometry.interactionDiameter == 44)
        #expect(geometry.cardinalSize(atMinute: 0) == CGSize(width: 20, height: 18))
        #expect(geometry.cardinalSize(atMinute: 360) == CGSize(width: 20, height: 18))
        #expect(geometry.dialBounds.contains(geometry.cardinalFrame(atMinute: 0)))
        #expect(geometry.dialBounds.contains(geometry.cardinalFrame(atMinute: 360)))
        #expect(abs(geometry.nowVisualDiameter - 18) < 0.001)
        #expect(geometry.eventVisualFrame(kind: .feed, atMinute: 0).size == CGSize(width: 30, height: 30))
        #expect(geometry.eventVisualFrame(kind: .diaper, atMinute: 0).size == CGSize(width: 30, height: 30))
        #expect(geometry.eventHitFrame(kind: .feed, atMinute: 0).size == CGSize(width: 44, height: 44))
        #expect(geometry.eventHitFrame(kind: .diaper, atMinute: 0).size == CGSize(width: 44, height: 44))
        #expect(geometry.trackRadius + geometry.trackStroke / 2 + geometry.bandGap == geometry.feedRadius - geometry.trackStroke / 2)
        #expect(geometry.diaperRadius + geometry.trackStroke / 2 + geometry.bandGap == geometry.trackRadius - geometry.trackStroke / 2)
    }

    @Test
    func clockScaleUsesFortyEightHalfHourPositionsWithEightNumberedHours() {
        let positions = CircularTimeline.clockScale
        let numberedPositions = positions.compactMap { position -> (minute: Int, hour: Int)? in
            guard case let .number(hour) = position.mark else { return nil }
            return (position.minute, hour)
        }
        let dotPositions = positions.filter {
            if case .dot = $0.mark { return true }
            return false
        }

        #expect(positions.count == 48)
        #expect(positions.map(\.minute) == Array(stride(from: 0, to: 1_440, by: 30)))
        #expect(numberedPositions.map(\.minute) == Array(stride(from: 0, to: 1_440, by: 180)))
        #expect(numberedPositions.map(\.hour) == [0, 3, 6, 9, 12, 15, 18, 21])
        #expect(dotPositions.count == 40)
        #expect(dotPositions.allSatisfy { $0.minute % 180 != 0 })
    }

    @Test
    func clockScaleDistinguishesWholeHourDotsAndSharesAnOutsideRadius() {
        let geometry = CircularTimeline.Geometry(side: 350)
        let dotKinds = CircularTimeline.clockScale.compactMap { position -> CircularTimeline.ClockDotKind? in
            guard case let .dot(kind) = position.mark else { return nil }
            return kind
        }

        #expect(dotKinds.count { $0 == .wholeHour } == 16)
        #expect(dotKinds.count { $0 == .halfHour } == 24)
        #expect(geometry.clockDotDiameter(for: .wholeHour) > geometry.clockDotDiameter(for: .halfHour))
        #expect(geometry.scaleRadius == 165)
        #expect(geometry.tickRadius == geometry.scaleRadius)
        #expect(geometry.scaleRadius > geometry.feedRadius + geometry.trackStroke / 2)
        #expect(geometry.cardinalFrame(atMinute: 0).midY == geometry.center.y - geometry.scaleRadius)
        #expect(geometry.dialBounds.contains(geometry.cardinalFrame(atMinute: 1_260)))
    }

    @Test(arguments: [
        (seconds: 0, expected: "0:00"),
        (seconds: 300, expected: "0:05"),
        (seconds: 3_600, expected: "1:00"),
        (seconds: 57_240, expected: "15:54"),
    ])
    func dashboardDurationUsesCompactHoursAndMinutes(argument: (seconds: Int, expected: String)) {
        let label = CircularTimeline.dashboardDurationLabel(argument.seconds)

        #expect(label == argument.expected)
        #expect(!label.contains("s"))
        #expect(!label.contains("\n"))
    }

    @Test
    func dashboardDurationHasUnambiguousAccessibilityCopy() {
        #expect(CircularTimeline.dashboardDurationAccessibilityLabel(0) == "0 minutos")
        #expect(CircularTimeline.dashboardDurationAccessibilityLabel(300) == "5 minutos")
        #expect(CircularTimeline.dashboardDurationAccessibilityLabel(3_600) == "1 hora")
        #expect(CircularTimeline.dashboardDurationAccessibilityLabel(57_240) == "15 horas y 54 minutos")
    }

    @Test
    func radialGeometryInsetsCenterContentFromTheDiaperRing() {
        let geometry = CircularTimeline.Geometry(side: 350)

        #expect(geometry.centerInnerDiameter == 116)
        #expect(geometry.centerSafetyInset == 6)
        #expect(geometry.centerContentDiameter == 104)
        #expect(abs(geometry.centerDurationFontSize - 32.24) < 0.01)
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

private extension Collection {
    var only: Element? { count == 1 ? first : nil }
}
