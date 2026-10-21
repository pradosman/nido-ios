import XCTest

@MainActor
final class SleepEvolutionLiveUITests: XCTestCase {
    // Regression coverage: the interactive design preview keeps the original read-only boundary.
    func testPreviewSleepRecordsDoNotExposeEditOrDeleteActions() {
        let app = launchScenario("evolution-design-sleep")
        app.buttons["tab-trends"].tap()

        let sleepCard = element("evolution-sleep-card", in: app)
        guard sleepCard.waitForExistence(timeout: 8) else {
            XCTFail("The design preview should expose its sleep detail card.")
            return
        }
        sleepCard.tap()
        guard app.buttons["sleep-evolution-records-link"].waitForExistence(timeout: 5) else {
            XCTFail("The preview sleep detail should expose its records list.")
            return
        }
        app.buttons["sleep-evolution-records-link"].tap()

        let rows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "sleep-evolution-record-")
        )
        guard rows.firstMatch.waitForExistence(timeout: 5) else {
            XCTFail("The design preview should retain its example sleep records.")
            return
        }
        let row = rows.firstMatch
        row.press(forDuration: 1)
        XCTAssertFalse(app.buttons["Editar"].exists)
        XCTAssertFalse(app.buttons["Eliminar"].exists)
        row.tap()
        XCTAssertFalse(app.navigationBars["Editar registro"].waitForExistence(timeout: 2))
    }

    func testLiveSleepRecordsEditAndDeleteRecomputeTheSummary() {
        let app = launchScenario("evolution-live")
        app.buttons["tab-trends"].tap()

        let sleepCard = element("evolution-card-sleep", in: app)
        guard sleepCard.waitForExistence(timeout: 8) else {
            XCTFail("The LIVE Evolution summary should expose the sleep card.")
            return
        }
        sleepCard.tap()
        guard element("sleep-evolution-detail", in: app).waitForExistence(timeout: 5) else {
            XCTFail("Selecting the LIVE sleep card should open its sleep detail.")
            return
        }
        let detailSummary = element("sleep-evolution-summary-value", in: app)
        XCTAssertEqual(detailSummary.label, "3 h", "The two seeded sleep intervals should total three hours on their recorded day.")

        let recordsLink = app.buttons["sleep-evolution-records-link"]
        guard recordsLink.waitForExistence(timeout: 5) else {
            XCTFail("The LIVE sleep detail should link to its records.")
            return
        }
        recordsLink.tap()

        let sleepA = element("sleep-evolution-record-evolution-live-sleep-a", in: app)
        let sleepB = element("sleep-evolution-record-evolution-live-sleep-b", in: app)
        guard sleepA.waitForExistence(timeout: 5), sleepB.waitForExistence(timeout: 5) else {
            XCTFail("The LIVE records list should show both seeded sleep entries.")
            return
        }
        XCTAssertTrue(sleepA.label.contains("1 h"))
        XCTAssertTrue(sleepB.label.contains("2 h"))
        XCTAssertTrue(sleepA.label.contains("2026"), "An accessible LIVE record row should expose its complete calendar date.")

        // Opening a live record must use the app's existing editor and update the saved interval.
        sleepA.tap()
        XCTAssertTrue(app.navigationBars["Editar registro"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Desde"].exists)
        XCTAssertTrue(app.staticTexts["Hasta"].exists)

        let endDatePicker = app.datePickers.element(boundBy: 1)
        let endTime = endDatePicker.buttons.matching(
            NSPredicate(format: "label == %@ OR label == %@", "9:00", "09:00")
        ).firstMatch
        guard endTime.waitForExistence(timeout: 3) else {
            XCTFail("The second sleep date picker should expose the saved end time.")
            return
        }
        endTime.tap()
        let hourWheel = app.pickerWheels.element(boundBy: 0)
        let minuteWheel = app.pickerWheels.element(boundBy: 1)
        XCTAssertTrue(hourWheel.waitForExistence(timeout: 3))
        XCTAssertTrue(minuteWheel.exists)
        hourWheel.adjust(toPickerWheelValue: "9")
        minuteWheel.adjust(toPickerWheelValue: "30")
        app.navigationBars.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForNonExistence(timeout: 3))
        app.buttons["Guardar"].tap()
        XCTAssertFalse(app.navigationBars["Editar registro"].waitForExistence(timeout: 5))

        let updatedSleepA = element("sleep-evolution-record-evolution-live-sleep-a", in: app)
        XCTAssertTrue(updatedSleepA.waitForExistence(timeout: 5))
        XCTAssertTrue(updatedSleepA.label.contains("1 h 30 min"), "Changing the end time by thirty minutes should update the saved record duration.")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertEqual(detailSummary.label, "3 h 30 min", "Editing the sleep interval should recompute the live summary from the observable store.")
        app.buttons["sleep-evolution-records-link"].tap()

        // The record context action should use the existing permission-checked store deletion path.
        let updatedSleepB = element("sleep-evolution-record-evolution-live-sleep-b", in: app)
        updatedSleepB.press(forDuration: 1)
        let delete = app.buttons["Eliminar"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()

        let removedSleepB = element("sleep-evolution-record-evolution-live-sleep-b", in: app)
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: removedSleepB)
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 8), .completed)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let summary = element("sleep-evolution-summary-value", in: app)
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertEqual(summary.label, "1 h 30 min", "Deleting the two-hour record should recompute the live week summary from the remaining ninety-minute record.")
        XCTAssertEqual(element("sleep-evolution-coverage", in: app).label, "1 de 1 día terminado con registros")
    }

    private func launchScenario(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchArguments += [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", scenario,
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
        ]
        app.launch()
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
