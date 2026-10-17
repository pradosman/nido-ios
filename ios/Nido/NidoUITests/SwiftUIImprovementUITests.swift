import XCTest

@MainActor
final class SwiftUIImprovementUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testAddingDetailsPreservesTheQuickDiaperContents() {
        launch(scenario: "quick-diaper-registration")
        openDetailedDiaperEntryForm()

        let pis = diaperChoice(containing: "Pis")
        let caca = diaperChoice(containing: "Caca")
        XCTAssertTrue(pis.waitForExistence(timeout: 3))
        XCTAssertTrue(pis.isSelected, "The full form must retain Pis from the quick summary.")
        XCTAssertTrue(caca.isSelected, "The full form must retain Caca from the quick summary.")
        XCTAssertTrue(app.buttons["Guardar"].isEnabled)
        app.buttons["Cancelar"].tap()
        XCTAssertTrue(app.navigationBars["Pañal"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["registration-action-button"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Historia"].tap()
        XCTAssertTrue(app.buttons["history-entry-ui-test-latest-diaper"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["history-entry-ui-test-older-diaper"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-entry-'" )).count, 2)
    }

    func testCancelingADirtyDetailedEntryKeepsTheDraftUntilDiscardIsConfirmed() {
        launch(scenario: "quick-diaper-registration")
        openDetailedDiaperEntryForm()
        let note = app.descendants(matching: .any)["entry-note-field"]
        scrollElementIntoViewport(note)
        note.tap()
        note.typeText("Nota que quiero conservar")
        app.buttons["Cancelar"].tap()

        let keepEditing = app.buttons["Seguir editando"]
        XCTAssertTrue(keepEditing.waitForExistence(timeout: 3))
        keepEditing.tap()
        XCTAssertEqual(note.value as? String, "Nota que quiero conservar")
        app.buttons["Cancelar"].tap()
        app.buttons["Descartar cambios"].tap()
        XCTAssertTrue(app.buttons["registration-action-button"].waitForExistence(timeout: 3))
    }

    func testDiaperChoicesGrowAndStackAtLargestAccessibilityTextSize() {
        launch(scenario: "quick-diaper-registration")
        openDetailedDiaperEntryForm()
        let regularPis = diaperChoice(containing: "Pis")
        let regularCaca = diaperChoice(containing: "Caca")
        XCTAssertTrue(regularPis.waitForExistence(timeout: 3))
        XCTAssertTrue(regularCaca.exists)
        let regularHeight = max(regularPis.frame.height, regularCaca.frame.height)

        app.terminate()
        launch(
            scenario: "quick-diaper-registration",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )
        openDetailedDiaperEntryForm()

        let largePis = diaperChoice(containing: "Pis")
        let largeCaca = diaperChoice(containing: "Caca")
        XCTAssertTrue(largePis.waitForExistence(timeout: 3))
        XCTAssertTrue(largeCaca.exists)
        let largeScreenshot = XCTAttachment(screenshot: app.screenshot())
        largeScreenshot.name = "Diaper choice layout at accessibility XXXL"
        largeScreenshot.lifetime = .keepAlways
        add(largeScreenshot)
        XCTAssertGreaterThan(
            largeCaca.frame.minY, largePis.frame.minY,
            "At accessibility sizes Caca should follow Pis in a vertical layout."
        )
        XCTAssertGreaterThanOrEqual(
            largeCaca.frame.minY, largePis.frame.maxY,
            "At accessibility sizes the diaper choices should stack vertically without overlap."
        )
        XCTAssertGreaterThan(
            largePis.frame.height, regularHeight,
            "The Pis option should gain vertical room when accessibility text grows."
        )
        XCTAssertGreaterThan(
            largeCaca.frame.height, regularHeight,
            "The Caca option should gain vertical room when accessibility text grows."
        )
        scrollElementIntoViewport(largePis)
        if largePis.isSelected { largePis.tap() }
        largePis.tap()
        scrollElementIntoViewport(largeCaca)
        if largeCaca.isSelected { largeCaca.tap() }
        largeCaca.tap()
        XCTAssertTrue(largePis.isSelected, "Pis should expose its selected state to accessibility.")
        XCTAssertTrue(largeCaca.isSelected, "Caca should expose its selected state to accessibility.")
        let save = app.buttons["Guardar"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        let activitySummary = app.descendants(matching: .any)["timeline-day-activity-list"]
        XCTAssertTrue(activitySummary.waitForExistence(timeout: 5))
        XCTAssertTrue(
            activitySummary.label.contains("3 registros"),
            "Saving both selected choices should increase today's fixture from two to three records."
        )
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "timeline-activity-", "Pis y caca")).firstMatch.exists)
    }

    func testRhythmMetricValuesRespectLargestAccessibilityTextSize() {
        launch(scenario: "quick-diaper-registration")
        app.tabBars.buttons["Ritmos"].tap()
        let regularNote = app.staticTexts["cambios hoy"]
        XCTAssertTrue(regularNote.waitForExistence(timeout: 5))
        scrollElementIntoViewport(regularNote)
        let regularValue = metricValue(above: regularNote)
        XCTAssertTrue(regularValue.waitForExistence(timeout: 5))
        let regularHeight = regularValue.frame.height

        app.terminate()
        launch(
            scenario: "quick-diaper-registration",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )
        app.tabBars.buttons["Ritmos"].tap()
        let largeNote = app.staticTexts["cambios hoy"]
        XCTAssertTrue(largeNote.waitForExistence(timeout: 5))
        scrollElementIntoViewport(largeNote)
        let largeValue = metricValue(above: largeNote)
        XCTAssertTrue(largeValue.exists)
        XCTAssertGreaterThan(
            largeValue.frame.height, regularHeight * 1.2,
            "The primary count in Ritmos should scale with the accessibility text setting."
        )
        XCTAssertTrue(largeValue.isHittable, "The full metric value should remain visible and reachable.")
    }

    private func openDetailedDiaperEntryForm() {
        let registration = app.buttons["registration-action-button"]
        XCTAssertTrue(registration.waitForExistence(timeout: 5))
        registration.tap()
        app.buttons["Registrar pañal"].tap()
        let details = app.buttons["Añadir detalles"]
        let quickRegistrationForm = app.collectionViews.firstMatch
        for _ in 0..<4 where !details.exists {
            quickRegistrationForm.swipeUp()
        }
        XCTAssertTrue(details.waitForExistence(timeout: 3))
        details.tap()
        XCTAssertTrue(app.navigationBars["Pañal"].waitForExistence(timeout: 5))
    }

    private func diaperChoice(containing title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
    }

    private func metricValue(above note: XCUIElement) -> XCUIElement {
        let noteFrame = note.frame
        let numbers = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "[0-9]+"))
        let candidates = numbers.allElementsBoundByIndex.filter { value in
            let frame = value.frame
            return frame.maxY <= noteFrame.minY && frame.intersects(noteFrame.insetBy(dx: -24, dy: -160))
        }
        return candidates.min {
            noteFrame.minY - $0.frame.maxY < noteFrame.minY - $1.frame.maxY
        } ?? numbers.firstMatch
    }

    private func scrollElementIntoViewport(_ element: XCUIElement) {
        for _ in 0..<6 where !element.isHittable {
            if app.collectionViews.firstMatch.exists {
                app.collectionViews.firstMatch.swipeUp()
            } else if app.scrollViews.firstMatch.exists {
                app.scrollViews.firstMatch.swipeUp()
            } else {
                return
            }
        }
    }

    private func launch(scenario: String, contentSizeCategory: String = "UICTContentSizeCategoryLarge") {
        app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"] = contentSizeCategory
        app.launchEnvironment["NIDO_UI_TEST_API_BASE_URL"] = "http://127.0.0.1:1"
        app.launchArguments += [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", scenario,
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
            "-UIPreferredContentSizeCategoryName", contentSizeCategory,
        ]
        app.launch()
    }
}
