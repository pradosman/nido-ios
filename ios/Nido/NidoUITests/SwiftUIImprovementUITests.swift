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
        app.floatingNavigationTabButtons["Historia"].tap()
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
        XCTAssertTrue(scrollUntilExists(activitySummary), "The saved activity should materialize while scrolling the lazy Today timeline.")
        XCTAssertTrue(activitySummary.waitForExistence(timeout: 5))
        scrollElementIntoViewport(activitySummary)
        XCTAssertTrue(
            activitySummary.label.contains("3 registros"),
            "Saving both selected choices should increase today's fixture from two to three records."
        )
        let savedActivity = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "timeline-activity-", "Pis y caca")
        ).firstMatch
        XCTAssertTrue(savedActivity.exists)
        scrollElementIntoViewport(savedActivity)
        XCTAssertTrue(savedActivity.isHittable, "The saved combined diaper record should be reachable in the timeline.")
    }

    func testEvolutionMetricValuesRespectLargestAccessibilityTextSize() {
        launch(scenario: "evolution-design-summary")
        app.floatingNavigationTabButtons["Evolución"].tap()
        let regularValue = app.descendants(matching: .any)
            .matching(identifier: "evolution-value-diapers").firstMatch
        XCTAssertTrue(regularValue.waitForExistence(timeout: 5))
        scrollElementIntoViewport(regularValue)
        let regularHeight = regularValue.frame.height

        app.terminate()
        launch(
            scenario: "evolution-design-summary",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )
        app.floatingNavigationTabButtons["Evolución"].tap()
        let largeValue = app.descendants(matching: .any)
            .matching(identifier: "evolution-value-diapers").firstMatch
        XCTAssertTrue(largeValue.waitForExistence(timeout: 5))
        scrollElementIntoViewport(largeValue)
        XCTAssertGreaterThan(
            largeValue.frame.height, regularHeight * 1.2,
            "The shared Evolution card value should scale with the accessibility text setting."
        )
        scrollElementIntoViewport(largeValue)
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

    private func metricValue(above note: XCUIElement) -> XCUIElement? {
        let noteFrame = note.frame
        let numbers = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "[0-9]+"))
        let candidates = numbers.allElementsBoundByIndex.filter { value in
            let frame = value.frame
            let gap = noteFrame.minY - frame.maxY
            return gap >= 0 && gap <= 40 && abs(frame.minX - noteFrame.minX) <= 18
        }
        guard candidates.count == 1 else { return nil }
        return candidates.first
    }

    private func scrollUntilExists(_ element: XCUIElement, attempts: Int = 8) -> Bool {
        guard let scrollView = primaryScrollView() else { return element.exists }
        for _ in 0..<attempts {
            if element.exists { return true }
            performScroll(in: scrollView, direction: .towardLaterContent)
        }
        return element.exists
    }

    private func scrollElementIntoViewport(_ element: XCUIElement, attempts: Int = 8) {
        guard let scrollView = primaryScrollView() else { return }
        for _ in 0..<attempts where !element.isHittable {
            let visibleFrame = unobscuredViewport(in: scrollView)
            let elementFrame = element.frame
            if elementFrame.maxY > visibleFrame.maxY {
                performScroll(in: scrollView, direction: .towardLaterContent)
            } else if elementFrame.minY < visibleFrame.minY {
                performScroll(in: scrollView, direction: .towardEarlierContent)
            } else {
                return
            }
        }
    }

    private func primaryScrollView() -> XCUIElement? {
        let collectionViews = app.collectionViews.allElementsBoundByIndex
        if let foreground = collectionViews.first(where: { $0.isHittable }) { return foreground }
        let scrollViews = app.scrollViews.allElementsBoundByIndex
        if let foreground = scrollViews.first(where: { $0.isHittable }) { return foreground }
        return collectionViews.first ?? scrollViews.first
    }

    private enum ScrollDirection {
        case towardEarlierContent
        case towardLaterContent
    }

    private func unobscuredViewport(in scrollView: XCUIElement) -> CGRect {
        var visibleFrame = scrollView.frame.insetBy(dx: 8, dy: 12)
        let tabBar = app.otherElements["floating-navigation-tabbar"]
        let registration = app.buttons["registration-action-button"]
        let blockers = [tabBar, registration].filter { $0.exists && $0.isHittable }
        if let top = blockers.map(\.frame.minY).min() {
            visibleFrame.size.height = max(0, min(visibleFrame.maxY, top - 12) - visibleFrame.minY)
        }
        return visibleFrame
    }

    private func performScroll(in scrollView: XCUIElement, direction: ScrollDirection) {
        let visibleFrame = unobscuredViewport(in: scrollView)
        guard visibleFrame.height > 80, scrollView.frame.height > 0 else { return }
        let startFraction: CGFloat = direction == .towardLaterContent ? 0.76 : 0.24
        let endFraction: CGFloat = direction == .towardLaterContent ? 0.24 : 0.76
        func coordinate(at fraction: CGFloat) -> XCUICoordinate {
            let y = visibleFrame.minY + visibleFrame.height * fraction
            let normalizedY = (y - scrollView.frame.minY) / scrollView.frame.height
            return scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: normalizedY))
        }
        coordinate(at: startFraction).press(
            forDuration: 0.15,
            thenDragTo: coordinate(at: endFraction),
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )
    }

    private func attachAccessibilityDiagnostics(named name: String) {
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = name
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "\(name) screenshot"
        screenshot.lifetime = .keepAlways
        add(screenshot)
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
