import XCTest
import UIKit

@MainActor
final class EvolutionDesignPreviewUITests: XCTestCase {
    private var app: XCUIApplication!

    func testLiveScenarioShowsEvolutionSummaryAndFiveMetricCatalog() {
        launch(scenario: "evolution-live", appearance: "light")
        openLiveEvolution()

        let summary = app.descendants(matching: .any)
            .matching(identifier: "evolution-summary-live")
            .firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 8), "The LIVE scenario should show the connected Evolution summary.")

        for metric in ["sleep", "feeds", "diapers", "weight", "height"] {
            XCTAssertTrue(
                app.descendants(matching: .any)
                    .matching(identifier: "evolution-card-\(metric)")
                    .firstMatch.waitForExistence(timeout: 3),
                "The LIVE summary should keep the \(metric) metric in the catalog."
            )
        }
    }

    func testLivePinChoicePersistsAfterRelaunch() {
        let runID = UUID().uuidString
        launch(scenario: "evolution-live", appearance: "light", runID: runID)
        openLiveEvolution()
        let edit = app.buttons["evolution-edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 8))
        edit.tap()

        let sleepPin = app.switches["evolution-pin-sleep"]
        XCTAssertTrue(sleepPin.waitForExistence(timeout: 5), "The pin editor should expose each catalog metric.")
        XCTAssertEqual(sleepPin.value as? String, "1", "Sleep should start pinned in the test fixture.")
        tapPinSwitch("sleep")
        XCTAssertEqual(app.switches["evolution-pin-sleep"].value as? String, "0", "The editor should move sleep into the unpinned section.")
        app.buttons["evolution-pin-done"].tap()
        XCTAssertFalse(app.descendants(matching: .any)
            .matching(identifier: "evolution-card-sleep").firstMatch.exists)

        app.terminate()
        launch(scenario: "evolution-live", appearance: "light", runID: runID)
        openLiveEvolution()
        XCTAssertFalse(app.descendants(matching: .any)
            .matching(identifier: "evolution-card-sleep").firstMatch.exists,
            "The local pin choice should survive relaunch for the same caregiver and baby.")
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "evolution-card-feeds").firstMatch.exists)
    }

    func testLiveCanKeepAnEmptyPinnedListAndStillReachEveryMetric() {
        let runID = UUID().uuidString
        launch(scenario: "evolution-live", appearance: "light", runID: runID)
        openLiveEvolution()
        app.buttons["evolution-edit"].tap()

        for metric in ["sleep", "feeds", "diapers", "weight", "height"] {
            let pin = app.switches["evolution-pin-\(metric)"]
            XCTAssertTrue(pin.waitForExistence(timeout: 3))
            XCTAssertEqual(pin.value as? String, "1", "\(metric) should begin pinned.")
            tapPinSwitch(metric)
            XCTAssertEqual(app.switches["evolution-pin-\(metric)"].value as? String, "0", "\(metric) should move to the unpinned section.")
        }
        app.buttons["evolution-pin-done"].tap()
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "evolution-empty-pins").firstMatch.waitForExistence(timeout: 5))
        app.terminate()

        launch(scenario: "evolution-live", appearance: "light", runID: runID)
        openLiveEvolution()
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "evolution-empty-pins").firstMatch.exists)
        let allData = app.buttons["evolution-all-data"]
        XCTAssertTrue(allData.exists, "An empty pinned selection must leave the full catalog reachable.")
        allData.tap()
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "evolution-card-sleep").firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "evolution-card-height").firstMatch.exists)
    }

    func testLivePinnedPreferencesAreScopedToCaregiver() {
        let runID = UUID().uuidString
        launch(scenario: "evolution-live", appearance: "light", runID: runID, caregiverID: "caregiver-a")
        openLiveEvolution()
        app.buttons["evolution-edit"].tap()
        let caregiverASleepPin = app.switches["evolution-pin-sleep"]
        XCTAssertEqual(caregiverASleepPin.waitForExistence(timeout: 3) ? caregiverASleepPin.value as? String : nil, "1")
        tapPinSwitch("sleep")
        XCTAssertEqual(app.switches["evolution-pin-sleep"].value as? String, "0")
        app.buttons["evolution-pin-done"].tap()
        app.terminate()

        launch(scenario: "evolution-live", appearance: "light", runID: runID, caregiverID: "caregiver-b")
        openLiveEvolution()
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "evolution-card-sleep").firstMatch.exists,
            "Caregiver B should retain the default pin list.")
        app.buttons["evolution-edit"].tap()
        let caregiverBFeedsPin = app.switches["evolution-pin-feeds"]
        XCTAssertEqual(caregiverBFeedsPin.waitForExistence(timeout: 3) ? caregiverBFeedsPin.value as? String : nil, "1")
        tapPinSwitch("feeds")
        XCTAssertEqual(app.switches["evolution-pin-feeds"].value as? String, "0")
        app.buttons["evolution-pin-done"].tap()
        app.terminate()

        launch(scenario: "evolution-live", appearance: "light", runID: runID, caregiverID: "caregiver-a")
        openLiveEvolution()
        XCTAssertFalse(app.descendants(matching: .any)
            .matching(identifier: "evolution-card-sleep").firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "evolution-card-feeds").firstMatch.exists)
    }

    func testSummaryShowsReadOnlySevenDayCatalogInLightAppearance() {
        launch(scenario: "evolution-design-summary", appearance: "light")
        openEvolutionPreview()
        assertPreviewChrome()

        XCTAssertEqual(value("sleep").label, "12 h 45 min")
        XCTAssertEqual(value("feeds").label, "8 tomas")
        XCTAssertEqual(value("diapers").label, "6 pañales")
        XCTAssertEqual(value("weight").label, "6,95 kg")
        XCTAssertEqual(value("height").label, "65,2 cm")

        XCTAssertEqual(coverage("sleep").label, "7 de 7 días con registros")
        XCTAssertEqual(coverage("feeds").label, "7 de 7 días con registros")
        XCTAssertEqual(coverage("diapers").label, "5 de 7 días con registros")
        for metric in ["sleep", "feeds", "diapers"] {
            XCTAssertEqual(
                app.descendants(matching: .any)
                    .matching(identifier: "evolution-average-label-\(metric)")
                    .firstMatch.label,
                "Promedio diario"
            )
        }
        XCTAssertTrue(app.staticTexts["evolution-date-weight"].label.contains("18 oct"))
        XCTAssertTrue(app.staticTexts["evolution-date-height"].label.contains("18 oct"))
        let growthValue = value("weight")
        bringIntoReach(growthValue)
        XCTAssertTrue(growthValue.isHittable, "The populated growth section should remain reachable in the normal layout.")
        let growthScreenshot = XCTAttachment(screenshot: app.screenshot())
        growthScreenshot.name = "Evolution growth · light · scrolled"
        growthScreenshot.lifetime = .keepAlways
        add(growthScreenshot)
        attach("Evolution summary · light · populated")
    }

    func testSummaryShowsTheSameCatalogInDarkAppearance() {
        launch(scenario: "evolution-design-summary", appearance: "dark")
        openEvolutionPreview()
        assertPreviewChrome()
        XCTAssertEqual(value("sleep").label, "12 h 45 min")
        XCTAssertEqual(value("feeds").label, "8 tomas")
        XCTAssertEqual(value("diapers").label, "6 pañales")
        XCTAssertEqual(value("weight").label, "6,95 kg")
        XCTAssertEqual(value("height").label, "65,2 cm")
        attach("Evolution summary · dark · populated")
    }

    func testPopulatedCareCardsRenderVisibleMiniBars() throws {
    launch(scenario: "evolution-design-summary", appearance: "light")
    openEvolutionPreview()

    let window = app.windows.firstMatch
    let scrollView = app.scrollViews.firstMatch
    let dock = app.descendants(matching: .any)
        .matching(identifier: "floating-navigation-tabbar").firstMatch
    XCTAssertTrue(dock.waitForExistence(timeout: 5), "Floating navigation must be present for chart visibility checks.")
    XCTAssertTrue(scrollView.exists, "The preview cards should be hosted in a scroll view.")

    for metric in ["sleep", "feeds", "diapers"] {
        let card = app.descendants(matching: .any)
            .matching(identifier: "evolution-card-\(metric)").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Missing \(metric) care card.")
        bringCardIntoSafeViewport(card, in: scrollView)
        let frame = card.frame
        let windowFrame = window.frame
        let viewport = unobscuredViewport(in: scrollView)
        XCTAssertTrue(card.isHittable, "The \(metric) card must be visible before sampling its chart.")
        XCTAssertTrue(frameIsContained(frame, in: windowFrame), "The \(metric) card must be fully inside the window before sampling; card=\(frame), window=\(windowFrame).")
        XCTAssertTrue(frameIsContained(frame, in: viewport), "The \(metric) card must be fully above floating controls before sampling; card=\(frame), viewport=\(viewport).")
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertGreaterThan(frame.height, 0)

        let chartBand = CGRect(
            x: frame.minX + frame.width * 0.68,
            y: frame.minY + frame.height * 0.35,
            width: frame.width * 0.32,
            height: frame.height * 0.45
        )
        let screenshot = app.screenshot().image
        let result = try countSaturatedPixels(in: chartBand, image: screenshot, windowFrame: windowFrame)
        if let crop = result.crop {
            let attachment = XCTAttachment(image: crop)
            attachment.name = "Evolution \(metric) mini-chart crop · \(result.pixelRect) · \(result.count) pixels"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertGreaterThan(result.count, 8,
                             "Expected visible colored mini-bars for \(metric); found \(result.count) pixels in \(result.pixelRect).")
        let full = XCTAttachment(image: screenshot)
        full.name = "Evolution mini-bars · \(metric) card fully visible"
        full.lifetime = .keepAlways
        add(full)
    }
 }

 func testLiveSparseCareMiniChartKeepsMissingDaysInTheirPositions() throws {
    launch(scenario: "evolution-live", appearance: "light")
    openLiveEvolution()

    let scrollView = app.scrollViews.firstMatch
    let card = app.descendants(matching: .any)
        .matching(identifier: "evolution-card-sleep").firstMatch
    XCTAssertTrue(card.waitForExistence(timeout: 5), "The LIVE fixture should show its recorded sleep day.")
    bringCardIntoSafeViewport(card, in: scrollView)
    XCTAssertTrue(card.isHittable)

    let frame = card.frame
    let chart = CGRect(
        x: frame.maxX - 18 - 92,
        y: frame.maxY - 18 - 46,
        width: 92,
        height: 46
    )
    XCTAssertTrue(frameIsContained(chart, in: frame), "The sleep mini-chart should be fully inside its card.")

    let screenshot = app.screenshot().image
    let full = try countSaturatedPixels(in: chart, image: screenshot, windowFrame: app.windows.firstMatch.frame)
    let earlierDays = CGRect(x: chart.minX, y: chart.minY, width: chart.width * 2 / 3, height: chart.height)
    let lastDay = CGRect(x: chart.maxX - chart.width / 7, y: chart.minY, width: chart.width / 7, height: chart.height)
    let early = try countSaturatedPixels(in: earlierDays, image: screenshot, windowFrame: app.windows.firstMatch.frame)
    let last = try countSaturatedPixels(in: lastDay, image: screenshot, windowFrame: app.windows.firstMatch.frame)

    XCTAssertGreaterThan(full.count, 8, "A recorded day should render a visible sleep mini-chart.")
    XCTAssertEqual(early.count, 0, "Missing days must not be stretched across the earlier two-thirds of the chart.")
    XCTAssertGreaterThan(last.count, 0, "The one recorded day in the fixture should remain in the final daily slot.")
 }

 func testEmptyScenarioUsesNoRecordStatesInsteadOfZeroes() {
        launch(scenario: "evolution-design-empty", appearance: "light")
        openEvolutionPreview()
        assertPreviewChrome()

        for metric in ["sleep", "feeds", "diapers"] {
            XCTAssertEqual(value(metric).label, "Sin registros")
        }
        for metric in ["weight", "height"] {
            XCTAssertEqual(value(metric).label, "Sin mediciones")
            XCTAssertFalse(app.staticTexts["evolution-date-\(metric)"].exists)
        }
        attach("Evolution summary · light · empty")
    }

    func testAllFiveValuesRemainReachableAtAccessibilityXXXL() {
        launch(
            scenario: "evolution-design-summary",
            appearance: "light",
            contentSize: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )
        openEvolutionPreview()
        assertPreviewChrome()

        for metric in ["sleep", "feeds", "diapers", "weight", "height"] {
            let element = value(metric)
            XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing Evolution value for \(metric).")
            bringIntoReach(element)
            XCTAssertTrue(element.isHittable, "Evolution value for \(metric) should remain reachable at XXXL.")
            let targetFrame = element.frame
            let windowFrame = app.windows.firstMatch.frame
            let cardFrame = app.descendants(matching: .any)
                .matching(identifier: "evolution-card-\(metric)").firstMatch.frame
            let viewport = unobscuredViewport(in: app.scrollViews.firstMatch)
            print("EVOLUTION_AX containment metric=\(metric) target=\(targetFrame) window=\(windowFrame) card=\(cardFrame) viewport=\(viewport) hittable=\(element.isHittable)")
            XCTAssertTrue(frameIsContained(targetFrame, in: windowFrame), "Evolution value \(metric) must be fully inside the window; target=\(targetFrame), window=\(windowFrame).")
            XCTAssertTrue(frameIsContained(targetFrame, in: cardFrame), "Evolution value \(metric) must be fully inside its card; target=\(targetFrame), card=\(cardFrame).")
            XCTAssertTrue(frameIsContained(targetFrame, in: viewport), "Evolution value \(metric) must be fully above the floating controls; target=\(targetFrame), viewport=\(viewport).")
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "Evolution XXXL · \(metric) reached"
            shot.lifetime = .keepAlways
            add(shot)
        }
        attach("Evolution summary · XXXL · populated")
    }

    func testPreviewUsesNativeNavigationBarTitle() {
    launch(scenario: "evolution-design-summary", appearance: "light")
    openEvolutionPreview()
    let navigationBar = app.navigationBars.firstMatch
    XCTAssertTrue(navigationBar.waitForExistence(timeout: 5), "Evolution should use the native NavigationStack title.")
    let title = navigationBar.staticTexts["Evolución"]
    XCTAssertTrue(title.waitForExistence(timeout: 5), "The native navigation bar should expose the Evolution title as text.")
    XCTAssertEqual(title.label, "Evolución")
    attach("Evolution native navigation title")
 }

    func testIntegratedDefaultTabUsesEvolutionLabel() {
        launch(scenario: "baby-care", appearance: "light")
        let rhythmTab = app.buttons["tab-trends"]
        XCTAssertTrue(rhythmTab.waitForExistence(timeout: 8))
        XCTAssertEqual(rhythmTab.label, "Evolución")
    }

    private func openEvolutionPreview() {
        let rhythmTab = app.buttons["tab-trends"]
        XCTAssertTrue(rhythmTab.waitForExistence(timeout: 8), "The existing Ritmos tab should be available.")
        XCTAssertTrue(rhythmTab.isHittable, "The existing Ritmos tab should be reachable.")
        rhythmTab.tap()

        let preview = app.descendants(matching: .any)
            .matching(identifier: "evolution-summary-preview")
            .firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 8), "Selecting the tab should open the Evolution preview.")
    }

    private func openLiveEvolution() {
        let tab = app.buttons["tab-trends"]
        XCTAssertTrue(tab.waitForExistence(timeout: 8), "The Evolution tab should be available.")
        tab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(identifier: "evolution-summary-live")
                .firstMatch.waitForExistence(timeout: 8),
            "Selecting the tab should open the live Evolution summary."
        )
    }

    private func tapPinSwitch(_ metric: String) {
        let row = app.switches["evolution-pin-\(metric)"]
        let nativeSwitch = row.switches.firstMatch
        XCTAssertTrue(nativeSwitch.waitForExistence(timeout: 3), "Missing native switch control for \(metric).")
        nativeSwitch.tap()
    }

    private func assertPreviewChrome() {
        XCTAssertEqual(app.buttons["tab-trends"].label, "Evolución")
        let navigationBar = app.navigationBars.firstMatch
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5), "The preview should show its native NavigationStack title.")
        let nativeTitle = navigationBar.staticTexts["Evolución"]
        XCTAssertTrue(nativeTitle.waitForExistence(timeout: 5), "The native navigation bar should expose the Evolution title as text.")
        XCTAssertEqual(nativeTitle.label, "Evolución")
        XCTAssertEqual(app.staticTexts["evolution-preview-notice"].label, "Vista previa · Datos de ejemplo")

        let edit = app.buttons["evolution-edit"]
        XCTAssertTrue(edit.exists, "The preview should explain where editing would normally happen.")
        XCTAssertFalse(edit.isEnabled, "Editing must remain disabled in the preview.")

        for metric in ["sleep", "feeds", "diapers", "weight", "height"] {
            let cardID = "evolution-card-\(metric)"
            XCTAssertTrue(
                app.descendants(matching: .any).matching(identifier: cardID).firstMatch.exists,
                "The read-only catalog should include the \(metric) card."
            )
            XCTAssertFalse(app.buttons[cardID].exists, "Preview cards must not open detail flows.")
        }
    }

    private func value(_ metric: String) -> XCUIElement {
        app.staticTexts["evolution-value-\(metric)"]
    }

    private func coverage(_ metric: String) -> XCUIElement {
        app.staticTexts["evolution-coverage-\(metric)"]
    }

    private func countSaturatedPixels(
    in points: CGRect,
    image: UIImage,
    windowFrame: CGRect
 ) throws -> (count: Int, pixelRect: CGRect, crop: UIImage?) {
    XCTAssertEqual(image.imageOrientation, .up, "Screenshot pixel coordinates require an upright image.")
    let source = try XCTUnwrap(image.cgImage)
    let scaleX = CGFloat(source.width) / windowFrame.width
    let scaleY = CGFloat(source.height) / windowFrame.height
    let rect = CGRect(
        x: floor((points.minX - windowFrame.minX) * scaleX),
        y: floor((points.minY - windowFrame.minY) * scaleY),
        width: ceil(points.width * scaleX),
        height: ceil(points.height * scaleY)
    ).integral
    let bounds = CGRect(x: 0, y: 0, width: source.width, height: source.height)
    guard rect.width > 0, rect.height > 0, bounds.contains(rect) else {
        XCTFail("Chart pixel crop is outside the screenshot: \(rect), screenshot \(bounds).")
        return (0, rect, nil)
    }

    let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
    var pixels = [UInt8](repeating: 0, count: source.width * source.height * 4)
    let context = try XCTUnwrap(CGContext(
        data: &pixels,
        width: source.width,
        height: source.height,
        bitsPerComponent: 8,
        bytesPerRow: source.width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.draw(source, in: bounds)

    var count = 0
    for y in Int(rect.minY)..<Int(rect.maxY) {
        for x in Int(rect.minX)..<Int(rect.maxX) {
            let offset = (y * source.width + x) * 4
            let red = Int(pixels[offset])
            let green = Int(pixels[offset + 1])
            let blue = Int(pixels[offset + 2])
            if max(red, green, blue) - min(red, green, blue) > 55,
               max(red, green, blue) > 100 {
                count += 1
            }
        }
    }
    let crop = source.cropping(to: rect).map { UIImage(cgImage: $0, scale: image.scale, orientation: .up) }
    return (count, rect, crop)
 }

 private func frameIsContained(_ target: CGRect, in container: CGRect, tolerance: CGFloat = 1) -> Bool {
    !target.isNull && !container.isNull &&
        target.minX >= container.minX - tolerance &&
        target.minY >= container.minY - tolerance &&
        target.maxX <= container.maxX + tolerance &&
        target.maxY <= container.maxY + tolerance
 }

 private func unobscuredViewport(in scrollView: XCUIElement) -> CGRect {
    let windowFrame = app.windows.firstMatch.frame
    let scrollFrame = scrollView.frame.intersection(windowFrame)
    guard !scrollFrame.isNull, scrollFrame.width > 0, scrollFrame.height > 0 else { return .null }

    var viewport = scrollFrame.insetBy(dx: 8, dy: 12)
    let navigationBar = app.navigationBars.firstMatch
    if navigationBar.exists {
        let visibleTop = max(viewport.minY, navigationBar.frame.maxY + 8)
        viewport = CGRect(
            x: viewport.minX,
            y: visibleTop,
            width: viewport.width,
            height: max(0, viewport.maxY - visibleTop)
        )
    }
    let tabBar = app.descendants(matching: .any)
        .matching(identifier: "floating-navigation-tabbar").firstMatch
    let registration = app.buttons["registration-action-button"]
    let blockers = [tabBar, registration].filter { $0.exists }
    if let blockerTop = blockers.map(\.frame.minY).min() {
        let visibleBottom = min(viewport.maxY, blockerTop - 12)
        viewport.size.height = max(0, visibleBottom - viewport.minY)
    }
    return viewport
 }

 private func bringCardIntoSafeViewport(_ card: XCUIElement, in scrollView: XCUIElement) {
    let windowFrame = app.windows.firstMatch.frame
    let metric = card.identifier.replacingOccurrences(of: "evolution-card-", with: "")

    for attempt in 0..<12 {
        let viewport = unobscuredViewport(in: scrollView)
        let before = card.frame
        let reachable = card.isHittable &&
            frameIsContained(before, in: windowFrame) &&
            frameIsContained(before, in: viewport)
        print("EVOLUTION_CHART before metric=\(metric) attempt=\(attempt) card=\(before) viewport=\(viewport) hittable=\(card.isHittable) reachable=\(reachable)")
        if reachable { return }
        guard viewport.height > 80, viewport.width > 40, before.height <= viewport.height else {
            XCTFail("The \(metric) card cannot fit in the unobscured viewport; card=\(before), viewport=\(viewport).")
            return
        }

        let towardLaterContent: Bool
        let overflow: CGFloat
        if before.maxY > viewport.maxY {
            towardLaterContent = true
            overflow = before.maxY - viewport.maxY
        } else if before.minY < viewport.minY {
            towardLaterContent = false
            overflow = viewport.minY - before.minY
        } else {
            XCTFail("The \(metric) card is inside the viewport but is not hittable; card=\(before), viewport=\(viewport).")
            return
        }

        let delta = min(max(overflow + 12, 32), viewport.height * 0.35)
        let startY: CGFloat
        let endY: CGFloat
        if towardLaterContent {
            startY = viewport.maxY - 16
            endY = max(viewport.minY + 16, startY - delta)
        } else {
            startY = viewport.minY + 16
            endY = min(viewport.maxY - 16, startY + delta)
        }
        func coordinate(at y: CGFloat) -> XCUICoordinate {
            let point = CGPoint(x: viewport.midX, y: y)
            return scrollView.coordinate(withNormalizedOffset: CGVector(
                dx: (point.x - scrollView.frame.minX) / scrollView.frame.width,
                dy: (point.y - scrollView.frame.minY) / scrollView.frame.height
            ))
        }
        coordinate(at: startY).press(
            forDuration: 0.15,
            thenDragTo: coordinate(at: endY),
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )
        let after = waitForSettledFrame(of: card)
        print("EVOLUTION_CHART after metric=\(metric) attempt=\(attempt) direction=\(towardLaterContent ? "later" : "earlier") drag=\(startY)->\(endY) card=\(after) viewport=\(unobscuredViewport(in: scrollView)) hittable=\(card.isHittable)")
        if abs(after.minY - before.minY) < 0.5 && abs(after.maxY - before.maxY) < 0.5 {
            XCTFail("Scrolling made no progress bringing \(metric) fully above floating controls; card=\(after), viewport=\(unobscuredViewport(in: scrollView)).")
            return
        }
    }

    let finalFrame = card.frame
    let finalViewport = unobscuredViewport(in: scrollView)
    XCTFail("The \(metric) card did not become fully visible above floating controls; card=\(finalFrame), viewport=\(finalViewport), hittable=\(card.isHittable).")
 }

 private func bringIntoReach(_ element: XCUIElement) {
    let scrollView = app.scrollViews.firstMatch
    guard scrollView.exists else {
        print("EVOLUTION_AX no-scroll target=\(element.identifier) frame=\(element.frame) hittable=\(element.isHittable)")
        return
    }
    let windowFrame = app.windows.firstMatch.frame
    let metric = element.identifier.replacingOccurrences(of: "evolution-value-", with: "")
    let card = app.descendants(matching: .any)
        .matching(identifier: "evolution-card-\(metric)").firstMatch

    for attempt in 0..<12 {
        let viewport = unobscuredViewport(in: scrollView)
        let before = element.frame
        let cardFrame = card.frame
        let reachable = element.isHittable &&
            frameIsContained(before, in: windowFrame) &&
            frameIsContained(before, in: cardFrame) &&
            frameIsContained(before, in: viewport)
        print("EVOLUTION_AX before metric=\(metric) attempt=\(attempt) target=\(before) hittable=\(element.isHittable) reachable=\(reachable) scroll=\(scrollView.frame) viewport=\(viewport) dock=\(app.descendants(matching: .any).matching(identifier: "floating-navigation-tabbar").firstMatch.frame) card=\(cardFrame) window=\(windowFrame)")
        if reachable { return }
        guard viewport.height > 80, viewport.width > 40, scrollView.frame.height > 0 else {
            print("EVOLUTION_AX unusable-viewport metric=\(metric) attempt=\(attempt)")
            break
        }

        let towardLaterContent: Bool
        let overflow: CGFloat
        if before.maxY > viewport.maxY {
            towardLaterContent = true
            overflow = before.maxY - viewport.maxY
        } else if before.minY < viewport.minY {
            towardLaterContent = false
            overflow = viewport.minY - before.minY
        } else {
            print("EVOLUTION_AX target-in-visible-rect-but-not-reachable metric=\(metric) target=\(before) viewport=\(viewport) inWindow=\(frameIsContained(before, in: windowFrame)) inCard=\(frameIsContained(before, in: cardFrame)) hittable=\(element.isHittable)")
            break
        }

        let delta = min(max(overflow + 12, 32), viewport.height * 0.35)
        let startY: CGFloat
        let endY: CGFloat
        if towardLaterContent {
            startY = viewport.maxY - 16
            endY = max(viewport.minY + 16, startY - delta)
        } else {
            startY = viewport.minY + 16
            endY = min(viewport.maxY - 16, startY + delta)
        }
        func coordinate(at y: CGFloat) -> XCUICoordinate {
            let point = CGPoint(x: viewport.midX, y: y)
            return scrollView.coordinate(withNormalizedOffset: CGVector(
                dx: (point.x - scrollView.frame.minX) / scrollView.frame.width,
                dy: (point.y - scrollView.frame.minY) / scrollView.frame.height
            ))
        }
        coordinate(at: startY).press(
            forDuration: 0.15,
            thenDragTo: coordinate(at: endY),
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )
        let after = waitForSettledFrame(of: element)
        let afterViewport = unobscuredViewport(in: scrollView)
        let afterCard = card.frame
        let afterReachable = element.isHittable &&
            frameIsContained(after, in: windowFrame) &&
            frameIsContained(after, in: afterCard) &&
            frameIsContained(after, in: afterViewport)
        print("EVOLUTION_AX after metric=\(metric) attempt=\(attempt) direction=\(towardLaterContent ? "later" : "earlier") drag=\(startY)->\(endY) target=\(after) hittable=\(element.isHittable) reachable=\(afterReachable) card=\(afterCard) viewport=\(afterViewport)")
        if !afterReachable && abs(after.minY - before.minY) < 0.5 && abs(after.maxY - before.maxY) < 0.5 {
            print("EVOLUTION_AX no-progress metric=\(metric) attempt=\(attempt)")
            break
        }
    }
 }

 private func waitForSettledFrame(of element: XCUIElement) -> CGRect {
    var previous = element.frame
    var stableSamples = 0
    for _ in 0..<8 {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        let current = element.frame
        if abs(current.minX - previous.minX) < 0.5 &&
            abs(current.minY - previous.minY) < 0.5 &&
            abs(current.width - previous.width) < 0.5 &&
            abs(current.height - previous.height) < 0.5 {
            stableSamples += 1
            if stableSamples >= 2 { return current }
        } else {
            stableSamples = 0
        }
        previous = current
    }
    return previous
 }

    private func launch(scenario: String, appearance: String, contentSize: String? = nil, runID: String = UUID().uuidString, caregiverID: String? = nil) {
        app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["NIDO_UI_TEST_APPEARANCE"] = appearance
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = runID
        if let caregiverID {
            app.launchEnvironment["NIDO_UI_TEST_CAREGIVER_ID"] = caregiverID
        }
        if let contentSize {
            app.launchEnvironment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"] = contentSize
        }
        app.launchArguments = [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", scenario,
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["tab-trends"].waitForExistence(timeout: 10))
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
