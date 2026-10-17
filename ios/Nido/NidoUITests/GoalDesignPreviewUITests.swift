import XCTest

@MainActor
final class GoalDesignPreviewUITests: XCTestCase {
    private var app: XCUIApplication!

    func testPartialGoalsShowQuantitiesAndTargetsWithoutAClock() {
        launch()
        XCTAssertTrue(app.otherElements["goal-rings-preview"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons["goal-summary-sleep"].value as? String, "9 horas y 18 minutos de 12 horas")
        XCTAssertEqual(app.buttons["goal-summary-feed"].value as? String, "5 de 8 tomas")
        XCTAssertEqual(app.buttons["goal-summary-diaper"].value as? String, "4 de 6 pañales")
        XCTAssertFalse(app.staticTexts["Ahora"].exists)
        attach("Goal design · light · partial")
    }

    func testDarkGoalsRemainReadable() {
        launch()
        XCTAssertTrue(app.buttons["goal-summary-sleep"].waitForExistence(timeout: 8))
        assertRenderedAppearance(app, dark: true)
        XCTAssertTrue(app.buttons["goal-summary-feed"].isHittable)
        XCTAssertTrue(app.buttons["goal-summary-diaper"].isHittable)
        attach("Goal design · dark · partial")
    }

    func testOverGoalKeepsTheRealQuantityInLightAppearance() {
        launch(scenario: "goal-design-over")
        XCTAssertTrue(app.buttons["goal-summary-feed"].waitForExistence(timeout: 8))
        assertRenderedAppearance(app, dark: false)
        XCTAssertEqual(app.buttons["goal-summary-feed"].value as? String, "10 de 8 tomas")
        attach("Goal design · above target · light")
    }

    func testOverGoalKeepsTheRealQuantityInDarkAppearance() {
        launch(scenario: "goal-design-over")
        XCTAssertTrue(app.buttons["goal-summary-feed"].waitForExistence(timeout: 8))
        assertRenderedAppearance(app, dark: true)
        XCTAssertEqual(app.buttons["goal-summary-feed"].value as? String, "10 de 8 tomas")
        attach("Goal design · above target · dark")
    }

    func testNoGoalsIsDistinctFromZeroProgress() {
        launch(scenario: "goal-design-unset")
        XCTAssertTrue(app.buttons["goal-summary-sleep"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons["goal-summary-sleep"].value as? String, "9 horas y 18 minutos, sin objetivo")
        attach("Goal design · no targets")
    }

    func testSummaryOpensGoalEditorAndUpdatesThePreview() {
        launch()
        let summary = app.buttons["goal-summary-feed"]
        XCTAssertTrue(summary.waitForExistence(timeout: 8))
        summary.tap()
        XCTAssertTrue(app.navigationBars["Objetivos de Marco"].waitForExistence(timeout: 3))
        app.buttons["goal-editor-feed-Increment"].tap()
        app.buttons["goal-editor-done"].tap()
        XCTAssertTrue(app.navigationBars["Objetivos de Marco"].waitForNonExistence(timeout: 3))
        XCTAssertEqual(summary.value as? String, "5 de 9 tomas")
    }

    func testMaximumTextKeepsSummaryAndGoalEditorReachable() {
        launch(accessibility: true)
        let summary = app.buttons["goal-summary-feed"]
        for _ in 0..<8 where !summary.isHittable { app.swipeUp() }
        XCTAssertTrue(summary.isHittable)
        summary.tap()
        XCTAssertTrue(app.navigationBars["Objetivos de Marco"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["goal-editor-done"].isHittable)
        app.buttons["goal-editor-done"].tap()
        attach("Goal design · maximum text")
    }

    private func launch(scenario: String = "goal-design-partial", accessibility: Bool = false) {
        app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchArguments = ["-NIDO_UI_TEST_MARKER", "1", "-NIDO_UI_TEST_SCENARIO", scenario,
                               "-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]
        if accessibility {
            app.launchEnvironment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"] = "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        }
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Hoy"].waitForExistence(timeout: 10))
    }

    private func assertRenderedAppearance(_ app: XCUIApplication, dark: Bool) {
        AppearanceScreenshotAssertion.assertRenderedAppearance(app, dark: dark, file: #filePath, line: #line)
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
