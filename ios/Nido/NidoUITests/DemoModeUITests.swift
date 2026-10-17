import XCTest

@MainActor
final class DemoModeUITests: XCTestCase {
    func testDemoEntryIsDisabledWhileAppleAuthenticationIsCompleting() {
        let app = launchUITestScenario("apple-auth-completing")
        XCTAssertTrue(app.staticTexts["apple-auth-completing"].waitForExistence(timeout: 5))

        let demoStart = app.buttons["demo-start"]
        XCTAssertTrue(demoStart.waitForExistence(timeout: 5))
        XCTAssertFalse(demoStart.isEnabled, "Demo entry must not race an in-flight Apple sign-in")
    }

    func testAppleSignInIsDisabledWhileDemoEntryIsStarting() {
        let app = launchUITestScenario("demo-starting")
        XCTAssertTrue(app.staticTexts["demo-start-in-progress"].waitForExistence(timeout: 5))

        let appleSignIn = app.descendants(matching: .any)["apple-sign-in"]
        XCTAssertTrue(appleSignIn.waitForExistence(timeout: 5))
        XCTAssertFalse(appleSignIn.isEnabled, "Apple sign-in must not race a demo session transition")
    }

    func testDemoCanBeEnteredWithoutAppleAndExitedBackToAuthentication() {
        let app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = "caregiver-removal"
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchArguments += [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", "caregiver-removal",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
        ]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Ajustes"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Ajustes"].tap()
        let signOut = app.buttons["Cerrar sesión"]
        for _ in 0..<7 where !signOut.isHittable { app.swipeUp() }
        XCTAssertTrue(signOut.isHittable)
        signOut.tap()
        XCTAssertTrue(app.staticTexts["El cuidado familiar, en privado."].waitForExistence(timeout: 10))

        let explore = app.buttons["demo-start"]
        XCTAssertTrue(explore.waitForExistence(timeout: 5), "The shipped sign-in screen must offer demonstration without Apple credentials")
        explore.tap()
        XCTAssertTrue(app.tabBars.buttons["Hoy"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["demo-status"].exists)
        let exit = app.buttons["demo-exit"]
        XCTAssertTrue(exit.isHittable)
        exit.tap()
        XCTAssertTrue(app.staticTexts["El cuidado familiar, en privado."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["demo-start"].exists)
    }

    func testDemoStatusAndExitRemainAvailableAcrossMainTabs() {
        let app = enterDemo()

        for tab in ["Historia", "Ritmos", "Ajustes", "Hoy"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.staticTexts["demo-status"].waitForExistence(timeout: 5), "Demo status should remain visible on the \(tab) tab")
            XCTAssertTrue(app.buttons["demo-exit"].exists, "Demo exit should remain available on the \(tab) tab")
        }
    }

    func testDemoEntryCanBeCreatedAndEditedLocally() {
        let app = enterDemo()
        app.buttons["registration-action-button"].tap()
        app.buttons["Registrar pañal"].tap()
        let addDetails = app.buttons["Añadir detalles"]
        for _ in 0..<4 where !addDetails.isHittable { app.swipeUp() }
        XCTAssertTrue(addDetails.waitForExistence(timeout: 5))
        addDetails.tap()
        let urineChoice = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Pis")).firstMatch
        XCTAssertTrue(urineChoice.waitForExistence(timeout: 5))
        if !urineChoice.isSelected { urineChoice.tap() }

        let note = app.descendants(matching: .any)["entry-note-field"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        note.typeText("Nota demo inicial")
        app.buttons["Guardar"].tap()

        app.tabBars.buttons["Historia"].tap()
        let createdEntry = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
            "history-entry-",
            "Nota demo inicial"
        )).firstMatch
        XCTAssertTrue(createdEntry.waitForExistence(timeout: 10))
        bringHistoryEntryIntoView(createdEntry, in: app)
        createdEntry.tap()

        let editNote = app.descendants(matching: .any)
            .matching(NSPredicate(format: "value == %@", "Nota demo inicial")).firstMatch
        XCTAssertTrue(editNote.waitForExistence(timeout: 5))
        editNote.tap()
        editNote.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 40) + "Nota demo editada")
        app.buttons["Guardar"].tap()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Nota demo editada")).firstMatch.waitForExistence(timeout: 10))
    }

    func testDemoResetRestoresSyntheticStarterRecords() {
        let app = enterDemo()
        app.buttons["registration-action-button"].tap()
        app.buttons["Registrar pañal"].tap()
        let addDetails = app.buttons["Añadir detalles"]
        for _ in 0..<4 where !addDetails.isHittable { app.swipeUp() }
        XCTAssertTrue(addDetails.waitForExistence(timeout: 5))
        addDetails.tap()
        let urineChoice = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Pis")).firstMatch
        XCTAssertTrue(urineChoice.waitForExistence(timeout: 5))
        if !urineChoice.isSelected { urineChoice.tap() }
        let note = app.descendants(matching: .any)["entry-note-field"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        note.typeText("Registro para reiniciar")
        app.buttons["Guardar"].tap()

        let reset = app.buttons["demo-reset"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        reset.tap()
        let history = app.tabBars.buttons["Historia"]
        XCTAssertTrue(history.waitForExistence(timeout: 10))
        history.tap()
        XCTAssertTrue(app.buttons["history-entry-demo-feed-today"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Registro para reiniciar")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["demo-status"].exists)
    }

    func testDemoCanGenerateLocalPediatricReport() {
        let app = enterDemo()
        app.tabBars.buttons["Ajustes"].tap()
        let prepare = app.buttons["Preparar informe de 30 días"]
        for _ in 0..<7 where !prepare.isHittable { app.swipeUp() }
        XCTAssertTrue(prepare.waitForExistence(timeout: 5))
        prepare.tap()
        XCTAssertTrue(app.buttons["Compartir informe de 30 días"].waitForExistence(timeout: 10))
    }

    func testDemoInvitationIsClearlyMarkedAsSyntheticBeforeSharing() {
        let app = enterDemo()
        app.tabBars.buttons["Ajustes"].tap()
        let invite = app.buttons["settings-invite-caregiver"]
        for _ in 0..<6 where !invite.isHittable { app.swipeUp() }
        XCTAssertTrue(invite.waitForExistence(timeout: 5))
        invite.tap()

        let name = app.textFields["Nombre del familiar"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Familiar de prueba")
        app.buttons["Crear"].tap()
        XCTAssertTrue(app.staticTexts["demo-invitation-notice"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["NIDO-DEMO-0001"].exists)
        XCTAssertTrue(app.buttons["Compartir invitación"].exists)

        app.buttons["Cerrar"].tap()
        let invitedCaregiver = app.descendants(matching: .any)
            .matching(identifier: "caregiver-row-demo-invite-1").firstMatch
        XCTAssertTrue(invitedCaregiver.waitForExistence(timeout: 5))
        app.buttons["Cancelar invitación de Familiar de prueba"].tap()
        XCTAssertTrue(app.buttons["Cancelar invitación"].waitForExistence(timeout: 5))
        app.buttons["Cancelar invitación"].tap()
        let removedCaregiver = app.descendants(matching: .any)
            .matching(identifier: "caregiver-row-demo-invite-1").firstMatch
        XCTAssertFalse(removedCaregiver.waitForExistence(timeout: 2))
    }

    func testPendingDemoInvitationSharePreviewSaysCodeIsFictitious() {
        let app = enterDemo()
        app.tabBars.buttons["Ajustes"].tap()
        let share = app.buttons["Volver a compartir la invitación de Alex"]
        for _ in 0..<7 where !share.isHittable { app.swipeUp() }
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        share.tap()

        let disclaimer = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[cd] %@", "Código ficticio de demostración")).firstMatch
        XCTAssertTrue(disclaimer.waitForExistence(timeout: 5),
                      "The share preview must carry the full fictitious-code demonstration disclaimer")
    }

    private func launchUITestScenario(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchArguments += [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", scenario,
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
        ]
        app.launch()
        return app
    }

    private func launchSignedInUITestFixture() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = "caregiver-removal"
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchArguments += [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", "caregiver-removal",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
        ]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Ajustes"].waitForExistence(timeout: 10))
        return app
    }

    private func enterDemo() -> XCUIApplication {
        let app = launchSignedInUITestFixture()
        app.tabBars.buttons["Ajustes"].tap()
        let signOut = app.buttons["Cerrar sesión"]
        for _ in 0..<7 where !signOut.isHittable { app.swipeUp() }
        XCTAssertTrue(signOut.isHittable)
        signOut.tap()
        let demoStart = app.buttons["demo-start"]
        XCTAssertTrue(demoStart.waitForExistence(timeout: 10))
        demoStart.tap()
        XCTAssertTrue(app.tabBars.buttons["Hoy"].waitForExistence(timeout: 10))
        return app
    }

    private func bringHistoryEntryIntoView(_ entry: XCUIElement, in app: XCUIApplication, maximumSwipes: Int = 12) {
        let historyScrollView = app.scrollViews["history-detail-scroll"]
        let scrollView: XCUIElement
        if historyScrollView.exists {
            scrollView = historyScrollView
        } else {
            let scrollViews = app.scrollViews.allElementsBoundByIndex
                .filter { $0.isHittable && $0.frame.height > 200 && $0.frame.width > 200 }
            scrollView = scrollViews.max { $0.frame.height < $1.frame.height } ?? app.scrollViews.firstMatch
        }

        for _ in 0..<maximumSwipes where !entry.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(entry.isHittable, "Expected the created History entry to be visible before editing it.")
    }
}
