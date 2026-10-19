import XCTest

@MainActor
final class PhysicalReviewRegressionUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testRegistrationActionAlignsWithFourTabTargets() {
        launch(scenario: "baby-care")
        let heading = app.staticTexts["timeline-day-heading"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        let headingFrame = heading.frame
        attachScreenshot(named: "Today before tab and registration geometry assertions")

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        let tabButtons = tabBar.buttons.allElementsBoundByIndex
        XCTAssertEqual(Set(tabButtons.map(\.label)), ["Hoy", "Historia", "Ritmos", "Ajustes"])

        let registration = app.buttons["registration-action-button"]
        XCTAssertTrue(registration.waitForExistence(timeout: 5))
        XCTAssertFalse(tabBar.buttons["registration-action-button"].exists)

        for button in tabButtons {
            XCTAssertGreaterThanOrEqual(button.frame.width, 44, "Tab targets must remain comfortably tappable.")
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, "Tab targets must remain comfortably tappable.")
        }
        XCTAssertGreaterThanOrEqual(registration.frame.width, 44)
        XCTAssertGreaterThanOrEqual(registration.frame.height, 44)

        let registrationFrame = registration.frame
        let tabButtonFrames = tabButtons.map { $0.frame }
        let tabButtonsFrame = tabButtonFrames.reduce(CGRect.null) { $0.union($1) }
        let verticalCenterDelta = abs(registrationFrame.midY - tabButtonsFrame.midY)
        let horizontalGap = tabButtonFrames.map { frame -> CGFloat in
            if registrationFrame.maxX <= frame.minX {
                return frame.minX - registrationFrame.maxX
            }
            if frame.maxX <= registrationFrame.minX {
                return registrationFrame.minX - frame.maxX
            }
            return 0
        }.min() ?? 0
        let geometryAttachment = XCTAttachment(string: "action=\(registrationFrame) tabs=\(tabButtonFrames) verticalCenterDelta=\(verticalCenterDelta) nearestHorizontalGap=\(horizontalGap)")
        geometryAttachment.name = "Registration action and tab button frames"
        geometryAttachment.lifetime = .keepAlways
        add(geometryAttachment)
        print("PHYSICAL_REVIEW_TAB_GEOMETRY action=\(registrationFrame) tabs=\(tabButtonFrames) deltaY=\(verticalCenterDelta) nearestGap=\(horizontalGap)")

        attachScreenshot(named: "Registration action and four-tab layout")
        registration.tap()
        for title in ["Registrar sueño", "Registrar toma", "Registrar pañal", "Registrar cuidados"] {
            XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 5), "The registration menu should expose \(title).")
        }
        attachScreenshot(named: "Open registration menu with four tabs")

        XCTAssertLessThanOrEqual(
            verticalCenterDelta,
            3,
            "The registration action should align vertically with the four tab targets."
        )
        XCTAssertGreaterThanOrEqual(horizontalGap, 8, "The menu action must not overlap a tab target.")

        let dismissalPoint = CGVector(dx: headingFrame.midX / app.frame.width, dy: headingFrame.midY / app.frame.height)
        print("PHYSICAL_REVIEW_MENU_DISMISS heading=\(headingFrame) point=\(dismissalPoint)")
        app.coordinate(withNormalizedOffset: dismissalPoint).tap()
        let historyTab = app.tabBars.buttons["Historia"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        XCTAssertTrue(historyTab.isHittable, "The History tab should be exposed after the menu dismisses.")
        historyTab.tap()
        let historyFeedSummary = app.buttons["history-summary-feed"]
        XCTAssertTrue(historyFeedSummary.waitForExistence(timeout: 5))
        XCTAssertEqual(historyFeedSummary.value as? String, "2, objetivo 8")
        XCTAssertEqual(app.buttons["history-summary-diaper"].value as? String, "1, objetivo 6")
        XCTAssertTrue(app.buttons["daily-goal-ring-graphic"].exists)
        attachScreenshot(named: "History configured rings with existing activity")
    }

    func testEmptyGoalSetupIsDiscoverableAndAddsTheFirstRings() {
        launch(scenario: "baby-care-empty")
        app.buttons["registration-action-button"].tap()
        app.buttons["Registrar pañal"].tap()
        let addDetails = app.buttons["Añadir detalles"]
        XCTAssertTrue(addDetails.waitForExistence(timeout: 5))
        addDetails.tap()
        let urineChoice = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Pis")).firstMatch
        XCTAssertTrue(urineChoice.waitForExistence(timeout: 5))
        if !urineChoice.isSelected { urineChoice.tap() }
        app.buttons["Guardar"].tap()

        let setup = app.buttons["today-define-goals"]
        XCTAssertTrue(setup.waitForExistence(timeout: 5), "An empty goal state should offer a clear first-goal setup action.")
        guard setup.exists else { return }
        attachScreenshot(named: "Existing activity with empty-goal first-setup prompt")
        setup.tap()

        let sleep = app.textFields["goals-value-sleep"]
        let feeds = app.textFields["goals-value-feed"]
        let diapers = app.textFields["goals-value-diaper"]
        XCTAssertTrue(sleep.waitForExistence(timeout: 3))
        XCTAssertEqual(sleep.value as? String, "Sin objetivo")
        XCTAssertEqual(feeds.value as? String, "Sin objetivo")
        XCTAssertEqual(diapers.value as? String, "Sin objetivo")

        sleep.tap()
        sleep.typeText("12")
        feeds.tap()
        feeds.typeText("8")
        diapers.tap()
        diapers.typeText("6")
        app.buttons["goals-save"].tap()

        XCTAssertFalse(setup.exists, "The first-goal setup prompt should leave once real goals are saved.")
        XCTAssertTrue(app.descendants(matching: .any)["daily-goal-ring-graphic"].waitForExistence(timeout: 5))
        XCTAssertTrue((app.buttons["day-goal-summary-feed"].value as? String)?.contains("objetivo 8") == true)
        XCTAssertEqual(app.buttons["day-goal-summary-diaper"].value as? String, "1, objetivo 6", "The real diaper count must remain visible against its saved goal.")
        attachScreenshot(named: "Today after saving first daily goals")

        app.tabBars.buttons["Historia"].tap()
        XCTAssertTrue(app.buttons["daily-goal-ring-graphic"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-10-17")
        XCTAssertEqual(app.buttons["history-summary-diaper"].value as? String, "1, objetivo 6")
        attachScreenshot(named: "History rings retain real activity and saved goals")
    }

    func testTodayMarkerStaysOnTodayWhilePreviousDayRemainsSelected() {
        launch(scenario: "history-calendar")
        app.tabBars.buttons["Historia"].tap()

        let todayButton = app.buttons["history-week-day-2026-08-28"]
        XCTAssertTrue(todayButton.waitForExistence(timeout: 5))
        XCTAssertTrue(todayButton.isSelected)
        XCTAssertTrue(todayButton.label.localizedCaseInsensitiveContains("hoy"), "VoiceOver should identify the current day on its existing day button.")
        let originalTodayFrame = todayButton.frame
        attachScreenshot(named: "History week strip with today's marker")

        let previousDay = app.buttons["history-week-day-2026-08-27"]
        XCTAssertTrue(previousDay.waitForExistence(timeout: 5))
        previousDay.tap()

        XCTAssertTrue(previousDay.isSelected)
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-27")
        XCTAssertTrue(todayButton.exists, "Today's indicator must stay present when another date is selected.")
        XCTAssertTrue(todayButton.label.localizedCaseInsensitiveContains("hoy"))
        XCTAssertEqual(todayButton.frame.midX, originalTodayFrame.midX, accuracy: 2)
        XCTAssertEqual(todayButton.frame.midY, originalTodayFrame.midY, accuracy: 2)
        XCTAssertFalse(todayButton.isSelected)
        attachScreenshot(named: "History week strip with previous day selected")
    }

    func testRapidConsecutiveWeekSelectionsCommitTheLatestDate() {
        launch(scenario: "history-calendar")
        app.tabBars.buttons["Historia"].tap()

        let firstDate = app.buttons["history-week-day-2026-08-27"]
        let latestDate = app.buttons["history-week-day-2026-08-26"]
        XCTAssertTrue(firstDate.waitForExistence(timeout: 5))
        XCTAssertTrue(latestDate.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-28")

        firstDate.tap()
        latestDate.tap()

        let detailDate = app.staticTexts["history-detail-date"]
        XCTAssertEqual(detailDate.value as? String, "2026-08-26", "When a second date is selected during a page animation, the latest selection must win.")
        XCTAssertTrue(latestDate.isSelected)
        attachScreenshot(named: "Latest date after rapid consecutive week selections")
    }

    func testShortSlowHorizontalRingDragDoesNotChangeTheSelectedDay() {
        launch(scenario: "history-calendar")
        app.tabBars.buttons["Historia"].tap()

        let selectedDate = app.staticTexts["history-detail-date"]
        XCTAssertTrue(selectedDate.waitForExistence(timeout: 5))
        XCTAssertEqual(selectedDate.value as? String, "2026-08-28")

        let ringArea = app.descendants(matching: .any)["history-detail-day-2026-08-28"]
        XCTAssertTrue(ringArea.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(ringArea.frame.width, 48)
        attachScreenshot(named: "History rings before a short horizontal drag")

        let dragStart = ringArea.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let dragEnd = ringArea.coordinate(withNormalizedOffset: CGVector(dx: 0.5 + 48 / ringArea.frame.width, dy: 0.5))
        print("PHYSICAL_REVIEW_SHORT_DRAG start=\(dragStart) end=\(dragEnd) duration=1s velocity=slow hold=1s dateBefore=\(String(describing: selectedDate.value))")
        dragStart.press(forDuration: 1, thenDragTo: dragEnd, withVelocity: .slow, thenHoldForDuration: 1)

        print("PHYSICAL_REVIEW_SHORT_DRAG dateAfter=\(String(describing: selectedDate.value))")
        XCTAssertEqual(selectedDate.value as? String, "2026-08-28", "A short, deliberate drag should cancel instead of paging to another day.")
        XCTAssertTrue(app.buttons["history-week-day-2026-08-28"].isSelected)
        attachScreenshot(named: "History selected day after a short horizontal drag")
    }

    private func launch(scenario: String) {
        app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["NIDO_UI_TEST_API_BASE_URL"] = ProcessInfo.processInfo.environment["NIDO_UI_TEST_API_BASE_URL"]
            ?? "http://127.0.0.1:34200"
        app.launchEnvironment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"] = "UICTContentSizeCategoryLarge"
        app.launchArguments = [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", scenario,
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
        ]
        app.launch()
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
