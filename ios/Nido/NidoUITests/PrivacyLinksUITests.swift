import XCTest

@MainActor
final class PrivacyLinksUITests: XCTestCase {
    func testSettingsOffersReachablePrivacyAndSupportLinks() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = "caregiver-removal"
        app.launchEnvironment["NIDO_UI_TEST_API_BASE_URL"] = "http://127.0.0.1:1"
        app.launchArguments += [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", "caregiver-removal",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
        ]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Ajustes"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Ajustes"].tap()

        for (identifier, label) in [
            ("privacy-policy-link", "Política de privacidad"),
            ("support-link", "Ayuda y contacto"),
        ] {
            let link = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            for _ in 0..<8 where !link.exists || !link.isHittable {
                app.swipeUp()
            }
            XCTAssertTrue(link.waitForExistence(timeout: 3), "Falta el enlace \(label)")
            XCTAssertEqual(link.label, label)
            XCTAssertTrue(link.isHittable, "El enlace \(label) debe ser accesible")
            XCTAssertGreaterThanOrEqual(link.frame.height, 44)
        }
    }
}
