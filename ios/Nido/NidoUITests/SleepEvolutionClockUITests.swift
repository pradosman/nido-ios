import XCTest

@MainActor
final class SleepEvolutionClockUITests: XCTestCase {
    func testLiveActiveSleepSummaryAdvancesWithoutInteraction() {
        let app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = "evolution-live"
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["NIDO_UI_TEST_TICKING_CLOCK"] = "1"
        app.launchArguments += [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", "evolution-live",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
        ]
        app.launch()
        app.buttons["tab-trends"].tap()

        let sleepCard = app.descendants(matching: .any)
            .matching(identifier: "evolution-card-sleep").firstMatch
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 8))
        sleepCard.tap()

        let dayRange = app.descendants(matching: .any)
            .matching(identifier: "sleep-evolution-range-day").firstMatch
        XCTAssertTrue(dayRange.waitForExistence(timeout: 5))
        dayRange.tap()

        let summary = app.descendants(matching: .any)
            .matching(identifier: "sleep-evolution-summary-value").firstMatch
        let activeSleep = app.descendants(matching: .any)
            .matching(identifier: "sleep-evolution-active-sleep").firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertFalse(summary.label.isEmpty)
        XCTAssertTrue(activeSleep.waitForExistence(timeout: 5))
        let startingLabel = summary.label

        let changed = XCTNSPredicateExpectation(
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "exists == true"),
                NSPredicate(format: "label != %@", ""),
                NSPredicate(format: "label != %@", startingLabel),
            ]),
            object: summary
        )
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 90), .completed)
        XCTAssertTrue(activeSleep.exists, "The active-sleep marker should remain visible while its duration advances.")
    }
}
