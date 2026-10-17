import XCTest

@MainActor
final class DayTimelineActivityContrastUITests: XCTestCase {
    func testEmptyDayActivityLabelPassesFocusedContrastAudit() throws {
        let app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = "ready"
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["NIDO_UI_TEST_API_BASE_URL"] = "http://127.0.0.1:34200"
        app.launchEnvironment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"] = "UICTContentSizeCategoryLarge"
        app.launchArguments += [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", "ready",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
        ]
        app.launch()

        let label = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Sin registros este día"))
            .firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.exists)
        for _ in 0..<8 where !label.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(label.isHittable, "The empty activity label must be visible before auditing its contrast.")
        let labelFrame = label.frame
        let scrollFrame = scrollView.frame
        XCTAssertGreaterThanOrEqual(labelFrame.minY, scrollFrame.minY)
        XCTAssertLessThanOrEqual(labelFrame.maxY, scrollFrame.maxY)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Empty day activity label before focused contrast audit"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        try app.performAccessibilityAudit(for: .contrast) { issue in
            guard let element = issue.element,
                  element.label == "Sin registros este día",
                  abs(element.frame.midY - labelFrame.midY) < 2 else {
                return true
            }
            print("EMPTY_ACTIVITY_CONTRAST_ISSUE: \(issue.compactDescription) | \(issue.detailedDescription)")
            return false
        }
    }
}
