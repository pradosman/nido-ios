import XCTest

@MainActor
final class EvolutionLiveIntegrationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func tearDown() {
        app?.terminate()
        app = nil
        super.tearDown()
    }

    func testLiveMonogramOpensSettings() {
        launch()
        let account = app.buttons["evolution-account"]
        guard account.waitForExistence(timeout: 5) else {
            XCTFail("The connected summary must expose the caregiver monogram.")
            return
        }
        account.tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-list"].waitForExistence(timeout: 5))
    }

    func testLiveTabUsesEvolutionLabel() {
        launch()
        XCTAssertEqual(app.buttons["tab-trends"].label, "Evolución")
    }

    func testReauthenticationClearsPendingPinPresentation() {
        launch(pendingPinsCleanup: true)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "evolution-pinning-editor").firstMatch.exists,
                       "Household cleanup must clear a pin editor left open by the expired session.")
        let tab = app.buttons["tab-trends"]
        guard tab.isHittable else {
            XCTFail("An inherited pin sheet must not block the next caregiver's navigation.")
            return
        }
        tab.tap()
        XCTAssertTrue(app.buttons["evolution-edit"].isHittable,
                      "The next caregiver must return to the summary without an inherited sheet.")
    }

    /// Proportional render validation for the shared cards and care presentation.
    func testNativeVisualCheckpoints() {
        launch(includeTodayFeed: true)
        attachCheckpoint("live-summary-light")
        openFeeds()
        app.buttons["evolution-care-range-day"].tap()
        let coverage = app.staticTexts["evolution-care-coverage"]
        XCTAssertTrue(coverage.waitForExistence(timeout: 5))
        XCTAssertEqual(coverage.label, "Datos registrados hasta ahora",
                       "Today's partial records must not be described as one of zero completed days.")
        let chart = app.descendants(matching: .any).matching(identifier: "evolution-care-chart").firstMatch
        let dock = app.descendants(matching: .any).matching(identifier: "floating-navigation-tabbar").firstMatch
        for _ in 0..<8 {
            if chart.isHittable && chart.frame.maxY < dock.frame.minY - 12 { break }
            app.swipeUp()
        }
        attachCheckpoint("live-care-hour-labels-light")
        XCTAssertTrue(app.staticTexts["Las horas sin registros se muestran sin valor."].exists)

        launch(appearance: "dark")
        openFeeds()
        attachCheckpoint("live-care-dark")

        launch(contentSize: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge")
        openFeeds()
        attachCheckpoint("live-care-accessibility")
    }

    func testBothGrowthRoutesKeepTheLatestMeasurementReachableAtAccessibilityXXXL() {
        launch(contentSize: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge")
        for metric in ["weight", "height"] {
            let card = app.buttons["evolution-card-\(metric)"]
            for _ in 0..<8 where !card.isHittable { app.swipeUp() }
            guard card.isHittable else {
                XCTFail("The \(metric) card must remain reachable above navigation.")
                return
            }
            card.tap()
            guard app.descendants(matching: .any)["growth.detail.\(metric)"].waitForExistence(timeout: 5) else {
                XCTFail("Missing live growth route: \(metric)")
                return
            }
            let history = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Peso", "Talla")).firstMatch
            let edit = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Editar medición del")).firstMatch
            let dock = app.descendants(matching: .any).matching(identifier: "floating-navigation-tabbar").firstMatch
            for _ in 0..<8 {
                if history.isHittable && edit.isHittable && (!dock.exists || max(history.frame.maxY, edit.frame.maxY) <= dock.frame.minY) { break }
                app.swipeUp()
            }
            XCTAssertTrue(history.isHittable, "The latest growth record must be reachable at maximum text size.")
            XCTAssertTrue(edit.isHittable, "The latest measurement must remain editable above navigation.")
            if dock.exists {
                XCTAssertLessThanOrEqual(max(history.frame.maxY, edit.frame.maxY), dock.frame.minY,
                                         "The complete latest measurement must scroll above the floating navigation.")
            }
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    private func openFeeds() {
        let card = app.buttons["evolution-card-feeds"]
        for _ in 0..<8 where !card.isHittable { app.swipeUp() }
        guard card.isHittable else { XCTFail("The feeds card must be reachable"); return }
        card.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "evolution-care-detail-feeds").firstMatch.waitForExistence(timeout: 5))
    }

    private func attachCheckpoint(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launch(appearance: String = "light", contentSize: String? = nil, pendingPinsCleanup: Bool = false, includeTodayFeed: Bool = false) {
        app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = "evolution-live"
        app.launchEnvironment["NIDO_UI_TEST_APPEARANCE"] = appearance
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        if pendingPinsCleanup { app.launchEnvironment["NIDO_UI_TEST_PENDING_PINS_CLEANUP"] = "1" }
        if includeTodayFeed { app.launchEnvironment["NIDO_UI_TEST_EVOLUTION_TODAY_FEED"] = "1" }
        if let contentSize { app.launchEnvironment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"] = contentSize }
        app.launchArguments = ["-NIDO_UI_TEST_MARKER", "1", "-NIDO_UI_TEST_SCENARIO", "evolution-live", "-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]
        app.launch()
        let tab = app.buttons["tab-trends"]
        guard tab.waitForExistence(timeout: 10) else { XCTFail("Missing Evolution tab"); return }
        if pendingPinsCleanup { return }
        tab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["evolution-summary-live"].waitForExistence(timeout: 5))
    }
}
