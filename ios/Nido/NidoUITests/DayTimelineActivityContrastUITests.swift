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

        let scrollViews = app.scrollViews.containing(.any, identifier: "timeline-day-activity-list")
        let scrollView = scrollViews.element(boundBy: 0)
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        XCTAssertEqual(scrollViews.count, 1, "Audit Today's activity inside its own vertical scroll view.")
        let activityList = scrollView.descendants(matching: .any)["timeline-day-activity-list"]
        let label = activityList.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Sin registros este día"))
            .firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        XCTAssertTrue(scrollView.exists)
        let registrationButton = app.buttons["registration-action-button"]
        XCTAssertTrue(registrationButton.exists)
        let scrollFrame = scrollView.frame
        let visibleBottom = min(scrollFrame.maxY, registrationButton.frame.minY - 12)
        let visibleHeight = visibleBottom - scrollFrame.minY
        XCTAssertGreaterThan(visibleHeight, 100)
        let origin = scrollView.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: scrollFrame.width / 2, dy: visibleHeight * 0.75))
        let end = origin.withOffset(CGVector(dx: scrollFrame.width / 2, dy: visibleHeight * 0.25))
        for _ in 0..<8 where !label.isHittable || label.frame.maxY > visibleBottom {
            // A full-window AX scroll frame includes the floating controls. Start
            // inside the visible content so the gesture reaches the scroll view.
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(label.isHittable, "The empty activity label must be visible before auditing its contrast.")
        let labelFrame = label.frame
        XCTAssertGreaterThanOrEqual(labelFrame.minY, scrollFrame.minY)
        XCTAssertLessThanOrEqual(labelFrame.maxY, scrollFrame.maxY)
        XCTAssertLessThanOrEqual(labelFrame.maxY, visibleBottom, "The audited text must clear the floating controls.")
        print("EMPTY_ACTIVITY_AUDIT_VIEWPORT: label=\(labelFrame), scroll=\(scrollFrame), visibleBottom=\(visibleBottom)")

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
