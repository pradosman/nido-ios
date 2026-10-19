import XCTest

#if !targetEnvironment(simulator)
@MainActor
final class PhysicalDeviceVisualUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() {
        app?.terminate()
        super.tearDown()
    }

    func testTodayMenuAndCalendarOnPhysicalIPhoneInLightAppearance() {
        captureTodayMenuAndCalendar(dark: false, label: "claro")
    }

    func testTodayMenuAndCalendarOnPhysicalIPhoneInDarkAppearance() {
        captureTodayMenuAndCalendar(dark: true, label: "oscuro")
    }

    private func captureTodayMenuAndCalendar(dark: Bool, label: String) {
        app.launchEnvironment["NIDO_UI_TEST_APPEARANCE"] = dark ? "dark" : "light"
        launch(scenario: "baby-care")
        XCTAssertTrue(app.staticTexts["timeline-day-heading"].waitForExistence(timeout: 10))
        AppearanceScreenshotAssertion.assertRenderedAppearance(app, dark: dark)
        capture("iphone-hoy-\(label)")

        app.buttons["registration-action-button"].tap()
        for title in ["Registrar sueño", "Registrar toma", "Registrar pañal", "Registrar cuidados"] {
            XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 5))
        }
        capture("iphone-registro-\(label)")

        app.terminate()
        launch(scenario: "history-calendar")
        XCTAssertTrue(app.tabBars.buttons["Historia"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Historia"].tap()
        XCTAssertTrue(app.buttons["history-day-picker"].waitForExistence(timeout: 5))
        capture("iphone-historia-\(label)")
        app.buttons["history-day-picker"].tap()
        XCTAssertTrue(app.scrollViews["history-calendar-scroll"].waitForExistence(timeout: 5))
        capture("iphone-calendario-\(label)")
    }

    private func launch(scenario: String) {
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"] = "UICTContentSizeCategoryLarge"
        app.launchArguments = [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", scenario,
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
        ]
        app.launch()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif
