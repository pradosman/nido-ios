import XCTest
import Vision

@MainActor
final class NidoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testOnboardingShowsOnlyTheInformationNeededToCreateAHome() {
        launch(scenario: "onboarding")

        XCTAssertTrue(app.staticTexts["El día a día de vuestro bebé."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Registra sueño, tomas, pañales y cuidados. Compartid la misma información entre familiares."].exists)
        XCTAssertTrue(app.textFields["Tu nombre"].exists)
        XCTAssertTrue(app.textFields["Nombre del bebé"].exists)
        XCTAssertTrue(app.buttons["Crear espacio"].exists)
        XCTAssertFalse(app.buttons["Crear espacio"].isEnabled)

        app.buttons["Tengo un código de invitación"].tap()
        XCTAssertTrue(app.staticTexts["Introduce el código que te ha enviado el administrador del hogar o un familiar."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Crear un espacio familiar"].exists)
    }

    func testSettingsUsesFamilyTerminologyAndAdministratorPolicy() {
        launch(scenario: "caregiver-removal")

        app.floatingNavigationTabButtons["Ajustes"].tap()
        XCTAssertTrue(app.staticTexts["Familiares"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Invitar familiar"].exists)
        XCTAssertTrue(app.staticTexts["Administrador del hogar"].exists)
        XCTAssertTrue(app.staticTexts["Familiar"].exists)
        XCTAssertTrue(app.staticTexts["Solo el administrador del hogar puede gestionar familiares y editar el perfil. Los familiares comparten el mismo historial."].exists)
    }

    func testRegistrationMenuShowsTheDiaperActionForVisualGlyphReview() throws {
        let fixtureURL = try XCTUnwrap(
            Bundle(for: type(of: self)).url(forResource: "registration-menu-ocr-fixture", withExtension: "png")
        )
        let fixtureData = try Data(contentsOf: fixtureURL)
        let fixtureImage = try XCTUnwrap(UIImage(data: fixtureData, scale: 3))
        let fixtureAppFrame = CGRect(origin: .zero, size: fixtureImage.size)
        let fixtureDiaperRow = CGRect(x: 132, y: 746, width: 250, height: 42)
        let fixtureIconColumnMaxX: CGFloat = 182
        let fixtureRegion = menuTextRegion(
            rowFrame: fixtureDiaperRow,
            iconColumnMaxX: fixtureIconColumnMaxX,
            appFrame: fixtureAppFrame
        )
        let fixtureLines = try recognizedMenuLines(in: fixtureImage, regionOfInterest: fixtureRegion)
        let fixtureDiaper = fixtureLines.first { normalizedMenuText($0.text) == "panal" }
        XCTAssertNotNil(
            fixtureDiaper,
            "The captured Pañal text region, to the right of its glyph column, should be recognized."
        )
        let fixtureLabelBox = try XCTUnwrap(fixtureDiaper).box
        let fixtureLabelFrame = CGRect(
            x: fixtureAppFrame.minX + fixtureLabelBox.minX * fixtureAppFrame.width,
            y: fixtureAppFrame.minY + (1 - fixtureLabelBox.maxY) * fixtureAppFrame.height,
            width: fixtureLabelBox.width * fixtureAppFrame.width,
            height: fixtureLabelBox.height * fixtureAppFrame.height
        )
        XCTAssertGreaterThanOrEqual(
            fixtureLabelFrame.minX,
            fixtureIconColumnMaxX + 2,
            "The fixture OCR box should begin beyond the glyph column, allowing two points of tolerance."
        )
        XCTAssertGreaterThanOrEqual(fixtureLabelFrame.minY, fixtureDiaperRow.minY - 2)
        XCTAssertLessThanOrEqual(fixtureLabelFrame.maxY, fixtureDiaperRow.maxY + 2)
        XCTAssertLessThanOrEqual(fixtureLabelFrame.maxX, fixtureDiaperRow.maxX + 2)

        launch(scenario: "today", appearance: "light")
        assertRenderedAppearance(.light)

        let registration = app.buttons["registration-action-button"]
        XCTAssertTrue(registration.waitForExistence(timeout: 5))
        registration.tap()

        let diaperRow = app.buttons["Registrar pañal"]
        let sleepRow = app.buttons["Registrar sueño"]
        let feedRow = app.buttons["Registrar toma"]
        XCTAssertTrue(diaperRow.waitForExistence(timeout: 3))
        XCTAssertTrue(sleepRow.waitForExistence(timeout: 3))
        XCTAssertTrue(feedRow.waitForExistence(timeout: 3))
        let sleepIcon = sleepRow.images.firstMatch
        let feedIcon = feedRow.images.firstMatch
        XCTAssertTrue(sleepIcon.waitForExistence(timeout: 3), "The Sueño row should expose its image glyph.")
        XCTAssertTrue(feedIcon.waitForExistence(timeout: 3), "The Toma row should expose its image glyph.")

        let commonIconColumn = sleepIcon.frame.union(feedIcon.frame)
        let appFrame = app.frame
        let sleepRegion = menuTextRegion(
            rowFrame: sleepRow.frame,
            iconColumnMaxX: commonIconColumn.maxX,
            appFrame: appFrame
        )
        let feedRegion = menuTextRegion(
            rowFrame: feedRow.frame,
            iconColumnMaxX: commonIconColumn.maxX,
            appFrame: appFrame
        )
        let diaperRegion = menuTextRegion(
            rowFrame: diaperRow.frame,
            iconColumnMaxX: commonIconColumn.maxX,
            appFrame: appFrame
        )
        let deadline = Date().addingTimeInterval(5)
        var screenshotImage = app.screenshot().image
        var sleepLines: [(text: String, box: CGRect)] = []
        var feedLines: [(text: String, box: CGRect)] = []
        var diaperLines: [(text: String, box: CGRect)] = []
        while Date() < deadline {
            screenshotImage = app.screenshot().image
            sleepLines = try recognizedMenuLines(in: screenshotImage, regionOfInterest: sleepRegion)
            feedLines = try recognizedMenuLines(in: screenshotImage, regionOfInterest: feedRegion)
            diaperLines = try recognizedMenuLines(in: screenshotImage, regionOfInterest: diaperRegion)
            if diaperLines.contains(where: { normalizedMenuText($0.text) == "panal" }) { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }

        let screenshot = XCTAttachment(image: screenshotImage)
        screenshot.name = "Today registration menu with diaper glyph"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Registration menu accessibility hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)

        let diaper = diaperLines.first { normalizedMenuText($0.text) == "panal" }
        XCTAssertNotNil(diaper, "The open registration menu should visibly render the Pañal action.")
        let sleep = sleepLines.first { normalizedMenuText($0.text) == "sueno" }
        let feed = feedLines.first { normalizedMenuText($0.text) == "toma" }
        XCTAssertNotNil(sleep, "The menu screenshot should contain the Sueño reference row.")
        XCTAssertNotNil(feed, "The menu screenshot should contain the Toma reference row.")
        let diaperLabel = try XCTUnwrap(diaper)
        let rows = [sleepRow.frame, feedRow.frame, diaperRow.frame].sorted { $0.minY < $1.minY }
        for pair in zip(rows, rows.dropFirst()) {
            XCTAssertLessThanOrEqual(pair.0.maxY, pair.1.minY, "Menu actions should occupy distinct, non-overlapping rows.")
        }

        let glyphHeight = max(sleepIcon.frame.height, feedIcon.frame.height)
        XCTAssertGreaterThan(glyphHeight, 0)
        XCTAssertGreaterThan(commonIconColumn.width, 0)

        let diaperOCRLabelLeft = appFrame.minX + diaperLabel.box.minX * appFrame.width
        XCTAssertLessThanOrEqual(
            commonIconColumn.maxX,
            diaperOCRLabelLeft,
            "The image-based glyph column should stay left of the OCR label box."
        )

        let diaperROI = CGRect(
            x: commonIconColumn.minX,
            y: diaperRow.frame.midY - glyphHeight * 0.65,
            width: commonIconColumn.width,
            height: glyphHeight * 1.3
        )
        let sleepROI = CGRect(
            x: commonIconColumn.minX,
            y: sleepRow.frame.midY - glyphHeight * 0.65,
            width: commonIconColumn.width,
            height: glyphHeight * 1.3
        )
        let feedROI = CGRect(
            x: commonIconColumn.minX,
            y: feedRow.frame.midY - glyphHeight * 0.65,
            width: commonIconColumn.width,
            height: glyphHeight * 1.3
        )
        XCTAssertLessThanOrEqual(diaperROI.height, diaperRow.frame.height)

        let canvasMask = CGRect(
            x: commonIconColumn.midX - 8.5,
            y: diaperRow.frame.midY - 8.5,
            width: 17,
            height: 17
        )
        let diaperPixels = try glyphInk(in: screenshotImage, roi: diaperROI, appFrame: appFrame)
        let diaperWithoutCanvas = try glyphInk(
            in: screenshotImage,
            roi: diaperROI,
            appFrame: appFrame,
            excluding: canvasMask
        )
        let sleepPixels = try glyphInk(in: screenshotImage, roi: sleepROI, appFrame: appFrame)
        let feedPixels = try glyphInk(in: screenshotImage, roi: feedROI, appFrame: appFrame)
        XCTAssertGreaterThan(sleepPixels.medianLuminance, 150, "The reference glyph ROI should have a light background.")
        XCTAssertGreaterThan(feedPixels.medianLuminance, 150, "The reference glyph ROI should have a light background.")
        let referenceInk = min(sleepPixels.darkPixelCount, feedPixels.darkPixelCount)
        let threshold = max(5, referenceInk / 8)
        print(
            "NIDO_MENU_GLYPH_INK: diaperROI=\(diaperPixels.pixelRect) " +
            "referenceROIs=\(sleepROI),\(feedROI) " +
            "diaperFull=\(diaperPixels.darkPixelCount) " +
            "reference=\(referenceInk) threshold=\(threshold) " +
            "diaperOutsideCanvas=\(diaperWithoutCanvas.darkPixelCount) " +
            "medianLuminance=\(diaperPixels.medianLuminance) " +
            "canvasMask=\(canvasMask)"
        )
        XCTAssertGreaterThan(diaperPixels.medianLuminance, 150, "The local glyph ROI should have a light background.")
        XCTAssertGreaterThan(diaperPixels.darkPixelCount, threshold, "The Pañal menu row should render a glyph alongside its label.")
        XCTAssertLessThanOrEqual(
            diaperWithoutCanvas.darkPixelCount,
            threshold,
            "Removing only the image canvas must make the glyph-presence check fail."
        )
    }

    private func recognizedMenuLines(
        in image: UIImage,
        regionOfInterest: CGRect? = nil
    ) throws -> [(text: String, box: CGRect)] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["es-ES"]
        if let regionOfInterest {
            request.regionOfInterest = regionOfInterest
        }
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let imageBox: CGRect
            if let regionOfInterest {
                imageBox = CGRect(
                    x: regionOfInterest.minX + observation.boundingBox.minX * regionOfInterest.width,
                    y: regionOfInterest.minY + observation.boundingBox.minY * regionOfInterest.height,
                    width: observation.boundingBox.width * regionOfInterest.width,
                    height: observation.boundingBox.height * regionOfInterest.height
                )
            } else {
                imageBox = observation.boundingBox
            }
            return (candidate.string, imageBox)
        }
    }

    private func menuTextRegion(
        rowFrame: CGRect,
        iconColumnMaxX: CGFloat,
        appFrame: CGRect
    ) -> CGRect {
        let right = min(rowFrame.maxX, appFrame.maxX)
        let left = min(max(iconColumnMaxX + 6, appFrame.minX), right)
        let top = max(rowFrame.minY, appFrame.minY)
        let bottom = min(rowFrame.maxY, appFrame.maxY)
        return CGRect(
            x: (left - appFrame.minX) / appFrame.width,
            y: (appFrame.maxY - bottom) / appFrame.height,
            width: (right - left) / appFrame.width,
            height: (bottom - top) / appFrame.height
        )
    }

    private func normalizedMenuText(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
    }

    private func glyphInk(
        in image: UIImage,
        roi: CGRect,
        appFrame: CGRect,
        excluding excludedRect: CGRect? = nil
    ) throws -> (darkPixelCount: Int, medianLuminance: Int, pixelRect: CGRect) {
        XCTAssertEqual(image.imageOrientation, .up, "Screenshot coordinates require an upright image.")
        let source = try XCTUnwrap(image.cgImage)
        let width = source.width
        let height = source.height
        XCTAssertGreaterThan(appFrame.width, 0)
        XCTAssertGreaterThan(appFrame.height, 0)

        func pixelRect(for points: CGRect, integralBounds: Bool = true) -> CGRect {
            let scaleX = CGFloat(width) / appFrame.width
            let scaleY = CGFloat(height) / appFrame.height
            let local = CGRect(
                x: points.minX - appFrame.minX,
                y: points.minY - appFrame.minY,
                width: points.width,
                height: points.height
            )
            let x0 = integralBounds ? floor(local.minX * scaleX) : local.minX * scaleX
            let y0 = integralBounds ? floor(local.minY * scaleY) : local.minY * scaleY
            let x1 = integralBounds ? ceil(local.maxX * scaleX) : local.maxX * scaleX
            let y1 = integralBounds ? ceil(local.maxY * scaleY) : local.maxY * scaleY
            return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
        }

        let roiPixels = pixelRect(for: roi)
        XCTAssertGreaterThan(roiPixels.width, 0)
        XCTAssertGreaterThan(roiPixels.height, 0)
        XCTAssertGreaterThanOrEqual(roiPixels.minX, 0)
        XCTAssertGreaterThanOrEqual(roiPixels.minY, 0)
        XCTAssertLessThanOrEqual(roiPixels.maxX, CGFloat(width))
        XCTAssertLessThanOrEqual(roiPixels.maxY, CGFloat(height))
        guard roiPixels.width > 0,
              roiPixels.height > 0,
              roiPixels.minX >= 0,
              roiPixels.minY >= 0,
              roiPixels.maxX <= CGFloat(width),
              roiPixels.maxY <= CGFloat(height) else {
            return (0, 0, roiPixels)
        }
        let excludedPixels = excludedRect.map { pixelRect(for: $0, integralBounds: false) }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

        var darkPixelCount = 0
        var luminances: [Int] = []
        for y in Int(roiPixels.minY)..<Int(roiPixels.maxY) {
            for x in Int(roiPixels.minX)..<Int(roiPixels.maxX) {
                let offset = (y * width + x) * 4
                let luminance = (Int(pixels[offset]) * 212 + Int(pixels[offset + 1]) * 715 + Int(pixels[offset + 2]) * 72) / 999
                luminances.append(luminance)
                let pixelCenter = CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
                let isExcluded = excludedPixels?.contains(pixelCenter) ?? false
                if luminance < 100 && !isExcluded { darkPixelCount += 1 }
            }
        }
        luminances.sort()
        let medianLuminance = luminances.isEmpty ? 0 : luminances[luminances.count / 2]
        return (darkPixelCount, medianLuminance, roiPixels)
    }

    func testOwnerAccountActionsRequireDestructiveConfirmationAndSignOutReturnsToAppleIdentity() {
        launch(scenario: "caregiver-removal")

        app.floatingNavigationTabButtons["Ajustes"].tap()
        let deleteAccount = app.buttons["Eliminar mi cuenta"]
        for _ in 0..<6 where !deleteAccount.exists { app.swipeUp() }
        XCTAssertTrue(deleteAccount.waitForExistence(timeout: 3))
        deleteAccount.tap()

        XCTAssertTrue(app.staticTexts["¿Eliminar permanentemente el espacio familiar?"].waitForExistence(timeout: 3))
        let deletionMessage = app.staticTexts.matching(NSPredicate(
            format: "label == %@",
            "Se eliminarán de forma permanente el perfil, todos los registros y el acceso de todos los familiares. Esta acción no se puede deshacer."
        )).firstMatch
        XCTAssertTrue(deletionMessage.exists)
        app.buttons["Cancelar"].tap()

        let signOut = app.buttons["Cerrar sesión"]
        XCTAssertTrue(signOut.waitForExistence(timeout: 3))
        signOut.tap()
        XCTAssertTrue(app.staticTexts["El cuidado familiar, en privado."].waitForExistence(timeout: 5))
    }

    func testRestoreConfirmationOffersCancel() {
        launch(scenario: "quick-diaper-registration")

        app.floatingNavigationTabButtons["Ajustes"].tap()
        let prepareBackup = app.buttons["Preparar copia de seguridad"]
        for _ in 0..<6 where !prepareBackup.exists { app.swipeUp() }
        XCTAssertTrue(prepareBackup.waitForExistence(timeout: 5))
        prepareBackup.tap()
        app.buttons["Compartir copia completa"].tap()

        let saveToFiles = app.cells["Guardar en Archivos"]
        XCTAssertTrue(saveToFiles.waitForExistence(timeout: 5))
        saveToFiles.tap()
        let save = app.buttons["Guardar"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        let importBackup = app.buttons["Restaurar desde un archivo"]
        XCTAssertTrue(importBackup.waitForExistence(timeout: 5))
        importBackup.tap()
        let localFilesTitle = app.staticTexts["En mi iPhone"]
        if !localFilesTitle.waitForExistence(timeout: 5) {
            let browse = app.buttons.matching(NSPredicate(
                format: "label == %@ AND identifier != %@", "Explorar", "BackButton"
            )).firstMatch
            XCTAssertTrue(browse.waitForExistence(timeout: 5))
            browse.tap()
        }
        XCTAssertTrue(localFilesTitle.waitForExistence(timeout: 5))
        let backupFile = app.cells.matching(NSPredicate(format: "label BEGINSWITH 'Copia-Nido-'" )).firstMatch
        XCTAssertTrue(backupFile.waitForExistence(timeout: 5))
        backupFile.tap()

        let restore = app.buttons["Restaurar registros"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        let cancel = app.buttons["Cancelar"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3), "Restore confirmation needs a visible Cancel action")
        XCTAssertTrue(cancel.isHittable)
        cancel.tap()
        XCTAssertFalse(restore.exists)

        let pickerCancel = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"].buttons["Cancelar"]
        if pickerCancel.waitForExistence(timeout: 2) {
            pickerCancel.tap()
            let pickerDismissed = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"),
                object: pickerCancel
            )
            XCTAssertEqual(XCTWaiter.wait(for: [pickerDismissed], timeout: 5), .completed)
        }
        app.floatingNavigationTabButtons["Historia"].tap()
        XCTAssertTrue(app.staticTexts["history-detail-date"].waitForExistence(timeout: 5))
        let latestDiaper = app.buttons["history-entry-ui-test-latest-diaper"]
        bringHistoryElementIntoView(latestDiaper)
        XCTAssertTrue(latestDiaper.waitForExistence(timeout: 5))
        let olderDiaper = app.buttons["history-entry-ui-test-older-diaper"]
        if !scrollHistoryElementIntoView(olderDiaper) {
            let dayWithOlderDiaper = app.buttons.matching(NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "history-week-day-", "1 pañales"
            )).firstMatch
            XCTAssertTrue(dayWithOlderDiaper.waitForExistence(timeout: 5))
            dayWithOlderDiaper.tap()
            bringHistoryElementIntoView(olderDiaper)
        }
        XCTAssertTrue(olderDiaper.waitForExistence(timeout: 5))
    }

    func testFreshInstallationCreatesAnIndependentHouseholdAndOnlySeesItsOwnBaby() async throws {
        let baseURL = ProcessInfo.processInfo.environment["NIDO_UI_TEST_API_BASE_URL"] ?? "http://127.0.0.1:34200"
        let ownerAToken = try requiredSessionToken(named: "NIDO_UI_TEST_OWNER_A_TOKEN")
        let ownerBToken = try requiredSessionToken(named: "NIDO_UI_TEST_OWNER_B_TOKEN")
        var bootstrap = URLRequest(url: try XCTUnwrap(URL(string: baseURL + "/api/nido/caregivers/bootstrap")))
        bootstrap.httpMethod = "POST"
        bootstrap.setValue("application/json", forHTTPHeaderField: "Content-Type")
        bootstrap.setValue("Bearer \(ownerAToken)", forHTTPHeaderField: "Authorization")
        bootstrap.httpBody = Data(#"{"name":"Owner A","babyName":"Baby A","birthDate":"2026-01-01"}"#.utf8)
        let (_, bootstrapResponse) = try await URLSession.shared.data(for: bootstrap)
        XCTAssertEqual((bootstrapResponse as? HTTPURLResponse)?.statusCode, 201)
        var profile = URLRequest(url: try XCTUnwrap(URL(string: baseURL + "/api/nido/profile")))
        profile.httpMethod = "PUT"
        profile.setValue("application/json", forHTTPHeaderField: "Content-Type")
        profile.setValue("Bearer \(ownerAToken)", forHTTPHeaderField: "Authorization")
        profile.httpBody = Data(#"{"caregiverName":"Owner A","babyName":"Baby A","birthDate":"2026-01-01"}"#.utf8)
        let (_, profileResponse) = try await URLSession.shared.data(for: profile)
        XCTAssertEqual((profileResponse as? HTTPURLResponse)?.statusCode, 200)

        launch(scenario: "multi-household", accessToken: ownerBToken)

        XCTAssertTrue(app.staticTexts["El día a día de vuestro bebé."].waitForExistence(timeout: 5))
        app.textFields["Tu nombre"].tap()
        app.textFields["Tu nombre"].typeText("Owner B")
        app.textFields["Nombre del bebé"].tap()
        app.textFields["Nombre del bebé"].typeText("Baby B")
        app.buttons["Crear espacio"].tap()

        XCTAssertTrue(app.staticTexts["Hoy con Baby B"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Baby A"].exists)
        let registrationButton = app.buttons["registration-action-button"]
        XCTAssertTrue(registrationButton.waitForExistence(timeout: 3))
        XCTAssertTrue(registrationButton.isHittable)
        registrationButton.tap()
        let diaperMenuRow = app.buttons["Registrar pañal"]
        XCTAssertTrue(diaperMenuRow.waitForExistence(timeout: 3))
        XCTAssertTrue(diaperMenuRow.isHittable)
        let menuOptions = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Registrar '"))
        let menuStateBeforeTap = menuOptions.allElementsBoundByIndex.map {
            "label=\($0.label), id=\($0.identifier), frame=\($0.frame), hittable=\($0.isHittable)"
        }.joined(separator: "\n")
        let menuScreenshot = XCTAttachment(screenshot: app.screenshot())
        menuScreenshot.name = "Fresh installation · menu before diaper selection"
        menuScreenshot.lifetime = .keepAlways
        add(menuScreenshot)
        let menuDiagnostics = XCTAttachment(string: "Registration action frame=\(registrationButton.frame), hittable=\(registrationButton.isHittable)\nMenu rows:\n\(menuStateBeforeTap)")
        menuDiagnostics.name = "Fresh installation · menu row accessibility before selection"
        menuDiagnostics.lifetime = .keepAlways
        add(menuDiagnostics)
        diaperMenuRow.tap()
        let quickDiaper = app.buttons["Registrar pañal · Pis"]
        let quickDiaperAppeared = quickDiaper.waitForExistence(timeout: 5)
        let menuOptionsAfterTap = menuOptions.allElementsBoundByIndex.map {
            "label=\($0.label), id=\($0.identifier), frame=\($0.frame), hittable=\($0.isHittable)"
        }.joined(separator: "\n")
        let afterSelectionScreenshot = XCTAttachment(screenshot: app.screenshot())
        afterSelectionScreenshot.name = "Fresh installation · state after diaper selection"
        afterSelectionScreenshot.lifetime = .keepAlways
        add(afterSelectionScreenshot)
        let selectionDiagnostics = XCTAttachment(
            string: "Quick diaper exists=\(quickDiaper.exists), hittable=\(quickDiaper.isHittable), frame=\(quickDiaper.frame)\nMenu rows after selection:\n\(menuOptionsAfterTap)"
        )
        selectionDiagnostics.name = "Fresh installation · menu and quick sheet accessibility after selection"
        selectionDiagnostics.lifetime = .keepAlways
        add(selectionDiagnostics)
        XCTAssertTrue(quickDiaperAppeared)
        quickDiaper.tap()
        let quickRegistrationDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: quickDiaper
        )
        await fulfillment(of: [quickRegistrationDismissed], timeout: 5)
        let history = app.floatingNavigationTabButtons["Historia"]
        let historyHittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND hittable == true"),
            object: history
        )
        await fulfillment(of: [historyHittable], timeout: 5)
        history.tap()
        XCTAssertTrue(app.staticTexts["history-detail-date"].waitForExistence(timeout: 5))
        bringHistoryElementIntoView(app.staticTexts["Pis"])
        XCTAssertTrue(app.staticTexts["Pis"].waitForExistence(timeout: 5))
    }

    func testRealBackendHistoryLoadsAndDisplaysAnEntryBeyondTheFirstFiveHundred() async throws {
        let baseURL = ProcessInfo.processInfo.environment["NIDO_UI_TEST_API_BASE_URL"] ?? "http://127.0.0.1:34200"
        let token = try requiredSessionToken(named: "NIDO_UI_TEST_HISTORY_TOKEN")
        var bootstrap = URLRequest(url: try XCTUnwrap(URL(string: baseURL + "/api/nido/caregivers/bootstrap")))
        bootstrap.httpMethod = "POST"
        bootstrap.setValue("application/json", forHTTPHeaderField: "Content-Type")
        bootstrap.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        bootstrap.httpBody = Data(#"{"name":"History Owner","babyName":"History Baby","birthDate":"2026-01-01"}"#.utf8)
        let (_, bootstrapResponse) = try await URLSession.shared.data(for: bootstrap)
        XCTAssertEqual((bootstrapResponse as? HTTPURLResponse)?.statusCode, 201)
        var profile = URLRequest(url: try XCTUnwrap(URL(string: baseURL + "/api/nido/profile")))
        profile.httpMethod = "PUT"
        profile.setValue("application/json", forHTTPHeaderField: "Content-Type")
        profile.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        profile.httpBody = Data(#"{"caregiverName":"History Owner","babyName":"History Baby","birthDate":"2026-01-01"}"#.utf8)
        let (_, profileResponse) = try await URLSession.shared.data(for: profile)
        XCTAssertEqual((profileResponse as? HTTPURLResponse)?.statusCode, 200)
        let runID = UUID().uuidString
        let distinctiveEntryID = "distinctive-oldest-entry-\(runID)"
        let recentTimestamp: Int64 = 1_787_958_000_000
        let oldestTimestamp: Int64 = 1_784_116_800_000
        let payloads: [[String: Any]] = (0..<504).map { index in
            [
                "id": "recent-\(runID)-\(String(format: "%04d", index))",
                "kind": "feed",
                "title": "Toma",
                "detail": "Recent fixture",
                "occurredAt": recentTimestamp,
                "amountMl": 90,
            ]
        } + [[
            "id": distinctiveEntryID,
            "kind": "diaper",
            "title": "Pañal histórico distintivo",
            "detail": "Más allá de la primera página",
            "occurredAt": oldestTimestamp,
        ]]
        for payload in payloads {
            var request = URLRequest(url: try XCTUnwrap(URL(string: baseURL + "/api/nido/entries")))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            var responseBody = Data()
            var statusCode = 0
            for attempt in 0..<3 {
                let (data, response) = try await URLSession.shared.data(for: request)
                responseBody = data
                statusCode = try XCTUnwrap(response as? HTTPURLResponse).statusCode
                if statusCode == 201 { break }
                if attempt < 2 { try await Task.sleep(for: .milliseconds(50)) }
            }
            XCTAssertEqual(
                statusCode,
                201,
                "Entry fixture \(payload["id"] ?? "unknown") failed: \(String(decoding: responseBody, as: UTF8.self))"
            )
        }

        app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = "history-pagination"
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = runID
        app.launchEnvironment["NIDO_UI_TEST_API_BASE_URL"] = baseURL
        app.launchEnvironment["NIDO_UI_TEST_ACCESS_TOKEN"] = token
        app.launchArguments += [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", "history-pagination",
            "-AppleLanguages", "(es)", "-AppleLocale", "es_ES",
        ]
        app.launch()

        let heading = app.staticTexts["timeline-day-heading"]
        XCTAssertTrue(heading.waitForExistence(timeout: 12))
        XCTAssertTrue(heading.label.contains("History Baby"))
        app.floatingNavigationTabButtons["Historia"].tap()
        XCTAssertTrue(app.staticTexts["history-detail-date"].waitForExistence(timeout: 5))
        app.buttons["history-day-picker"].tap()
        XCTAssertTrue(app.navigationBars["Elegir día"].waitForExistence(timeout: 3))

        var fixtureCalendar = Calendar(identifier: .gregorian)
        fixtureCalendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        let initialToday = fixtureCalendar.startOfDay(for: .now)
        let initialTodayComponents = fixtureCalendar.dateComponents([.year, .month, .day], from: initialToday)
        let initialTodayValue = String(
            format: "%04d-%02d-%02d",
            initialTodayComponents.year!, initialTodayComponents.month!, initialTodayComponents.day!
        )
        let initialTodayMonthIdentifier = String(
            format: "%04d-%02d", initialTodayComponents.year!, initialTodayComponents.month!
        )
        let initialSelectedDay = app.buttons["history-calendar-day-\(initialTodayValue)"]
        let initialCalendarScrollView = app.scrollViews["history-calendar-scroll"]
        let initialDayPickerNavigationBar = app.navigationBars["Elegir día"]
        let initialMonthHeader = app.descendants(matching: .any)
            .matching(identifier: "history-calendar-header-\(initialTodayMonthIdentifier)").firstMatch
        let initialPreviousMonthStart = fixtureCalendar.date(
            byAdding: .month,
            value: -1,
            to: fixtureCalendar.date(from: DateComponents(
                year: initialTodayComponents.year!, month: initialTodayComponents.month!, day: 1
            ))!
        )!
        let initialPreviousMonthComponents = fixtureCalendar.dateComponents([.year, .month], from: initialPreviousMonthStart)
        let initialPreviousMonthIdentifier = String(
            format: "%04d-%02d", initialPreviousMonthComponents.year!, initialPreviousMonthComponents.month!
        )
        let initialPreviousHeader = app.descendants(matching: .any)
            .matching(identifier: "history-calendar-header-\(initialPreviousMonthIdentifier)").firstMatch
        XCTAssertTrue(initialSelectedDay.exists, "The initially selected day must exist in the calendar.")
        XCTAssertTrue(initialCalendarScrollView.exists, "The calendar viewport must exist.")
        XCTAssertTrue(initialMonthHeader.exists, "The selected month's current header must exist.")
        let initialSelectedDayFrame = initialSelectedDay.frame
        let initialViewportFrame = initialCalendarScrollView.frame
        let initialNavigationBarFrame = initialDayPickerNavigationBar.frame
        let initialMonthHeaderFrame = initialMonthHeader.frame
        let initialPreviousHeaderFrame = initialPreviousHeader.exists ? initialPreviousHeader.frame : nil
        let initialVisibilityDiagnostic = """
        selectedDate=\(initialTodayValue)
        selectedDayFrame=\(initialSelectedDayFrame)
        viewportFrame=\(initialViewportFrame)
        navigationBarFrame=\(initialNavigationBarFrame)
        currentMonthHeaderFrame=\(initialMonthHeaderFrame)
        previousMonthHeaderFrame=\(String(describing: initialPreviousHeaderFrame))
        isEnabled=\(initialSelectedDay.isEnabled)
        isHittable=\(initialSelectedDay.isHittable)
        """
        let initialVisibilityAttachment = XCTAttachment(string: initialVisibilityDiagnostic)
        initialVisibilityAttachment.name = "History initial selected-day and month-header geometry"
        initialVisibilityAttachment.lifetime = .keepAlways
        add(initialVisibilityAttachment)
        let initialVisibilityScreenshot = XCTAttachment(image: app.screenshot().image)
        initialVisibilityScreenshot.name = "History initial selected-day and month-header visibility"
        initialVisibilityScreenshot.lifetime = .keepAlways
        add(initialVisibilityScreenshot)

        XCTAssertTrue(
            initialViewportFrame.contains(initialSelectedDayFrame),
            "The initially selected day must be fully inside the calendar viewport."
        )
        XCTAssertGreaterThanOrEqual(
            initialMonthHeaderFrame.minY,
            initialNavigationBarFrame.maxY,
            "The current month header must be below the picker navigation bar."
        )
        XCTAssertGreaterThanOrEqual(
            initialSelectedDayFrame.minY,
            max(initialNavigationBarFrame.maxY, initialMonthHeaderFrame.maxY) + 8,
            "The initially selected day must be fully below the navigation bar and current month header."
        )
        if let initialPreviousHeaderFrame = initialPreviousHeaderFrame {
            XCTAssertLessThanOrEqual(
                initialPreviousHeaderFrame.maxY,
                initialNavigationBarFrame.maxY,
                "The previous month header must remain above the calendar's usable content area."
            )
        }
        XCTAssertTrue(initialSelectedDay.isEnabled, "The initially selected day must be enabled.")
        XCTAssertTrue(initialSelectedDay.isHittable, "The initially selected day must be hittable before scrolling.")

        let targetMonth = Date(timeIntervalSince1970: Double(oldestTimestamp) / 1_000)
        let targetDate = fixtureCalendar.dateComponents([.year, .month, .day], from: targetMonth)
        let targetDateIdentifier = String(
            format: "history-calendar-day-%04d-%02d-%02d",
            targetDate.year!, targetDate.month!, targetDate.day!
        )
        let oldDate = app.buttons[targetDateIdentifier]
        let monthsBack = max(
            0, Calendar.current.dateComponents([.month], from: targetMonth, to: .now).month ?? 0
        )
        let calendarScrollView = app.scrollViews["history-calendar-scroll"]
        XCTAssertTrue(
            calendarScrollView.waitForExistence(timeout: 3),
            "The open month sheet needs a visible vertical scroll view."
        )
        let dayPickerNavigationBar = app.navigationBars["Elegir día"]
        let targetMonthComponents = fixtureCalendar.dateComponents([.year, .month], from: targetMonth)
        let targetMonthIdentifier = String(
            format: "%04d-%02d", targetMonthComponents.year!, targetMonthComponents.month!
        )
        let targetMonthHeader = app.descendants(matching: .any)
            .matching(identifier: "history-calendar-header-\(targetMonthIdentifier)").firstMatch
        let monthScrollLimit = min(24, monthsBack * 4 + 4)
        func dateCellHasUnobstructedViewportFrame() -> Bool {
            guard oldDate.exists, dayPickerNavigationBar.exists else { return false }
            let frame = oldDate.frame
            let monthHeaderBottom = targetMonthHeader.exists ? targetMonthHeader.frame.maxY : dayPickerNavigationBar.frame.maxY
            return frame.minY >= max(dayPickerNavigationBar.frame.maxY, monthHeaderBottom) + 8
                && frame.maxY <= app.frame.maxY - 8
                && frame.minX >= app.frame.minX
                && frame.maxX <= app.frame.maxX
        }
        for _ in 0..<monthScrollLimit where !dateCellHasUnobstructedViewportFrame() {
            let dragStart = calendarScrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
            let dragEnd = calendarScrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
            dragStart.press(forDuration: 0.05, thenDragTo: dragEnd, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTAssertTrue(oldDate.waitForExistence(timeout: 3))
        XCTAssertTrue(oldDate.isHittable)
        XCTAssertTrue(
            dateCellHasUnobstructedViewportFrame(),
            "The fixture date must be fully below its month header and picker navigation bar before tapping."
        )
        let targetDateGeometry = """
        targetDateFrame=\(oldDate.frame)
        targetMonthHeaderExists=\(targetMonthHeader.exists)
        targetMonthHeaderFrame=\(targetMonthHeader.exists ? String(describing: targetMonthHeader.frame) : "unavailable")
        viewportFrame=\(calendarScrollView.frame)
        navigationBarFrame=\(dayPickerNavigationBar.frame)
        isEnabled=\(oldDate.isEnabled)
        isHittable=\(oldDate.isHittable)
        """
        let targetDateGeometryAttachment = XCTAttachment(string: targetDateGeometry)
        targetDateGeometryAttachment.name = "History fixture date and full month-header geometry before tap"
        targetDateGeometryAttachment.lifetime = .keepAlways
        add(targetDateGeometryAttachment)
        let beforeDateSelection = XCTAttachment(image: app.screenshot().image)
        beforeDateSelection.name = "History fixture date fully visible below month header and picker navigation bar"
        beforeDateSelection.lifetime = .keepAlways
        add(beforeDateSelection)
        oldDate.tap()
        XCTAssertTrue(
            app.navigationBars["Elegir día"].waitForNonExistence(timeout: 5),
            "Selecting the fixture date must close the day picker before history is queried."
        )
        let distinctiveEntry = app.buttons["history-entry-\(distinctiveEntryID)"]
        bringHistoryElementIntoView(distinctiveEntry)
        XCTAssertTrue(distinctiveEntry.waitForExistence(timeout: 5))
        bringHistoryElementIntoView(app.staticTexts["Más allá de la primera página"])
        XCTAssertTrue(app.staticTexts["Más allá de la primera página"].exists)
    }

    func testRealBackendCaregiverPermissionsAndRevocation() async throws {
        let baseURL = ProcessInfo.processInfo.environment["NIDO_UI_TEST_API_BASE_URL"] ?? "http://127.0.0.1:34200"
        let ownerToken = try requiredSessionToken(named: "NIDO_UI_TEST_PERMISSIONS_OWNER_TOKEN")
        let caregiverToken = try requiredSessionToken(named: "NIDO_UI_TEST_PERMISSIONS_CAREGIVER_TOKEN")
        let bootstrap = try await apiRequest(
            baseURL: baseURL,
            path: "/api/nido/caregivers/bootstrap",
            method: "POST",
            token: ownerToken,
            body: ["name": "UI Owner", "babyName": "UI Baby", "birthDate": "2026-01-01"]
        )
        XCTAssertEqual(bootstrap.status, 201)
        let owner = try XCTUnwrap(bootstrap.payload["caregiver"] as? [String: Any])
        let profile = try await apiRequest(
            baseURL: baseURL,
            path: "/api/nido/profile",
            method: "PUT",
            token: ownerToken,
            body: ["caregiverName": "UI Owner", "babyName": "UI Baby", "birthDate": "2026-01-01"]
        )
        XCTAssertEqual(profile.status, 200)
        let entryID = "ui-owner-entry-\(UUID().uuidString)"
        let createdEntry = try await apiRequest(
            baseURL: baseURL,
            path: "/api/nido/entries",
            method: "POST",
            token: ownerToken,
            body: [
                "id": entryID,
                "kind": "health",
                "title": "Cuidados",
                "detail": "Owner original detail",
                "occurredAt": Int64(Date.now.timeIntervalSince1970 * 1_000),
            ]
        )
        XCTAssertEqual(createdEntry.status, 201)
        let invitation = try await apiRequest(
            baseURL: baseURL,
            path: "/api/nido/caregivers/invite",
            method: "POST",
            token: ownerToken,
            body: ["name": "UI Caregiver"]
        )
        XCTAssertEqual(invitation.status, 201)
        let invited = try XCTUnwrap(invitation.payload["caregiver"] as? [String: Any])
        let inviteCode = try XCTUnwrap(invited["inviteCode"] as? String)
        let joined = try await apiRequest(
            baseURL: baseURL,
            path: "/api/nido/caregivers/join",
            method: "POST",
            token: caregiverToken,
            body: ["code": inviteCode]
        )
        XCTAssertEqual(joined.status, 200)
        let caregiver = try XCTUnwrap(joined.payload["caregiver"] as? [String: Any])
        let caregiverID = try XCTUnwrap(caregiver["id"] as? String)

        launch(scenario: "caregiver-permissions", accessToken: caregiverToken)
        XCTAssertTrue(app.staticTexts["Hoy con UI Baby"].waitForExistence(timeout: 8))
        app.floatingNavigationTabButtons["Ajustes"].tap()
        let profileButton = app.buttons["settings-profile-button"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 5))
        XCTAssertFalse(profileButton.isEnabled)
        XCTAssertFalse(app.buttons["settings-invite-caregiver"].exists)
        XCTAssertTrue(app.staticTexts["Familiares"].exists)
        XCTAssertTrue(app.staticTexts["Administrador del hogar"].exists)
        XCTAssertTrue(app.staticTexts["Familiar"].exists)
        XCTAssertTrue(app.staticTexts["Solo el administrador del hogar puede gestionar familiares y editar el perfil. Los familiares comparten el mismo historial."].exists)
        let ownerRow = app.staticTexts["UI Owner"]
        XCTAssertTrue(ownerRow.exists)
        ownerRow.swipeLeft()
        XCTAssertFalse(app.buttons["Retirar"].exists)
        XCTAssertFalse(app.buttons["Cancelar"].exists)
        let restoreBackup = app.buttons["Restaurar desde un archivo"]
        for _ in 0..<4 where !restoreBackup.exists { app.swipeUp() }
        XCTAssertTrue(app.buttons["Preparar informe de 30 días"].exists)
        XCTAssertTrue(restoreBackup.exists)
        XCTAssertTrue(app.buttons["Preparar copia de seguridad"].exists)

        app.floatingNavigationTabButtons["Historia"].tap()
        XCTAssertTrue(app.staticTexts["history-detail-date"].waitForExistence(timeout: 5))
        let ownerEntry = app.buttons["history-entry-\(entryID)"]
        bringHistoryElementIntoView(ownerEntry)
        XCTAssertTrue(ownerEntry.waitForExistence(timeout: 5))
        ownerEntry.tap()
        XCTAssertTrue(app.navigationBars["Editar registro"].waitForExistence(timeout: 3))
        let detail = app.textFields.firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 3))
        XCTAssertEqual(detail.value as? String, "Owner original detail")
        replaceText(in: detail, with: "Corrected by invited caregiver")
        XCTAssertEqual(detail.value as? String, "Corrected by invited caregiver")
        app.buttons["Guardar"].tap()
        XCTAssertTrue(app.staticTexts["history-detail-date"].waitForExistence(timeout: 5))

        let afterEdit = try await apiRequest(baseURL: baseURL, path: "/api/nido", token: ownerToken)
        XCTAssertEqual(afterEdit.status, 200)
        let entries = try XCTUnwrap(afterEdit.payload["entries"] as? [[String: Any]])
        let edited = try XCTUnwrap(entries.first { $0["id"] as? String == entryID })
        XCTAssertEqual(edited["detail"] as? String, "Corrected by invited caregiver")

        let removal = try await apiRequest(
            baseURL: baseURL,
            path: "/api/nido/caregivers/invite?id=\(caregiverID)",
            method: "DELETE",
            token: ownerToken
        )
        XCTAssertEqual(removal.status, 200)
        let revokedLoad = try await apiRequest(baseURL: baseURL, path: "/api/nido", token: caregiverToken)
        XCTAssertEqual(revokedLoad.status, 401)
        XCUIDevice.shared.press(.home)
        app.activate()
        let appleSignInHeading = app.staticTexts["El cuidado familiar, en privado."]
        XCTAssertTrue(appleSignInHeading.waitForExistence(timeout: 5))
        let sessionRevocationNotice = app.staticTexts["Vuelve a iniciar sesión para acceder."]
        let sessionRevocationNoticeAppeared = sessionRevocationNotice.waitForExistence(timeout: 5)
        let revocationNoticeScreenshot = XCTAttachment(screenshot: app.screenshot())
        revocationNoticeScreenshot.name = "Caregiver revocation · reauthentication notice state"
        revocationNoticeScreenshot.lifetime = .keepAlways
        add(revocationNoticeScreenshot)
        let revocationNoticeHierarchy = XCTAttachment(string: app.debugDescription)
        revocationNoticeHierarchy.name = "Caregiver revocation · accessibility hierarchy at notice assertion"
        revocationNoticeHierarchy.lifetime = .keepAlways
        add(revocationNoticeHierarchy)
        XCTAssertTrue(sessionRevocationNoticeAppeared)
        try await Task.sleep(for: .seconds(4))
        XCTAssertTrue(sessionRevocationNotice.exists, "The reauthentication explanation must remain visible long enough to read.")
        XCTAssertFalse(app.textFields["XXXX-XXXX-XXXX"].exists)
        XCTAssertFalse(app.floatingNavigationTabButtons["Historia"].exists)
        XCTAssertEqual(owner["role"] as? String, "owner")
    }

    func testQueuedEntrySynchronizesOnceAfterReconnectAndSurvivesRelaunch() throws {
        let fixture = OfflineSyncFixtureServer()
        try fixture.start()
        defer { fixture.stop() }

        let runID = UUID().uuidString
        fixture.setAvailable(true)
        launch(
            scenario: "caregiver-permissions",
            accessToken: "offline-sync-test-token",
            runID: runID,
            apiBaseURL: fixture.baseURL
        )
        XCTAssertTrue(app.floatingNavigationTabButtons["Hoy"].waitForExistence(timeout: 10))
        app.terminate()

        fixture.setAvailable(false)
        launch(
            scenario: "caregiver-permissions",
            accessToken: "offline-sync-test-token",
            runID: runID,
            apiBaseURL: fixture.baseURL
        )
        XCTAssertTrue(app.floatingNavigationTabButtons["Hoy"].waitForExistence(timeout: 10), "Cached household should remain available offline.")

        app.floatingNavigationTabButtons["Historia"].tap()
        let historyOfflineStatus = app.staticTexts["history-offline-status"]
        XCTAssertTrue(historyOfflineStatus.waitForExistence(timeout: 3), "History should disclose that its cached entries may be incomplete while offline.")
        XCTAssertTrue(historyOfflineStatus.isHittable)
        let offlineEmptyMessage = app.staticTexts["Sin registros guardados este día"]
        bringHistoryElementIntoView(offlineEmptyMessage)
        XCTAssertTrue(offlineEmptyMessage.isHittable, "History should distinguish an empty local cache from a confirmed empty day.")
        app.floatingNavigationTabButtons["Hoy"].tap()

        app.floatingNavigationTabButtons["Ajustes"].tap()
        XCTAssertTrue(app.staticTexts["Sin conexión"].waitForExistence(timeout: 3))

        app.buttons["registration-action-button"].tap()
        app.buttons["Registrar pañal"].tap()
        let diaperChoice = app.buttons["Registrar pañal · Pis"]
        XCTAssertTrue(diaperChoice.waitForExistence(timeout: 3))
        diaperChoice.tap()
        XCTAssertTrue(app.staticTexts["Pañal registrado · Pis"].waitForExistence(timeout: 3))
        app.floatingNavigationTabButtons["Ajustes"].tap()
        XCTAssertTrue(app.staticTexts["Sin conexión"].waitForExistence(timeout: 3))
        app.terminate()

        fixture.setAvailable(true)
        launch(
            scenario: "caregiver-permissions",
            accessToken: "offline-sync-test-token",
            runID: runID,
            apiBaseURL: fixture.baseURL
        )
        XCTAssertTrue(app.floatingNavigationTabButtons["Hoy"].waitForExistence(timeout: 10))
        let uploaded = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in fixture.acceptedEntryIDs.count == 1 },
            object: fixture
        )
        XCTAssertEqual(XCTWaiter.wait(for: [uploaded], timeout: 5), .completed)
        let stableEntryID = try XCTUnwrap(fixture.acceptedEntryIDs.first)
        XCTAssertEqual(fixture.attemptedEntryIDs, [stableEntryID, stableEntryID])
        XCTAssertEqual(fixture.remoteEntryIDs, [stableEntryID])

        app.floatingNavigationTabButtons["Historia"].tap()
        XCTAssertTrue(app.staticTexts["history-detail-date"].waitForExistence(timeout: 5))
        let stableEntry = app.buttons["history-entry-\(stableEntryID)"]
        bringHistoryElementIntoView(stableEntry)
        XCTAssertTrue(stableEntry.waitForExistence(timeout: 5))
        app.floatingNavigationTabButtons["Ajustes"].tap()
        XCTAssertTrue(app.staticTexts["Actualizado"].waitForExistence(timeout: 3))
        app.terminate()

        launch(
            scenario: "caregiver-permissions",
            accessToken: "offline-sync-test-token",
            runID: runID,
            apiBaseURL: fixture.baseURL
        )
        XCTAssertTrue(app.floatingNavigationTabButtons["Hoy"].waitForExistence(timeout: 10))
        XCTAssertEqual(fixture.acceptedEntryIDs, [stableEntryID], "The persisted queue must not POST the same entry twice.")
        XCTAssertEqual(fixture.attemptedEntryIDs, [stableEntryID, stableEntryID])
    }

    func testAcceptedCreateSurvivesLaterLoadFailureWithoutDuplicatePost() throws {
        let fixture = OfflineSyncFixtureServer()
        try fixture.start()
        defer { fixture.stop() }

        let runID = UUID().uuidString
        fixture.setAvailable(true)
        launch(
            scenario: "caregiver-permissions",
            accessToken: "offline-sync-test-token",
            runID: runID,
            apiBaseURL: fixture.baseURL
        )
        XCTAssertTrue(app.floatingNavigationTabButtons["Hoy"].waitForExistence(timeout: 10))
        app.terminate()

        fixture.setAvailable(false)
        launch(
            scenario: "caregiver-permissions",
            accessToken: "offline-sync-test-token",
            runID: runID,
            apiBaseURL: fixture.baseURL
        )
        XCTAssertTrue(app.floatingNavigationTabButtons["Hoy"].waitForExistence(timeout: 10))
        app.buttons["registration-action-button"].tap()
        app.buttons["Registrar pañal"].tap()
        let diaperChoice = app.buttons["Registrar pañal · Pis"]
        XCTAssertTrue(diaperChoice.waitForExistence(timeout: 3))
        diaperChoice.tap()
        XCTAssertTrue(app.staticTexts["Pañal registrado · Pis"].waitForExistence(timeout: 3))
        app.terminate()

        fixture.setAvailable(true)
        fixture.failNextLoadAfterAcceptedCreate()
        launch(
            scenario: "caregiver-permissions",
            accessToken: "offline-sync-test-token",
            runID: runID,
            apiBaseURL: fixture.baseURL
        )
        XCTAssertTrue(app.floatingNavigationTabButtons["Hoy"].waitForExistence(timeout: 10))
        let stableEntryID = try XCTUnwrap(fixture.acceptedEntryIDs.first)
        XCTAssertEqual(fixture.acceptedEntryIDs, [stableEntryID])

        app.floatingNavigationTabButtons["Ajustes"].tap()
        XCTAssertTrue(app.staticTexts["Sin conexión"].waitForExistence(timeout: 5))
        app.floatingNavigationTabButtons["Historia"].tap()
        XCTAssertTrue(app.staticTexts["history-detail-date"].waitForExistence(timeout: 5))
        let stableEntry = app.buttons["history-entry-\(stableEntryID)"]
        bringHistoryElementIntoView(stableEntry)
        XCTAssertTrue(
            stableEntry.waitForExistence(timeout: 5),
            "An acknowledged entry must remain visible after a later sync request fails."
        )
        app.terminate()

        launch(
            scenario: "caregiver-permissions",
            accessToken: "offline-sync-test-token",
            runID: runID,
            apiBaseURL: fixture.baseURL
        )
        XCTAssertTrue(app.floatingNavigationTabButtons["Hoy"].waitForExistence(timeout: 10))
        XCTAssertEqual(fixture.acceptedEntryIDs, [stableEntryID], "A durable acknowledgement must prevent a duplicate POST after relaunch.")
        XCTAssertEqual(fixture.attemptedEntryIDs, [stableEntryID, stableEntryID])
    }

    func testRemoteFamilySleepBecomesVisibleWhileTodayRemainsOpen() throws {
        let fixture = OfflineSyncFixtureServer()
        try fixture.start()
        defer { fixture.stop() }

        launch(
            scenario: "caregiver-permissions",
            accessToken: "offline-sync-test-token",
            apiBaseURL: fixture.baseURL
        )
        XCTAssertTrue(app.floatingNavigationTabButtons["Hoy"].waitForExistence(timeout: 10))
        let sleepCard = app.descendants(matching: .any)["sleep-status-card"]
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sleep-status-card"].exists, "The other caregiver has not started sleep yet.")

        fixture.setRemoteSleepStartedAt(Date.now.addingTimeInterval(-120))

        XCTAssertTrue(
            app.staticTexts["Marco está durmiendo"].waitForExistence(timeout: 12),
            "An active sleep started by another caregiver should appear without reopening the app or manually refreshing."
        )
        XCTAssertTrue(app.buttons["Terminar"].exists)

        fixture.setRemoteSleepStartedAt(nil)
        let sleepEnded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.staticTexts["Marco está durmiendo"]
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [sleepEnded], timeout: 12),
            .completed,
            "Finishing sleep from another caregiver should update the open Today screen."
        )
    }

    func testReadyHomeAndPrimaryNavigationAreAvailable() {
        launch(scenario: "ready")

        XCTAssertTrue(app.staticTexts["Hoy con Marco"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.floatingNavigationTabButtons["Historia"].exists)
        XCTAssertTrue(app.floatingNavigationTabButtons["Evolución"].exists)
        XCTAssertTrue(app.floatingNavigationTabButtons["Ajustes"].exists)

        app.floatingNavigationTabButtons["Historia"].tap()
        XCTAssertTrue(app.staticTexts["history-detail-date"].waitForExistence(timeout: 2))
    }

    func testIsolatedReadySessionSurvivesPeriodicRefresh() async throws {
        launch(scenario: "ready")

        XCTAssertTrue(app.staticTexts["Hoy con Marco"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.floatingNavigationTabButtons["Hoy"].exists)

        try await Task.sleep(for: .seconds(48))

        XCTAssertTrue(app.staticTexts["Hoy con Marco"].exists)
        XCTAssertTrue(app.floatingNavigationTabButtons["Hoy"].exists)
        XCTAssertFalse(app.staticTexts["El cuidado familiar, en privado."].exists)
    }

    func testTodayUnfilteredAccessibilityAuditDiagnosticInLightAppearance() throws {
        try requireNativeAccessibilityAuditOptIn()
        launch(scenario: "ready", useSystemDynamicType: true)

        XCTAssertTrue(app.staticTexts["Hoy con Marco"].waitForExistence(timeout: 3))
        assertRenderedAppearance(.light)
        let scrollCaptionForAudit =
            ProcessInfo.processInfo.environment["NIDO_AUDIT_SCROLL_ACTIVITY_CAPTION"] == "1"
        if scrollCaptionForAudit {
            try scrollActivityCaptionIntoViewForAudit()
            try scrollEmptyActivityMessageIntoViewportForAudit()
        }
        try auditTodayWithoutSuppressingFindings()
    }

    func testTodayUnfilteredAccessibilityAuditDiagnosticInDarkAppearance() throws {
        try requireNativeAccessibilityAuditOptIn()
        launch(scenario: "ready", useSystemDynamicType: true)

        XCTAssertTrue(app.staticTexts["Hoy con Marco"].waitForExistence(timeout: 3))
        assertRenderedAppearance(.dark)
        let scrollCaptionForAudit =
            ProcessInfo.processInfo.environment["NIDO_AUDIT_SCROLL_ACTIVITY_CAPTION"] == "1"
        if scrollCaptionForAudit {
            try scrollActivityCaptionIntoViewForAudit()
            try scrollEmptyActivityMessageIntoViewportForAudit()
        }
        try auditTodayWithoutSuppressingFindings()
    }

    func testFloatingNavigationTabLabelsMeetRenderedContrastInLightAppearance() throws {
        try assertFloatingNavigationTabLabelContrast(appearance: "light", dark: false)
    }

    func testFloatingNavigationTabLabelsMeetRenderedContrastInDarkAppearance() throws {
        try assertFloatingNavigationTabLabelContrast(appearance: "dark", dark: true)
    }

    func testTodayDateLeavesAccessibilityTreeWhenScrolledOutOfView() throws {
        launch(scenario: "circular-timeline")
        let dateHeading = app.staticTexts["timeline-date-heading"]
        XCTAssertTrue(dateHeading.waitForExistence(timeout: 3))
        XCTAssertTrue(dateHeading.isHittable)
        try scrollActivityCaptionIntoViewForAudit()
        scrollTodayHeadingOutOfView()
        let absent = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: dateHeading
        )
        XCTAssertEqual(XCTWaiter.wait(for: [absent], timeout: 3), .completed)
    }

    func testTodayHeadingLeavesAccessibilityTreeWhenScrolledOutOfView() throws {
        launch(scenario: "circular-timeline", useSystemDynamicType: true)

        let heading = app.staticTexts["timeline-day-heading"]
        XCTAssertTrue(heading.waitForExistence(timeout: 3))
        assertRenderedAppearance(.dark)
        XCTAssertTrue(heading.isHittable, "The heading must be accessible at the top.")
        let topHeadingFrame = heading.frame
        let top = XCTAttachment(screenshot: app.screenshot())
        top.name = "Today heading accessible at top"
        top.lifetime = .keepAlways
        add(top)

        try scrollActivityCaptionIntoViewForAudit()
        scrollTodayHeadingOutOfView()
        let headingAbsent = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: heading)
        XCTAssertEqual(XCTWaiter.wait(for: [headingAbsent], timeout: 3), .completed,
                       "The fully faded heading must not remain in the accessibility tree.")

        let scrollView = app.scrollViews.firstMatch
        for _ in 0..<8 where !heading.exists || !heading.isHittable { scrollView.swipeDown() }
        XCTAssertTrue(heading.waitForExistence(timeout: 3), "The heading must return to accessibility at the top.")
        XCTAssertTrue(heading.isHittable)
        XCTAssertEqual(heading.frame.height, topHeadingFrame.height, accuracy: 1,
                       "Replacing the offscreen heading must preserve its top layout.")
        let restored = XCTAttachment(screenshot: app.screenshot())
        restored.name = "Today heading accessible after scrolling back"
        restored.lifetime = .keepAlways
        add(restored)
    }

    func testTodayDarkScrolledHeadingAtAccessibilityXXXL() throws {
        launch(
            scenario: "circular-timeline",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )

        let heading = app.staticTexts["timeline-day-heading"]
        XCTAssertTrue(heading.waitForExistence(timeout: 3))
        XCTAssertTrue(heading.isHittable, "The Today heading must remain visible at rest.")
        assertRenderedAppearance(.dark)
        let top = XCTAttachment(screenshot: app.screenshot())
        top.name = "Today dark Accessibility XXXL at rest"
        top.lifetime = .keepAlways
        add(top)

        try scrollActivityCaptionIntoViewForAudit()
        scrollTodayHeadingOutOfView()
        let headingAbsent = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: heading
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [headingAbsent], timeout: 3),
            .completed,
            "The faded Today heading must leave the accessibility tree after scrolling."
        )
        let scrolledScreenshot = app.screenshot()
        let windowFrame = app.windows.firstMatch.frame
        let statusBar = app.statusBars.firstMatch
        let statusRegionHeight = statusBar.exists ? statusBar.frame.height : 0
        if statusRegionHeight >= 60 {
            try assertNoHeadingInkInStatusBarBand(
                try XCTUnwrap(scrolledScreenshot.image.cgImage),
                windowFrame: windowFrame
            )
            print("NIDO_STATUS_BAR_HEADING_INK: pixel assertion ran; status region=\(statusRegionHeight)pt")
        } else {
            print(
                "NIDO_STATUS_BAR_HEADING_INK: pixel assertion skipped; observed status region " +
                "\(statusRegionHeight)pt is too compact to separate heading pixels from system glyphs"
            )
        }
        let scrolled = XCTAttachment(screenshot: scrolledScreenshot)
        scrolled.name = "Today dark Accessibility XXXL after scrolling"
        scrolled.lifetime = .keepAlways
        add(scrolled)
    }

    private func assertNoHeadingInkInStatusBarBand(_ image: CGImage, windowFrame: CGRect) throws {
        let bytes = try XCTUnwrap(image.dataProvider?.data)
        let pixelBytes = image.bitsPerPixel / 8
        XCTAssertGreaterThanOrEqual(pixelBytes, 3, "Status-bar pixel sampling requires RGB screenshot data.")
        let dataLength = CFDataGetLength(bytes)
        let data = try XCTUnwrap(CFDataGetBytePtr(bytes))
        let scaleX = CGFloat(image.width) / windowFrame.width
        let scaleY = CGFloat(image.height) / windowFrame.height
        // This crop is used only when observed top-chrome geometry leaves sufficient room
        // above status glyphs. The old large Today heading painted through this strip
        // when the scroll-edge chrome was absent.
        let minX = max(0, Int(12 * scaleX))
        let maxX = min(image.width, Int(132 * scaleX))
        let minY = max(0, Int(windowFrame.minY * scaleY))
        let maxY = min(image.height, Int((windowFrame.minY + 18) * scaleY))
        var intensities: [Int] = []
        intensities.reserveCapacity((maxX - minX) * (maxY - minY))
        for y in minY..<maxY {
            for x in minX..<maxX {
                let offset = y * image.bytesPerRow + x * pixelBytes
                XCTAssertLessThan(offset + 2, dataLength, "Status-bar sample must stay inside the screenshot buffer.")
                intensities.append((Int(data[offset]) + Int(data[offset + 1]) + Int(data[offset + 2])) / 3)
            }
        }
        XCTAssertFalse(intensities.isEmpty, "Status-bar sample must contain pixels.")
        let baseline = intensities.sorted()[intensities.count / 2]
        let highContrastPixelCount = intensities.filter { $0 > baseline + 8 }.count
        let highContrastPixelFraction = Double(highContrastPixelCount) / Double(intensities.count)
        print("NIDO_STATUS_BAR_HEADING_INK: baseline=\(baseline) highContrastFraction=\(highContrastPixelFraction)")
        XCTAssertLessThan(
            highContrastPixelFraction,
            0.01,
            "The dark scrolled status-bar strip must not contain the faded Today heading."
        )
    }

    func testTodayVisibleHitRegionsPassInLightAppearance() throws {
        launch(scenario: "ready", useSystemDynamicType: true)

        XCTAssertTrue(app.staticTexts["Hoy con Marco"].waitForExistence(timeout: 3))
        assertRenderedAppearance(.light)
        try app.performAccessibilityAudit(for: .hitRegion)
    }

    func testTodayVisibleHitRegionsPassInDarkAppearance() throws {
        launch(scenario: "ready", useSystemDynamicType: true)

        XCTAssertTrue(app.staticTexts["Hoy con Marco"].waitForExistence(timeout: 3))
        assertRenderedAppearance(.dark)
        try app.performAccessibilityAudit(for: .hitRegion)
    }

    func testDiaperActivityTitleScalesAndRemainsReachableAtAccessibilityXXXL() {
        launch(scenario: "circular-timeline")

        let largeRow = app.buttons["timeline-activity-ui-test-diaper-0210"]
        let largeScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(largeScrollView.waitForExistence(timeout: 3))
        scrollElementIntoViewport(largeRow, in: largeScrollView)
        XCTAssertTrue(largeRow.waitForExistence(timeout: 2))
        XCTAssertTrue(largeRow.isHittable)
        XCTAssertTrue(largeRow.label.contains("Pañal"))
        let largeRowFrame = largeRow.frame
        XCTAssertTrue(
            visibleScrollViewport(in: largeScrollView).contains(largeRowFrame),
            "The Large-size diaper activity row must fit inside the visible scroll viewport."
        )

        app.terminate()
        launch(
            scenario: "circular-timeline",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )

        let accessibilityRow = app.buttons["timeline-activity-ui-test-diaper-0210"]
        let accessibilityScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(accessibilityScrollView.waitForExistence(timeout: 3))
        scrollElementIntoViewport(accessibilityRow, in: accessibilityScrollView)
        XCTAssertTrue(accessibilityRow.waitForExistence(timeout: 2))
        XCTAssertTrue(accessibilityRow.isHittable)
        XCTAssertTrue(accessibilityRow.label.contains("Pañal"))

        let accessibilityRowFrame = accessibilityRow.frame
        XCTAssertGreaterThan(accessibilityRowFrame.height, largeRowFrame.height)
        XCTAssertTrue(
            visibleScrollViewport(in: accessibilityScrollView).contains(accessibilityRowFrame),
            "The enlarged diaper activity row must remain inside the scrollable viewport."
        )
    }

    func testTodayActivityCaptionScalesAndRemainsReachableAtAccessibilityXXXL() {
        launch(scenario: "ready", contentSizeCategory: "UICTContentSizeCategoryLarge")

        let largeCaption = app.staticTexts["Actividad del día"]
        let largeScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(largeCaption.waitForExistence(timeout: 3))
        XCTAssertTrue(largeScrollView.waitForExistence(timeout: 3))
        scrollElementIntoViewport(largeCaption, in: largeScrollView, maximumSwipes: 8)
        XCTAssertTrue(largeCaption.isHittable, "The Large-size activity caption must be reachable by scrolling.")
        let largeCaptionFrame = largeCaption.frame
        XCTAssertTrue(
            visibleScrollViewport(in: largeScrollView).contains(largeCaptionFrame),
            "The Large-size activity caption must fit inside the scroll viewport."
        )
        print("NIDO_ACTIVITY_CAPTION_DYNAMIC_TYPE: category=Large frame=\(largeCaptionFrame)")
        let largeAttachment = XCTAttachment(screenshot: app.screenshot())
        largeAttachment.name = "Today activity caption at Large"
        largeAttachment.lifetime = .keepAlways
        add(largeAttachment)

        app.terminate()
        launch(
            scenario: "ready",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )

        let accessibilityScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(accessibilityScrollView.waitForExistence(timeout: 3))
        for _ in 0..<8 where !app.staticTexts["Actividad del día"].exists {
            dragScrollViewUpWithinVisibleViewport(
                accessibilityScrollView,
                viewport: visibleScrollViewport(in: accessibilityScrollView)
            )
        }
        let accessibilityCaption = app.staticTexts["Actividad del día"]
        XCTAssertTrue(accessibilityCaption.waitForExistence(timeout: 3))
        scrollElementIntoViewport(accessibilityCaption, in: accessibilityScrollView)
        XCTAssertTrue(
            accessibilityCaption.isHittable,
            "The Accessibility XXXL activity caption must be reachable by scrolling."
        )
        let accessibilityCaptionFrame = accessibilityCaption.frame
        XCTAssertTrue(
            accessibilityScrollView.frame.contains(accessibilityCaptionFrame),
            "The Accessibility XXXL activity caption must fit inside the scroll viewport."
        )
        print("NIDO_ACTIVITY_CAPTION_DYNAMIC_TYPE: category=AccessibilityXXXL frame=\(accessibilityCaptionFrame)")
        let accessibilityAttachment = XCTAttachment(screenshot: app.screenshot())
        accessibilityAttachment.name = "Today activity caption at Accessibility XXXL"
        accessibilityAttachment.lifetime = .keepAlways
        add(accessibilityAttachment)

        XCTAssertGreaterThan(
            accessibilityCaptionFrame.height,
            largeCaptionFrame.height,
            "The activity caption must grow at Accessibility XXXL; compare the measured frames above."
        )
    }

    func testSettingsInviteActionScalesAndRemainsReachableAtAccessibilityXXXL() {
        launch(scenario: "caregiver-removal", contentSizeCategory: "UICTContentSizeCategoryLarge")
        app.floatingNavigationTabButtons["Ajustes"].tap()

        let largeAction = app.buttons["settings-invite-caregiver"]
        let largeScrollView = app.collectionViews["settings-list"]
        XCTAssertTrue(largeScrollView.waitForExistence(timeout: 3))
        scrollElementIntoViewport(largeAction, in: largeScrollView)
        XCTAssertTrue(largeAction.waitForExistence(timeout: 3))
        XCTAssertTrue(largeAction.isHittable, "The Large-size invite action must be reachable by scrolling.")
        XCTAssertEqual(largeAction.label, "Invitar familiar")
        let largeActionFrame = largeAction.frame
        let largeViewport = visibleScrollViewport(in: largeScrollView)
        let largeInviteText = app.staticTexts["Invitar familiar"]
        let largeInviteTextFrame = largeInviteText.exists ? largeInviteText.frame : nil
        XCTAssertTrue(
            largeViewport.contains(largeActionFrame),
            "The Large-size invite action must fit inside the scroll viewport."
        )
        print("NIDO_SETTINGS_INVITE_DYNAMIC_TYPE: category=Large frame=\(largeActionFrame)")
        print("NIDO_SETTINGS_INVITE_DYNAMIC_TYPE: category=Large staticTextFrame=\(String(describing: largeInviteTextFrame))")
        let largeAttachment = XCTAttachment(screenshot: app.screenshot())
        largeAttachment.name = "Settings invite action at Large"
        largeAttachment.lifetime = .keepAlways
        add(largeAttachment)

        app.terminate()
        launch(
            scenario: "caregiver-removal",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )
        app.floatingNavigationTabButtons["Ajustes"].tap()

        let accessibilityAction = app.buttons["settings-invite-caregiver"]
        let accessibilityScrollView = app.collectionViews["settings-list"]
        XCTAssertTrue(accessibilityScrollView.waitForExistence(timeout: 3))
        scrollElementIntoViewport(accessibilityAction, in: accessibilityScrollView)
        XCTAssertTrue(accessibilityAction.waitForExistence(timeout: 3))
        XCTAssertTrue(
            accessibilityAction.isHittable,
            "The Accessibility XXXL invite action must be reachable by scrolling."
        )
        XCTAssertEqual(accessibilityAction.label, "Invitar familiar")
        let accessibilityActionFrame = accessibilityAction.frame
        let accessibilityViewport = visibleScrollViewport(in: accessibilityScrollView)
        let accessibilityInviteText = app.staticTexts["Invitar familiar"]
        let accessibilityInviteTextFrame = accessibilityInviteText.exists ? accessibilityInviteText.frame : nil
        print("NIDO_SETTINGS_INVITE_DYNAMIC_TYPE: category=AccessibilityXXXL viewport=\(accessibilityViewport) action=\(accessibilityActionFrame) fullyContained=\(accessibilityViewport.contains(accessibilityActionFrame)) hittable=\(accessibilityAction.isHittable)")
        let accessibilityViewportAttachment = XCTAttachment(screenshot: app.screenshot())
        accessibilityViewportAttachment.name = "Settings invite viewport before containment assertion"
        accessibilityViewportAttachment.lifetime = .keepAlways
        add(accessibilityViewportAttachment)
        XCTAssertTrue(
            accessibilityViewport.contains(accessibilityActionFrame),
            "The Accessibility XXXL invite action must fit inside the scroll viewport."
        )
        guard let largeInviteTextFrame else {
            XCTFail("The invite label must expose a StaticText node at Large.")
            return
        }
        guard let accessibilityInviteTextFrame else {
            XCTFail("The invite label must expose a StaticText node at Accessibility XXXL.")
            return
        }
        XCTAssertGreaterThan(
            accessibilityInviteTextFrame.height,
            largeInviteTextFrame.height,
            "The Invitar familiar StaticText frame must grow at Accessibility XXXL."
        )
        XCTAssertGreaterThan(
            accessibilityActionFrame.height,
            largeActionFrame.height,
            "The invite action's measured row must grow with Accessibility XXXL Dynamic Type."
        )
        print("NIDO_SETTINGS_INVITE_DYNAMIC_TYPE: category=AccessibilityXXXL frame=\(accessibilityActionFrame)")
        print("NIDO_SETTINGS_INVITE_DYNAMIC_TYPE: category=AccessibilityXXXL staticTextFrame=\(String(describing: accessibilityInviteTextFrame))")
        let accessibilityAttachment = XCTAttachment(screenshot: app.screenshot())
        accessibilityAttachment.name = "Settings invite action at Accessibility XXXL"
        accessibilityAttachment.lifetime = .keepAlways
        add(accessibilityAttachment)
    }

    private func scrollElementIntoViewport(_ element: XCUIElement, in scrollView: XCUIElement, maximumSwipes: Int = 12) {
        for _ in 0..<maximumSwipes {
            let viewport = visibleScrollViewport(in: scrollView)
            if element.exists && viewport.contains(element.frame) { return }
            guard element.exists else {
                dragScrollViewUpWithinVisibleViewport(scrollView, viewport: viewport)
                continue
            }

            let frame = element.frame
            let overshoot = frame.minY < viewport.minY
                ? frame.minY - viewport.minY
                : frame.maxY - viewport.maxY
            let fraction = min(0.35, max(0.05, abs(overshoot) / scrollView.frame.height))
            let startY = (viewport.midY - scrollView.frame.minY) / scrollView.frame.height
            let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
            let minimumVisibleY = (viewport.minY + 16 - scrollView.frame.minY) / scrollView.frame.height
            let maximumVisibleY = (viewport.maxY - 16 - scrollView.frame.minY) / scrollView.frame.height
            let endY = min(maximumVisibleY, max(minimumVisibleY, startY + (overshoot > 0 ? -fraction : fraction)))
            start.press(
                forDuration: 0.05,
                thenDragTo: scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY)),
                withVelocity: .slow,
                thenHoldForDuration: 0.2
            )
        }

        let viewport = visibleScrollViewport(in: scrollView)
        let frame = element.exists ? element.frame : .zero
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Scroll element viewport failure"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Scroll element accessibility hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        XCTFail(
            "Could not fully place element \(element.identifier) frame=\(frame) inside viewport=\(viewport)."
        )
    }

    private func visibleScrollViewport(in scrollView: XCUIElement) -> CGRect {
        let navigationBar = app.navigationBars.firstMatch
        let registrationAction = app.buttons["registration-action-button"]
        let floatingTabBar = app.floatingNavigationTabBars.firstMatch
        let scrollFrame = scrollView.frame
        let top = navigationBar.exists ? max(scrollFrame.minY, navigationBar.frame.maxY) : scrollFrame.minY
        let controlBottoms = [
            registrationAction.exists ? registrationAction.frame.minY : scrollFrame.maxY,
            floatingTabBar.exists ? floatingTabBar.frame.minY : scrollFrame.maxY,
        ]
        let bottom = max(top, min(scrollFrame.maxY, controlBottoms.min() ?? scrollFrame.maxY) - (registrationAction.exists || floatingTabBar.exists ? 12 : 0))
        return CGRect(
            x: scrollFrame.minX,
            y: top,
            width: scrollFrame.width,
            height: max(0, bottom - top)
        )
    }

    private func dragScrollViewUpWithinVisibleViewport(_ scrollView: XCUIElement, viewport: CGRect) {
        let scrollFrame = scrollView.frame
        let startY = (viewport.maxY - 16 - scrollFrame.minY) / scrollFrame.height
        let endY = (viewport.minY + 16 - scrollFrame.minY) / scrollFrame.height
        let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
        start.press(
            forDuration: 0.05,
            thenDragTo: scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY)),
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )
    }

    func testDailyGoalMetricsRemainAccessibleAtAccessibilityXXXL() {
        launch(
            scenario: "circular-timeline",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))
        for metricID in ["day-goal-summary-sleep", "day-goal-summary-feed", "day-goal-summary-diaper"] {
            let metric = app.buttons[metricID]
            scrollElementIntoViewport(metric, in: scrollView)
            XCTAssertTrue(metric.waitForExistence(timeout: 5), "Missing accessible goal metric \(metricID)")
            XCTAssertTrue(metric.isHittable, "The Accessibility XXXL metric must remain reachable by scrolling.")
            XCTAssertGreaterThanOrEqual(metric.frame.height, 44)
            XCTAssertFalse((metric.value as? String ?? "").isEmpty)
        }

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Daily goal metrics at Accessibility XXXL"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func requireNativeAccessibilityAuditOptIn() throws {
        guard ProcessInfo.processInfo.environment["NIDO_RUN_NATIVE_ACCESSIBILITY_AUDIT"] == "1" else {
            throw XCTSkip(
                "Opt-in diagnostic only: set NIDO_RUN_NATIVE_ACCESSIBILITY_AUDIT=1 to run the unfiltered .all system audit; current simulator findings include offscreen attribution and a nil element."
            )
        }
    }

    private func auditTodayWithoutSuppressingFindings() throws {
        attachTodayAccessibilityAuditState()
        let previousContinueAfterFailure = continueAfterFailure
        continueAfterFailure = true
        defer { continueAfterFailure = previousContinueAfterFailure }

        try app.performAccessibilityAudit(for: .all) { issue in
            print("NIDO_AUDIT_ISSUE: \(issue.compactDescription) | \(issue.detailedDescription)")
            if let element = issue.element {
                print("NIDO_AUDIT_ELEMENT: identifier=\(element.identifier) label=\(element.label) frame=\(element.frame)")
            } else {
                print("NIDO_AUDIT_ELEMENT: nil; accessibility tree follows:\n\(self.app.debugDescription)")
            }
            return false
        }
    }

    private func attachTodayAccessibilityAuditState() {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Today immediately before unfiltered accessibility audit"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let elements: [(String, XCUIElement)] = [
            ("window", app.windows.firstMatch),
            ("scrollView", app.scrollViews.firstMatch),
            ("navigationBar", app.navigationBars.firstMatch),
            ("tabBar", app.floatingNavigationTabBars.firstMatch),
            ("registrationAction", app.buttons["registration-action-button"]),
            ("pageHeading", app.staticTexts["timeline-day-heading"]),
            ("dateHeading", app.staticTexts["timeline-date-heading"]),
            ("sleepCard", app.buttons["sleep-status-card"]),
            ("sleepCaption", app.staticTexts["Sueño de hoy"]),
            ("sleepAction", app.staticTexts["Registrar sueño"]),
            ("activityCaption", app.staticTexts["Actividad del día"])
        ]
        let geometry = elements.map { name, element in
            "\(name): \(geometryDescription(of: element))"
        }.joined(separator: "\n")
        let state = XCTAttachment(string: "\(geometry)\n\nAccessibility tree:\n\(app.debugDescription)")
        state.name = "Today geometry and accessibility tree before audit"
        state.lifetime = .keepAlways
        add(state)
    }

    private func scrollTodayHeadingOutOfView() {
        let heading = app.staticTexts["timeline-day-heading"]
        let scrollView = app.scrollViews.firstMatch
        for _ in 0..<8 where heading.exists && heading.isHittable {
            scrollView.swipeUp()
        }
        logActivityCaptionAuditState("after scrolling the header out of view")
    }

    private func scrollActivityCaptionIntoViewForAudit() throws {
        let target = app.staticTexts["Actividad del día"]
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))
        logActivityCaptionAuditState("before scrolling")

        // The caption sits below a LazyVStack boundary at Accessibility XXXL, so it
        // may not enter the accessibility tree until scrolling materializes it.
        var captionExists = target.waitForExistence(timeout: 1)
        for _ in 0..<8 where !captionExists {
            scrollView.swipeUp()
            captionExists = target.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(
            captionExists,
            "The activity caption should materialize after scrolling before the .all audit."
        )
        for _ in 0..<8 where !target.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(target.isHittable, "The activity caption should be visible before the .all audit.")
        logActivityCaptionAuditState("after scrolling into view")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Dark audit with activity caption visible"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func scrollEmptyActivityMessageIntoViewportForAudit() throws {
        let scrollView = app.scrollViews.firstMatch
        let emptyMessage = app.staticTexts["Sin registros este día"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))
        XCTAssertTrue(emptyMessage.waitForExistence(timeout: 3))

        for _ in 0..<6 where !scrollView.frame.contains(emptyMessage.frame) {
            scrollView.swipeUp()
        }

        XCTAssertTrue(
            scrollView.frame.contains(emptyMessage.frame),
            "The empty activity message must be inside the viewport before the unfiltered audit."
        )
        print(
            "NIDO_EMPTY_ACTIVITY_LABEL_AUDIT: frame=\(emptyMessage.frame) " +
                "scrollView=\(scrollView.frame) hittable=\(emptyMessage.isHittable)"
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Empty activity message inside viewport before unfiltered audit"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func logActivityCaptionAuditState(_ phase: String) {
        let target = app.staticTexts["Actividad del día"]
        let window = app.windows.firstMatch
        let scrollView = app.scrollViews.firstMatch
        let heading = app.staticTexts["timeline-day-heading"]
        let statusBar = app.statusBars.firstMatch
        let navigationBar = app.navigationBars.firstMatch
        print(
            "NIDO_ACTIVITY_CAPTION_\(phase): caption=\(geometryDescription(of: target)) " +
                "window=\(geometryDescription(of: window)) " +
                "scrollView=\(geometryDescription(of: scrollView)) " +
                "heading=\(geometryDescription(of: heading)) " +
                "statusBar=\(geometryDescription(of: statusBar)) " +
                "navigationBar=\(geometryDescription(of: navigationBar))"
        )
    }

    private func geometryDescription(of element: XCUIElement) -> String {
        guard element.exists else { return "absent" }
        return "frame=\(element.frame) isHittable=\(element.isHittable)"
    }

    private func assertRenderedAppearance(_ appearance: XCUIDevice.Appearance) {
        AppearanceScreenshotAssertion.assertRenderedAppearance(
            app,
            dark: appearance == .dark,
            minimumLightBrightness: 220,
            file: #filePath,
            line: #line
        )
    }

    func testSettingsShowsBundleVersionBuildAndOptionalGitRevision() {
        launch(scenario: "ready")

        app.floatingNavigationTabButtons["Ajustes"].tap()
        let versionValue = app.staticTexts["app-version-value"]
        for _ in 0..<4 where !versionValue.exists {
            app.swipeUp()
        }

        XCTAssertTrue(versionValue.waitForExistence(timeout: 2))
        XCTAssertTrue(
            versionValue.label.wholeMatch(
                of: /[0-9]+\.[0-9]+\.[0-9]+ \([0-9]+\)( · [0-9a-f]{7}( dirty)?)?/
            ) != nil,
            "Expected semantic version and build from the app bundle, got: \(versionValue.label)"
        )
    }

    func testPrimaryNavigationUsesLabeledTabsAndSeparateRegistrationAction() {
        launch(scenario: "baby-care")

        let tabBar = app.floatingNavigationTabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3))
        XCTAssertEqual(Set(app.floatingNavigationTabButtons.allElementsBoundByIndex.map(\.label)), ["Hoy", "Historia", "Evolución", "Ajustes"])
        let registrationButton = app.buttons["registration-action-button"]
        XCTAssertTrue(registrationButton.exists)
        XCTAssertEqual(registrationButton.label, "Registrar una actividad")
        XCTAssertFalse(tabBar.buttons["registration-action-button"].exists)
        XCTAssertFalse(tabBar.buttons["Registrar una actividad"].exists)

        app.floatingNavigationTabButtons["Historia"].tap()
        XCTAssertTrue(app.staticTexts["history-detail-date"].waitForExistence(timeout: 2))
        registrationButton.tap()
        XCTAssertTrue(app.buttons["Registrar sueño"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["history-detail-date"].exists)
        XCTAssertTrue(app.floatingNavigationTabButtons["Historia"].isSelected)

        app.staticTexts["history-detail-date"].tap()
        XCTAssertFalse(app.buttons["Registrar sueño"].exists)

        let navigationBar = app.floatingNavigationTabBars.firstMatch
        let registrationTop = registrationButton.frame.minY
        let navigationTop = navigationBar.frame.minY
        let controlTop = min(registrationTop, navigationTop)

        func scrollToEndAndCapture(
            tabTitle: String,
            scrollView: XCUIElement,
            finalElement: XCUIElement,
            screenshotName: String
        ) {
            let tab = app.floatingNavigationTabButtons[tabTitle]
            XCTAssertTrue(tab.waitForExistence(timeout: 3))
            tab.tap()
            XCTAssertTrue(tab.isSelected)
            XCTAssertTrue(scrollView.waitForExistence(timeout: 5))

            for _ in 0..<12 {
                if finalElement.exists,
                   finalElement.isHittable,
                   finalElement.frame.maxY <= controlTop - 12 {
                    break
                }
let scrollFrame = scrollView.frame
let visibleBottom = min(scrollFrame.maxY, navigationBar.frame.minY - 16)
let visibleHeight = visibleBottom - scrollFrame.minY
XCTAssertGreaterThan(visibleHeight, 100, "The (tabTitle) scroll view must have a usable viewport above the dock.")
let scrollOrigin = scrollView.coordinate(withNormalizedOffset: .zero)
let dragStart = scrollOrigin.withOffset(
CGVector(dx: scrollFrame.width / 2, dy: visibleHeight * 0.75)
)
let dragEnd = scrollOrigin.withOffset(
CGVector(dx: scrollFrame.width / 2, dy: visibleHeight * 0.25)
)
                dragStart.press(
                    forDuration: 0.05,
thenDragTo: dragEnd,
                    withVelocity: .slow,
                    thenHoldForDuration: 0.2
                )
            }

            XCTAssertTrue(finalElement.waitForExistence(timeout: 3), "The final (tabTitle) content must exist.")
            XCTAssertTrue(finalElement.isHittable, "The final (tabTitle) content must remain reachable above the dock.")
            XCTAssertLessThanOrEqual(
                finalElement.frame.maxY,
                controlTop - 12,
                "The final (tabTitle) content must clear the floating controls by at least 12 points."
            )
            print("PRIMARY_NAV_END tab=\(tabTitle) frame=\(finalElement.frame) controlsTop=\(controlTop)")

            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = screenshotName
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }

        scrollToEndAndCapture(
            tabTitle: "Hoy",
            scrollView: app.scrollViews.containing(.any, identifier: "timeline-day-activity-list").firstMatch,
            finalElement: app.buttons["timeline-activity-fixture-baby-sleep"],
            screenshotName: "Hoy end-scroll after dock-origin gesture"
        )
        scrollToEndAndCapture(
            tabTitle: "Historia",
            scrollView: app.scrollViews["history-detail-scroll"],
            finalElement: app.buttons["history-entry-fixture-baby-sleep"],
            screenshotName: "Historia end-scroll after dock-origin gesture"
        )
        scrollToEndAndCapture(
            tabTitle: "Evolución",
            scrollView: app.scrollViews.firstMatch,
            finalElement: app.buttons["evolution-all-data"],
            screenshotName: "Evolución end-scroll after dock-origin gesture"
        )
        scrollToEndAndCapture(
            tabTitle: "Ajustes",
            scrollView: app.collectionViews["settings-list"],
            finalElement: app.staticTexts["Nido acompaña el cuidado diario, pero no sustituye el consejo de un profesional sanitario."],
            screenshotName: "Ajustes end-scroll after dock-origin gesture"
        )
    }

    func testTodayHeaderAndSingleNavigationBarRemainVisible() {
        launch(scenario: "circular-timeline")
        let heading = app.staticTexts["timeline-day-heading"]
        XCTAssertTrue(heading.waitForExistence(timeout: 3))
        XCTAssertTrue(heading.isHittable)
        XCTAssertEqual(app.floatingNavigationTabBars.count, 1, "Only the floating navigation bar should be exposed.")
    }

    func testDailyGoalRingKeepsASquareCoordinateSpaceAtLargestText() {
        launch(
            scenario: "circular-timeline",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )

        let ring = app.buttons["daily-goal-ring-graphic"]
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))
        scrollElementIntoViewport(ring, in: scrollView)

        XCTAssertLessThanOrEqual(
            abs(ring.frame.width - ring.frame.height),
            1.0,
            "The daily goal ring must remain square at Accessibility XXXL."
        )
        XCTAssertGreaterThanOrEqual(ring.frame.width, 240)
    }
    func testPremiumTodayVisualReviewCapturesInLightAppearance() throws {
        defer {
            app.terminate()
            launch(scenario: "live-activity-cleanup")
            app.terminate()
        }
        launch(scenario: "baby-care")
        XCTAssertTrue(app.staticTexts["timeline-day-heading"].waitForExistence(timeout: 5))
        assertRenderedAppearance(.light)
        captureUnobstructedToday(named: "hoy-claro")
        app.terminate()

        launch(scenario: "circular-timeline")
        let feedActivity = app.buttons["timeline-activity-ui-test-feed"]
        XCTAssertTrue(feedActivity.waitForExistence(timeout: 5))
        feedActivity.tap()
        let selectedRecord = app.descendants(matching: .any)["today-selected-record"]
        XCTAssertTrue(selectedRecord.waitForExistence(timeout: 3))
        captureUnobstructedToday(named: "hoy-registro-seleccionado")

        app.buttons["today-clear-selection"].tap()
        XCTAssertFalse(selectedRecord.exists)
        app.buttons["registration-action-button"].tap()
        for choice in ["Registrar sueño", "Registrar toma", "Registrar pañal", "Registrar cuidados"] {
            XCTAssertTrue(app.buttons[choice].waitForExistence(timeout: 3))
        }
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertFalse(springboard.alerts.firstMatch.exists, "The menu capture must not contain a SpringBoard alert.")
        XCTAssertFalse(app.alerts.firstMatch.exists, "The menu capture must not contain an app alert.")
        XCTAssertFalse(app.buttons["apple-sign-in"].exists, "The menu capture must not show an account sign-in screen.")
        let menuAttachment = XCTAttachment(screenshot: app.screenshot())
        menuAttachment.name = "hoy-menu-registro"
        menuAttachment.lifetime = .keepAlways
        add(menuAttachment)
        app.terminate()

        launch(scenario: "active-sleep")
        XCTAssertTrue(app.buttons["Terminar"].waitForExistence(timeout: 5))
        captureUnobstructedToday(named: "hoy-sueno-activo")
        app.terminate()

        launch(scenario: "circular-timeline", contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge")
        let dial = app.buttons["daily-goal-ring-graphic"]
        XCTAssertTrue(dial.waitForExistence(timeout: 5))
        scrollElementIntoViewport(dial, in: app.scrollViews.firstMatch)
        captureUnobstructedToday(named: "hoy-texto-accesibilidad")

        app.terminate()
        launch(scenario: "live-activity-ten-hour-sleep")
        XCTAssertTrue(app.staticTexts["timeline-day-heading"].waitForExistence(timeout: 8))
        let activitySpringboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        activitySpringboard.activate()
        activitySpringboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.035)).press(forDuration: 1.0)
        let liveActivityDeadline = Date().addingTimeInterval(5)
        var liveActivityScreenshot = activitySpringboard.screenshot()
        var liveActivityText = ""
        while Date() < liveActivityDeadline {
            liveActivityScreenshot = activitySpringboard.screenshot()
            liveActivityText = try recognizedMenuLines(in: liveActivityScreenshot.image)
                .map { normalizedMenuText($0.text) }
                .joined(separator: " ")
            if liveActivityText.contains("en curso para test") { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
        let liveActivityAttachment = XCTAttachment(screenshot: liveActivityScreenshot)
        liveActivityAttachment.name = "Live Activity · sueño · Dynamic Island expanded"
        liveActivityAttachment.lifetime = .keepAlways
        add(liveActivityAttachment)
        XCTAssertTrue(
            liveActivityText.contains("en curso para test"),
            "Expanded system Live Activity should show the active sleep label and baby name; OCR saw: \(liveActivityText)"
        )
    }

    func testPremiumTodayVisualReviewCapturesInDarkAppearance() throws {
        launch(scenario: "baby-care")
        XCTAssertTrue(app.staticTexts["timeline-day-heading"].waitForExistence(timeout: 5))
        assertRenderedAppearance(.dark)
        captureUnobstructedToday(named: "hoy-oscuro")
    }

    private func captureUnobstructedToday(named name: String) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let notNow = springboard.buttons["Ahora no"]
        if notNow.waitForExistence(timeout: 2) {
            notNow.tap()
            XCTAssertTrue(notNow.waitForNonExistence(timeout: 3))
        }
        XCTAssertFalse(springboard.alerts.firstMatch.exists, "Dismiss system alerts before capturing the design.")
        XCTAssertFalse(app.alerts.firstMatch.exists, "The capture must show the unobstructed app.")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSeparateRegistrationActionPreservesSelectedTab() {
        launch(scenario: "ready")

        let tabBar = app.floatingNavigationTabBars.firstMatch
        let history = app.floatingNavigationTabButtons["Historia"]
        let registrationButton = app.buttons["registration-action-button"]
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3))
        XCTAssertTrue(history.waitForExistence(timeout: 3))
        XCTAssertTrue(registrationButton.waitForExistence(timeout: 3))
        XCTAssertTrue(registrationButton.isHittable)
        XCTAssertEqual(registrationButton.label, "Registrar una actividad")
        let tabBarButtonLabels = Set(app.floatingNavigationTabButtons.allElementsBoundByIndex.map(\.label))
        XCTAssertEqual(
            tabBarButtonLabels,
            ["Hoy", "Historia", "Evolución", "Ajustes"]
        )
        XCTAssertFalse(tabBar.buttons["Registrar una actividad"].exists)

        history.tap()
        XCTAssertTrue(app.staticTexts["history-detail-date"].waitForExistence(timeout: 2))
        registrationButton.tap()

        for choice in ["Registrar sueño", "Registrar toma", "Registrar pañal", "Registrar cuidados"] {
            XCTAssertTrue(app.buttons[choice].waitForExistence(timeout: 2))
        }
        XCTAssertTrue(app.staticTexts["history-detail-date"].exists)
        XCTAssertTrue(history.isSelected)
    }

    func testRegistrationChoicesRemainAnchoredToTheFloatingAction() {
        launch(scenario: "circular-timeline")

        let registrationButton = app.buttons["registration-action-button"]
        XCTAssertTrue(registrationButton.waitForExistence(timeout: 3))
        registrationButton.tap()

        let choiceLabels = ["Registrar sueño", "Registrar toma", "Registrar pañal", "Registrar cuidados"]
        let choices = choiceLabels.map { app.buttons[$0] }
        for choice in choices {
            XCTAssertTrue(choice.waitForExistence(timeout: 3))
        }

        let choicesMaxY = choices.map(\.frame.maxY).max() ?? 0
        let gapAboveAction = registrationButton.frame.minY - choicesMaxY
        XCTAssertGreaterThanOrEqual(
            gapAboveAction,
            -registrationButton.frame.height,
            "Native menu content may overlap its origin button but must not extend below it."
        )
        XCTAssertLessThanOrEqual(
            gapAboveAction,
            100,
            "Registration choices must remain visually anchored near the floating action button."
        )
    }

    func testRegistrationMenuSupportsConsecutiveSelectionsAndCancellation() {
        launch(scenario: "quick-diaper-registration")

        let registrationButton = app.buttons["registration-action-button"]
        let history = app.floatingNavigationTabButtons["Historia"]
        XCTAssertTrue(registrationButton.waitForExistence(timeout: 3))
        history.tap()
        XCTAssertTrue(app.staticTexts["history-detail-date"].waitForExistence(timeout: 3))

        func assertRegistrationActionIsReadyAfterDismissal() {
            let registrationActionReady = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == true AND hittable == true"),
                object: registrationButton
            )
            XCTAssertEqual(
                XCTWaiter.wait(for: [registrationActionReady], timeout: 3),
                .completed,
                "The registration sheet must finish dismissing before the next menu cycle."
            )
        }

        func openMenuAndSelect(_ row: String, destination: String) {
            registrationButton.tap()
            let menuRow = app.buttons[row]
            XCTAssertTrue(menuRow.waitForExistence(timeout: 3), "The \(row) row must be exposed by the registration menu.")
            XCTAssertTrue(menuRow.isHittable, "The \(row) row must be hittable before selection.")
            let before = XCTAttachment(screenshot: app.screenshot())
            before.name = "Registro · menú abierto · \(row)"
            before.lifetime = .keepAlways
            add(before)

            menuRow.tap()

            let destinationView = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", destination))
                .firstMatch
            XCTAssertTrue(
                destinationView.waitForExistence(timeout: 3),
                "Selecting \(row) must dismiss the menu and show \(destination)."
            )
            let menuDismissed = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"),
                object: menuRow
            )
            XCTAssertEqual(XCTWaiter.wait(for: [menuDismissed], timeout: 3), .completed)
            let after = XCTAttachment(screenshot: app.screenshot())
            after.name = "Registro · destino · \(row)"
            after.lifetime = .keepAlways
            add(after)
            XCTAssertTrue(history.isSelected, "Opening a registration flow must preserve the selected tab.")
        }

        openMenuAndSelect("Registrar pañal", destination: "Pañal")
        app.buttons["Cancelar"].tap()
        XCTAssertTrue(app.staticTexts["history-detail-date"].waitForExistence(timeout: 3))
        assertRegistrationActionIsReadyAfterDismissal()

        openMenuAndSelect("Registrar pañal", destination: "Pañal")
        app.buttons["Añadir detalles"].tap()
        XCTAssertTrue(app.staticTexts["¿Qué había en el pañal?"].waitForExistence(timeout: 3))
        app.buttons["Cancelar"].tap()
        XCTAssertTrue(app.staticTexts["history-detail-date"].waitForExistence(timeout: 3))
        assertRegistrationActionIsReadyAfterDismissal()

        openMenuAndSelect("Registrar sueño", destination: "Sueño")
        app.buttons["Cancelar"].tap()
        XCTAssertTrue(app.staticTexts["history-detail-date"].waitForExistence(timeout: 3))
        assertRegistrationActionIsReadyAfterDismissal()

        openMenuAndSelect("Registrar cuidados", destination: "Cuidados")
        app.buttons["Cancelar"].tap()
        XCTAssertTrue(app.staticTexts["history-detail-date"].waitForExistence(timeout: 3))
        assertRegistrationActionIsReadyAfterDismissal()

        openMenuAndSelect("Registrar toma", destination: "Toma")
        app.buttons["Cancelar"].tap()
        XCTAssertTrue(app.staticTexts["history-detail-date"].waitForExistence(timeout: 3))
        assertRegistrationActionIsReadyAfterDismissal()
        XCTAssertTrue(registrationButton.isHittable)
        XCTAssertFalse(app.buttons["Registrar pañal"].exists)
        XCTAssertFalse(app.buttons["Registrar sueño"].exists)
        XCTAssertFalse(app.buttons["Registrar toma"].exists)
        XCTAssertFalse(app.buttons["Registrar cuidados"].exists)
    }

    func testSemanticEditorsExposeTheStoredActivityFields() {
        launch(scenario: "semantic-edit")

        app.floatingNavigationTabButtons["Historia"].tap()
        XCTAssertTrue(app.staticTexts["history-detail-date"].waitForExistence(timeout: 3))

        let feedEntry = app.descendants(matching: .any)["history-entry-ui-test-semantic-feed"]
        bringHistoryElementIntoView(feedEntry)
        feedEntry.tap()
        XCTAssertTrue(app.navigationBars["Editar registro"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Tipo"].exists)
        let contentPicker = app.descendants(matching: .any)["entry-editor-feed-content-picker"]
        for _ in 0..<3 where !contentPicker.isHittable { app.swipeUp() }
        XCTAssertTrue(contentPicker.waitForExistence(timeout: 2))
        XCTAssertTrue(contentPicker.isHittable)
        XCTAssertTrue(app.staticTexts["Fórmula"].exists)
        app.buttons["Cancelar"].tap()

        let feedEditorDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.navigationBars["Editar registro"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [feedEditorDismissed], timeout: 5), .completed)
        let diaperEntry = app.descendants(matching: .any)["history-entry-ui-test-semantic-diaper"]
        bringHistoryElementIntoView(diaperEntry)
        XCTAssertTrue(diaperEntry.waitForExistence(timeout: 5))
        XCTAssertTrue(diaperEntry.isHittable)
        diaperEntry.tap()
        XCTAssertTrue(app.staticTexts["¿Qué había en el pañal?"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Pis"].isSelected)
        XCTAssertTrue(app.buttons["Caca"].isSelected)
        app.buttons["Cancelar"].tap()

        let diaperEditorDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.navigationBars["Editar registro"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [diaperEditorDismissed], timeout: 5), .completed)
        let careEntry = app.descendants(matching: .any)["history-entry-ui-test-semantic-care"]
        bringHistoryElementIntoView(careEntry)
        XCTAssertTrue(careEntry.waitForExistence(timeout: 5))
        XCTAssertTrue(careEntry.isHittable)
        careEntry.tap()
        XCTAssertTrue(app.staticTexts["¿Qué quieres registrar?"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Temperatura"].isSelected)
        let careForm = app.collectionViews.firstMatch
        XCTAssertTrue(careForm.exists)
        let measurement = app.staticTexts["Medición"]
        for _ in 0..<4 where !measurement.exists {
            careForm.swipeUp()
        }
        XCTAssertTrue(measurement.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Medición, 37,2 °C"].exists)
    }

    func testActionableUndoRemainsAvailableUntilDismissedOrUsed() {
        launch(
            scenario: "undo-notice",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )

        let undo = app.buttons["Deshacer"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        let registrationButton = app.buttons["registration-action-button"]
        XCTAssertTrue(registrationButton.exists)
        let noticeScreenshot = XCTAttachment(screenshot: app.screenshot())
        noticeScreenshot.name = "Undo notice above floating navigation at Accessibility XXXL"
        noticeScreenshot.lifetime = .keepAlways
        add(noticeScreenshot)
        XCTAssertLessThan(undo.frame.maxY, registrationButton.frame.minY)
        sleep(6)
        XCTAssertTrue(undo.exists)
        XCTAssertTrue(app.buttons["Cerrar aviso"].exists)
    }

    func testActiveFeedHasTodayPriorityAndDoesNotAppearOnPreviousDays() {
        launch(scenario: "active-feed")

        let feed = app.descendants(matching: .any)["active-feed-card"]
        let dial = app.descendants(matching: .any)["today-goal-rings"]
        XCTAssertTrue(feed.waitForExistence(timeout: 3))
        XCTAssertTrue(dial.exists)
        XCTAssertGreaterThanOrEqual(feed.frame.minY, dial.frame.maxY)
        let sleepCard = app.descendants(matching: .any)["sleep-status-card"]
        XCTAssertTrue(sleepCard.exists)
        XCTAssertLessThan(feed.frame.maxY, sleepCard.frame.minY)

        let previousDay = app.buttons["Día anterior"]
        XCTAssertTrue(previousDay.waitForExistence(timeout: 3))
        previousDay.tap()
        XCTAssertTrue(app.buttons["Volver a hoy"].waitForExistence(timeout: 3))
        XCTAssertFalse(feed.exists)
    }

    func testCaregiverRemovalRequiresExplicitConfirmation() {
        launch(scenario: "caregiver-removal")

        app.floatingNavigationTabButtons["Ajustes"].tap()
        let caregiver = app.collectionViews["settings-list"].cells.containing(
            .staticText,
            identifier: "caregiver-row-ui-test-caregiver-ana"
        ).firstMatch
        XCTAssertTrue(caregiver.waitForExistence(timeout: 3))
        let remove = app.buttons["Retirar a Ana"]
        XCTAssertTrue(remove.waitForExistence(timeout: 2))
        remove.tap()

        XCTAssertTrue(app.staticTexts["¿Retirar el acceso de Ana?"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Ana dejará de poder consultar y registrar información en Nido."].exists)
        app.buttons["Cancelar"].tap()
        XCTAssertTrue(caregiver.exists)
    }

    func testSleepRegistrationUsesStartAndEndDates() {
        launch(scenario: "ready")

        let activityButton = app.buttons["registration-action-button"]
        XCTAssertTrue(activityButton.waitForExistence(timeout: 3))
        activityButton.tap()
        app.buttons["Registrar sueño"].tap()

        XCTAssertTrue(app.navigationBars["Sueño"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Desde"].exists)
        XCTAssertTrue(app.staticTexts["Hasta"].exists)
        XCTAssertFalse(app.staticTexts["Fecha y hora"].exists)
    }

    func testActiveSleepStartCanBeEdited() {
        launch(scenario: "active-sleep")

        XCTAssertTrue(app.staticTexts["Marco está durmiendo"].waitForExistence(timeout: 3))
        let editStart = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Editar hora de inicio'")
        ).firstMatch
        XCTAssertTrue(editStart.exists)
        editStart.tap()
        XCTAssertTrue(app.navigationBars["Hora de inicio"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Guardar"].exists)
    }

    func testTodayTimelineFormatsDurationAsHoursAndMinutes() {
        launch(scenario: "timeline-duration")

        XCTAssertTrue(app.staticTexts["timeline-day-heading"].waitForExistence(timeout: 3))
        let sleep = app.buttons["timeline-activity-ui-test-sleep"]
        XCTAssertTrue(sleep.exists)
        sleep.tap()
        XCTAssertTrue(app.staticTexts["1 h 15 min"].exists)
        XCTAssertFalse(app.staticTexts["75 min"].exists)
    }

    func testLongPressingATodayEntryOpensItsEditor() {
        launch(scenario: "timeline-duration")

        XCTAssertTrue(app.staticTexts["timeline-day-heading"].waitForExistence(timeout: 3))
        let sleepEntry = app.buttons["timeline-activity-ui-test-sleep"]
        XCTAssertTrue(sleepEntry.exists)
        scrollToHittable(sleepEntry)
        sleepEntry.press(forDuration: 1)

        XCTAssertTrue(app.navigationBars["Editar registro"].waitForExistence(timeout: 2))
    }

    func testTodayActivityRowExposesEditButton() {
        launch(scenario: "timeline-duration")

        XCTAssertTrue(app.staticTexts["timeline-day-heading"].waitForExistence(timeout: 3))
        let activityEdit = app.buttons["timeline-edit-activity-ui-test-sleep"]
        XCTAssertTrue(activityEdit.exists)
        XCTAssertEqual(activityEdit.label, "Editar Sueño")
        XCTAssertGreaterThanOrEqual(activityEdit.frame.width, 44)
        XCTAssertGreaterThanOrEqual(activityEdit.frame.height, 44)
        scrollElementIntoViewport(activityEdit, in: app.scrollViews.firstMatch)
        XCTAssertTrue(activityEdit.isHittable)
        activityEdit.tap()
        XCTAssertTrue(app.navigationBars["Editar registro"].waitForExistence(timeout: 2))
    }

    func testTodayHasOneFullEditableActivityListBelowTheGoalPanel() {
        launch(scenario: "circular-timeline")

        let goalPanel = app.descendants(matching: .any)["today-goal-rings"]
        let activityList = app.otherElements["timeline-day-activity-list"]
        XCTAssertTrue(goalPanel.waitForExistence(timeout: 3))
        XCTAssertTrue(activityList.exists)
        XCTAssertFalse(app.otherElements["timeline-latest-events"].exists)
        XCTAssertFalse(app.staticTexts["Últimos registros"].exists)
        XCTAssertTrue(activityList.label.contains("17 registros"))
        XCTAssertTrue(app.buttons["timeline-activity-ui-test-sleep"].exists)
        XCTAssertTrue(app.buttons["timeline-edit-activity-ui-test-sleep"].exists)
    }
    func testDailyGoalSleepQuantityShowsExplicitHourAndMinuteUnits() {
        launch(scenario: "circular-timeline")

        let sleep = app.buttons["day-goal-summary-sleep"]
        XCTAssertTrue(sleep.waitForExistence(timeout: 3))
        let value = sleep.value as? String ?? ""
        XCTAssertTrue(value.contains("11 h 20 min"), "Daily sleep must retain explicit hour and minute units: \(value)")
        XCTAssertTrue(value.localizedCaseInsensitiveContains("sin objetivo"))
    }

    func testTodaySeeAllKeepsMinimumTappableTargetAfterScrolling() {
        launch(scenario: "circular-timeline")

        let seeAll = app.buttons["Ver todo"]
        XCTAssertTrue(seeAll.waitForExistence(timeout: 3))
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.exists)
        for _ in 0..<4 where !seeAll.isHittable {
            let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            start.press(forDuration: 0.05, thenDragTo: end)
        }

        XCTAssertTrue(seeAll.isHittable)
        XCTAssertGreaterThanOrEqual(seeAll.frame.height, 44)
    }

    func testSelectedDayRecordShowsContextBelowTheGoalPanelAndCanReturnToNow() {
        launch(scenario: "circular-timeline")

        let sleepActivity = app.buttons["timeline-activity-ui-test-sleep"]
        XCTAssertTrue(sleepActivity.waitForExistence(timeout: 5))
        sleepActivity.tap()

        let detail = app.descendants(matching: .any)["today-selected-record"]
        XCTAssertTrue(detail.waitForExistence(timeout: 3))
        let goalPanel = app.descendants(matching: .any)["today-goal-rings"]
        XCTAssertGreaterThanOrEqual(detail.frame.minY, goalPanel.frame.maxY)
        XCTAssertTrue(app.buttons["today-clear-selection"].exists)
        app.buttons["today-clear-selection"].tap()
        XCTAssertFalse(detail.exists)
        XCTAssertTrue(app.descendants(matching: .any)["sleep-status-card"].exists)
    }
    func testSleepInteractionRemainsInTheDayActivityListBelowGoalPanel() {
        launch(scenario: "circular-timeline")

        XCTAssertTrue(app.descendants(matching: .any)["today-goal-rings"].waitForExistence(timeout: 3))
        let sleepActivity = app.buttons["timeline-activity-ui-test-sleep"]
        XCTAssertTrue(sleepActivity.exists)
        sleepActivity.tap()
        let selectedRecord = app.descendants(matching: .any)["today-selected-record"]
        XCTAssertTrue(selectedRecord.staticTexts["07:00–08:15"].exists)
        XCTAssertTrue(app.staticTexts["1 h 15 min"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["07:00–08:15"].exists)

        sleepActivity.press(forDuration: 1)
        XCTAssertTrue(app.navigationBars["Editar registro"].waitForExistence(timeout: 2))
    }
    func testSleepControlsFollowTheGoalPanelWhenIdleAndActive() {
        launch(scenario: "circular-timeline")

        var sleepCard = app.descendants(matching: .any)["sleep-status-card"]
        var dial = app.descendants(matching: .any)["today-goal-rings"]
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 3))
        XCTAssertTrue(sleepCard.label.contains("Iniciar"))
        XCTAssertTrue(dial.exists)
        XCTAssertGreaterThanOrEqual(sleepCard.frame.minY, dial.frame.maxY)

        app.terminate()
        launch(scenario: "active-sleep")

        sleepCard = app.descendants(matching: .any)["sleep-status-card"]
        dial = app.descendants(matching: .any)["today-goal-rings"]
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Terminar"].exists)
        XCTAssertTrue(dial.exists)
        XCTAssertGreaterThanOrEqual(sleepCard.frame.minY, dial.frame.maxY)
    }

    func testTenHourSleepActivityFixtureLoads() {
        launch(scenario: "live-activity-ten-hour-sleep")
        XCTAssertTrue(app.staticTexts["timeline-day-heading"].waitForExistence(timeout: 5))
    }

    func testTenMinuteFeedActivityAppearsOnDynamicIsland() throws {
        defer {
            app.terminate()
            launch(scenario: "live-activity-cleanup")
            app.terminate()
        }
        launch(scenario: "live-activity-ten-minute-feed")
        XCTAssertTrue(app.staticTexts["timeline-day-heading"].waitForExistence(timeout: 8))

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        springboard.activate()
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.035)).press(forDuration: 1.0)

        let deadline = Date().addingTimeInterval(5)
        var screenshot = springboard.screenshot()
        var recognizedText = ""
        while Date() < deadline {
            screenshot = springboard.screenshot()
            recognizedText = try recognizedMenuLines(in: screenshot.image)
                .map { normalizedMenuText($0.text) }
                .joined(separator: " ")
            if recognizedText.contains("lactancia") { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Live Activity · lactancia · Dynamic Island expanded"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(
            recognizedText.contains("lactancia"),
            "Expanded system Live Activity should show the lactation label; OCR saw: \(recognizedText)"
        )
    }

    func testSleepActionsMeetTheMinimumTouchTarget() {
        launch(scenario: "circular-timeline")

        var sleepCard = app.descendants(matching: .any)["sleep-status-card"]
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 3))
        XCTAssertTrue(sleepCard.label.contains("Iniciar"))
        XCTAssertGreaterThanOrEqual(sleepCard.frame.height, 44)

        app.terminate()
        launch(scenario: "active-sleep")

        let finishButton = app.buttons["Terminar"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(finishButton.frame.height, 44)
    }

    func testDailyGoalPanelExplainsActualQuantitiesWithoutInventingGoals() {
        launch(scenario: "circular-timeline")

        let ring = app.buttons["daily-goal-ring-graphic"]
        XCTAssertTrue(ring.waitForExistence(timeout: 3))
        XCTAssertTrue(ring.label.contains("Ver el detalle de este día"))

        let expectedMetrics = [
            ("day-goal-summary-sleep", "Sueño"),
            ("day-goal-summary-feed", "Tomas"),
            ("day-goal-summary-diaper", "Pañales"),
        ]
        for (identifier, label) in expectedMetrics {
            let metric = app.buttons[identifier]
            XCTAssertTrue(metric.waitForExistence(timeout: 3), "Missing daily metric: \(identifier)")
            XCTAssertEqual(metric.label, label)
            XCTAssertTrue((metric.value as? String)?.localizedCaseInsensitiveContains("sin objetivo") == true)
        }
    }
    func testDailyGoalMetricControlsHaveComfortableHitAreas() {
        launch(scenario: "circular-timeline")

        let metricIDs = [
            "day-goal-summary-sleep",
            "day-goal-summary-feed",
            "day-goal-summary-diaper",
        ]
        for metricID in metricIDs {
            let metric = app.buttons[metricID]
            XCTAssertTrue(metric.waitForExistence(timeout: 3), "Missing daily metric \(metricID)")
            XCTAssertGreaterThanOrEqual(metric.frame.width, 44)
            XCTAssertGreaterThanOrEqual(metric.frame.height, 44)
            XCTAssertTrue(metric.isHittable, "Daily metric should be an actionable control: \(metricID)")
        }
    }
    func testDailyGoalRingAndMetricsShareAnAccessibleMeaning() {
        launch(scenario: "circular-timeline")

        let ring = app.buttons["daily-goal-ring-graphic"]
        XCTAssertTrue(ring.waitForExistence(timeout: 3))
        XCTAssertTrue(ring.label.contains("Ver el detalle de este día"))

        let metrics = [
            ("day-goal-summary-sleep", "Sueño"),
            ("day-goal-summary-feed", "Tomas"),
            ("day-goal-summary-diaper", "Pañales"),
        ]
        for (identifier, label) in metrics {
            let metric = app.buttons[identifier]
            XCTAssertTrue(metric.waitForExistence(timeout: 3))
            XCTAssertEqual(metric.label, label)
            let value = metric.value as? String ?? ""
            XCTAssertFalse(value.isEmpty, "The \(label) quantity must be announced.")
            XCTAssertTrue(value.localizedCaseInsensitiveContains("sin objetivo"))
        }
    }
    func testTodayPresentsGoalSummaryAndFullActivityList() {
        launch(scenario: "circular-timeline")

        let goalPanel = app.descendants(matching: .any)["today-goal-rings"]
        XCTAssertTrue(goalPanel.waitForExistence(timeout: 3))
        for metric in ["sleep", "feed", "diaper"] {
            XCTAssertTrue(app.buttons["day-goal-summary-\(metric)"].exists)
        }
        XCTAssertFalse(app.otherElements["timeline-latest-events"].exists)

        let activityList = app.otherElements["timeline-day-activity-list"]
        XCTAssertTrue(activityList.exists)
        XCTAssertTrue(activityList.label.contains("Actividad del día"))
    }
    func testDailyGoalPanelPagesToPreviousDayAndBackToToday() {
        launch(scenario: "circular-timeline")

        XCTAssertTrue(app.staticTexts["Hoy con Marco"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Volver a hoy"].exists)
        XCTAssertTrue(app.buttons["daily-goal-ring-graphic"].exists)

        let goalPanel = app.descendants(matching: .any)["today-goal-rings"]
        goalPanel.swipeRight()
        XCTAssertTrue(app.buttons["Volver a hoy"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["daily-goal-ring-graphic"].exists)
        XCTAssertTrue(app.buttons["day-goal-summary-sleep"].exists)
        XCTAssertTrue(app.buttons["day-goal-summary-feed"].exists)
        XCTAssertTrue(app.buttons["day-goal-summary-diaper"].exists)

        app.buttons["Volver a hoy"].tap()
        XCTAssertTrue(app.staticTexts["Hoy con Marco"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Volver a hoy"].exists)
        XCTAssertFalse(app.buttons["Día siguiente"].isEnabled)
        XCTAssertTrue(app.buttons["daily-goal-ring-graphic"].exists)
    }
    func testDenseDayShowsActualGoalQuantitiesWithoutDroppingActivityRows() {
        launch(scenario: "circular-timeline-dense")

        let goalPanel = app.descendants(matching: .any)["today-goal-rings"]
        XCTAssertTrue(goalPanel.waitForExistence(timeout: 3))
        for metric in ["sleep", "feed", "diaper"] {
            let button = app.buttons["day-goal-summary-\(metric)"]
            XCTAssertTrue(button.waitForExistence(timeout: 3))
            XCTAssertTrue((button.value as? String)?.localizedCaseInsensitiveContains("sin objetivo") == true)
        }

        let activityRows = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "timeline-activity-"
        ))
        XCTAssertGreaterThanOrEqual(activityRows.count, 6, "Dense activity must remain available below the goal summary.")
    }
    func testGoalPanelFitsAboveTheTabBarAtNormalTextSize() {
        launch(scenario: "circular-timeline")

        let dial = app.descendants(matching: .any)["today-goal-rings"]
        let registration = app.buttons["registration-action-button"]
        let tabBar = app.floatingNavigationTabBars.firstMatch
        XCTAssertTrue(dial.waitForExistence(timeout: 3))
        XCTAssertTrue(registration.exists)
        XCTAssertTrue(tabBar.exists)
        XCTAssertLessThanOrEqual(dial.frame.maxY, registration.frame.minY - 16)
        XCTAssertLessThanOrEqual(dial.frame.maxY, tabBar.frame.minY - 16)

        app.terminate()
        launch(scenario: "active-sleep")
        let activeDial = app.descendants(matching: .any)["today-goal-rings"]
        let activeRegistration = app.buttons["registration-action-button"]
        XCTAssertTrue(activeDial.waitForExistence(timeout: 3))
        XCTAssertTrue(activeRegistration.exists)
        XCTAssertLessThanOrEqual(activeDial.frame.maxY, activeRegistration.frame.minY - 16)
    }

    func testGoalPanelIsInTheFirstViewportAtAccessibilityXXXL() {
        launch(
            scenario: "circular-timeline",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )

        let dial = app.descendants(matching: .any)["today-goal-rings"]
        let tabBar = app.floatingNavigationTabBars.firstMatch
        XCTAssertTrue(dial.waitForExistence(timeout: 3))
        XCTAssertTrue(tabBar.exists)
        XCTAssertLessThan(dial.frame.minY, tabBar.frame.minY)
        XCTAssertLessThan(dial.frame.minY, app.buttons["registration-action-button"].frame.minY)
    }

    func testTodayGoalPanelHeadingKeepsOrderAndScalesAtLargestAccessibilitySize() {
        launch(scenario: "circular-timeline")
        let normalHeading = app.staticTexts["timeline-day-heading"]
        let normalDayControl = app.buttons["Día anterior"]
        XCTAssertTrue(normalHeading.waitForExistence(timeout: 3))
        XCTAssertTrue(normalDayControl.exists)
        XCTAssertLessThanOrEqual(normalHeading.frame.maxY, normalDayControl.frame.minY)
        let normalHeight = normalHeading.frame.height

        app.terminate()
        launch(
            scenario: "circular-timeline",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )
        let largeHeading = app.staticTexts["timeline-day-heading"]
        let largeDayControl = app.buttons["Día anterior"]
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))
        scrollElementIntoViewport(largeHeading, in: scrollView)
        XCTAssertTrue(largeDayControl.exists)
        XCTAssertGreaterThan(largeHeading.frame.height, normalHeight * 1.5)
        let largeScreenshot = XCTAttachment(screenshot: app.screenshot())
        largeScreenshot.name = "Story heading and daily goal panel at largest text size"
        largeScreenshot.lifetime = .keepAlways
        add(largeScreenshot)
        XCTAssertLessThanOrEqual(
            largeHeading.frame.maxY, largeDayControl.frame.minY,
            "Changing text size must preserve the heading before the activity it introduces."
        )
    }

    func testLargestTextKeepsTheGoalRingUncompressedAndMetricsReachable() {
        launch(
            scenario: "circular-timeline",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )

        let ring = app.buttons["daily-goal-ring-graphic"]
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))
        scrollElementIntoViewport(ring, in: scrollView)
        XCTAssertTrue(ring.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(ring.frame.height, 240)
        XCTAssertGreaterThanOrEqual(ring.frame.width, 240)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Daily goal ring at largest text size"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        for metricID in ["day-goal-summary-sleep", "day-goal-summary-feed", "day-goal-summary-diaper"] {
            let metric = app.buttons[metricID]
            scrollElementIntoViewport(metric, in: scrollView)
            XCTAssertTrue(metric.waitForExistence(timeout: 3), "Missing daily metric \(metricID)")
            XCTAssertTrue(metric.isHittable, "The metric must remain reachable at Accessibility XXXL: \(metricID)")
            XCTAssertGreaterThanOrEqual(metric.frame.height, 44)
            XCTAssertTrue((metric.value as? String)?.localizedCaseInsensitiveContains("sin objetivo") == true)
        }
    }
    func testLargestTextRegistrationActionKeepsACompactReachableLabel() {
        launch(
            scenario: "circular-timeline",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )
        let action = app.buttons["registration-action-button"]
        XCTAssertTrue(action.waitForExistence(timeout: 3))
        XCTAssertEqual(action.label, "Registrar una actividad")
        XCTAssertTrue(action.isHittable)
        XCTAssertLessThanOrEqual(action.frame.height, 110)
    }

    func testTodayStoryHeadingRemainsAvailableAtAccessibilityXXXL() {
        launch(
            scenario: "circular-timeline",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )

        let heading = app.staticTexts["timeline-day-heading"]
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 2))
        scrollElementIntoViewport(heading, in: scrollView)

        XCTAssertTrue(heading.waitForExistence(timeout: 2))
        XCTAssertTrue(heading.isHittable)

        let headingFrame = heading.frame
        let viewportFrame = visibleScrollViewport(in: scrollView)
        XCTAssertGreaterThanOrEqual(headingFrame.minX, viewportFrame.minX)
        XCTAssertLessThanOrEqual(headingFrame.maxX, viewportFrame.maxX)
        XCTAssertGreaterThanOrEqual(headingFrame.minY, viewportFrame.minY)
        XCTAssertLessThanOrEqual(headingFrame.maxY, viewportFrame.maxY)
    }

    func testHistoryFormatsDurationAsHoursAndMinutes() {
        launch(scenario: "timeline-duration")

        app.floatingNavigationTabButtons["Historia"].tap()
        XCTAssertTrue(app.staticTexts["history-detail-date"].waitForExistence(timeout: 2))
        let duration = app.staticTexts.matching(identifier: "1 h 15 min").firstMatch
        bringHistoryElementIntoView(duration)
        XCTAssertTrue(duration.exists)
        XCTAssertFalse(app.staticTexts["75 min"].exists)
    }

    func testHistoryDayPickerAndDailySummaryControlTheSelectedDay() {
        launch(scenario: "history-calendar")

        app.floatingNavigationTabButtons["Historia"].tap()
        let dayPicker = app.buttons["history-day-picker"]
        XCTAssertTrue(dayPicker.waitForExistence(timeout: 3))
        XCTAssertTrue(dayPicker.label.contains("viernes, 28 de agosto"))

        let previousDay = app.buttons["history-week-day-2026-08-27"]
        XCTAssertTrue(previousDay.exists)
        previousDay.tap()
        XCTAssertTrue(previousDay.isSelected)
        XCTAssertEqual(app.staticTexts["history-detail-date"].value as? String, "2026-08-27")
        XCTAssertTrue(app.descendants(matching: .any)["history-detail-day-2026-08-27"].exists)
        for category in ["sleep", "feed", "diaper"] {
            XCTAssertTrue(app.buttons["history-summary-\(category)"].exists)
        }

        dayPicker.tap()
        let calendarGrid = app.descendants(matching: .any)["history-calendar-grid"]
        XCTAssertTrue(calendarGrid.waitForExistence(timeout: 2))
        let futureDay = app.buttons["history-calendar-day-2026-08-29"]
        XCTAssertTrue(futureDay.exists)
        XCTAssertFalse(futureDay.isEnabled)

        app.buttons["history-calendar-day-2026-08-26"].tap()
        let calendarDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: calendarGrid
        )
        XCTAssertEqual(XCTWaiter.wait(for: [calendarDismissed], timeout: 5), .completed)
        for category in ["sleep", "feed", "diaper"] {
            XCTAssertTrue(app.buttons["history-summary-\(category)"].exists)
        }
        XCTAssertTrue(app.buttons["history-week-day-2026-08-26"].isSelected)
    }

    func testHistoryWeekDaysHaveComfortableTargetsOnCompactIPhone() {
        launch(scenario: "history-calendar")

        app.floatingNavigationTabButtons["Historia"].tap()
        let strip = app.scrollViews["history-week-strip"]
        XCTAssertTrue(strip.waitForExistence(timeout: 3))
        let dates = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "history-week-day-"
        )).allElementsBoundByIndex.map(\.identifier).sorted()
        XCTAssertEqual(dates.count, 7)
        XCTAssertTrue(app.buttons[dates[0]].exists)
        for identifier in dates.dropFirst() {
            let day = app.buttons[identifier]
            XCTAssertTrue(day.waitForExistence(timeout: 3), "Missing day: \(identifier)")
            XCTAssertGreaterThanOrEqual(day.frame.width, 44, "Narrow target: \(identifier)")
            XCTAssertGreaterThanOrEqual(day.frame.height, 44, "Short target: \(identifier)")
        }

        let previousRecordedDay = app.buttons["history-week-day-2026-08-27"]
        XCTAssertTrue(previousRecordedDay.waitForExistence(timeout: 3))
        previousRecordedDay.tap()
        XCTAssertTrue(previousRecordedDay.isSelected)
        XCTAssertFalse(app.buttons["history-week-day-2026-08-29"].isEnabled)
        let oldestDay = app.buttons[dates[0]]
        XCTAssertGreaterThanOrEqual(oldestDay.frame.width, 44)
        oldestDay.tap()
        XCTAssertTrue(oldestDay.isSelected)
        XCTAssertEqual(app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "history-week-day-"
        )).count, 7)
    }

    func testPediatricReportCanBePreparedFromDurationEntry() {
        launch(scenario: "timeline-duration")

        app.floatingNavigationTabButtons["Ajustes"].tap()
        let prepareReport = app.buttons["Preparar informe de 30 días"]
        for _ in 0..<3 where !prepareReport.exists {
            app.swipeUp()
        }
        XCTAssertTrue(prepareReport.exists)
        prepareReport.tap()

        XCTAssertTrue(app.buttons["Compartir informe de 30 días"].waitForExistence(timeout: 3))
    }

    func testEditingADiaperUpdatesItsTimelineTime() {
        launch(scenario: "diaper-edit")

        app.floatingNavigationTabButtons["Historia"].tap()
        let diaperEntry = app.buttons["history-entry-ui-test-diaper"]
        bringHistoryElementIntoView(diaperEntry)
        XCTAssertTrue(app.staticTexts["15:24"].waitForExistence(timeout: 3))
        diaperEntry.tap()
        XCTAssertTrue(app.navigationBars["Editar registro"].waitForExistence(timeout: 2))

        let timeButton = app.buttons["15:24"]
        XCTAssertTrue(timeButton.waitForExistence(timeout: 2))
        timeButton.tap()
        let hourWheel = app.pickerWheels.element(boundBy: 0)
        XCTAssertTrue(hourWheel.waitForExistence(timeout: 2))
        hourWheel.adjust(toPickerWheelValue: "13")
        dismissTimePickerBeforeSaving()
        app.buttons["Guardar"].tap()

        bringHistoryElementIntoView(app.staticTexts["13:24"])
        XCTAssertTrue(app.staticTexts["13:24"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["15:24"].exists)
    }

    func testCreatingAFeedUsesTheSelectedTimelineTime() {
        launch(scenario: "feed-create")

        let activityButton = app.buttons["registration-action-button"]
        XCTAssertTrue(activityButton.waitForExistence(timeout: 3))
        activityButton.tap()
        app.buttons["Registrar toma"].tap()
        XCTAssertTrue(app.navigationBars["Toma"].waitForExistence(timeout: 2))

        let timeButton = app.buttons["17:50"]
        XCTAssertTrue(timeButton.waitForExistence(timeout: 2))
        timeButton.tap()
        let hourWheel = app.pickerWheels.element(boundBy: 0)
        let minuteWheel = app.pickerWheels.element(boundBy: 1)
        XCTAssertTrue(hourWheel.waitForExistence(timeout: 2))
        XCTAssertTrue(minuteWheel.exists)
        hourWheel.adjust(toPickerWheelValue: "16")
        minuteWheel.adjust(toPickerWheelValue: "00")
        dismissTimePickerBeforeSaving()
        app.buttons["Guardar"].tap()

        let savedFeed = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Toma' AND label CONTAINS '16:00'")
        ).firstMatch
        XCTAssertTrue(savedFeed.waitForExistence(timeout: 3))
        let feedAtDefaultTime = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Toma' AND label CONTAINS '17:50'")
        ).firstMatch
        XCTAssertFalse(feedAtDefaultTime.exists)
    }

    func testQuickDiaperStatesContentsSavesAndCanBeUndone() {
        launch(scenario: "quick-diaper-registration")

        app.buttons["registration-action-button"].tap()
        app.buttons["Registrar pañal"].tap()

        let quickAction = app.buttons["Repetir pañal · Pis y caca"]
        XCTAssertTrue(quickAction.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Añadir detalles"].exists)
        quickAction.tap()

        XCTAssertTrue(app.staticTexts["Pañal registrado · Pis y caca"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Editar"].exists)
        let undo = app.buttons["Deshacer"]
        XCTAssertTrue(undo.exists)

        app.floatingNavigationTabButtons["Historia"].tap()
        XCTAssertTrue(app.staticTexts["history-detail-date"].waitForExistence(timeout: 2))
        let savedDiaperDetail = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Pis y caca'")).firstMatch
        bringHistoryElementIntoView(savedDiaperDetail)
        let diaperDetails = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Pis y caca'"))
        XCTAssertEqual(diaperDetails.count, 2)

        undo.tap()
        XCTAssertEqual(diaperDetails.count, 1)
    }

    func testRepeatLastFeedStatesCopiedSummaryCreatesNewEntryAndOpensEdit() {
        launch(scenario: "repeat-feed-registration")

        app.buttons["registration-action-button"].tap()
        app.buttons["Registrar toma"].tap()

        XCTAssertTrue(app.staticTexts["Biberón · Fórmula · 120 ml"].waitForExistence(timeout: 2))
        let repeatAction = app.buttons["Repetir última toma"]
        XCTAssertTrue(repeatAction.exists)
        repeatAction.tap()

        XCTAssertTrue(app.staticTexts["Toma registrada · Biberón · Fórmula · 120 ml"].waitForExistence(timeout: 3))
        let edit = app.buttons["Editar"]
        let undo = app.buttons["Deshacer"]
        XCTAssertTrue(edit.exists)
        XCTAssertTrue(undo.exists)
        edit.tap()

        XCTAssertTrue(app.navigationBars["Editar registro"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Fórmula"].exists)
        XCTAssertEqual(app.textFields["Cantidad"].value as? String, "120")
        app.buttons["Cancelar"].tap()

        XCTAssertTrue(undo.waitForExistence(timeout: 2))
        undo.tap()
        app.floatingNavigationTabButtons["Historia"].tap()
        XCTAssertTrue(app.staticTexts["history-detail-date"].waitForExistence(timeout: 2))
        let originalFeed = app.buttons["history-entry-ui-test-latest-feed"]
        if !scrollHistoryElementIntoView(originalFeed) {
            let dayWithOriginalFeed = app.buttons.matching(NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "history-week-day-", "1 tomas"
            )).firstMatch
            XCTAssertTrue(dayWithOriginalFeed.waitForExistence(timeout: 5))
            dayWithOriginalFeed.tap()
            bringHistoryElementIntoView(originalFeed)
        }
        XCTAssertTrue(originalFeed.waitForExistence(timeout: 5))
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-entry-'" )).count,
            1
        )
    }

    private func scrollToHittable(_ element: XCUIElement) {
        var previousFrame = element.frame
        while !element.isHittable {
            app.swipeUp()
            let currentFrame = element.frame
            XCTAssertNotEqual(currentFrame, previousFrame, "Scrolling made no progress toward the target element")
            previousFrame = currentFrame
        }
    }

    @discardableResult
    private func scrollHistoryElementIntoView(_ element: XCUIElement, maximumSwipes: Int = 12) -> Bool {
        let historyScrollView = app.scrollViews.allElementsBoundByIndex
            .filter { $0.isHittable && $0.frame.height > 200 && $0.frame.width > 200 }
            .max { $0.frame.height < $1.frame.height } ?? app.scrollViews.firstMatch
        guard historyScrollView.exists else { return element.isHittable }
        for _ in 0..<maximumSwipes where !element.isHittable {
            historyScrollView.swipeUp()
        }
        return element.isHittable
    }

    private func bringHistoryElementIntoView(_ element: XCUIElement, maximumSwipes: Int = 12) {
        XCTAssertTrue(
            scrollHistoryElementIntoView(element, maximumSwipes: maximumSwipes),
            "Expected History content to be visible before interacting: \(element.identifier)"
        )
    }

    private func replaceText(in element: XCUIElement, with replacement: String) {
        element.tap()
        guard let currentValue = element.value as? String else {
            XCTFail("The editable field must expose its current text before replacement.")
            return
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.5)).tap()
        element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count))
        element.typeText(replacement)
        let replaced = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", replacement),
            object: element
        )
        wait(for: [replaced], timeout: 2)
    }

    private func apiRequest(
        baseURL: String,
        path: String,
        method: String = "GET",
        token: String? = nil,
        body: [String: Any]? = nil
    ) async throws -> (status: Int, payload: [String: Any]) {
        var request = URLRequest(url: try XCTUnwrap(URL(string: baseURL + path)))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return (http.statusCode, payload)
    }

    private func dismissTimePickerBeforeSaving() {
        let before = XCTAttachment(screenshot: app.screenshot())
        before.name = "Time picker before dismissal"
        before.lifetime = .keepAlways
        add(before)

        let navigationBar = app.navigationBars.firstMatch
        XCTAssertTrue(navigationBar.exists)
        navigationBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForNonExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Guardar"].isHittable)
    }

    private func assertFloatingNavigationTabLabelContrast(
        appearance: String,
        dark: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        launch(scenario: "ready", appearance: appearance, useSystemDynamicType: true)
        XCTAssertTrue(app.staticTexts["Hoy con Marco"].waitForExistence(timeout: 5))
        assertRenderedAppearance(dark ? .dark : .light)

        let tabBar = app.floatingNavigationTabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
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

        var failures: [(title: String, ratio: CGFloat, foreground: CGFloat, background: CGFloat, image: UIImage, crop: CGRect)] = []
        for selected in expectedTabs {
            let selectedTab = app.buttons[selected.id]
            XCTAssertTrue(selectedTab.waitForExistence(timeout: 5), "Missing tab button \(selected.id).")
            XCTAssertTrue(selectedTab.isHittable, "Tab button \(selected.id) must be hittable.")
            selectedTab.tap()
            XCTAssertTrue(selectedTab.isSelected, "Tapping \(selected.title) must select it before pixel sampling.")
            let screenshot = app.screenshot()
            let image = screenshot.image
            let windowFrame = app.windows.firstMatch.frame
            for expected in expectedTabs {
                let tab = app.buttons[expected.id]
                XCTAssertTrue(tab.waitForExistence(timeout: 5), "Missing tab button \(expected.id).")
                XCTAssertTrue(tab.isHittable, "Tab button \(expected.id) must be hittable.")
                let titleElement = tab.buttons.matching(NSPredicate(format: "label == %@", expected.title)).firstMatch
                XCTAssertTrue(
                    titleElement.waitForExistence(timeout: 3),
                    "Tab \(expected.id) must expose its visible title as a nested accessibility element."
                )
                let titleFrame = titleElement.frame
                let buttonFrame = tab.frame
                XCTAssertGreaterThan(titleFrame.width, 0, "Tab title \(expected.title) must have a visible frame.")
                XCTAssertGreaterThan(titleFrame.height, 0, "Tab title \(expected.title) must have a visible frame.")
                XCTAssertLessThan(
                    titleFrame.height, buttonFrame.height,
                    "The nested accessibility element should describe the title only, not the icon and title as one frame."
                )
                XCTAssertGreaterThanOrEqual(
                    titleFrame.minY, buttonFrame.minY + buttonFrame.height * 0.5,
                    "The nested title frame should lie below the tab icon, in the lower caption region."
                )
                XCTAssertTrue(
                    buttonFrame.insetBy(dx: -1, dy: -1).contains(titleFrame),
                    "Title \(expected.title) must be inside its tab button: title=\(titleFrame), button=\(buttonFrame)."
                )

                let measurement = try renderedTabLabelContrast(
                    image: image,
                    appFrame: windowFrame,
                    buttonFrame: buttonFrame,
                    titleFrame: titleFrame,
                    dark: dark
                )
                print(
                    "NIDO_FLOATING_TAB_CONTRAST: appearance=\(appearance) selected=\(selected.title) " +
                    "title=\(expected.title) ratio=\(measurement.ratio) " +
                    "foregroundL=\(measurement.foreground) backgroundMedianL=\(measurement.background) " +
                    "titleFrame=\(titleFrame)"
                )
                if measurement.ratio < 4.5 {
                    failures.append((expected.title, measurement.ratio, measurement.foreground, measurement.background, image, measurement.crop))
                }
            }
        }

        guard failures.isEmpty else {
            let fullScreenshot = XCTAttachment(screenshot: app.screenshot())
            fullScreenshot.name = "Floating navigation contrast failure (\(appearance)) full screenshot"
            fullScreenshot.lifetime = .keepAlways
            add(fullScreenshot)
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "Floating navigation contrast failure (\(appearance)) accessibility hierarchy"
            tree.lifetime = .keepAlways
            add(tree)
            for failure in failures {
                let full = XCTAttachment(image: failure.image)
                full.name = "Floating navigation \(failure.title) contrast failure (\(appearance)) source screenshot"
                full.lifetime = .keepAlways
                add(full)
                if let crop = croppedAttachmentImage(failure.image, points: failure.crop, appFrame: app.windows.firstMatch.frame) {
                    let attachment = XCTAttachment(image: crop)
                    attachment.name = "Floating navigation \(failure.title) measured label crop (\(appearance))"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
            XCTFail(
                "Rendered tab-title contrast must be at least 4.5:1 in \(appearance): " +
                failures.map { "\($0.title)=\($0.ratio) (fg \($0.foreground), bg \($0.background))" }.joined(separator: ", "),
                file: file,
                line: line
            )
            return
        }
    }

    private func renderedTabLabelContrast(
        image: UIImage,
        appFrame: CGRect,
        buttonFrame: CGRect,
        titleFrame: CGRect,
        dark: Bool
    ) throws -> (ratio: CGFloat, foreground: CGFloat, background: CGFloat, crop: CGRect) {
        XCTAssertEqual(image.imageOrientation, .up, "Screenshot pixel coordinates require an upright image.")
        let source = try XCTUnwrap(image.cgImage)
        let width = source.width
        let height = source.height
        let scaleX = CGFloat(width) / appFrame.width
        let scaleY = CGFloat(height) / appFrame.height

        func pixelRect(for points: CGRect) -> CGRect {
            let localX = points.minX - appFrame.minX
            let localY = points.minY - appFrame.minY
            let minX = floor(localX * scaleX)
            let minY = floor(localY * scaleY)
            let maxX = ceil((localX + points.width) * scaleX)
            let maxY = ceil((localY + points.height) * scaleY)
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }

        func luminances(in points: CGRect, pixels: [UInt8]) -> [CGFloat] {
            let rect = pixelRect(for: points).integral
            guard rect.width > 0, rect.height > 0,
                  rect.minX >= 0, rect.minY >= 0,
                  rect.maxX <= CGFloat(width), rect.maxY <= CGFloat(height) else { return [] }
            var values: [CGFloat] = []
            values.reserveCapacity(Int(rect.width * rect.height))
            for y in Int(rect.minY)..<Int(rect.maxY) {
                for x in Int(rect.minX)..<Int(rect.maxX) {
                    let offset = (y * width + x) * 4
                    func linear(_ byte: UInt8) -> CGFloat {
                        let channel = CGFloat(byte) / 255
                        return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
                    }
                    let luminance = 0.2126 * linear(pixels[offset]) +
                        0.7152 * linear(pixels[offset + 1]) +
                        0.0722 * linear(pixels[offset + 2])
                    values.append(luminance)
                }
            }
            return values
        }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let sRGB = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: sRGB,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

        // A median from the exact title-only crop is conservative when antialiasing
        // or glyph coverage contributes foreground pixels. It measures this local
        // rendered surface, not a worst-case bound for spatially varying glass.
        var titleSamples = luminances(in: titleFrame, pixels: pixels)
        guard titleSamples.count > 100 else {
            XCTFail("Tab title pixel crop must contain enough in-bounds sRGB samples: \(titleSamples.count).")
            return (0, 0, 0, titleFrame.intersection(appFrame))
        }
        titleSamples.sort()
        let background = titleSamples[titleSamples.count / 2]
        let foregroundIndex = Int(CGFloat(titleSamples.count - 1) * (dark ? 0.9 : 0.1))
        let foreground = titleSamples[foregroundIndex]
        let lighter = max(background, foreground)
        let darker = min(background, foreground)
        let ratio = (lighter + 0.05) / (darker + 0.05)
        let crop = CGRect(
            x: buttonFrame.minX,
            y: titleFrame.minY - 4,
            width: buttonFrame.width,
            height: titleFrame.height + 8
        ).intersection(appFrame)
        return (ratio, foreground, background, crop)
    }

    private func croppedAttachmentImage(_ image: UIImage, points: CGRect, appFrame: CGRect) -> UIImage? {
        guard let source = image.cgImage, appFrame.width > 0, appFrame.height > 0 else { return nil }
        let scaleX = CGFloat(source.width) / appFrame.width
        let scaleY = CGFloat(source.height) / appFrame.height
        let pixelRect = CGRect(
            x: floor((points.minX - appFrame.minX) * scaleX),
            y: floor((points.minY - appFrame.minY) * scaleY),
            width: ceil(points.width * scaleX),
            height: ceil(points.height * scaleY)
        ).intersection(CGRect(x: 0, y: 0, width: source.width, height: source.height)).integral
        guard let crop = source.cropping(to: pixelRect), pixelRect.width > 0, pixelRect.height > 0 else { return nil }
        return UIImage(cgImage: crop, scale: image.scale, orientation: .up)
    }

    private func launch(
        scenario: String,
        contentSizeCategory: String? = nil,
        accessToken: String? = nil,
        appearance: String? = nil,
        useSystemDynamicType: Bool = false,
        runID: String? = nil,
        apiBaseURL: String? = nil
    ) {
        app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["NIDO_UI_TEST_APPEARANCE"] = appearance
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = runID ?? UUID().uuidString
        app.launchEnvironment["NIDO_UI_TEST_API_BASE_URL"] = apiBaseURL
            ?? ProcessInfo.processInfo.environment["NIDO_UI_TEST_API_BASE_URL"]
            ?? "http://127.0.0.1:34200"
        if !useSystemDynamicType {
            app.launchEnvironment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"] = contentSizeCategory
                ?? "UICTContentSizeCategoryLarge"
        }
        app.launchEnvironment["NIDO_UI_TEST_ACCESS_TOKEN"] = accessToken
        app.launchArguments += [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", scenario,
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
        ]
        app.launch()
    }

    private func requiredSessionToken(named name: String) throws -> String {
        guard let token = ProcessInfo.processInfo.environment[name], !token.isEmpty else {
            throw XCTSkip("\(name) must contain a provisioned Sign in with Apple session token.")
        }
        return token
    }

}

@MainActor
enum AppearanceScreenshotAssertion {
    static func assertRenderedAppearance(
        _ app: XCUIApplication,
        dark: Bool,
        minimumLightBrightness: Int = 150,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let screenshot = app.screenshot().image.cgImage,
              let data = screenshot.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            XCTFail("Appearance screenshot must expose RGB pixels.", file: file, line: line)
            return
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Rendered \(dark ? "dark" : "light") appearance assertion"
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: "Verify rendered appearance") { activity in
            activity.add(attachment)
        }

        let window = app.windows.firstMatch.frame
        let samplePoint = CGPoint(x: window.minX + 12, y: window.minY + window.height * 0.25)
        XCTAssertTrue(window.contains(samplePoint), "Appearance sample point must be inside the app window.", file: file, line: line)
        let x = Int((samplePoint.x - window.minX) * CGFloat(screenshot.width) / window.width)
        let y = Int((samplePoint.y - window.minY) * CGFloat(screenshot.height) / window.height)
        let bytesPerPixel = screenshot.bitsPerPixel / 8
        guard bytesPerPixel >= 3 else {
            XCTFail("Appearance screenshot must contain RGB channels.", file: file, line: line)
            return
        }
        let offset = y * screenshot.bytesPerRow + x * bytesPerPixel
        guard offset >= 0, offset + 2 < CFDataGetLength(data) else {
            XCTFail("Appearance sample must be inside screenshot bounds.", file: file, line: line)
            return
        }
        let brightness = (0..<3).reduce(0) { $0 + Int(bytes[offset + $1]) } / 3
        let rgb = (0..<3).map { Int(bytes[offset + $0]) }
        print("NIDO_RENDERED_APPEARANCE: requested=\(dark ? "dark" : "light") rgb=\(rgb) brightness=\(brightness)")
        if dark {
            XCTAssertLessThan(brightness, 100, "Dark appearance must render dark paper pixels; got RGB \(rgb), brightness \(brightness).", file: file, line: line)
        } else {
            XCTAssertGreaterThan(brightness, minimumLightBrightness, "Light appearance must render light paper pixels; got RGB \(rgb), brightness \(brightness).", file: file, line: line)
        }
    }
}
