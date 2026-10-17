import Foundation
import Testing
@testable import NidoCore

@Suite struct FamilyCalendarTests {
    @Test func spanishWeekStartsOnMondayWithoutChangingFamilyTimeZone() {
        let calendar = BabyCareMetrics.calendar(for: BabyCareState(timeZoneID: "Europe/Madrid"), locale: Locale(identifier: "es_ES"))
        #expect(calendar.firstWeekday == 2)
        #expect(calendar.timeZone.identifier == "Europe/Madrid")
        #expect(calendar.identifier == .gregorian)
    }
}
