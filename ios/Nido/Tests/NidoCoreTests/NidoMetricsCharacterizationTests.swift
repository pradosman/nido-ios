import Foundation
import Testing
@testable import NidoCore

struct NidoMetricsCharacterizationTests {
    @Test
    func feedDurationDoesNotCountAsSleep() {
        let date = Date(timeIntervalSince1970: 1_787_918_400)
        let nursing = Entry(
            id: "feed",
            kind: .feed,
            title: "Toma",
            detail: "Lactancia · Pecho izquierdo",
            occurredAt: Int64(date.timeIntervalSince1970 * 1_000),
            durationMinutes: 25,
            amountMl: nil
        )

        let metrics = NidoMetrics.day(date, entries: [nursing], calendar: utcCalendar)

        #expect(metrics.sleepMinutes == 0)
        #expect(metrics.feeds == 1)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
