import XCTest

@MainActor
final class AccountDeletionAuthorizationUITests: XCTestCase {
    func testOnboardingCanCancelAccountDeletionWithoutCreatingAHome() throws {
        let fixture = OfflineSyncFixtureServer()
        try fixture.start()
        defer { fixture.stop() }

        let app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = "account-deletion-onboarding"
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["NIDO_UI_TEST_API_BASE_URL"] = fixture.baseURL
        app.launchArguments += [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", "account-deletion-onboarding",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
        ]
        app.launch()

        XCTAssertTrue(app.textFields["Tu nombre"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["Nombre del bebé"].exists)
        let accountMenu = app.buttons["account-actions-button"]
        XCTAssertTrue(accountMenu.waitForExistence(timeout: 5))
        XCTAssertTrue(accountMenu.isHittable)
        accountMenu.tap()
        app.buttons["Eliminar cuenta"].tap()
        XCTAssertTrue(app.staticTexts["¿Eliminar tu cuenta?"].waitForExistence(timeout: 3))
        app.buttons["Eliminar definitivamente"].tap()

        XCTAssertTrue(app.staticTexts["Confirma tu identidad"].waitForExistence(timeout: 5))
        app.buttons["account-deletion-cancel"].tap()

        XCTAssertTrue(app.textFields["Tu nombre"].exists)
        XCTAssertTrue(app.textFields["Nombre del bebé"].exists)
        XCTAssertEqual(fixture.appleChallengeRequestCount, 1)
        XCTAssertEqual(fixture.appleSessionRequestCount, 0)
        XCTAssertEqual(fixture.accountDeletionRequestCount, 0)
    }

    func testCaregiverAccessCanCancelAccountDeletionWithoutJoiningAHome() throws {
        let fixture = OfflineSyncFixtureServer()
        try fixture.start()
        defer { fixture.stop() }

        let app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = "account-deletion-caregiver-access"
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["NIDO_UI_TEST_API_BASE_URL"] = fixture.baseURL
        app.launchArguments += [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", "account-deletion-caregiver-access",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
        ]
        app.launch()

        XCTAssertTrue(app.textFields["XXXX-XXXX-XXXX"].waitForExistence(timeout: 10))
        let accountMenu = app.buttons["account-actions-button"]
        XCTAssertTrue(accountMenu.waitForExistence(timeout: 5))
        accountMenu.tap()
        app.buttons["Eliminar cuenta"].tap()
        XCTAssertTrue(app.staticTexts["¿Eliminar tu cuenta?"].waitForExistence(timeout: 3))
        app.buttons["Eliminar definitivamente"].tap()

        XCTAssertTrue(app.staticTexts["Confirma tu identidad"].waitForExistence(timeout: 5))
        app.buttons["account-deletion-cancel"].tap()

        XCTAssertTrue(app.textFields["XXXX-XXXX-XXXX"].exists)
        XCTAssertEqual(fixture.appleChallengeRequestCount, 1)
        XCTAssertEqual(fixture.appleSessionRequestCount, 0)
        XCTAssertEqual(fixture.accountDeletionRequestCount, 0)
    }

    func testStandardSizeRetryButtonMeetsMinimumTapTarget() throws {
        let fixture = OfflineSyncFixtureServer()
        try fixture.start()
        defer { fixture.stop() }

        let app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = "caregiver-permissions"
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["NIDO_UI_TEST_API_BASE_URL"] = fixture.baseURL
        app.launchEnvironment["NIDO_UI_TEST_ACCESS_TOKEN"] = "offline-sync-test-token"
        app.launchEnvironment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"] = "UICTContentSizeCategoryLarge"
        app.launchArguments += [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", "caregiver-permissions",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryLarge",
        ]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Hoy"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Ajustes"].tap()
        let deleteAccount = app.buttons["Eliminar mi cuenta"]
        for _ in 0..<16 where !deleteAccount.isHittable { app.swipeUp() }
        XCTAssertTrue(deleteAccount.waitForExistence(timeout: 5))
        XCTAssertTrue(deleteAccount.isHittable)
        deleteAccount.tap()
        XCTAssertTrue(app.staticTexts["¿Eliminar permanentemente el espacio familiar?"].waitForExistence(timeout: 3))
        app.buttons["Eliminar definitivamente"].tap()

        let retry = app.buttons["account-deletion-refresh-challenge"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(retry.frame.height, 44)
    }

    func testAccessibilitySizeKeepsAuthorizationCopyAndActionsReachable() throws {
        let fixture = OfflineSyncFixtureServer()
        try fixture.start()
        defer { fixture.stop() }

        let app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = "caregiver-permissions"
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["NIDO_UI_TEST_API_BASE_URL"] = fixture.baseURL
        app.launchEnvironment["NIDO_UI_TEST_ACCESS_TOKEN"] = "offline-sync-test-token"
        app.launchEnvironment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"] = "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        app.launchArguments += [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", "caregiver-permissions",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
        ]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Hoy"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Ajustes"].tap()
        let deleteAccount = app.buttons["Eliminar mi cuenta"]
        for _ in 0..<16 where !deleteAccount.isHittable { app.swipeUp() }
        XCTAssertTrue(deleteAccount.waitForExistence(timeout: 5))
        XCTAssertTrue(deleteAccount.isHittable)
        deleteAccount.tap()
        XCTAssertTrue(app.staticTexts["¿Eliminar permanentemente el espacio familiar?"].waitForExistence(timeout: 3))
        app.buttons["Eliminar definitivamente"].tap()

        let instruction = app.staticTexts[
            "Apple te pedirá que confirmes tu identidad. Puedes cancelar antes de confirmar con Apple."
        ]
        XCTAssertTrue(instruction.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(instruction.frame.height, 120, "At accessibility XXXL, the full explanation must wrap across multiple visible lines.")
        let accessibilityScreenshot = XCTAttachment(screenshot: app.screenshot())
        accessibilityScreenshot.name = "Account deletion authorization at accessibility XXXL"
        accessibilityScreenshot.lifetime = .keepAlways
        add(accessibilityScreenshot)
        XCTAssertTrue(instruction.isHittable, "The complete authorization explanation must remain reachable at AX5.")

        let appleButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Apple")).firstMatch
        XCTAssertTrue(appleButton.exists)
        XCTAssertTrue(appleButton.isHittable)
        XCTAssertGreaterThanOrEqual(appleButton.frame.height, 44)

        let retry = app.buttons["account-deletion-refresh-challenge"]
        XCTAssertTrue(retry.exists)
        XCTAssertTrue(retry.isHittable)
        XCTAssertGreaterThanOrEqual(retry.frame.height, 44)
        XCTAssertTrue(app.buttons["account-deletion-cancel"].isHittable)
    }

    func testCancelingAccountDeletionAuthorizationSheetKeepsTheAccountAndSession() throws {
        let fixture = OfflineSyncFixtureServer()
        try fixture.start()
        defer { fixture.stop() }

        let app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = "caregiver-permissions"
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["NIDO_UI_TEST_API_BASE_URL"] = fixture.baseURL
        app.launchEnvironment["NIDO_UI_TEST_ACCESS_TOKEN"] = "offline-sync-test-token"
        app.launchArguments += [
            "-NIDO_UI_TEST_MARKER", "1",
            "-NIDO_UI_TEST_SCENARIO", "caregiver-permissions",
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
        ]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Hoy"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Ajustes"].tap()
        let deleteAccount = app.buttons["Eliminar mi cuenta"]
        for _ in 0..<16 where !deleteAccount.isHittable { app.swipeUp() }
        XCTAssertTrue(deleteAccount.waitForExistence(timeout: 5))
        XCTAssertTrue(deleteAccount.isHittable)
        deleteAccount.tap()
        XCTAssertTrue(app.staticTexts["¿Eliminar permanentemente el espacio familiar?"].waitForExistence(timeout: 3))
        app.buttons["Eliminar definitivamente"].tap()

        XCTAssertTrue(app.staticTexts["Confirma tu identidad"].waitForExistence(timeout: 5))
        app.buttons["account-deletion-cancel"].tap()

        XCTAssertTrue(app.buttons["Cerrar sesión"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Eliminar mi cuenta"].exists)
        XCTAssertEqual(fixture.appleChallengeRequestCount, 1)
        XCTAssertEqual(fixture.appleSessionRequestCount, 0, "Deletion must not create or rotate a Nido session.")
        XCTAssertEqual(fixture.accountDeletionRequestCount, 0, "Cancel must leave the account untouched.")
    }
}
