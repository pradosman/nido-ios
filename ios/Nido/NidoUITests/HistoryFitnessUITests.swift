import XCTest

@MainActor
final class HistoryFitnessUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testHistoryShowsSelectedDayClockAndHourlySectionsWithCoherentTotals() {
        launchHistory()

        XCTAssertTrue(element("history-detail-day-2026-08-28").waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-28")
        attachScreenshot(named: "History light first screen before scrolling")
        XCTAssertFalse(app.staticTexts["Escala visual: los anillos no representan objetivos médicos."].exists)

        bringIntoView(element("history-chart-sleep"))
        XCTAssertTrue(element("history-section-sleep").isHittable)
        XCTAssertTrue(app.staticTexts["1 h 30 min"].exists)
        bringIntoView(element("history-chart-feed"))
        XCTAssertTrue(element("history-section-feed").isHittable)
        bringIntoView(element("history-chart-diaper"))
        XCTAssertTrue(element("history-section-diaper").isHittable)
        bringIntoView(app.buttons["history-entry-history-friday-sleep"])
        bringIntoView(app.buttons["history-entry-history-friday-feed"])
        bringIntoView(app.buttons["history-entry-history-friday-diaper"])
        XCTAssertTrue(app.buttons["history-entry-history-friday-feed"].exists)
        XCTAssertTrue(app.buttons["history-entry-history-friday-diaper"].exists)

        returnToTop(day: "2026-08-28")
        attachScreenshot(named: "History light detail with hourly charts")
    }

    func testSelectingAWeekDayUpdatesDateAndItsRecordsTogether() {
        launchHistory()

        let thursday = app.buttons["history-week-day-2026-08-27"]
        XCTAssertTrue(thursday.waitForExistence(timeout: 5))
        thursday.tap()

        XCTAssertTrue(thursday.isSelected)
        XCTAssertTrue(element("history-detail-day-2026-08-27").waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-27")
        bringIntoView(app.buttons["history-entry-history-thursday"])
        XCTAssertTrue(app.buttons["history-entry-history-thursday"].exists)
        XCTAssertFalse(app.buttons["history-entry-history-friday-feed"].exists)
    }

    func testSummaryTotalScrollsToItsChartAndKeepsWeekStripVisible() {
        launchHistory()

        let diaperSummary = app.buttons["history-summary-diaper"]
        XCTAssertTrue(diaperSummary.waitForExistence(timeout: 5))
        diaperSummary.tap()

        let diaperChart = element("history-chart-diaper")
        XCTAssertTrue(diaperChart.waitForExistence(timeout: 3))
        XCTAssertTrue(diaperChart.isHittable)
        XCTAssertTrue(app.scrollViews["history-week-strip"].isHittable)
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-28")
    }

    func testSelectedDaySurvivesLeavingAndReturningToHistoryTab() {
        launchHistory()

        let thursday = app.buttons["history-week-day-2026-08-27"]
        XCTAssertTrue(thursday.waitForExistence(timeout: 5))
        thursday.tap()
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-27")
        bringIntoView(app.buttons["history-entry-history-thursday"])

        app.tabBars.buttons["Hoy"].tap()
        app.tabBars.buttons["Historia"].tap()

        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-27")
        XCTAssertTrue(app.buttons["history-week-day-2026-08-27"].isSelected)
        bringIntoView(app.buttons["history-entry-history-thursday"])
        XCTAssertTrue(app.buttons["history-entry-history-thursday"].exists)
    }

    func testCalendarSelectionClosesAndCancelPreservesTheSelectedDate() {
        launchHistory()

        app.buttons["history-week-day-2026-08-26"].tap()
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-26")

        app.buttons["history-day-picker"].tap()
        XCTAssertTrue(app.buttons["history-calendar-close"].waitForExistence(timeout: 3))
        app.buttons["history-calendar-close"].tap()
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-26")

        app.buttons["history-day-picker"].tap()
        let calendarGrid = app.descendants(matching: .any)["history-calendar-grid"]
        XCTAssertTrue(calendarGrid.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["history-calendar-day-2026-08-26"].isSelected)
        XCTAssertFalse(app.buttons["history-calendar-day-2026-08-29"].isEnabled)
        attachScreenshot(named: "History monthly calendar and selected day")
        app.buttons["history-calendar-close"].tap()
    }

    func testCalendarMonthHeadingStaysPinnedWhileScrollingAcrossMonths() {
        // Unknown isolated UI-test scenarios start with an empty local fixture, so History
        // exposes its full one-year calendar range without changing production data.
        launchScenario(scenario: "timeline-empty", openHistory: true)

        let selectedDateText = app.staticTexts["history-detail-date"]
        XCTAssertTrue(selectedDateText.waitForExistence(timeout: 5))
        let currentDate = dateFromISO(selectedDateText.value as? String)
        XCTAssertNotNil(currentDate)
        guard let currentDate else { return }
        let previousMonthDate = Calendar.current.date(byAdding: .month, value: -1, to: currentDate)!

        app.buttons["history-day-picker"].tap()
        let selectedMonthGrid = element("history-calendar-grid")
        XCTAssertTrue(selectedMonthGrid.waitForExistence(timeout: 5), "Opening the calendar should center the currently selected month.")
        guard let calendarScroll = calendarScrollView(containing: "history-calendar-grid") else {
            XCTFail("The calendar month grid should be inside a vertical scroll view.")
            return
        }

        let monthHeading = app.staticTexts[localizedMonthTitle(containing: currentDate)]
        XCTAssertTrue(monthHeading.waitForExistence(timeout: 5))
        XCTAssertTrue(monthHeading.isHittable)

        let dragStart = calendarScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        let dragEnd = calendarScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42))
        dragStart.press(forDuration: 0.05, thenDragTo: dragEnd, withVelocity: .slow, thenHoldForDuration: 0.1)

        XCTAssertTrue(monthHeading.isHittable, "The current month heading should stay available while its grid scrolls.")
        let visibleTop = max(calendarScroll.frame.minY, app.navigationBars["Elegir día"].frame.maxY)
        XCTAssertGreaterThanOrEqual(monthHeading.frame.minY, visibleTop - 2)
        XCTAssertLessThanOrEqual(monthHeading.frame.minY, visibleTop + 48)
        attachScreenshot(named: "History calendar with pinned month heading")

        let previousMonthDay = app.buttons["history-calendar-day-\(calendarDateIdentifier(previousMonthDate))"]
        let previousMonthComponents = Calendar.current.dateComponents([.year, .month], from: previousMonthDate)
        let previousMonthIdentifier = String(
            format: "%04d-%02d", previousMonthComponents.year ?? 0, previousMonthComponents.month ?? 0
        )
        let previousMonthHeader = app.descendants(matching: .any)
            .matching(identifier: "history-calendar-header-\(previousMonthIdentifier)").firstMatch
        let pickerNavigationBar = app.navigationBars["Elegir día"]
        func hasUnobstructedPreviousDayFrame() -> Bool {
            guard previousMonthDay.exists, calendarScroll.exists, pickerNavigationBar.exists else { return false }
            let dayFrame = previousMonthDay.frame
            let viewportFrame = calendarScroll.frame
            let navigationFrame = pickerNavigationBar.frame
            let monthHeaderBottom = previousMonthHeader.exists ? previousMonthHeader.frame.maxY : navigationFrame.maxY
            return viewportFrame.contains(dayFrame)
                && dayFrame.minY >= max(navigationFrame.maxY, monthHeaderBottom) + 8
                && previousMonthDay.isEnabled
                && previousMonthDay.isHittable
        }
        for _ in 0..<12 where !hasUnobstructedPreviousDayFrame() {
            let start = calendarScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
            let end = calendarScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }

        guard previousMonthDay.exists, calendarScroll.exists, pickerNavigationBar.exists else {
            let missingElementsDiagnostic = """
            previousMonthDayExists=\(previousMonthDay.exists)
            calendarScrollExists=\(calendarScroll.exists)
            pickerNavigationBarExists=\(pickerNavigationBar.exists)
            """
            let missingElementsAttachment = XCTAttachment(string: missingElementsDiagnostic)
            missingElementsAttachment.name = "History previous-month lookup state before tap"
            missingElementsAttachment.lifetime = .keepAlways
            add(missingElementsAttachment)
            attachScreenshot(named: "History previous-month elements unavailable before tap")
            XCTFail("The previous-month day, calendar viewport, and picker navigation bar must exist before reading final geometry.\n\(missingElementsDiagnostic)")
            return
        }
        let finalDayExists = previousMonthDay.exists
        let finalDayFrame = previousMonthDay.frame
        let finalViewportFrame = calendarScroll.frame
        let finalNavigationFrame = pickerNavigationBar.frame
        let finalHeaderExists = previousMonthHeader.exists
        let finalHeaderFrame = finalHeaderExists ? previousMonthHeader.frame : nil
        let finalHeaderBottom = max(finalNavigationFrame.maxY, finalHeaderFrame?.maxY ?? finalNavigationFrame.maxY)
        let fullyInsideViewport = finalViewportFrame.contains(finalDayFrame)
        let belowNavigationAndHeader = finalDayFrame.minY >= finalHeaderBottom + 8
        let dayIsEnabled = previousMonthDay.isEnabled
        let dayIsHittable = previousMonthDay.isHittable
        let finalGeometry = """
        dayIdentifier=\(previousMonthDay.identifier)
        dayExists=\(finalDayExists)
        dayFrame=\(finalDayFrame)
        viewportFrame=\(finalViewportFrame)
        navigationBarFrame=\(finalNavigationFrame)
        monthHeaderExists=\(finalHeaderExists)
        monthHeaderFrame=\(finalHeaderFrame.map { String(describing: $0) } ?? "unknown")
        fullyInsideViewport=\(fullyInsideViewport)
        belowNavigationAndHeader=\(belowNavigationAndHeader)
        isEnabled=\(dayIsEnabled)
        isHittable=\(dayIsHittable)
        """
        let geometryAttachment = XCTAttachment(string: finalGeometry)
        geometryAttachment.name = "History previous-month day geometry before tap"
        geometryAttachment.lifetime = .keepAlways
        add(geometryAttachment)
        attachScreenshot(named: "History previous-month day unobstructed before tap")
        XCTAssertTrue(dayIsHittable, "Scrolling to the previous month should remain available in the same calendar.")

        guard fullyInsideViewport && belowNavigationAndHeader && dayIsEnabled && dayIsHittable else {
            XCTFail("The previous-month day must be enabled, hittable, fully inside the calendar viewport, and below the picker navigation bar and full month header.\n\(finalGeometry)")
            return
        }
        previousMonthDay.tap()
        XCTAssertEqual(selectedDateText.value as? String, calendarDateIdentifier(previousMonthDate))
    }

    func testCalendarTodayActionSelectsTodayAndClosesTheSheet() {
        launchHistory()

        app.buttons["history-week-day-2026-08-26"].tap()
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-26")

        app.buttons["history-day-picker"].tap()
        let today = app.buttons["history-calendar-today"]
        XCTAssertTrue(today.waitForExistence(timeout: 3))
        today.tap()

        XCTAssertTrue(element("history-calendar-grid").waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-28")
        XCTAssertTrue(app.buttons["history-week-day-2026-08-28"].isSelected)
    }

    func testWeekStripRemainsAvailableAfterScrollingAndJumpTodayReturnsToToday() {
        launchHistory()

        app.buttons["history-week-day-2026-08-27"].tap()
        verticalScrollView().swipeUp()
        let strip = app.scrollViews["history-week-strip"]
        XCTAssertTrue(strip.exists)
        XCTAssertTrue(strip.isHittable, "The selected week strip must remain available while the detail scrolls.")
        attachScreenshot(named: "History scrolled with fixed week strip")

        app.buttons["history-jump-today"].tap()
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-28")
        XCTAssertTrue(app.buttons["history-week-day-2026-08-28"].isSelected)
    }

    func testTodaySeeAllOpensHistoryForTheActivityDay() {
        launchScenario(openHistory: false)

        let previousDay = app.buttons["Día anterior"]
        XCTAssertTrue(previousDay.waitForExistence(timeout: 5))
        previousDay.tap()
        XCTAssertTrue(app.staticTexts["timeline-day-heading"].label.contains("27 de agosto"))

        let seeAll = app.buttons["Ver todo"]
        for _ in 0..<5 where !seeAll.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(seeAll.waitForExistence(timeout: 5))
        seeAll.tap()

        XCTAssertTrue(element("history-detail-day-2026-08-27").waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-27")
        bringIntoView(app.buttons["history-entry-history-thursday"])
        XCTAssertTrue(app.buttons["history-entry-history-thursday"].exists)
        XCTAssertFalse(app.buttons["history-entry-history-friday-feed"].exists)
    }

    func testHorizontalTimelineSwipeSelectsThePreviousDay() {
        launchScenario(openHistory: false)

        let dial = app.buttons["daily-goal-ring-graphic"]
        XCTAssertTrue(dial.waitForExistence(timeout: 5))
        dial.swipeRight()

        XCTAssertTrue(app.staticTexts["timeline-day-heading"].label.contains("27 de agosto"))
        XCTAssertTrue(app.buttons["daily-goal-ring-graphic"].exists)

        app.tabBars.buttons["Historia"].tap()
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-28")
        app.buttons["daily-goal-ring-graphic"].swipeRight()
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-27")
    }

    func testExploringChartDoesNotChangeTheSelectedDay() {
        launchHistory()

        let chart = element("history-chart-feed")
        bringIntoView(chart)
        XCTAssertTrue(chart.isHittable)
        chart.tap()

        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-28")
        XCTAssertTrue(element("history-chart-selection").exists)
        attachScreenshot(named: "History selected hourly chart interval")
    }

    func testDarkAppearanceKeepsDateAndChartContentAccessible() {
        launchHistory()

        XCTAssertTrue(element("history-detail-day-2026-08-28").waitForExistence(timeout: 5))
        assertRenderedAppearance(dark: true)
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-28")
        attachScreenshot(named: "History dark first screen before scrolling")
        for kind in ["sleep", "feed", "diaper"] {
            let chart = element("history-chart-\(kind)")
            bringIntoView(chart)
            XCTAssertTrue(chart.isHittable)
        }
        returnToTop(day: "2026-08-28")
        attachScreenshot(named: "History dark detail accessibility")
    }

    func testDarkCalendarSelectsADayAndDisablesFutureDates() {
        launchHistory()
        XCTAssertTrue(element("history-detail-day-2026-08-28").waitForExistence(timeout: 5))
        assertRenderedAppearance(dark: true)
        app.buttons["history-day-picker"].tap()
        XCTAssertTrue(element("history-calendar-grid").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["history-calendar-day-2026-08-28"].isSelected)
        XCTAssertFalse(app.buttons["history-calendar-day-2026-08-29"].isEnabled)
        attachScreenshot(named: "History dark monthly calendar")
        app.buttons["history-calendar-day-2026-08-26"].tap()
        XCTAssertTrue(element("history-calendar-grid").waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-26")
    }

    func testAccessibilityTextSizeKeepsSelectedDateAndTotalsAvailable() {
        launchScenario(dynamicTypeSize: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge", openHistory: true)

        XCTAssertTrue(element("history-detail-day-2026-08-28").waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-28")
        bringIntoView(element("history-chart-sleep"))
        XCTAssertTrue(element("history-section-sleep").exists)
        XCTAssertTrue(element("history-chart-sleep").isHittable)
        bringIntoView(app.buttons["history-entry-history-friday-feed"])
        XCTAssertTrue(app.buttons["history-entry-history-friday-feed"].exists)
        attachScreenshot(named: "History accessibility text size")
    }

    func testAccessibilityTextSizeSummaryTotalScrollsToItsChart() {
        launchScenario(dynamicTypeSize: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge", openHistory: true)

        let diaperSummary = app.buttons["history-summary-diaper"]
        XCTAssertTrue(diaperSummary.waitForExistence(timeout: 5))
        diaperSummary.tap()

        let diaperChart = element("history-chart-diaper")
        bringIntoView(diaperChart)
        XCTAssertTrue(diaperChart.isHittable)
        XCTAssertTrue(app.scrollViews["history-week-strip"].isHittable)
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-28")
    }

    func testAccessibilityChartDayChangesKeepReadingPositionAndRemainResponsive() {
        launchScenario(dynamicTypeSize: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge", openHistory: true)

        let diaperSummary = app.buttons["history-summary-diaper"]
        XCTAssertTrue(diaperSummary.waitForExistence(timeout: 5))
        diaperSummary.tap()

        let diaperChart = element("history-chart-diaper")
        XCTAssertTrue(diaperChart.waitForExistence(timeout: 5))
        XCTAssertTrue(diaperChart.isHittable)
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-28")

        let thursday = app.buttons["history-week-day-2026-08-27"]
        let friday = app.buttons["history-week-day-2026-08-28"]
        let date = app.staticTexts["history-detail-date"]

        for _ in 0..<2 {
            XCTAssertTrue(thursday.isHittable)
            thursday.tap()
            XCTAssertEqual(date.value as? String, "2026-08-27")
            XCTAssertTrue(diaperChart.isHittable, "Changing the day should preserve the selected chart reading position.")

            app.buttons["history-day-picker"].tap()
            let calendarClose = app.buttons["history-calendar-close"]
            XCTAssertTrue(calendarClose.waitForExistence(timeout: 3))
            calendarClose.tap()
            XCTAssertEqual(date.value as? String, "2026-08-27", "Cancelling the calendar should preserve the selected day.")
            XCTAssertTrue(diaperChart.isHittable)

            XCTAssertTrue(friday.isHittable)
            friday.tap()
            XCTAssertEqual(date.value as? String, "2026-08-28")
            XCTAssertTrue(diaperChart.isHittable, "Returning to Friday should keep the chart visible and responsive.")
        }
    }

    private func launchHistory() {
        launchScenario(openHistory: true)
    }

    private func launchScenario(
        scenario: String = "history-calendar",
        dynamicTypeSize: String = "UICTContentSizeCategoryLarge",
        openHistory: Bool
    ) {
        app = XCUIApplication()
        let runID = UUID().uuidString
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = runID
        app.launchEnvironment["NIDO_UI_TEST_API_BASE_URL"] = ProcessInfo.processInfo.environment["NIDO_UI_TEST_API_BASE_URL"]
            ?? "http://127.0.0.1:34200"
        app.launchEnvironment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"] = dynamicTypeSize
        app.launchArguments += [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", scenario,
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
        ]
        app.launch()
        if openHistory {
            app.tabBars.buttons["Historia"].tap()
        }
    }

    private func assertRenderedAppearance(dark: Bool) {
        AppearanceScreenshotAssertion.assertRenderedAppearance(app, dark: dark, file: #filePath, line: #line)
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func calendarScrollView(containing gridIdentifier: String) -> XCUIElement? {
        app.scrollViews.allElementsBoundByIndex.first {
            $0.descendants(matching: .any)[gridIdentifier].exists
        }
    }

    private func dateFromISO(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func calendarDateIdentifier(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func localizedMonthTitle(containing date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "es_ES")))
    }

    private func verticalScrollView() -> XCUIElement {
        let historyScrollView = app.scrollViews["history-detail-scroll"]
        if historyScrollView.exists { return historyScrollView }
        let scrollViews = app.scrollViews.allElementsBoundByIndex
        return scrollViews.first(where: { $0.frame.height > 200 && $0.frame.width > 200 })
            ?? app.scrollViews.firstMatch
    }

    private func bringIntoView(_ target: XCUIElement, maximumSwipes: Int = 40) {
        let scrollView = verticalScrollView()
        print("History visibility: \(target.identifier), target=\(target.frame), viewport=\(scrollView.frame)")
        for _ in 0..<maximumSwipes where !target.isHittable {
            let isAbove = target.exists && target.frame.midY < scrollView.frame.minY
            let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: isAbove ? 0.35 : 0.65))
            let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: isAbove ? 0.6 : 0.4))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)
        }
        XCTAssertTrue(target.isHittable, "Expected UI element to be visible: \(target.identifier)")
    }

    private func returnToTop(day: String) {
        let dayClock = element("history-detail-day-\(day)")
        let scrollView = verticalScrollView()
        for _ in 0..<12 where !dayClock.isHittable {
            scrollView.swipeDown()
        }
        XCTAssertTrue(dayClock.isHittable, "Expected the selected day clock at the top of History.")
    }
}
