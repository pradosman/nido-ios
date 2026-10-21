import XCTest

@MainActor
final class BabyCareUITests: XCTestCase {
    private func launch(_ scenario: String = "baby-care", accessibility: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        if accessibility {
            app.launchEnvironment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"] = "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        }
        app.launchArguments = ["-NIDO_UI_TEST_MARKER", "1", "-NIDO_UI_TEST_SCENARIO", scenario,
                               "-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]
        app.launch()
        XCTAssertTrue(app.floatingNavigationTabButtons["Hoy"].waitForExistence(timeout: 10))
        return app
    }

    func testProductionTodayUsesHouseholdGoalsAndOpensVersionedEditor() {
        let app = launch()
        XCTAssertTrue(app.descendants(matching: .any)["today-goal-rings"].firstMatch.waitForExistence(timeout: 5))
        let edit = app.buttons["today-edit-goals"]
        XCTAssertTrue(edit.exists)
        guard edit.exists else { return }
        edit.tap()
        XCTAssertTrue(app.buttons["goals-save"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.datePickers["goals-effective-date"].exists)
        XCTAssertFalse(app.staticTexts["Datos y objetivos de ejemplo"].exists)
    }

    func testBabyGrowthOpensFromSettingsAndSupportsDatedMeasurements() {
        let app = launch()
        app.floatingNavigationTabButtons["Ajustes"].tap()
        let growth = app.buttons["open-baby-growth"]
        for _ in 0..<5 where !growth.isHittable { app.swipeUp() }
        XCTAssertTrue(growth.waitForExistence(timeout: 3))
        guard growth.exists else { return }
        growth.tap()
        XCTAssertTrue(app.buttons["growth.add"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["growth.latest.weight.value"].exists)
        XCTAssertTrue(app.staticTexts["growth.latest.height.value"].exists)
        app.buttons["growth.add"].tap()
        XCTAssertTrue(app.textFields["growth.measurement.weight"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.datePickers["growth.measurement.date"].exists)
        XCTAssertTrue(app.buttons["growth.measurement.save"].exists)
    }

    func testHistoryUsesTheSameGoalPanelAndCalendar() {
        let app = launch()
        app.floatingNavigationTabButtons["Historia"].tap()
        let feeds = app.buttons.matching(NSPredicate(format: "label == %@", "Tomas")).firstMatch
        XCTAssertTrue(feeds.waitForExistence(timeout: 5))
        XCTAssertTrue((feeds.value as? String)?.contains("objetivo 8") == true)
        XCTAssertFalse(app.staticTexts["Ahora"].exists)
    }

    func testGrowthSavesARealMeasurementAndShowsItsDate() {
        let app = launch("baby-care-empty")
        app.floatingNavigationTabButtons["Ajustes"].tap()
        app.buttons["open-baby-growth"].tap()
        app.buttons["growth.add"].tap()
        let weight = app.textFields["growth.measurement.weight"]
        XCTAssertTrue(weight.waitForExistence(timeout: 3))
        weight.tap()
        weight.typeText("6,95")
        app.buttons["growth.measurement.save"].tap()
        XCTAssertTrue(app.staticTexts["growth.latest.weight.value"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["growth.latest.weight.value"].label.contains("6,95"))
        XCTAssertTrue(app.staticTexts["growth.latest.weight.date"].exists)
    }

    func testFirstManualGoalsSaveForTodayWithoutInventedDefaults() {
        let app = launch("baby-care-empty")
        app.buttons["today-edit-goals"].tap()
        let sleep = app.textFields["goals-value-sleep"]
        XCTAssertTrue(sleep.waitForExistence(timeout: 3))
        XCTAssertEqual(sleep.value as? String, "Sin objetivo")
        sleep.tap()
        sleep.typeText("12")
        app.textFields["goals-value-feed"].tap()
        app.textFields["goals-value-feed"].typeText("8")
        app.textFields["goals-value-diaper"].tap()
        app.textFields["goals-value-diaper"].typeText("6")
        app.buttons["goals-save"].tap()
        XCTAssertTrue(app.buttons["today-edit-goals"].waitForExistence(timeout: 5))
        XCTAssertTrue((app.buttons["day-goal-summary-feed"].value as? String)?.contains("objetivo 8") == true)
        XCTAssertTrue((app.buttons["day-goal-summary-diaper"].value as? String)?.contains("objetivo 6") == true)
    }

    func testRegisteringAnActivityUpdatesTheGoalAndUndoRestoresIt() {
        let app = launch()
        let diapers = app.buttons["day-goal-summary-diaper"]
        XCTAssertEqual(diapers.value as? String, "1, objetivo 6")
        app.buttons["registration-action-button"].tap()
        app.buttons["Registrar pañal"].tap()
        let repeatDiaper = app.buttons["Repetir pañal · Pis"]
        XCTAssertTrue(repeatDiaper.waitForExistence(timeout: 3))
        repeatDiaper.tap()
        let undo = app.buttons["Deshacer"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        XCTAssertEqual(diapers.value as? String, "2, objetivo 6")
        XCTAssertEqual(app.buttons["day-goal-summary-feed"].value as? String, "2, objetivo 8")
        undo.tap()
        let restored = expectation(for: NSPredicate(format: "value == %@", "1, objetivo 6"), evaluatedWith: diapers)
        wait(for: [restored], timeout: 5)
    }

    func testNativeVisualCheckpointsInLightAppearance() {
        captureNativeVisualCheckpoints(dark: false)
        let app = launch(accessibility: true)
        app.floatingNavigationTabButtons["Ajustes"].tap()
        let growth = app.buttons["open-baby-growth"]
        for _ in 0..<8 where !growth.isHittable { app.swipeUp() }
        growth.tap()
        XCTAssertTrue(app.staticTexts["growth.latest.weight.value"].waitForExistence(timeout: 5))
        attach(app, "accessibility-growth")
    }

    func testNativeVisualCheckpointsInDarkAppearance() {
        captureNativeVisualCheckpoints(dark: true)
    }

    private func captureNativeVisualCheckpoints(dark: Bool) {
        let app = launch()
        assertRenderedAppearance(app, dark: dark)
        attach(app, "\(dark ? "dark" : "light")-today")
        app.floatingNavigationTabButtons["Historia"].tap()
        attach(app, "\(dark ? "dark" : "light")-history")
        app.floatingNavigationTabButtons["Ajustes"].tap()
        app.buttons["open-baby-growth"].tap()
        attach(app, "\(dark ? "dark" : "light")-growth")
        app.buttons["growth.series.weight"].tap()
        attach(app, "\(dark ? "dark" : "light")-weight")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "baby-care-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertRenderedAppearance(_ app: XCUIApplication, dark: Bool) {
        AppearanceScreenshotAssertion.assertRenderedAppearance(app, dark: dark, file: #filePath, line: #line)
    }
}
