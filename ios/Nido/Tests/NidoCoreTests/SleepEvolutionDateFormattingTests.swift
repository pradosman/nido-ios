import Foundation
import Testing
@testable import NidoCore

struct SleepEvolutionDateFormattingTests {
    private let locale = Locale(identifier: "es_ES")

    @Test func twelveHourLocaleDistinguishesMorningAndAfternoon() throws {
        let familyCalendar = try calendar("Europe/Madrid")
        let morning = try date("2026-10-20T01:00:00+02:00")
        let afternoon = try date("2026-10-20T13:00:00+02:00")
        let twelveHourLocale = Locale(identifier: "en_US")

        #expect(SleepEvolutionDateFormatting.axisLabel(for: morning, range: .day, calendar: familyCalendar, locale: twelveHourLocale) != SleepEvolutionDateFormatting.axisLabel(for: afternoon, range: .day, calendar: familyCalendar, locale: twelveHourLocale))
        #expect(SleepEvolutionDateFormatting.time(for: morning, calendar: familyCalendar, locale: twelveHourLocale) != SleepEvolutionDateFormatting.time(for: afternoon, calendar: familyCalendar, locale: twelveHourLocale))
    }

    @Test func axisAndRecordLabelsUseTheFamilyCalendarZone() throws {
        let madridCalendar = try calendar("Europe/Madrid")
        let honoluluCalendar = try calendar("Pacific/Honolulu")
        let instant = try date("2026-10-18T22:00:00Z")

        #expect(SleepEvolutionDateFormatting.axisLabel(for: instant, range: .week, calendar: madridCalendar, locale: locale) == "19")
        #expect(SleepEvolutionDateFormatting.axisLabel(for: instant, range: .week, calendar: honoluluCalendar, locale: locale) == "18")
        #expect(SleepEvolutionDateFormatting.recordDate(for: instant, calendar: madridCalendar, locale: locale).contains("19"))
        #expect(SleepEvolutionDateFormatting.recordDate(for: instant, calendar: honoluluCalendar, locale: locale).contains("18"))
    }

    @Test func timeAndMonthLabelsRespectFamilyZoneAtBoundaries() throws {
        let madridCalendar = try calendar("Europe/Madrid")
        let honoluluCalendar = try calendar("Pacific/Honolulu")
        let midnightMadrid = try date("2026-07-01T00:00:00+02:00")

        #expect(SleepEvolutionDateFormatting.time(for: midnightMadrid, calendar: madridCalendar, locale: locale) == "00:00")
        #expect(SleepEvolutionDateFormatting.time(for: midnightMadrid, calendar: honoluluCalendar, locale: locale) == "12:00")
        #expect(SleepEvolutionDateFormatting.axisLabel(for: midnightMadrid, range: .sixMonths, calendar: madridCalendar, locale: locale) == "jul")
        #expect(SleepEvolutionDateFormatting.axisLabel(for: midnightMadrid, range: .sixMonths, calendar: honoluluCalendar, locale: locale) == "jun")
    }

    private func calendar(_ timeZoneID: String) throws -> Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = try #require(TimeZone(identifier: timeZoneID))
        value.firstWeekday = 2
        return value
    }

    private func date(_ value: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: value))
    }
}
