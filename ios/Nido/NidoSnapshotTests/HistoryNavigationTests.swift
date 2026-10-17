import Foundation
import XCTest

@testable import Nido

@MainActor
final class HistoryNavigationTests: XCTestCase {
    func testOpeningHistoryKeepsTheRequestedDayAndClampsFutureDates() {
        let now = Date(timeIntervalSince1970: 1_788_000_000)
        let store = NidoStore(now: { now }, shouldLoadCredential: false, allowsExternalEffects: false)
        let calendar = Calendar.current
        let previous = calendar.date(byAdding: .day, value: -1, to: now)!

        store.showHistory(on: previous)

        XCTAssertEqual(store.selectedTab, .history)
        XCTAssertEqual(store.historySelectedDay, calendar.startOfDay(for: previous))
        store.selectedTab = .today
        XCTAssertEqual(store.historySelectedDay, calendar.startOfDay(for: previous))

        store.showHistory(on: calendar.date(byAdding: .day, value: 1, to: now)!)
        XCTAssertEqual(store.historySelectedDay, calendar.startOfDay(for: now))
    }
}
