import XCTest

@MainActor
final class EvolutionSyncStatusUITests: XCTestCase {
    func testSummarySeparatesOfflineAndPendingChangeLabels() {
        let app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = "evolution-live"
        app.launchEnvironment["NIDO_UI_TEST_APPEARANCE"] = "light"
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["NIDO_UI_TEST_SYNC_STATUS"] = "pending-offline"
        app.launchArguments = [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", "evolution-live",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
        ]
        app.launch()

        let tab = app.buttons["tab-trends"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["evolution-summary-live"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.staticTexts["evolution-offline-status"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["evolution-pending-status"].waitForExistence(timeout: 5))
        let checkpoint = XCTAttachment(screenshot: app.screenshot())
        checkpoint.name = "evolution-offline-pending-summary"
        checkpoint.lifetime = .keepAlways
        add(checkpoint)
    }
}
