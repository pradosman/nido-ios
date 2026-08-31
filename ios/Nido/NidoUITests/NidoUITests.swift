import XCTest

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
        XCTAssertTrue(app.textFields["Tu nombre"].exists)
        XCTAssertTrue(app.textFields["Nombre del bebé"].exists)
        XCTAssertTrue(app.buttons["Crear espacio"].exists)
        XCTAssertFalse(app.buttons["Crear espacio"].isEnabled)
    }

    func testFreshInstallationCreatesAnIndependentHouseholdAndOnlySeesItsOwnBaby() async throws {
        let baseURL = ProcessInfo.processInfo.environment["NIDO_UI_TEST_API_BASE_URL"] ?? "http://127.0.0.1:34200"
        var bootstrap = URLRequest(url: try XCTUnwrap(URL(string: baseURL + "/api/nido/caregivers/bootstrap")))
        bootstrap.httpMethod = "POST"
        bootstrap.setValue("application/json", forHTTPHeaderField: "Content-Type")
        bootstrap.httpBody = Data(#"{"name":"Owner A","babyName":"Baby A","birthDate":"2026-01-01"}"#.utf8)
        let (credentialData, bootstrapResponse) = try await URLSession.shared.data(for: bootstrap)
        XCTAssertEqual((bootstrapResponse as? HTTPURLResponse)?.statusCode, 201)
        let credential = try XCTUnwrap(JSONSerialization.jsonObject(with: credentialData) as? [String: Any])
        let token = try XCTUnwrap(credential["accessToken"] as? String)
        var profile = URLRequest(url: try XCTUnwrap(URL(string: baseURL + "/api/nido/profile")))
        profile.httpMethod = "PUT"
        profile.setValue("application/json", forHTTPHeaderField: "Content-Type")
        profile.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        profile.httpBody = Data(#"{"caregiverName":"Owner A","babyName":"Baby A","birthDate":"2026-01-01"}"#.utf8)
        let (_, profileResponse) = try await URLSession.shared.data(for: profile)
        XCTAssertEqual((profileResponse as? HTTPURLResponse)?.statusCode, 200)

        launch(scenario: "multi-household")

        XCTAssertTrue(app.staticTexts["El día a día de vuestro bebé."].waitForExistence(timeout: 5))
        app.textFields["Tu nombre"].tap()
        app.textFields["Tu nombre"].typeText("Owner B")
        app.textFields["Nombre del bebé"].tap()
        app.textFields["Nombre del bebé"].typeText("Baby B")
        app.buttons["Crear espacio"].tap()

        XCTAssertTrue(app.staticTexts["Hoy con Baby B"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Baby A"].exists)
        app.buttons["registration-action-button"].tap()
        app.buttons["Registrar pañal"].tap()
        let quickDiaper = app.buttons["Registrar pañal · Pis"]
        XCTAssertTrue(quickDiaper.waitForExistence(timeout: 5))
        quickDiaper.tap()
        let quickRegistrationDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: quickDiaper
        )
        await fulfillment(of: [quickRegistrationDismissed], timeout: 5)
        let history = app.buttons["bottom-nav-history"]
        let historyHittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND hittable == true"),
            object: history
        )
        await fulfillment(of: [historyHittable], timeout: 5)
        history.tap()
        XCTAssertTrue(app.navigationBars["Historia"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Pis"].waitForExistence(timeout: 5))
    }

    func testRealBackendHistoryLoadsAndDisplaysAnEntryBeyondTheFirstFiveHundred() async throws {
        let baseURL = ProcessInfo.processInfo.environment["NIDO_UI_TEST_API_BASE_URL"] ?? "http://127.0.0.1:34200"
        var bootstrap = URLRequest(url: try XCTUnwrap(URL(string: baseURL + "/api/nido/caregivers/bootstrap")))
        bootstrap.httpMethod = "POST"
        bootstrap.setValue("application/json", forHTTPHeaderField: "Content-Type")
        bootstrap.httpBody = Data(#"{"name":"History Owner","babyName":"History Baby","birthDate":"2026-01-01"}"#.utf8)
        let (credentialData, bootstrapResponse) = try await URLSession.shared.data(for: bootstrap)
        XCTAssertEqual((bootstrapResponse as? HTTPURLResponse)?.statusCode, 201)
        let credential = try XCTUnwrap(JSONSerialization.jsonObject(with: credentialData) as? [String: Any])
        let token = try XCTUnwrap(credential["accessToken"] as? String)
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
        app.launchArguments += ["-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]
        app.launch()

        let heading = app.staticTexts["timeline-day-heading"]
        XCTAssertTrue(heading.waitForExistence(timeout: 12))
        XCTAssertTrue(heading.label.contains("History Baby"))
        app.buttons["bottom-nav-history"].tap()
        XCTAssertTrue(app.navigationBars["Historia"].waitForExistence(timeout: 5))
        app.buttons["history-day-picker"].tap()
        XCTAssertTrue(app.navigationBars["Elegir día"].waitForExistence(timeout: 3))
        app.buttons["Mes anterior"].tap()
        let oldDate = app.buttons["history-calendar-day-2026-07-14"]
        XCTAssertTrue(oldDate.waitForExistence(timeout: 3))
        oldDate.tap()
        let distinctiveEntry = app.buttons["history-entry-\(distinctiveEntryID)"]
        for _ in 0..<4 where !distinctiveEntry.exists { app.swipeUp() }
        XCTAssertTrue(distinctiveEntry.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Más allá de la primera página"].exists)
    }

    func testRealBackendCaregiverPermissionsAndRevocation() async throws {
        let baseURL = ProcessInfo.processInfo.environment["NIDO_UI_TEST_API_BASE_URL"] ?? "http://127.0.0.1:34200"
        let bootstrap = try await apiRequest(
            baseURL: baseURL,
            path: "/api/nido/caregivers/bootstrap",
            method: "POST",
            body: ["name": "UI Owner", "babyName": "UI Baby", "birthDate": "2026-01-01"]
        )
        XCTAssertEqual(bootstrap.status, 201)
        let ownerToken = try XCTUnwrap(bootstrap.payload["accessToken"] as? String)
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
            body: ["code": inviteCode]
        )
        XCTAssertEqual(joined.status, 200)
        let caregiverToken = try XCTUnwrap(joined.payload["accessToken"] as? String)
        let caregiver = try XCTUnwrap(joined.payload["caregiver"] as? [String: Any])
        let caregiverID = try XCTUnwrap(caregiver["id"] as? String)

        launch(scenario: "caregiver-permissions", accessToken: caregiverToken)
        XCTAssertTrue(app.staticTexts["Hoy con UI Baby"].waitForExistence(timeout: 8))
        app.buttons["bottom-nav-settings"].tap()
        let profileButton = app.buttons["settings-profile-button"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 5))
        XCTAssertFalse(profileButton.isEnabled)
        XCTAssertFalse(app.buttons["settings-invite-caregiver"].exists)
        XCTAssertTrue(app.staticTexts["Solo el propietario puede gestionar cuidadores y editar el perfil."].exists)
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

        app.buttons["bottom-nav-history"].tap()
        XCTAssertTrue(app.navigationBars["Historia"].waitForExistence(timeout: 5))
        let ownerEntry = app.buttons["history-entry-\(entryID)"]
        XCTAssertTrue(ownerEntry.waitForExistence(timeout: 5))
        ownerEntry.tap()
        XCTAssertTrue(app.navigationBars["Editar registro"].waitForExistence(timeout: 3))
        let detail = app.textFields.firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 3))
        XCTAssertEqual(detail.value as? String, "Owner original detail")
        replaceText(in: detail, with: "Corrected by invited caregiver")
        XCTAssertEqual(detail.value as? String, "Corrected by invited caregiver")
        app.buttons["Guardar"].tap()
        XCTAssertTrue(app.navigationBars["Historia"].waitForExistence(timeout: 5))

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
        let caregiverAccessHeading = app.staticTexts["Únete al espacio familiar."]
        XCTAssertTrue(caregiverAccessHeading.waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["XXXX-XXXX-XXXX"].exists)
        XCTAssertFalse(app.buttons["bottom-nav-history"].exists)
        XCTAssertEqual(owner["role"] as? String, "owner")
    }

    func testReadyHomeAndPrimaryNavigationAreAvailable() {
        launch(scenario: "ready")

        XCTAssertTrue(app.staticTexts["Hoy con Marco"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["bottom-nav-history"].exists)
        XCTAssertTrue(app.buttons["bottom-nav-trends"].exists)
        XCTAssertTrue(app.buttons["bottom-nav-settings"].exists)

        app.buttons["bottom-nav-history"].tap()
        XCTAssertTrue(app.navigationBars["Historia"].waitForExistence(timeout: 2))
    }

    func testSettingsShowsBundleVersionBuildAndOptionalGitRevision() {
        launch(scenario: "ready")

        app.buttons["bottom-nav-settings"].tap()
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

    func testBottomBarUsesFiveEqualSlotsWithoutVisibleLabels() {
        launch(scenario: "ready")

        let items = [
            (identifier: "bottom-nav-today", label: "Hoy"),
            (identifier: "bottom-nav-history", label: "Historia"),
            (identifier: "registration-action-button", label: "Registrar una actividad"),
            (identifier: "bottom-nav-trends", label: "Ritmos"),
            (identifier: "bottom-nav-settings", label: "Ajustes"),
        ]
        let controls = items.map { app.buttons[$0.identifier] }
        for (item, control) in zip(items, controls) {
            XCTAssertTrue(control.waitForExistence(timeout: 3), "Missing bottom bar control: \(control)")
            XCTAssertEqual(control.label, item.label)
        }

        let adjacentSpacing = zip(controls, controls.dropFirst()).map {
            $1.frame.midX - $0.frame.midX
        }
        let horizontalSpread = adjacentSpacing.max()! - adjacentSpacing.min()!
        XCTAssertLessThanOrEqual(
            horizontalSpread,
            1.5,
            "Bottom bar adjacent center spacing differs by \(horizontalSpread) pt: \(adjacentSpacing)"
        )

        let verticalCenters = controls.map { $0.frame.midY }
        let verticalSpread = verticalCenters.max()! - verticalCenters.min()!
        XCTAssertLessThanOrEqual(
            verticalSpread,
            1.5,
            "Bottom bar control center Y coordinates differ by \(verticalSpread) pt: \(verticalCenters)"
        )

        let bottomBar = app.otherElements["nido-bottom-bar"]
        XCTAssertTrue(bottomBar.exists)
        for control in controls {
            XCTAssertTrue(bottomBar.frame.contains(control.frame), "Bottom bar must contain \(control.label)")
        }
        for item in items {
            XCTAssertFalse(
                bottomBar.descendants(matching: .staticText)[item.label].exists,
                "Bottom bar label must not be visually rendered: \(item.label)"
            )
        }

        let registrationButton = controls[2]
        XCTAssertGreaterThanOrEqual(registrationButton.frame.width, 56)
        XCTAssertGreaterThanOrEqual(registrationButton.frame.height, 56)
        controls[1].tap()
        XCTAssertTrue(app.navigationBars["Historia"].waitForExistence(timeout: 2))
        registrationButton.tap()
        XCTAssertTrue(app.buttons["Registrar sueño"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.navigationBars["Historia"].exists)
        XCTAssertTrue(controls[1].isSelected)
    }

    func testMoreTabPresentsRegistrationChoicesWithoutChangingTheSelectedTab() {
        launch(scenario: "ready")

        let tabBar = app.otherElements["nido-bottom-bar"]
        let history = app.buttons["bottom-nav-history"]
        let registrationButton = app.buttons["registration-action-button"]
        let trends = app.buttons["bottom-nav-trends"]
        XCTAssertTrue(history.waitForExistence(timeout: 3))
        XCTAssertTrue(registrationButton.waitForExistence(timeout: 3))
        XCTAssertTrue(trends.exists)
        XCTAssertLessThan(history.frame.midX, registrationButton.frame.midX)
        XCTAssertLessThan(registrationButton.frame.midX, trends.frame.midX)
        XCTAssertGreaterThanOrEqual(registrationButton.frame.width, 56)
        XCTAssertGreaterThanOrEqual(registrationButton.frame.height, 56)
        XCTAssertEqual(registrationButton.label, "Registrar una actividad")
        let tabBarButtonLabels = Set(tabBar.buttons.allElementsBoundByIndex.map(\.label))
        XCTAssertEqual(
            tabBarButtonLabels,
            ["Hoy", "Historia", "Registrar una actividad", "Ritmos", "Ajustes"]
        )
        XCTAssertFalse(tabBar.buttons["Más"].exists)
        XCTAssertFalse(app.staticTexts["Más"].exists)

        history.tap()
        XCTAssertTrue(app.navigationBars["Historia"].waitForExistence(timeout: 2))
        registrationButton.tap()

        for choice in ["Registrar sueño", "Registrar toma", "Registrar pañal", "Registrar cuidados"] {
            XCTAssertTrue(app.buttons[choice].waitForExistence(timeout: 2))
        }
        XCTAssertTrue(app.navigationBars["Historia"].exists)
        XCTAssertTrue(history.isSelected)
    }

    func testSemanticEditorsExposeTheStoredActivityFields() {
        launch(scenario: "semantic-edit")

        app.buttons["bottom-nav-history"].tap()
        XCTAssertTrue(app.navigationBars["Historia"].waitForExistence(timeout: 3))

        let feedEntry = app.descendants(matching: .any)["history-entry-ui-test-semantic-feed"]
        for _ in 0..<3 where !feedEntry.exists { app.swipeUp() }
        feedEntry.tap()
        XCTAssertTrue(app.navigationBars["Editar registro"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Tipo"].exists)
        XCTAssertTrue(app.buttons["Contenido"].exists)
        XCTAssertTrue(app.staticTexts["Fórmula"].exists)
        app.buttons["Cancelar"].tap()

        app.descendants(matching: .any)["history-entry-ui-test-semantic-diaper"].tap()
        XCTAssertTrue(app.staticTexts["¿Qué había en el pañal?"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Pis"].isSelected)
        XCTAssertTrue(app.buttons["Caca"].isSelected)
        app.buttons["Cancelar"].tap()

        app.descendants(matching: .any)["history-entry-ui-test-semantic-care"].tap()
        XCTAssertTrue(app.staticTexts["¿Qué quieres registrar?"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Temperatura"].isSelected)
        XCTAssertTrue(app.staticTexts["Medición"].exists)
    }

    func testActionableUndoRemainsAvailableUntilDismissedOrUsed() {
        launch(scenario: "undo-notice")

        let undo = app.buttons["Deshacer"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        let bottomBar = app.otherElements["nido-bottom-bar"]
        XCTAssertTrue(bottomBar.exists)
        XCTAssertLessThan(undo.frame.maxY, bottomBar.frame.minY)
        sleep(6)
        XCTAssertTrue(undo.exists)
        XCTAssertTrue(app.buttons["Cerrar aviso"].exists)
    }

    func testActiveFeedHasTodayPriorityAndDoesNotAppearOnPreviousDays() {
        launch(scenario: "active-feed")

        let feed = app.descendants(matching: .any)["active-feed-card"]
        let dial = app.otherElements["timeline-circular-dial"]
        XCTAssertTrue(feed.waitForExistence(timeout: 3))
        XCTAssertTrue(dial.exists)
        XCTAssertLessThan(feed.frame.maxY, dial.frame.minY)

        dial.swipeRight()
        XCTAssertFalse(feed.exists)
    }

    func testCaregiverRemovalRequiresExplicitConfirmation() {
        launch(scenario: "caregiver-removal")

        app.buttons["bottom-nav-settings"].tap()
        let caregiver = app.staticTexts["Ana"]
        XCTAssertTrue(caregiver.waitForExistence(timeout: 3))
        caregiver.swipeLeft()
        app.buttons["Retirar"].tap()

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

        XCTAssertTrue(app.staticTexts["Actividad de hoy"].waitForExistence(timeout: 3))
        let sleep = app.buttons["timeline-activity-ui-test-sleep"]
        XCTAssertTrue(sleep.exists)
        sleep.tap()
        XCTAssertTrue(app.staticTexts["1 h 15 min"].exists)
        XCTAssertFalse(app.staticTexts["75 min"].exists)
    }

    func testLongPressingATodayEntryOpensItsEditor() {
        launch(scenario: "timeline-duration")

        XCTAssertTrue(app.staticTexts["Actividad de hoy"].waitForExistence(timeout: 3))
        let sleepEntry = app.buttons["timeline-activity-ui-test-sleep"]
        XCTAssertTrue(sleepEntry.exists)
        scrollToHittable(sleepEntry)
        sleepEntry.press(forDuration: 1)

        XCTAssertTrue(app.navigationBars["Editar registro"].waitForExistence(timeout: 2))
    }

    func testCircularTimelineKeepsSleepInteractionInDayActivityList() {
        launch(scenario: "circular-timeline")

        let dial = app.otherElements["timeline-circular-dial"]
        XCTAssertTrue(dial.waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["today-vertical-timeline"].exists)

        XCTAssertFalse(app.buttons["timeline-event-ui-test-sleep"].exists)
        let sleepActivity = app.buttons["timeline-activity-ui-test-sleep"]
        XCTAssertTrue(sleepActivity.exists)
        sleepActivity.tap()
        XCTAssertTrue(app.staticTexts["1 h 15 min"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["07:00–08:15"].exists)
        XCTAssertTrue(app.otherElements["timeline-dial-center-detail"].exists)

        sleepActivity.press(forDuration: 1)
        XCTAssertTrue(app.navigationBars["Editar registro"].waitForExistence(timeout: 2))
    }

    func testSleepControlsStayAboveTheCircularTimelineWhenIdleAndActive() {
        launch(scenario: "circular-timeline")

        var sleepCard = app.descendants(matching: .any)["sleep-status-card"]
        var dial = app.otherElements["timeline-circular-dial"]
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 3))
        XCTAssertTrue(sleepCard.label.contains("Iniciar"))
        XCTAssertTrue(dial.exists)
        XCTAssertLessThan(sleepCard.frame.maxY, dial.frame.minY)

        app.terminate()
        launch(scenario: "active-sleep")

        sleepCard = app.descendants(matching: .any)["sleep-status-card"]
        dial = app.otherElements["timeline-circular-dial"]
        XCTAssertTrue(sleepCard.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Terminar"].exists)
        XCTAssertTrue(dial.exists)
        XCTAssertLessThan(sleepCard.frame.maxY, dial.frame.minY)
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

    func testCircularTimelineExplainsItsOrientationAndDefaultState() {
        launch(scenario: "circular-timeline")

        let cardinalLabels = [
            (identifier: "timeline-cardinal-0", label: "00:00"),
            (identifier: "timeline-cardinal-360", label: "06:00"),
            (identifier: "timeline-cardinal-720", label: "12:00"),
            (identifier: "timeline-cardinal-1080", label: "18:00"),
        ]
        for cardinal in cardinalLabels {
            let label = app.staticTexts[cardinal.identifier]
            XCTAssertTrue(label.waitForExistence(timeout: 3))
            XCTAssertTrue(label.label.contains(cardinal.label))
        }
        XCTAssertTrue(app.otherElements["timeline-now-marker"].exists)
        let summary = app.otherElements["timeline-dial-default-summary"]
        XCTAssertTrue(summary.exists)
        XCTAssertTrue(summary.label.contains("17 registros hoy"))
        XCTAssertTrue(summary.label.contains("22:40"))
    }

    func testCircularTimelineRenderedMarkerHitAreasStayInsideTheDial() {
        launch(scenario: "circular-timeline")

        let dial = app.otherElements["timeline-circular-dial"]
        XCTAssertTrue(dial.waitForExistence(timeout: 3))

        for feedID in [
            "timeline-event-ui-test-feed-0115",
            "timeline-event-ui-test-feed-0355",
            "timeline-event-ui-test-feed-0850",
            "timeline-event-ui-test-feed-1223",
            "timeline-event-ui-test-feed-1540",
            "timeline-event-ui-test-feed",
            "timeline-event-ui-test-feed-2110",
        ] {
            let feed = app.buttons[feedID]
            XCTAssertTrue(feed.exists, "Missing rendered feed marker \(feedID)")
            XCTAssertTrue(dial.frame.contains(feed.frame), "Feed marker must remain inside the dial")
        }

        for diaperID in [
            "timeline-event-ui-test-diaper-0210",
            "timeline-event-ui-test-diaper-0642",
            "timeline-event-ui-test-diaper-1105",
            "timeline-event-ui-test-diaper-1530",
            "timeline-event-ui-test-diaper-2035",
        ] {
            let diaper = app.buttons[diaperID]
            XCTAssertTrue(diaper.exists, "Missing rendered diaper marker \(diaperID)")
            XCTAssertTrue(dial.frame.contains(diaper.frame), "Diaper marker must remain inside the dial")
        }
    }

    func testCircularTimelineUsesOneCivilClockTrackAndCategorySpecificMarkers() {
        launch(scenario: "circular-timeline")

        let ring = app.otherElements["timeline-day-ring"]
        XCTAssertTrue(ring.waitForExistence(timeout: 3))
        XCTAssertTrue(ring.label.contains("24 horas"))
        XCTAssertTrue(app.otherElements["timeline-clock-ticks"].exists)

        let feeds = app.otherElements["timeline-feed-markers"]
        XCTAssertTrue(feeds.exists)
        XCTAssertTrue(feeds.label.contains("fuera del anillo"))

        let diapers = app.otherElements["timeline-diaper-markers"]
        XCTAssertTrue(diapers.exists)
        XCTAssertTrue(diapers.label.contains("dentro del anillo"))

        let summary = app.otherElements["timeline-center-summary"]
        XCTAssertTrue(summary.exists)
        XCTAssertTrue(summary.label.contains("Sueño"))
        XCTAssertTrue(summary.label.contains("tomas"))
        XCTAssertTrue(summary.label.contains("pañales"))
        XCTAssertFalse(summary.label.contains("Cuidados"))
    }

    func testCircularTimelinePresentsDashboardHierarchy() {
        launch(scenario: "circular-timeline")

        let summary = app.otherElements["timeline-center-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 3))
        for category in ["Sueño", "tomas", "pañales"] {
            XCTAssertTrue(summary.label.contains(category))
        }
        XCTAssertFalse(summary.label.contains("Cuidados"))

        let latestEvents = app.otherElements["timeline-latest-events"]
        XCTAssertTrue(latestEvents.exists)
        XCTAssertTrue(latestEvents.label.contains("Últimos registros"))

        let activityList = app.otherElements["timeline-day-activity-list"]
        XCTAssertTrue(activityList.exists)
        XCTAssertTrue(activityList.label.contains("Actividad del día"))
    }

    func testCircularTimelinePagesToThePreviousDayAndBackToToday() {
        launch(scenario: "circular-timeline")

        XCTAssertTrue(app.staticTexts["Hoy con Marco"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Volver a hoy"].exists)
        let dial = app.otherElements["timeline-circular-dial"]
        XCTAssertTrue(dial.exists)
        XCTAssertTrue(app.otherElements["timeline-now-marker"].exists)
        dial.swipeRight()
        dial.swipeRight()

        XCTAssertTrue(app.buttons["Volver a hoy"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.otherElements["timeline-circular-dial"].exists)
        XCTAssertFalse(app.otherElements["timeline-now-marker"].exists)
        app.buttons["Volver a hoy"].tap()
        XCTAssertTrue(app.staticTexts["Hoy con Marco"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Volver a hoy"].exists)
        XCTAssertFalse(app.buttons["Día siguiente"].isEnabled)
        XCTAssertTrue(app.otherElements["timeline-now-marker"].exists)
    }

    func testDenseCircularTimelineKeepsFeedAndDiaperClustersIndependent() {
        launch(scenario: "circular-timeline-dense")

        let feedCluster = app.buttons["timeline-cluster-feed-480"]
        let diaperCluster = app.buttons["timeline-cluster-diaper-481"]
        XCTAssertTrue(feedCluster.waitForExistence(timeout: 3))
        XCTAssertTrue(diaperCluster.exists)
        XCTAssertTrue(feedCluster.label.contains("3 tomas"))
        XCTAssertTrue(diaperCluster.label.contains("3 pañales"))

        feedCluster.tap()

        XCTAssertTrue(app.otherElements["timeline-cluster-expanded"].waitForExistence(timeout: 2))
        for index in [0, 2, 4] {
            XCTAssertTrue(app.buttons["timeline-expanded-dense-\(index)"].exists)
        }
        app.buttons["Cerrar registros"].tap()

        diaperCluster.tap()
        XCTAssertTrue(app.otherElements["timeline-cluster-expanded"].waitForExistence(timeout: 2))
        for index in [1, 3, 5] {
            XCTAssertTrue(app.buttons["timeline-expanded-dense-\(index)"].exists)
        }

        app.buttons["timeline-expanded-dense-1"].press(forDuration: 1)
        XCTAssertTrue(app.navigationBars["Editar registro"].waitForExistence(timeout: 2))
    }

    func testCircularTimelineFitsAboveTheTabBarAtNormalTextSize() {
        launch(scenario: "circular-timeline")

        let dial = app.otherElements["timeline-circular-dial"]
        let tabBar = app.otherElements["nido-bottom-bar"]
        XCTAssertTrue(dial.waitForExistence(timeout: 3))
        XCTAssertTrue(tabBar.exists)
        XCTAssertLessThanOrEqual(dial.frame.maxY, tabBar.frame.minY - 16)
    }

    func testCircularTimelineIsInTheFirstViewportAtAccessibilityXXXL() {
        launch(
            scenario: "circular-timeline",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )

        let dial = app.otherElements["timeline-circular-dial"]
        let tabBar = app.otherElements["nido-bottom-bar"]
        XCTAssertTrue(dial.waitForExistence(timeout: 3))
        XCTAssertTrue(tabBar.exists)
        XCTAssertLessThan(dial.frame.minY, tabBar.frame.minY)
    }

    func testHistoryFormatsDurationAsHoursAndMinutes() {
        launch(scenario: "timeline-duration")

        app.buttons["bottom-nav-history"].tap()
        XCTAssertTrue(app.navigationBars["Historia"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["1 h 15 min"].exists)
        XCTAssertFalse(app.staticTexts["75 min"].exists)
    }

    func testHistoryDayPickerAndDailyRingsControlTheSelectedDay() {
        launch(scenario: "history-calendar")

        app.buttons["bottom-nav-history"].tap()
        let dayPicker = app.buttons["history-day-picker"]
        XCTAssertTrue(dayPicker.waitForExistence(timeout: 3))
        XCTAssertTrue(dayPicker.label.contains("viernes, 28 de agosto"))

        let previousDay = app.buttons["history-week-day-2026-08-27"]
        XCTAssertTrue(previousDay.exists)
        previousDay.tap()
        XCTAssertTrue(previousDay.isSelected)
        let selectedDaySummary = app.descendants(matching: .any)["history-selected-day-summary"]
        XCTAssertTrue(selectedDaySummary.exists)

        dayPicker.tap()
        let calendarGrid = app.descendants(matching: .any)["history-calendar-grid"]
        XCTAssertTrue(calendarGrid.waitForExistence(timeout: 2))
        let futureDay = app.buttons["history-calendar-day-2026-08-29"]
        XCTAssertTrue(futureDay.exists)
        XCTAssertFalse(futureDay.isEnabled)

        app.buttons["history-calendar-day-2026-08-26"].tap()
        XCTAssertFalse(calendarGrid.exists)
        XCTAssertTrue(selectedDaySummary.exists)
        XCTAssertTrue(app.buttons["history-week-day-2026-08-26"].isSelected)
    }

    func testPediatricReportCanBePreparedFromDurationEntry() {
        launch(scenario: "timeline-duration")

        app.buttons["bottom-nav-settings"].tap()
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

        app.buttons["bottom-nav-history"].tap()
        XCTAssertTrue(app.staticTexts["15:24"].waitForExistence(timeout: 3))
        app.staticTexts["Pañal"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Editar registro"].waitForExistence(timeout: 2))

        let timeButton = app.buttons["15:24"]
        XCTAssertTrue(timeButton.waitForExistence(timeout: 2))
        timeButton.tap()
        let hourWheel = app.pickerWheels.element(boundBy: 0)
        XCTAssertTrue(hourWheel.waitForExistence(timeout: 2))
        hourWheel.adjust(toPickerWheelValue: "13")
        app.buttons["Guardar"].tap()

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

        app.buttons["bottom-nav-history"].tap()
        XCTAssertTrue(app.navigationBars["Historia"].waitForExistence(timeout: 2))
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
        app.buttons["bottom-nav-history"].tap()
        XCTAssertTrue(app.navigationBars["Historia"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["history-entry-ui-test-latest-feed"].exists)
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

    private func replaceText(in element: XCUIElement, with replacement: String) {
        element.tap()
        element.press(forDuration: 1)
        let selectAll = app.menuItems.matching(
            NSPredicate(format: "label IN %@", ["Seleccionar todo", "Select All"])
        ).firstMatch
        XCTAssertTrue(selectAll.waitForExistence(timeout: 2))
        selectAll.tap()
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

    private func launch(scenario: String, contentSizeCategory: String? = nil, accessToken: String? = nil) {
        app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = scenario
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["NIDO_UI_TEST_API_BASE_URL"] = ProcessInfo.processInfo.environment["NIDO_UI_TEST_API_BASE_URL"]
            ?? "http://127.0.0.1:34200"
        app.launchEnvironment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"] = contentSizeCategory
            ?? "UICTContentSizeCategoryLarge"
        app.launchEnvironment["NIDO_UI_TEST_ACCESS_TOKEN"] = accessToken
        app.launchArguments += [
            "-AppleLanguages", "(es)",
            "-AppleLocale", "es_ES",
            "-UIUserInterfaceStyle", "Light",
        ]
        app.launch()
    }

}
