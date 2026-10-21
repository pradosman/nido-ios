import XCTest
import Vision
import UIKit

@MainActor
final class SleepEvolutionDetailUITests: XCTestCase {
    private var app: XCUIApplication!

    func testSleepCardOpensNativeSleepDetail() {
        openSleepDetail()
        XCTAssertEqual(app.navigationBars.firstMatch.staticTexts["Sueño"].label, "Sueño")
        XCTAssertTrue(rangeButton("week").exists)
        XCTAssertEqual(element("sleep-evolution-summary-value").label, "12 h 30 min")
        XCTAssertEqual(element("sleep-evolution-summary-label").label, "Promedio diario")
        XCTAssertEqual(element("sleep-evolution-coverage").label, "1 de 1 día terminado con registros")
        attach("Evolution sleep detail · initial week")
    }

    func testAllFiveRangesUpdateThePeriodSummaryTogether() {
        openSleepDetail()
        let summary = element("sleep-evolution-summary-value")
        let summaryLabel = element("sleep-evolution-summary-label")
        let coverage = element("sleep-evolution-coverage")
        let period = element("sleep-evolution-period")

        XCTAssertTrue(summary.exists)
        XCTAssertTrue(summaryLabel.exists)
        XCTAssertTrue(coverage.exists)
        var priorPeriod = period.label
        for range in ["day", "week", "month", "sixMonths", "year"] {
            let option = rangeButton(range)
            XCTAssertTrue(option.waitForExistence(timeout: 5), "Missing (range) sleep range.")
            option.tap()
            XCTAssertTrue(option.isSelected, "The (range) range should be selected after tapping it.")
            XCTAssertFalse(period.label.isEmpty)
            XCTAssertFalse(summary.label.isEmpty)
            XCTAssertFalse(summaryLabel.label.isEmpty)
            XCTAssertFalse(coverage.label.isEmpty)
            XCTAssertNotEqual(period.label, priorPeriod)
            if range == "day" {
                XCTAssertEqual(summary.label, "6 h")
                XCTAssertEqual(summaryLabel.label, "Total registrado")
                XCTAssertTrue(element("sleep-evolution-active-sleep").exists)
                attach("Evolution sleep detail · day active")
            }
            if range == "week" {
                XCTAssertEqual(summary.label, "12 h 30 min")
                XCTAssertEqual(coverage.label, "1 de 1 día terminado con registros")
            }
            if range == "month" || range == "sixMonths" || range == "year" {
                XCTAssertEqual(summary.label, "12 h 45 min")
                let denominator = range == "month" ? 19 : (range == "sixMonths" ? 111 : 292)
                XCTAssertEqual(coverage.label, "7 de \(denominator) días terminados con registros")
            }
            priorPeriod = period.label
        }
        let currentPeriod = period.label
        app.buttons["sleep-evolution-previous"].tap()
        XCTAssertNotEqual(period.label, currentPeriod)
        app.buttons["sleep-evolution-current"].tap()
        XCTAssertEqual(period.label, currentPeriod)
        XCTAssertFalse(app.buttons["sleep-evolution-next"].isEnabled)
        attach("Evolution sleep detail · all ranges")
    }

    func testChartSelectionShowsBucketAndResetRestoresPeriodSummary() {
        openSleepDetail()
        let summary = element("sleep-evolution-summary-value")
        let summaryLabel = element("sleep-evolution-summary-label")
        let coverage = element("sleep-evolution-coverage")
        let initialSummary = summary.label
        let initialSummaryLabel = summaryLabel.label
        let initialCoverage = coverage.label
        XCTAssertTrue(element("sleep-evolution-chart").waitForExistence(timeout: 5))
        app.buttons["sleep-evolution-explore-values"].tap()
        let weekBuckets = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "sleep-evolution-bucket-")
        )
        let recordedWeekBucket = weekBuckets.matching(NSPredicate(format: "label CONTAINS %@", " h ")).firstMatch
        XCTAssertTrue(recordedWeekBucket.waitForExistence(timeout: 5))
        let weekBucketElements = weekBuckets.allElementsBoundByIndex
        let recordedWeekBucketIndex = weekBucketElements.firstIndex { $0.identifier == recordedWeekBucket.identifier }
        XCTAssertNotNil(recordedWeekBucketIndex)
        recordedWeekBucket.tap()
        XCTAssertEqual(summary.label, initialSummary, "A selected bucket may equal the weekly mean when only one day has records.")
        XCTAssertEqual(summaryLabel.label, "Total registrado")
        XCTAssertTrue(
            element("sleep-evolution-selected-interval").waitForExistence(timeout: 3),
            "Selecting a bucket should expose its date or interval."
        )
        let reset = app.buttons["sleep-evolution-chart-reset"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        reset.tap()
        XCTAssertEqual(summary.label, initialSummary)
        XCTAssertEqual(summaryLabel.label, initialSummaryLabel)
        XCTAssertEqual(coverage.label, initialCoverage)

        let chart = element("sleep-evolution-chart")
        let bucketCenterX = 0.14 + (CGFloat(recordedWeekBucketIndex!) + 0.5) * 0.80 / CGFloat(weekBucketElements.count)
        let plotStart = chart.coordinate(withNormalizedOffset: CGVector(dx: bucketCenterX, dy: 0.60))
        let plotEnd = chart.coordinate(withNormalizedOffset: CGVector(dx: bucketCenterX + 0.015, dy: 0.60))
        plotStart.press(forDuration: 0.3, thenDragTo: plotEnd)
        XCTAssertTrue(
            reset.waitForExistence(timeout: 5),
            "Pressing and dragging across the chart should select a bucket."
        )
        XCTAssertTrue(element("sleep-evolution-selected-interval").exists)
        reset.tap()

        rangeButton("month").tap()
        let recordsLink = app.buttons["sleep-evolution-records-link"]
        let periodRecordCountLabel = recordsLink.label
        app.buttons["sleep-evolution-explore-values"].tap()
        let buckets = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "sleep-evolution-bucket-")
        )
        XCTAssertGreaterThan(buckets.count, 0, "The populated chart should expose selectable period buckets.")
        let recordedBucket = buckets.matching(NSPredicate(format: "label CONTAINS %@", " h ")).firstMatch
        XCTAssertTrue(recordedBucket.waitForExistence(timeout: 5))
        recordedBucket.tap()
        XCTAssertTrue(element("sleep-evolution-selected-interval").waitForExistence(timeout: 3))
        XCTAssertEqual(recordsLink.label, periodRecordCountLabel, "Chart selection should keep the all-records count for the full period.")
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        reset.tap()
        attach("Evolution sleep detail · selected bucket and reset")
    }

    func testDailyChartShowsReadableHourlyAxisWithoutDroppingBuckets() throws {
        openSleepDetail()
        rangeButton("day").tap()

        let chart = element("sleep-evolution-chart")
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
        let screenshot = app.screenshot().image
        let sourceImage = try XCTUnwrap(screenshot.cgImage)
        let window = app.windows.firstMatch.frame
        let chartFrame = chart.frame
        let pixelsPerPoint = CGFloat(sourceImage.width) / window.width
        let axisBand = CGRect(
            x: (chartFrame.minX - window.minX) * pixelsPerPoint,
            y: (chartFrame.maxY - 52 - window.minY) * pixelsPerPoint,
            width: chartFrame.width * pixelsPerPoint,
            height: 52 * pixelsPerPoint
        ).integral.intersection(CGRect(x: 0, y: 0, width: sourceImage.width, height: sourceImage.height))
        let axisCrop = try XCTUnwrap(sourceImage.cropping(to: axisBand))
        let cropAttachment = XCTAttachment(image: UIImage(cgImage: axisCrop))
        cropAttachment.name = "Sleep daily chart · hourly axis crop"
        cropAttachment.lifetime = .keepAlways
        add(cropAttachment)

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["es-ES"]
        try VNImageRequestHandler(cgImage: axisCrop).perform([request])
        let recognizedText = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        let hourlyLabels = recognizedText
            .flatMap { $0.split(whereSeparator: \.isWhitespace).map(String.init) }
            .filter { $0.range(of: #"^([01]\d|2[0-3])$"#, options: .regularExpression) != nil }

        XCTAssertTrue((1...6).contains(hourlyLabels.count), "The daily axis should show one to six hourly labels. OCR: \(recognizedText)")
        XCTAssertTrue(hourlyLabels.contains("00"), "The first hour should be fully visible as 00. OCR: \(recognizedText)")

        app.buttons["sleep-evolution-explore-values"].tap()
        let buckets = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "sleep-evolution-bucket-")
        )
        var bucketIdentifiers = Set(buckets.allElementsBoundByIndex.map(\.identifier))
        var stagnantSwipes = 0
        for _ in 0..<8 where bucketIdentifiers.count < 24 && stagnantSwipes < 2 {
            guard buckets.count > 0 else { break }
            let middleBucket = buckets.element(boundBy: buckets.count / 2)
            let beforeCount = bucketIdentifiers.count
            middleBucket.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).press(
                forDuration: 0.1,
                thenDragTo: middleBucket.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            )
            bucketIdentifiers.formUnion(buckets.allElementsBoundByIndex.map(\.identifier))
            stagnantSwipes = bucketIdentifiers.count == beforeCount ? stagnantSwipes + 1 : 0
        }
        XCTAssertEqual(bucketIdentifiers.count, 24, "Reducing axis labels must preserve all 24 hourly buckets.")
    }

    func testRecordsRouteReturnsToTheSameSelectedRange() {
        openSleepDetail()
        rangeButton("month").tap()
        let recordsLink = app.buttons["sleep-evolution-records-link"]
        XCTAssertTrue(recordsLink.waitForExistence(timeout: 5))
        recordsLink.tap()

        let records = element("sleep-evolution-records")
        XCTAssertTrue(records.waitForExistence(timeout: 5), "The records action should open the sleep records list.")
        XCTAssertEqual(app.navigationBars.firstMatch.staticTexts["Registros de sueño"].label, "Registros de sueño")
        XCTAssertGreaterThan(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "sleep-evolution-record-")).count,
            0,
            "The records list should show its recorded entries."
        )

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element("sleep-evolution-detail").waitForExistence(timeout: 5))
        XCTAssertTrue(rangeButton("month").isSelected, "Returning from records should retain the selected range.")
        attach("Evolution sleep detail · records and return")
    }

    func testCurrentWeekRecordsIncludeTodayEvenWhenMeanExcludesToday() {
        openSleepDetail()
        XCTAssertEqual(element("sleep-evolution-summary-value").label, "12 h 30 min")
        XCTAssertEqual(element("sleep-evolution-coverage").label, "1 de 1 día terminado con registros")
        app.buttons["sleep-evolution-records-link"].tap()

        let todayRecord = element("sleep-evolution-record-evolution-preview-sleep-today-completed")
        XCTAssertTrue(
            todayRecord.waitForExistence(timeout: 5),
            "The current-week records list should include today's completed sleep even though today is excluded from the mean."
        )
    }

    func testOldestPeriodRecordCanScrollFullyAboveFloatingDock() {
        openSleepDetail()
        rangeButton("month").tap()
        app.buttons["sleep-evolution-records-link"].tap()

        let rows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "sleep-evolution-record-")
        )
        XCTAssertGreaterThan(rows.count, 0)
        let oldest = rows.element(boundBy: rows.count - 1)
        let top = app.navigationBars.firstMatch.frame.maxY + 8
        let dock = app.floatingNavigationTabBars.firstMatch
        XCTAssertTrue(dock.waitForExistence(timeout: 5))
        let bottom = dock.frame.minY - 8

        for _ in 0..<8 where oldest.frame.maxY > bottom {
            app.swipeUp()
        }
        XCTAssertTrue(oldest.isHittable)
        XCTAssertGreaterThanOrEqual(oldest.frame.minY, top)
        XCTAssertLessThanOrEqual(oldest.frame.maxY, bottom)
        attach("Evolution sleep detail · oldest record above floating dock")
    }

    func testEmptySleepDetailDoesNotPresentZeroAsRecordedSleep() {
        openSleepDetail(scenario: "evolution-design-sleep-empty")
        let value = element("sleep-evolution-summary-value")
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        XCTAssertEqual(value.label, "Sin datos")
        let chart = element("sleep-evolution-chart")
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", "No hay registros de sueño en este periodo."))
                .firstMatch.exists,
            "The empty chart should explain that this period has no saved sleep records."
        )
        XCTAssertFalse(app.buttons["sleep-evolution-explore-values"].exists)
        XCTAssertFalse(
            ["0 h", "0 min", "0 horas", "0 minutos"].contains(value.label),
            "Missing sleep records must stay distinct from a zero-hour total."
        )
        attach("Evolution sleep detail · empty")
    }

    func testSleepDetailRemainsReachableAtAccessibilityXXXL() {
        openSleepDetail(contentSize: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge")
        let scroll = app.scrollViews.firstMatch
        let safeTop = app.navigationBars.firstMatch.frame.maxY + 8
        XCTAssertTrue(app.floatingNavigationOverlay.waitForExistence(timeout: 5))
        let dock = app.floatingNavigationTabBars.firstMatch
        XCTAssertTrue(dock.waitForExistence(timeout: 5))
        let safeBottom = dock.frame.minY - 8
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        for identifier in [
            "sleep-evolution-summary-value",
            "sleep-evolution-summary-label",
            "sleep-evolution-range-week",
            "sleep-evolution-period"
        ] {
            let target = element(identifier)
            XCTAssertTrue(target.waitForExistence(timeout: 5), "Missing (identifier) at XXXL.")
            for _ in 0..<8 where target.frame.maxY > safeBottom {
                scroll.swipeUp()
            }
            for _ in 0..<8 where target.frame.minY < safeTop {
                scroll.swipeDown()
            }
            XCTAssertTrue(target.isHittable, "(identifier) should remain reachable at XXXL after scrolling.")
            XCTAssertGreaterThanOrEqual(target.frame.minY, safeTop, "(identifier) should fit below the navigation bar.")
            XCTAssertLessThanOrEqual(target.frame.maxY, safeBottom, "(identifier) should remain above the floating dock.")
        }
        attach("Evolution sleep detail · XXXL")
    }

    func testSleepDetailUsesNativeNavigationAndChartInDarkAppearance() {
        openSleepDetail(appearance: "dark")
        XCTAssertEqual(app.navigationBars.firstMatch.staticTexts["Sueño"].label, "Sueño")
        XCTAssertTrue(element("sleep-evolution-chart").exists)
        XCTAssertTrue(element("sleep-evolution-summary-value").exists)
        attach("Evolution sleep detail · dark")
    }

    private func openSleepDetail(
        scenario: String = "evolution-design-sleep",
        appearance: String = "light",
        contentSize: String? = nil
    ) {
        launch(scenario: scenario, appearance: appearance, contentSize: contentSize)
        if scenario == "evolution-design-sleep-empty" {
            app.buttons["tab-trends"].tap()
            XCTAssertTrue(element("sleep-evolution-detail").waitForExistence(timeout: 8))
            return
        }
        app.buttons["tab-trends"].tap()
        let sleepCard = app.buttons["evolution-sleep-card"]
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 8), "The sleep summary card should open the dedicated sleep detail.")
        sleepCard.tap()
        XCTAssertTrue(element("sleep-evolution-detail").waitForExistence(timeout: 8))
    }

    private func rangeButton(_ range: String) -> XCUIElement {
        app.buttons["sleep-evolution-range-\(range)"]
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func contains(_ target: CGRect, _ container: CGRect, tolerance: CGFloat = 1) -> Bool {
        !target.isNull && !container.isNull &&
            target.minX >= container.minX - tolerance &&
            target.minY >= container.minY - tolerance &&
            target.maxX <= container.maxX + tolerance &&
            target.maxY <= container.maxY + tolerance
    }

    private func launch(scenario: String, appearance: String = "light", contentSize: String? = nil) {
        app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["NIDO_UI_TEST_APPEARANCE"] = appearance
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
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
