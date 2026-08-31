import XCTest

@MainActor
final class NidoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testOnboardingShowsOnlyTheInformationNeededToCreateAHome() {
        launch(scenario: "onboarding")

        XCTAssertTrue(app.staticTexts["El día a día de vuestro bebé."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["Tu nombre"].exists)
        XCTAssertTrue(app.textFields["Nombre del bebé"].exists)
        XCTAssertTrue(app.buttons["Crear espacio"].exists)
        XCTAssertFalse(app.buttons["Crear espacio"].isEnabled)
    }

    func testReadyHomeAndPrimaryNavigationAreAvailable() {
        launch(scenario: "ready")

        XCTAssertTrue(app.staticTexts["Hoy con Marco"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["Historia"].exists)
        XCTAssertTrue(app.tabBars.buttons["Ritmos"].exists)
        XCTAssertTrue(app.tabBars.buttons["Ajustes"].exists)

        app.tabBars.buttons["Historia"].tap()
        XCTAssertTrue(app.navigationBars["Historia"].waitForExistence(timeout: 2))
    }

    func testSleepRegistrationUsesStartAndEndDates() {
        launch(scenario: "ready")

        let activityButton = app.buttons["Registrar una actividad"]
        XCTAssertTrue(activityButton.waitForExistence(timeout: 3))
        activityButton.tap()
        app.buttons["Registrar sueño"].tap()

        XCTAssertTrue(app.navigationBars["Sueño"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Desde"].exists)
        XCTAssertTrue(app.staticTexts["Hasta"].exists)
        XCTAssertFalse(app.staticTexts["Fecha y hora"].exists)
    }

    func testActiveSleepStartCanBeEdited() {
        launch(scenario: "active-sleep")

        XCTAssertTrue(app.staticTexts["Marco está durmiendo"].waitForExistence(timeout: 3))
        let editStart = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Editar hora de inicio'")
        ).firstMatch
        XCTAssertTrue(editStart.exists)
        editStart.tap()
        XCTAssertTrue(app.navigationBars["Hora de inicio"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Guardar"].exists)
    }

    func testTodayTimelineFormatsDurationAsHoursAndMinutes() {
        launch(scenario: "timeline-duration")

        XCTAssertTrue(app.staticTexts["Actividad de hoy"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["timeline-event-ui-test-sleep"].exists)
        let sleepActivity = app.buttons["timeline-activity-ui-test-sleep"]
        XCTAssertTrue(sleepActivity.exists)
        sleepActivity.tap()
        XCTAssertTrue(app.staticTexts["1 h 15 min"].exists)
        XCTAssertFalse(app.staticTexts["75 min"].exists)
    }

    func testLongPressingATodayEntryOpensItsEditor() {
        launch(scenario: "timeline-duration")

        XCTAssertTrue(app.staticTexts["Actividad de hoy"].waitForExistence(timeout: 3))
        let sleepEntry = app.buttons["timeline-activity-ui-test-sleep"]
        XCTAssertTrue(sleepEntry.exists)
        sleepEntry.press(forDuration: 1)

        XCTAssertTrue(app.navigationBars["Editar registro"].waitForExistence(timeout: 2))
    }

    func testCircularTimelineKeepsSleepInteractionInDayActivityList() {
        launch(scenario: "circular-timeline")

        let dial = app.otherElements["timeline-circular-dial"]
        XCTAssertTrue(dial.waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["today-vertical-timeline"].exists)

        let sleep = app.buttons["timeline-activity-ui-test-sleep"]
        XCTAssertTrue(sleep.exists)
        sleep.tap()
        XCTAssertTrue(app.staticTexts["1 h 15 min"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["07:00–08:15"].exists)
        XCTAssertTrue(app.otherElements["timeline-dial-center-detail"].exists)

        sleepActivity.press(forDuration: 1)
        XCTAssertTrue(app.navigationBars["Editar registro"].waitForExistence(timeout: 2))
    }

    func testSleepControlsStayAboveTheCircularTimelineWhenIdleAndActive() {
        launch(scenario: "circular-timeline")

        var sleepCard = app.descendants(matching: .any)["sleep-status-card"]
        var dial = app.otherElements["timeline-circular-dial"]
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 3))
        XCTAssertTrue(sleepCard.label.contains("Iniciar"))
        XCTAssertTrue(dial.exists)
        XCTAssertLessThan(sleepCard.frame.maxY, dial.frame.minY)

        app.terminate()
        launch(scenario: "active-sleep")

        sleepCard = app.descendants(matching: .any)["sleep-status-card"]
        dial = app.otherElements["timeline-circular-dial"]
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Terminar"].exists)
        XCTAssertTrue(dial.exists)
        XCTAssertLessThan(sleepCard.frame.maxY, dial.frame.minY)
    }

    func testSleepActionsMeetTheMinimumTouchTarget() {
        launch(scenario: "circular-timeline")

        var sleepCard = app.descendants(matching: .any)["sleep-status-card"]
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 3))
        XCTAssertTrue(sleepCard.label.contains("Iniciar"))
        XCTAssertGreaterThanOrEqual(sleepCard.frame.height, 44)

        app.terminate()
        launch(scenario: "active-sleep")

        let finishButton = app.buttons["Terminar"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(finishButton.frame.height, 44)
    }

    func testCircularTimelineExplainsItsOrientationAndDefaultState() {
        launch(scenario: "circular-timeline")

        let cardinalLabels = [
            (identifier: "timeline-cardinal-0", label: "00:00"),
            (identifier: "timeline-cardinal-360", label: "06:00"),
            (identifier: "timeline-cardinal-720", label: "12:00"),
            (identifier: "timeline-cardinal-1080", label: "18:00"),
        ]
        for cardinal in cardinalLabels {
            let label = app.staticTexts[cardinal.identifier]
            XCTAssertTrue(label.waitForExistence(timeout: 3))
            XCTAssertTrue(label.label.contains(cardinal.label))
        }
        XCTAssertTrue(app.otherElements["timeline-now-marker"].exists)
        let summary = app.otherElements["timeline-dial-default-summary"]
        XCTAssertTrue(summary.exists)
        XCTAssertTrue(summary.label.contains("17 registros hoy"))
        XCTAssertTrue(summary.label.contains("22:40"))
    }

    func testCircularTimelineRenderedMarkerHitAreasStayInsideTheDial() {
        launch(scenario: "circular-timeline")

        let dial = app.otherElements["timeline-circular-dial"]
        XCTAssertTrue(dial.waitForExistence(timeout: 3))

        for feedID in [
            "timeline-event-ui-test-feed-0115",
            "timeline-event-ui-test-feed-0355",
            "timeline-event-ui-test-feed-0850",
            "timeline-event-ui-test-feed-1223",
            "timeline-event-ui-test-feed-1540",
            "timeline-event-ui-test-feed",
            "timeline-event-ui-test-feed-2110",
        ] {
            let feed = app.buttons[feedID]
            XCTAssertTrue(feed.exists, "Missing rendered feed marker \(feedID)")
            XCTAssertTrue(dial.frame.contains(feed.frame), "Feed marker must remain inside the dial")
        }

        for diaperID in [
            "timeline-event-ui-test-diaper-0210",
            "timeline-event-ui-test-diaper-0642",
            "timeline-event-ui-test-diaper-1105",
            "timeline-event-ui-test-diaper-1530",
            "timeline-event-ui-test-diaper-2035",
        ] {
            let diaper = app.buttons[diaperID]
            XCTAssertTrue(diaper.exists, "Missing rendered diaper marker \(diaperID)")
            XCTAssertTrue(dial.frame.contains(diaper.frame), "Diaper marker must remain inside the dial")
        }
    }

    func testCircularTimelineUsesOneCivilClockTrackAndCategorySpecificMarkers() {
        launch(scenario: "circular-timeline")

        let ring = app.otherElements["timeline-day-ring"]
        XCTAssertTrue(ring.waitForExistence(timeout: 3))
        XCTAssertTrue(ring.label.contains("24 horas"))
        XCTAssertTrue(app.otherElements["timeline-clock-ticks"].exists)

        let feeds = app.otherElements["timeline-feed-markers"]
        XCTAssertTrue(feeds.exists)
        XCTAssertTrue(feeds.label.contains("fuera del anillo"))

        let diapers = app.otherElements["timeline-diaper-markers"]
        XCTAssertTrue(diapers.exists)
        XCTAssertTrue(diapers.label.contains("dentro del anillo"))

        let summary = app.otherElements["timeline-center-summary"]
        XCTAssertTrue(summary.exists)
        XCTAssertTrue(summary.label.contains("Sueño"))
        XCTAssertTrue(summary.label.contains("tomas"))
        XCTAssertTrue(summary.label.contains("pañales"))
        XCTAssertFalse(summary.label.contains("Cuidados"))
    }

    func testCircularTimelinePresentsDashboardHierarchy() {
        launch(scenario: "circular-timeline")

        let summary = app.otherElements["timeline-center-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 3))
        for category in ["Sueño", "tomas", "pañales"] {
            XCTAssertTrue(summary.label.contains(category))
        }
        XCTAssertFalse(summary.label.contains("Cuidados"))

        let latestEvents = app.otherElements["timeline-latest-events"]
        XCTAssertTrue(latestEvents.exists)
        XCTAssertTrue(latestEvents.label.contains("Últimos registros"))

        let activityList = app.otherElements["timeline-day-activity-list"]
        XCTAssertTrue(activityList.exists)
        XCTAssertTrue(activityList.label.contains("Actividad del día"))
    }

    func testCircularTimelinePagesToThePreviousDayAndBackToToday() {
        launch(scenario: "circular-timeline")

        XCTAssertTrue(app.staticTexts["Hoy con Marco"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Volver a hoy"].exists)
        let dial = app.otherElements["timeline-circular-dial"]
        XCTAssertTrue(dial.exists)
        XCTAssertTrue(app.otherElements["timeline-now-marker"].exists)
        dial.swipeRight()
        dial.swipeRight()

        XCTAssertTrue(app.buttons["Volver a hoy"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.otherElements["timeline-circular-dial"].exists)
        XCTAssertFalse(app.otherElements["timeline-now-marker"].exists)
        app.buttons["Volver a hoy"].tap()
        XCTAssertTrue(app.staticTexts["Hoy con Marco"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Volver a hoy"].exists)
        XCTAssertFalse(app.buttons["Día siguiente"].isEnabled)
        XCTAssertTrue(app.otherElements["timeline-now-marker"].exists)
    }

    func testDenseCircularTimelineKeepsFeedAndDiaperClustersIndependent() {
        launch(scenario: "circular-timeline-dense")

        let feedCluster = app.buttons["timeline-cluster-feed-480"]
        let diaperCluster = app.buttons["timeline-cluster-diaper-481"]
        XCTAssertTrue(feedCluster.waitForExistence(timeout: 3))
        XCTAssertTrue(diaperCluster.exists)
        XCTAssertTrue(feedCluster.label.contains("3 tomas"))
        XCTAssertTrue(diaperCluster.label.contains("3 pañales"))

        XCTAssertTrue(app.otherElements["timeline-cluster-expanded"].waitForExistence(timeout: 2))
        for index in [1, 3, 5] {
            XCTAssertTrue(app.buttons["timeline-expanded-dense-\(index)"].exists)
        }

        app.buttons["timeline-expanded-dense-1"].press(forDuration: 1)
        XCTAssertTrue(app.navigationBars["Editar registro"].waitForExistence(timeout: 2))
    }

    func testCircularTimelineFitsAboveTheTabBarAtNormalTextSize() {
        launch(scenario: "circular-timeline")

        let dial = app.otherElements["timeline-circular-dial"]
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(dial.waitForExistence(timeout: 3))
        XCTAssertTrue(tabBar.exists)
        XCTAssertLessThanOrEqual(dial.frame.maxY, tabBar.frame.minY - 16)
    }

    func testCircularTimelineIsInTheFirstViewportAtAccessibilityXXXL() {
        launch(
            scenario: "circular-timeline",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )

        let dial = app.otherElements["timeline-circular-dial"]
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(dial.waitForExistence(timeout: 3))
        XCTAssertTrue(tabBar.exists)
        XCTAssertLessThan(dial.frame.minY, tabBar.frame.minY)
    }

    func testHistoryFormatsDurationAsHoursAndMinutes() {
        launch(scenario: "timeline-duration")

        app.tabBars.buttons["Historia"].tap()
        XCTAssertTrue(app.navigationBars["Historia"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["1 h 15 min"].exists)
        XCTAssertFalse(app.staticTexts["75 min"].exists)
    }

    func testPediatricReportCanBePreparedFromDurationEntry() {
        launch(scenario: "timeline-duration")

        app.tabBars.buttons["Ajustes"].tap()
        let prepareReport = app.buttons["Preparar informe de 30 días"]
        for _ in 0..<3 where !prepareReport.exists {
            app.swipeUp()
        }
        XCTAssertTrue(prepareReport.exists)
        prepareReport.tap()

        XCTAssertTrue(app.buttons["Compartir informe de 30 días"].waitForExistence(timeout: 3))
    }

    func testEditingADiaperUpdatesItsTimelineTime() {
        launch(scenario: "diaper-edit")

        app.tabBars.buttons["Historia"].tap()
        XCTAssertTrue(app.staticTexts["15:24"].waitForExistence(timeout: 3))
        app.staticTexts["Pañal"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Editar registro"].waitForExistence(timeout: 2))

        let timeButton = app.buttons["15:24"]
        XCTAssertTrue(timeButton.waitForExistence(timeout: 2))
        timeButton.tap()
        let hourWheel = app.pickerWheels.element(boundBy: 0)
        XCTAssertTrue(hourWheel.waitForExistence(timeout: 2))
        hourWheel.adjust(toPickerWheelValue: "13")
        app.buttons["Guardar"].tap()

        XCTAssertTrue(app.staticTexts["13:24"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["15:24"].exists)
    }

    func testCreatingAFeedUsesTheSelectedTimelineTime() {
        launch(scenario: "feed-create")

        let activityButton = app.buttons["Registrar una actividad"]
        XCTAssertTrue(activityButton.waitForExistence(timeout: 3))
        activityButton.tap()
        app.buttons["Registrar toma"].tap()
        XCTAssertTrue(app.navigationBars["Toma"].waitForExistence(timeout: 2))

        let timeButton = app.buttons["17:50"]
        XCTAssertTrue(timeButton.waitForExistence(timeout: 2))
        timeButton.tap()
        let hourWheel = app.pickerWheels.element(boundBy: 0)
        let minuteWheel = app.pickerWheels.element(boundBy: 1)
        XCTAssertTrue(hourWheel.waitForExistence(timeout: 2))
        XCTAssertTrue(minuteWheel.exists)
        hourWheel.adjust(toPickerWheelValue: "16")
        minuteWheel.adjust(toPickerWheelValue: "00")
        app.buttons["Guardar"].tap()

        let savedFeed = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Toma' AND label CONTAINS '16:00'")
        ).firstMatch
        XCTAssertTrue(savedFeed.waitForExistence(timeout: 3))
        let feedAtDefaultTime = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Toma' AND label CONTAINS '17:50'")
        ).firstMatch
        XCTAssertFalse(feedAtDefaultTime.exists)
    }

    private func launch(scenario: String, contentSizeCategory: String? = nil) {
        app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchArguments += ["-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]
        if let contentSizeCategory {
            app.launchEnvironment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"] = contentSizeCategory
        }
        app.launch()
    }
}
        feedCluster.tap()

        XCTAssertTrue(app.otherElements["timeline-cluster-expanded"].waitForExistence(timeout: 2))
        for index in [0, 2, 4] {
            XCTAssertTrue(app.buttons["timeline-expanded-dense-\(index)"].exists)
        }
        app.buttons["Cerrar registros"].tap()

        diaperCluster.tap()
