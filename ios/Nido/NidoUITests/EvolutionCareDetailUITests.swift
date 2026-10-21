import XCTest

@MainActor
final class EvolutionCareDetailUITests: XCTestCase {
    private var app: XCUIApplication!

    func testLiveSummaryOpensFeedAndDiaperDetailsWithRealRecords() {
        launchLiveScenario()
        guard element("evolution-summary-live").waitForExistence(timeout: 8) else {
            XCTFail("The live Evolution summary should be reachable from the Trends tab.")
            return
        }

        guard openMetric("feeds"), element("evolution-care-detail-feeds").waitForExistence(timeout: 5) else {
            XCTFail("The feed summary card should open its detail.")
            return
        }
        XCTAssertEqual(element("evolution-care-summary-value").label, "2 tomas")
        XCTAssertEqual(element("evolution-care-summary-detail").label, "150 ml")
        XCTAssertTrue(element("evolution-care-chart-card").exists)
        app.buttons["evolution-care-records-link"].tap()
        XCTAssertTrue(element("evolution-care-records-feeds").waitForExistence(timeout: 5))
        XCTAssertTrue(element("evolution-care-record-evolution-live-feed-a").exists)
        let backButton = app.navigationBars.buttons.firstMatch
        guard backButton.exists else {
            XCTFail("The feed detail should expose a back button.")
            return
        }
        backButton.tap()
        app.navigationBars.buttons.firstMatch.tap()

        guard openMetric("diapers"), element("evolution-care-detail-diapers").waitForExistence(timeout: 5) else {
            XCTFail("The diaper summary card should open its detail.")
            return
        }
        XCTAssertEqual(element("evolution-care-summary-value").label, "2 pañales")
        XCTAssertTrue(element("evolution-care-chart-card").exists)
        app.buttons["evolution-care-records-link"].tap()
        XCTAssertTrue(element("evolution-care-records-diapers").waitForExistence(timeout: 5))
        XCTAssertTrue(element("evolution-care-record-evolution-live-diaper-a").exists)
    }

    func testDeletingFeedRecomputesLiveDetailFromStore() {
        launchLiveScenario()
        guard openMetric("feeds"), element("evolution-care-detail-feeds").waitForExistence(timeout: 5) else {
            XCTFail("The feed summary card should open its detail.")
            return
        }
        XCTAssertEqual(element("evolution-care-summary-value").label, "2 tomas")

        app.buttons["evolution-care-records-link"].tap()
        let firstFeed = app.cells.containing(.any, identifier: "evolution-care-record-evolution-live-feed-a").firstMatch
        XCTAssertTrue(firstFeed.waitForExistence(timeout: 5))
        firstFeed.swipeLeft()
        app.buttons["Eliminar"].firstMatch.tap()
        app.alerts.buttons["Eliminar"].tap()

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertEqual(element("evolution-care-summary-value").label, "1 toma")
        XCTAssertEqual(element("evolution-care-summary-detail").label, "90 ml")
        XCTAssertFalse(element("evolution-care-record-evolution-live-feed-a").exists)
    }

    func testCareRecordsShowFamilyLocalDateAndTime() {
        launchLiveScenario(timeZone: "America/Los_Angeles")
        guard openMetric("feeds"), element("evolution-care-detail-feeds").waitForExistence(timeout: 5) else {
            XCTFail("The feed summary card should open its detail.")
            return
        }
        app.buttons["evolution-care-records-link"].tap()
        let record = element("evolution-care-record-evolution-live-feed-a")
        guard record.waitForExistence(timeout: 5) else {
            XCTFail("The seeded feed record should appear in its period.")
            return
        }
        XCTAssertTrue(record.label.localizedCaseInsensitiveContains("19 oct"), "The row should identify the family-local calendar date.")
        XCTAssertTrue(record.label.contains("09:00"), "The seeded 09:00 family-local time should not shift with the device time zone.")
    }

    func testPeriodSummaryOmitsTodayUntilItsBucketIsComplete() {
        launchLiveScenario(includeTodayFeed: true)
        guard openMetric("feeds"), element("evolution-care-detail-feeds").waitForExistence(timeout: 5) else {
            XCTFail("The feed summary card should open its detail.")
            return
        }

        XCTAssertEqual(element("evolution-care-summary-value").label, "2 tomas")
        XCTAssertEqual(element("evolution-care-summary-detail").label, "150 ml")
        app.buttons["evolution-care-records-link"].tap()
        let liveFeedIDs = [
            "evolution-care-record-evolution-live-feed-a",
            "evolution-care-record-evolution-live-feed-b",
            "evolution-care-record-evolution-live-feed-today"
        ]
        for id in liveFeedIDs {
            XCTAssertTrue(
                app.cells.containing(.any, identifier: id).firstMatch.waitForExistence(timeout: 3),
                "The records list should include \(id) even while period totals exclude today's feed."
            )
        }
    }

    func testSelectedMonthlyBucketUsesItsOwnCoverage() {
        launchLiveScenario()
        guard openMetric("feeds"), element("evolution-care-detail-feeds").waitForExistence(timeout: 5) else {
            XCTFail("The feed summary card should open its detail.")
            return
        }
        let monthRange = app.buttons["evolution-care-range-month"]
        guard monthRange.waitForExistence(timeout: 5) else {
            XCTFail("The care detail should expose monthly range selection.")
            return
        }
        monthRange.tap()
        app.buttons["evolution-care-explore-values"].tap()
        let buckets = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "evolution-care-bucket-"
        ))
        let dayNineteen = buckets.matching(NSPredicate(format: "label CONTAINS[c] %@", "19 oct")).firstMatch
        guard dayNineteen.waitForExistence(timeout: 5) else {
            XCTFail("The monthly chart should expose its 19 Oct record bucket.")
            return
        }
        dayNineteen.tap()
        XCTAssertTrue(element("evolution-care-selected-interval").label.localizedCaseInsensitiveContains("19 oct"))
        XCTAssertEqual(
            element("evolution-care-coverage").label,
            "1 de 1 día terminado con registros",
            "Coverage should describe the selected day bucket, not the entire month."
        )
    }

    func testCareChartTouchSelectsTheBucketUnderThePointer() {
        launchLiveScenario()
        guard openMetric("feeds"), element("evolution-care-detail-feeds").waitForExistence(timeout: 5) else {
            XCTFail("The feed summary card should open its detail.")
            return
        }
        app.buttons["evolution-care-range-month"].tap()
        let chart = element("evolution-care-chart")
        guard chart.waitForExistence(timeout: 5) else {
            XCTFail("The monthly care chart should be accessible as a touch target.")
            return
        }
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.60, dy: 0.55)).tap()
        XCTAssertTrue(element("evolution-care-selected-interval").waitForExistence(timeout: 3))
    }

    func testCarePeriodDateRemainsReadableAtAccessibilityXXXL() {
        launchLiveScenario(contentSize: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge")
        guard openMetric("feeds"), element("evolution-care-detail-feeds").waitForExistence(timeout: 5) else {
            XCTFail("The feed summary card should open its detail.")
            return
        }
        let period = element("evolution-care-period")
        XCTAssertTrue(period.waitForExistence(timeout: 5))
        XCTAssertTrue(period.label.contains("19") && period.label.contains("25"), "The complete family-week date range should remain available.")
        XCTAssertTrue(period.isHittable, "The period label should remain reachable at Accessibility XXXL.")
        let periodFrame = period.frame
        let windowFrame = app.windows.firstMatch.frame
        let previousPeriod = app.buttons["evolution-care-previous"]
        XCTAssertLessThanOrEqual(
            periodFrame.maxY, previousPeriod.frame.minY,
            "At maximum text size the date needs a separate row above the arrow controls."
        )
        XCTAssertGreaterThanOrEqual(periodFrame.minX, windowFrame.minX)
        XCTAssertLessThanOrEqual(periodFrame.maxX, windowFrame.maxX)
        XCTAssertGreaterThanOrEqual(periodFrame.minY, windowFrame.minY)
        XCTAssertLessThanOrEqual(periodFrame.maxY, windowFrame.maxY)
        let floatingDock = element("floating-navigation-tabbar")
        XCTAssertTrue(floatingDock.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(
            periodFrame.maxY,
            floatingDock.frame.minY,
            "The complete family-week date must stay above the floating navigation dock."
        )
        let currentPeriod = app.buttons["evolution-care-current"]
        XCTAssertTrue(currentPeriod.exists)
        XCTAssertGreaterThanOrEqual(currentPeriod.frame.minX, windowFrame.minX)
        XCTAssertLessThanOrEqual(currentPeriod.frame.maxX, windowFrame.maxX)
        XCTAssertLessThanOrEqual(currentPeriod.frame.maxY, floatingDock.frame.minY)
        let checkpoint = XCTAttachment(screenshot: app.screenshot())
        checkpoint.name = "care-period-accessibility-xxxl"
        checkpoint.lifetime = .keepAlways
        add(checkpoint)
    }

    func testCareChartExposesAccessibleBucketSelectionAndReset() {
        launchLiveScenario()
        guard openMetric("feeds"), element("evolution-care-detail-feeds").waitForExistence(timeout: 5) else {
            XCTFail("The feed summary card should open its detail.")
            return
        }
        app.buttons["evolution-care-range-month"].tap()
        let summary = element("evolution-care-summary-value")
        let periodValue = summary.label
        app.buttons["evolution-care-explore-values"].tap()
        let buckets = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "evolution-care-bucket-"
        ))
        let recordedBucket = buckets.firstMatch
        guard recordedBucket.waitForExistence(timeout: 5) else {
            XCTFail("The care chart should expose its buckets as accessible controls.")
            return
        }
        recordedBucket.tap()
        XCTAssertTrue(element("evolution-care-selected-interval").waitForExistence(timeout: 3))

        let reset = app.buttons["evolution-care-chart-reset"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        reset.tap()
        XCTAssertEqual(summary.label, periodValue, "Reset should restore the whole-period summary.")
    }

    private func openMetric(_ metric: String) -> Bool {
        let card = element("evolution-card-\(metric)")
        guard card.waitForExistence(timeout: 8) else {
            XCTFail("Missing \(metric) Evolution card.")
            return false
        }
        card.tap()
        return true
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func launchLiveScenario(
        timeZone: String? = nil,
        includeTodayFeed: Bool = false,
        contentSize: String? = nil
    ) {
        app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = "evolution-live"
        app.launchEnvironment["NIDO_UI_TEST_APPEARANCE"] = "light"
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        if let timeZone { app.launchEnvironment["TZ"] = timeZone }
        if includeTodayFeed { app.launchEnvironment["NIDO_UI_TEST_EVOLUTION_TODAY_FEED"] = "1" }
        if let contentSize { app.launchEnvironment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"] = contentSize }
        app.launchArguments = [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", "evolution-live",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES"
        ]
        app.launch()
        let trendsTab = app.buttons["tab-trends"]
        if trendsTab.waitForExistence(timeout: 10) {
            trendsTab.tap()
        } else {
            XCTFail("The Trends tab should be available in the live scenario.")
        }
    }
}
