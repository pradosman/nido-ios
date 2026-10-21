import XCTest
import UIKit
import Vision

@MainActor
final class FloatingNavigationUITests: XCTestCase {
    func testCompactAccessibilityXXXLTabTitlesFitInsideTheirDockButtons() throws {
        let app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = "baby-care"
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = "compact-axx-xl-dock-title-fit"
        app.launchEnvironment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"] =
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        app.launchEnvironment["NIDO_UI_TEST_APPEARANCE"] = "light"
        app.launchEnvironment["NIDO_UI_TEST_API_BASE_URL"] = "http://127.0.0.1:1"
        app.launchArguments = [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", "baby-care",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["timeline-day-heading"].waitForExistence(timeout: 10))
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)
        print("COMPACT_AXXXL_TAB_WINDOW frame=\(window.frame)")

        let dock = app.floatingNavigationTabBars.firstMatch
        XCTAssertTrue(dock.waitForExistence(timeout: 5))
        let expectedTabs: [(id: String, title: String)] = [
            ("tab-today", "Hoy"),
            ("tab-history", "Historia"),
            ("tab-trends", "Evolución"),
            ("tab-settings", "Ajustes"),
        ]
        XCTAssertEqual(
            Set(app.floatingNavigationTabButtons.allElementsBoundByIndex.map(\.label)),
            Set(expectedTabs.map(\.title))
        )

        let renderedScreenshot = app.screenshot()
        let screenshotAttachment = XCTAttachment(screenshot: renderedScreenshot)
        screenshotAttachment.name = "Compact SE Accessibility XXXL floating navigation titles"
        screenshotAttachment.lifetime = .keepAlways
        add(screenshotAttachment)
        let windowFrame = window.frame
        let sourceImage = try XCTUnwrap(renderedScreenshot.image.cgImage)

        for expected in expectedTabs {
            let tab = app.buttons[expected.id]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "Missing tab target \(expected.id).")
            XCTAssertTrue(tab.isHittable, "Tab target \(expected.id) must remain hittable at compact Accessibility XXXL.")
            let titleElement = tab.buttons.matching(NSPredicate(format: "label == %@", expected.title)).firstMatch
            XCTAssertTrue(
                titleElement.waitForExistence(timeout: 3),
                "Tab \(expected.id) must expose its title as a nested accessibility element."
            )
            let titleFrame = titleElement.frame
            let buttonFrame = tab.frame
            print("COMPACT_AXXXL_TAB_TITLE id=\(expected.id) title=\(expected.title) button=\(buttonFrame) titleFrame=\(titleFrame) dock=\(dock.frame)")
            XCTAssertGreaterThan(titleFrame.width, 0, "Tab title \(expected.title) must have a visible frame.")
            XCTAssertGreaterThan(titleFrame.height, 0, "Tab title \(expected.title) must have a visible frame.")
            XCTAssertLessThan(
                titleFrame.height, buttonFrame.height,
                "Tab title \(expected.title) must fit on one line within its own row, not wrap below the dock row."
            )
            XCTAssertTrue(
                buttonFrame.insetBy(dx: -1, dy: -1).contains(titleFrame),
                "Tab title \(expected.title) must fit completely inside its button; titleFrame=\(titleFrame), buttonFrame=\(buttonFrame)."
            )
            XCTAssertTrue(
                dock.frame.insetBy(dx: -1, dy: -1).contains(titleFrame),
                "Tab title \(expected.title) must fit completely inside the visible dock capsule."
            )

            let visibleTitleRegion = titleFrame.intersection(buttonFrame)
            let cropRect = CGRect(
                x: (visibleTitleRegion.minX - windowFrame.minX) * CGFloat(sourceImage.width) / windowFrame.width,
                y: (visibleTitleRegion.minY - windowFrame.minY) * CGFloat(sourceImage.height) / windowFrame.height,
                width: visibleTitleRegion.width * CGFloat(sourceImage.width) / windowFrame.width,
                height: visibleTitleRegion.height * CGFloat(sourceImage.height) / windowFrame.height
            ).integral.intersection(CGRect(x: 0, y: 0, width: sourceImage.width, height: sourceImage.height))
            let crop = cropRect.width > 0 && cropRect.height > 0 ? sourceImage.cropping(to: cropRect) : nil
            XCTAssertNotNil(crop, "Tab title \(expected.title) must have an in-button rendered crop.")
            if let crop {
                let cropAttachment = XCTAttachment(image: UIImage(cgImage: crop))
                cropAttachment.name = "Compact AXXXL visible title crop \(expected.title)"
                cropAttachment.lifetime = .keepAlways
                add(cropAttachment)

                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                request.recognitionLanguages = ["es-ES"]
                try VNImageRequestHandler(cgImage: crop).perform([request])
                let recognizedLines = (request.results ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                    .map { $0.lowercased().filter(\.isLetter) }
                    .filter { !$0.isEmpty }
                let expectedLetters = expected.title.lowercased().filter(\.isLetter)
                print("COMPACT_AXXXL_TAB_OCR id=\(expected.id) expected=\(expectedLetters) lines=\(recognizedLines)")
                XCTAssertEqual(
                    recognizedLines.count, 1,
                    "One-word tab title \(expected.title) must render on one visible line, not orphan its final letters: OCR=\(recognizedLines), titleFrame=\(titleFrame), buttonFrame=\(buttonFrame)."
                )
                XCTAssertEqual(
                    recognizedLines.first, expectedLetters,
                    "The single visible title line must contain the complete title \(expected.title); OCR=\(recognizedLines), titleFrame=\(titleFrame), buttonFrame=\(buttonFrame)."
                )
            }
        }
    }

    func testTodayScrollAndFloatingNavigationGeometry() throws {
        let app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = "baby-care"
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        if let contentSize = ProcessInfo.processInfo.environment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"],
           !contentSize.isEmpty {
            app.launchEnvironment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"] = contentSize
        }
        if let appearance = ProcessInfo.processInfo.environment["NIDO_UI_TEST_APPEARANCE"],
           !appearance.isEmpty {
            app.launchEnvironment["NIDO_UI_TEST_APPEARANCE"] = appearance
        }
        app.launchEnvironment["NIDO_UI_TEST_API_BASE_URL"] =
            ProcessInfo.processInfo.environment["NIDO_UI_TEST_API_BASE_URL"] ?? "http://127.0.0.1:1"
        app.launchArguments = [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", "baby-care",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
        ]
        app.launch()

        let heading = app.staticTexts["timeline-day-heading"]
        XCTAssertTrue(heading.waitForExistence(timeout: 10))
        let scrollView = app.scrollViews.containing(
            .any, identifier: "timeline-day-activity-list"
        ).firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        let registration = app.buttons["registration-action-button"]
        XCTAssertTrue(registration.waitForExistence(timeout: 5))
        let tabBar = app.floatingNavigationTabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        let navigationOverlay = app.floatingNavigationOverlay
        XCTAssertTrue(navigationOverlay.waitForExistence(timeout: 5))
        let tabs = app.floatingNavigationTabButtons.allElementsBoundByIndex
        XCTAssertEqual(Set(tabs.map(\.label)), ["Hoy", "Historia", "Evolución", "Ajustes"])

        let window = app.windows.firstMatch.frame
        let tabFrames = tabs.map(\.frame)
        let tabGroup = tabFrames.reduce(CGRect.null) { $0.union($1) }
        let usesAccessibilityDynamicType =
            ProcessInfo.processInfo.environment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"]?
                .contains("Accessibility") == true
        let measuredTabTopInset = tabBar.frame.minY - tabGroup.minY
        let measuredTabBottomInset = tabGroup.maxY - tabBar.frame.maxY
        let measuredRegistrationBottomInset = window.maxY - registration.frame.maxY
        print("FLOATING_NAV_GEOMETRY window=\(window) overlay=\(navigationOverlay.frame) scroll=\(scrollView.frame) tabs=\(tabFrames) tabBar=\(tabBar.frame) registration=\(registration.frame) measuredInsets=(tabTop:\(measuredTabTopInset),tabBottom:\(measuredTabBottomInset),registrationBottom:\(measuredRegistrationBottomInset))")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Today floating navigation geometry before assertions"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        XCTAssertGreaterThanOrEqual(
            scrollView.frame.maxY,
            registration.frame.maxY,
            "Today's activity scroll viewport should continue behind the registration control."
        )
        for tab in tabs {
            XCTAssertGreaterThanOrEqual(tab.frame.width, 44)
            XCTAssertGreaterThanOrEqual(tab.frame.height, 44)
            XCTAssertTrue(
                tabBar.frame.insetBy(dx: -1, dy: -1).contains(tab.frame),
                "Every full-label tab target must remain inside the visible capsule: \(tab.label) \(tab.frame) in \(tabBar.frame)"
            )
        }
        if usesAccessibilityDynamicType {
            XCTAssertGreaterThanOrEqual(
                tabBar.frame.height, 62,
                "The two-row accessibility dock may grow, but must retain its default minimum height."
            )
        } else {
            XCTAssertEqual(
                tabBar.frame.height, 62, accuracy: 1,
                "The regular four-column dock should retain its 62-point height."
            )
        }
        XCTAssertGreaterThanOrEqual(registration.frame.width, 44)
        XCTAssertGreaterThanOrEqual(registration.frame.height, 44)
        let registrationAndTabsCenterDelta = abs(registration.frame.midY - tabGroup.midY)
        XCTAssertLessThanOrEqual(
            registrationAndTabsCenterDelta, 3,
            "The registration control should share the tab targets' vertical center."
        )
        let horizontalGap = registration.frame.minX - tabGroup.maxX
        XCTAssertGreaterThanOrEqual(
            horizontalGap, 8,
            "The registration control should sit beside, with a tappable gap from, the four tab targets."
        )
        XCTAssertEqual(
            tabGroup.midX, tabBar.frame.midX, accuracy: 3,
            "The four tab targets should be centered in their bar."
        )
        // The semantic tab bar is the visible capsule and ends at the safe-area boundary.
        // The transparent overlay is the physical hit-test/scroll container and reaches the window edge.
        XCTAssertEqual(navigationOverlay.frame.minX, window.minX, accuracy: 3)
        XCTAssertEqual(navigationOverlay.frame.maxX, window.maxX, accuracy: 3)
        XCTAssertEqual(
            navigationOverlay.frame.maxY, window.maxY, accuracy: 3,
            "The floating-navigation overlay should cover the physical window through the home-indicator area."
        )
        XCTAssertGreaterThanOrEqual(
            navigationOverlay.frame.height, tabBar.frame.height,
            "The floating-navigation overlay should include the visible tab capsule."
        )
        XCTAssertGreaterThanOrEqual(tabBar.frame.minY, window.minY - 3)
        XCTAssertLessThanOrEqual(
            tabBar.frame.maxY, window.maxY + 3,
            "The visible semantic capsule should remain inside the physical window."
        )
        let visibleCapsuleBottomGap = window.maxY - tabBar.frame.maxY
        XCTAssertGreaterThanOrEqual(
            visibleCapsuleBottomGap, 6,
            "The visible capsule should keep at least 6 points from the physical window edge."
        )
        XCTAssertLessThanOrEqual(
            visibleCapsuleBottomGap, 24,
            "The visible capsule should stay within 24 points of the physical window edge."
        )

        let expectedDynamicTypeLabels = Set(["Hoy", "Historia", "Evolución", "Ajustes"])
        var reportedNavigationLabels = Set<String>()
        var unresolvedDynamicTypeFindings: [String] = []
        try app.performAccessibilityAudit(for: .dynamicType) { issue in
            guard let element = issue.element else {
                let finding = "unattributed: \(issue.compactDescription) | \(issue.detailedDescription)"
                unresolvedDynamicTypeFindings.append(finding)
                print("FLOATING_NAV_DYNAMIC_TYPE_UNRESOLVED: \(finding)")
                return false
            }

            let label = element.label
            let frame = element.frame
            guard expectedDynamicTypeLabels.contains(label) else {
                guard !frame.isEmpty, !frame.intersects(tabBar.frame) else {
                    let finding = "unknown dock finding: identifier=\(element.identifier) label=\(label) frame=\(frame) issue=\(issue.compactDescription)"
                    unresolvedDynamicTypeFindings.append(finding)
                    print("FLOATING_NAV_DYNAMIC_TYPE_UNRESOLVED: \(finding)")
                    return false
                }

                print("FLOATING_NAV_DYNAMIC_TYPE_OUTSIDE_DOCK: identifier=\(element.identifier) label=\(label) frame=\(frame) issue=\(issue.compactDescription)")
                return true
            }

            let matchingTab = tabs.first { $0.label == label }
            guard let matchingTab,
                  frame.intersects(tabBar.frame),
                  abs(frame.midX - matchingTab.frame.midX) <= 3,
                  abs(frame.midY - matchingTab.frame.midY) <= 3 else {
                let finding = "misattributed dock label: label=\(label) issueFrame=\(frame) tabFrame=\(matchingTab?.frame as Any) barFrame=\(tabBar.frame)"
                unresolvedDynamicTypeFindings.append(finding)
                print("FLOATING_NAV_DYNAMIC_TYPE_UNRESOLVED: \(finding)")
                return false
            }

            reportedNavigationLabels.insert(label)
            print("FLOATING_NAV_DYNAMIC_TYPE_FINDING: label=\(label) frame=\(frame) barFrame=\(tabBar.frame) issue=\(issue.compactDescription) | \(issue.detailedDescription)")
            return true
        }

        XCTAssertTrue(
            unresolvedDynamicTypeFindings.isEmpty,
            "The focused dock audit must not silently ignore nil, unknown, or misattributed findings: \(unresolvedDynamicTypeFindings)"
        )
        XCTAssertTrue(
            reportedNavigationLabels.isEmpty,
            "All four visible tab labels should support Dynamic Type; unsupported labels found: \(reportedNavigationLabels)"
        )

        let dockTree = XCTAttachment(string: tabBar.debugDescription)
        dockTree.name = usesAccessibilityDynamicType
            ? "Accessibility-size floating navigation accessibility tree"
            : "Regular-size floating navigation accessibility tree"
        dockTree.lifetime = .keepAlways
        add(dockTree)

        for label in expectedDynamicTypeLabels.sorted() {
            let tab = app.floatingNavigationTabButtons[label]
            XCTAssertTrue(tab.waitForExistence(timeout: 3), "Missing complete navigation label \(label).")
            XCTAssertEqual(tab.label, label, "The accessible label should remain complete when the dock grows.")
            XCTAssertTrue(tab.isHittable, "The full-title tab should remain tappable at the current text size: \(label)")
            tab.tap()
            XCTAssertTrue(tab.isSelected, "Selecting \(label) should update the selected-tab trait.")
        }
        let todayTab = app.floatingNavigationTabButtons["Hoy"]
        todayTab.tap()
        XCTAssertTrue(todayTab.isSelected)
        if usesAccessibilityDynamicType {
            registration.tap()
            for title in ["Registrar sueño", "Registrar toma", "Registrar pañal", "Registrar cuidados"] {
                let choice = app.buttons[title]
                XCTAssertTrue(choice.waitForExistence(timeout: 5), "The registration menu should retain \(title) at Accessibility XXXL.")
                XCTAssertTrue(choice.isHittable, "The registration choice should remain tappable at Accessibility XXXL: \(title)")
            }
            heading.tap()
        }

        let listItems = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "timeline-activity-")
        )
        XCTAssertGreaterThan(listItems.count, 0, "The isolated Today fixture should contain activity rows.")
        let navigationBand = registration.frame.minY...tabBar.frame.maxY
        let targetRowCenterY = navigationBand.lowerBound + 12
        let rowsBeforeDockDrag = listItems.allElementsBoundByIndex
            .filter { $0.exists && $0.frame.height > 0 }
            .sorted { $0.frame.minY < $1.frame.minY }
        print("FLOATING_NAV_ROWS_BEFORE_DOCK_DRAG frames=\(rowsBeforeDockDrag.map(\.frame))")
        let targetRowIndex = rowsBeforeDockDrag.indices.dropFirst().first { index in
            rowsBeforeDockDrag[index].frame.midY >= targetRowCenterY + 20
        }
        let rowToMoveIndex = try XCTUnwrap(
            targetRowIndex,
            "The isolated fixture should expose a second activity row below the dock band."
        )
        let rowToMove = rowsBeforeDockDrag[rowToMoveIndex]
        let precedingRow = rowsBeforeDockDrag[rowToMoveIndex - 1]
        XCTAssertLessThan(precedingRow.frame.midY, rowToMove.frame.midY,
                          "A real preceding activity row should remain available above the dock.")

        // Aim the second real activity row at the floating controls using its measured frame.
        // Require a meaningful drag and keep both touch points above the dock.
        let safeGestureY = min(registration.frame.minY, tabBar.frame.minY) - 16
        let safeGestureTopY = scrollView.frame.minY + 16
        let maxGestureTravel = safeGestureY - safeGestureTopY
        let minimumMeaningfulGestureTravel = min(25, maxGestureTravel)
        let initialFingerTravelY = targetRowCenterY - rowToMove.frame.midY
        XCTAssertGreaterThanOrEqual(abs(initialFingerTravelY), 20,
                                    "The measured row should require a real scroll gesture.")
        XCTAssertGreaterThan(maxGestureTravel, 0,
                             "The scroll view should expose a touch path above the dock.")

        let placementScore: (CGRect, CGRect) -> CGFloat = { row, preceding in
            let gapToDockBand: CGFloat
            if row.maxY <= navigationBand.lowerBound {
                gapToDockBand = navigationBand.lowerBound - row.maxY
            } else if row.minY >= navigationBand.upperBound {
                gapToDockBand = row.minY - navigationBand.upperBound
            } else {
                gapToDockBand = 0
            }
            let precedingRowOverlap = max(0, preceding.maxY - registration.frame.minY)
            return gapToDockBand + precedingRowOverlap
        }

        var placementCompleted = false
        for attempt in 0..<6 {
            let currentRowFrame = rowToMove.frame
            let currentPrecedingFrame = precedingRow.frame
            let rowOverlapsDockBand = currentRowFrame.maxY > navigationBand.lowerBound
                && currentRowFrame.minY < navigationBand.upperBound
            let precedingIsReachableAboveControls = currentPrecedingFrame.maxY <= registration.frame.minY
                && precedingRow.isHittable
            if rowOverlapsDockBand && precedingIsReachableAboveControls {
                placementCompleted = true
                break
            }

            let clearanceCorrection = max(
                0,
                currentPrecedingFrame.maxY - registration.frame.minY + 2
            )
            let lowestCenterStillOverlappingBand = navigationBand.lowerBound - currentRowFrame.height / 2 + 1
            let desiredRowCenterY = max(
                lowestCenterStillOverlappingBand,
                min(targetRowCenterY, currentRowFrame.midY - clearanceCorrection)
            )
            let requestedFingerTravelY = desiredRowCenterY - currentRowFrame.midY
            let gestureMagnitude = min(
                max(abs(requestedFingerTravelY), minimumMeaningfulGestureTravel),
                maxGestureTravel
            )
            let fingerTravelY = gestureMagnitude
                * (requestedFingerTravelY < 0 ? -1 : 1)
            guard fingerTravelY.isFinite, abs(fingerTravelY) > 0.5 else {
                XCTFail("Could not compute a measurable scroll correction for the dock band.")
                break
            }

            let dragStartY = fingerTravelY >= 0 ? safeGestureY - fingerTravelY : safeGestureY
            let dragEndY = fingerTravelY >= 0 ? safeGestureY : safeGestureY + fingerTravelY
            XCTAssertGreaterThanOrEqual(dragStartY, safeGestureTopY)
            XCTAssertLessThanOrEqual(dragStartY, safeGestureY)
            XCTAssertGreaterThanOrEqual(dragEndY, safeGestureTopY)
            XCTAssertLessThanOrEqual(dragEndY, safeGestureY)

            let scoreBefore = placementScore(currentRowFrame, currentPrecedingFrame)
                + (precedingRow.isHittable ? 0 : 1)
            print("FLOATING_NAV_MID_SCROLL attempt=\(attempt + 1) target=\(currentRowFrame) preceding=\(currentPrecedingFrame) navigationBand=\(navigationBand) gestureY=(\(dragStartY),\(dragEndY)) score=\(scoreBefore)")
            let scrollStart = scrollView.coordinate(withNormalizedOffset: CGVector(
                dx: 0.5,
                dy: (dragStartY - scrollView.frame.minY) / scrollView.frame.height
            ))
            let scrollEnd = scrollView.coordinate(withNormalizedOffset: CGVector(
                dx: 0.5,
                dy: (dragEndY - scrollView.frame.minY) / scrollView.frame.height
            ))
            scrollStart.press(
                forDuration: 0.05,
                thenDragTo: scrollEnd,
                withVelocity: .slow,
                thenHoldForDuration: 0.2
            )

            let measuredRowFrame = rowToMove.frame
            let measuredPrecedingFrame = precedingRow.frame
            let scoreAfter = placementScore(measuredRowFrame, measuredPrecedingFrame)
                + (precedingRow.isHittable ? 0 : 1)
            print("FLOATING_NAV_MID_SCROLL_AFTER attempt=\(attempt + 1) target=\(measuredRowFrame) preceding=\(measuredPrecedingFrame) score=\(scoreAfter)")
            guard scoreAfter < scoreBefore else {
                XCTFail("The measured scroll correction made no progress toward the dock band.")
                break
            }
            let measuredRowOverlapsDockBand = measuredRowFrame.maxY > navigationBand.lowerBound
                && measuredRowFrame.minY < navigationBand.upperBound
            let measuredPrecedingIsReachableAboveControls = measuredPrecedingFrame.maxY <= registration.frame.minY
                && precedingRow.isHittable
            if measuredRowOverlapsDockBand && measuredPrecedingIsReachableAboveControls {
                placementCompleted = true
                break
            }
        }
        XCTAssertTrue(placementCompleted,
                      "The measured row should settle under the dock while its preceding row remains reachable above it.")
        let items = listItems.allElementsBoundByIndex
        let rowsInViewport = items.filter { $0.frame.intersects(scrollView.frame) }
        print("FLOATING_NAV_MID_SCROLL_AFTER frames=\(rowsInViewport.map(\.frame))")
        XCTAssertFalse(rowsInViewport.isEmpty, "Activity rows should remain in the viewport while scrolling.")
        for item in rowsInViewport {
            XCTAssertGreaterThanOrEqual(item.frame.minX, scrollView.frame.minX - 1)
            XCTAssertLessThanOrEqual(item.frame.maxX, scrollView.frame.maxX + 1,
                                     "An activity row must not be clipped horizontally at navigation height.")
        }
        XCTAssertTrue(rowsInViewport.contains {
            $0.frame.maxY < registration.frame.minY && $0.isHittable
        }, "A row above the controls should remain reachable.")
        XCTAssertTrue(precedingRow.frame.maxY < registration.frame.minY && precedingRow.isHittable,
                      "The real row preceding the one under the dock should remain reachable above it.")
        let rowsAtNavigationHeight = rowsInViewport.filter {
            $0.frame.maxY >= navigationBand.lowerBound && $0.frame.minY <= navigationBand.upperBound
        }
        XCTAssertFalse(rowsAtNavigationHeight.isEmpty,
                       "At mid-scroll, activity should pass behind the floating controls instead of ending above them.")
        let scrolledScreenshot = XCTAttachment(screenshot: app.screenshot())
        scrolledScreenshot.name = "Today rows scrolled behind floating navigation"
        scrolledScreenshot.lifetime = .keepAlways
        add(scrolledScreenshot)

        let finalActivity = try XCTUnwrap(items.last)
        let finalActivityClearance = min(registration.frame.minY, tabBar.frame.minY) - 12
        for _ in 0..<8 where !finalActivity.isHittable || finalActivity.frame.maxY > finalActivityClearance {
            scrollView.swipeUp()
        }
        print("FLOATING_NAV_END_SCROLL finalActivity=\(finalActivity.frame) registration=\(registration.frame) tabBar=\(tabBar.frame)")
        XCTAssertTrue(finalActivity.isHittable, "The final activity row should remain reachable at end-scroll.")
        XCTAssertLessThanOrEqual(
            finalActivity.frame.maxY, min(registration.frame.minY, tabBar.frame.minY) - 12,
            "At end-scroll, the final row should clear the floating controls by at least 12 points."
        )
        XCTAssertEqual(Set(app.floatingNavigationTabButtons.allElementsBoundByIndex.map(\.label)), ["Hoy", "Historia", "Evolución", "Ajustes"])
        let endScrollScreenshot = XCTAttachment(screenshot: app.screenshot())
        endScrollScreenshot.name = "Today end-scroll final activity row above four-tab dock"
        endScrollScreenshot.lifetime = .keepAlways
        add(endScrollScreenshot)
        _ = measuredTabTopInset
        _ = measuredTabBottomInset
        _ = measuredRegistrationBottomInset
    }
}
