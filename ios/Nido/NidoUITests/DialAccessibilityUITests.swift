import XCTest

@MainActor
final class DialAccessibilityUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testDailyGoalMetricsAnnounceActualQuantitiesAndMissingGoals() {
        launchDailyGoals()

        let expectedMetrics = [
            (identifier: "day-goal-summary-sleep", label: "Sueño"),
            (identifier: "day-goal-summary-feed", label: "Tomas"),
            (identifier: "day-goal-summary-diaper", label: "Pañales"),
        ]
        for metric in expectedMetrics {
            let button = app.buttons[metric.identifier]
            XCTAssertTrue(button.waitForExistence(timeout: 5), app.debugDescription)
            XCTAssertEqual(button.label, metric.label)
            let value = button.value as? String ?? ""
            XCTAssertFalse(value.isEmpty, "The actual \\(metric.label.lowercased()) quantity must be accessible.")
            XCTAssertTrue(value.localizedCaseInsensitiveContains("sin objetivo"), value)
        }
    }

    func testDailyGoalRingAndMetricsExposeDistinctActions() {
        launchDailyGoals()

        let ring = app.buttons["daily-goal-ring-graphic"]
        XCTAssertTrue(ring.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(ring.label, "Ver el detalle de este día")

        let metricIDs = [
            "day-goal-summary-sleep",
            "day-goal-summary-feed",
            "day-goal-summary-diaper",
        ]
        for metricID in metricIDs {
            let metric = app.buttons[metricID]
            XCTAssertTrue(metric.waitForExistence(timeout: 5))
            XCTAssertNotEqual(metric.identifier, ring.identifier)
            XCTAssertTrue(metric.isHittable)
            XCTAssertGreaterThanOrEqual(metric.frame.width, 44)
            XCTAssertGreaterThanOrEqual(metric.frame.height, 44)
        }
    }

    private func launchDailyGoals() {
        app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = "circular-timeline"
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["NIDO_UI_TEST_API_BASE_URL"] =
            ProcessInfo.processInfo.environment["NIDO_UI_TEST_API_BASE_URL"] ?? "http://127.0.0.1:34200"
        app.launchEnvironment["NIDO_UI_TEST_ACCESS_TOKEN"] =
            ProcessInfo.processInfo.environment["NIDO_UI_TEST_ACCESS_TOKEN"]
        app.launchArguments += [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", "circular-timeline",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
        ]
        app.launch()
    }
}
