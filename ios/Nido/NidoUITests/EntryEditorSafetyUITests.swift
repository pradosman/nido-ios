import XCTest

@MainActor
final class EntryEditorSafetyUITests: XCTestCase {
    func testCancellingAnEditedEntryRequiresDiscardAndCanKeepDraft() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = "semantic-edit"
        app.launchEnvironment["NIDO_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["NIDO_UI_TEST_API_BASE_URL"] = "http://127.0.0.1:34200"
        app.launchEnvironment["NIDO_UI_TEST_DYNAMIC_TYPE_SIZE"] = "UICTContentSizeCategoryLarge"
        app.launchArguments += [
            "-NIDO_UI_TEST_MARKER", "1", "-NIDO_UI_TEST_SCENARIO", "semantic-edit",
            "-AppleLanguages", "(es)", "-AppleLocale", "es_ES",
        ]
        app.launch()
        app.floatingNavigationTabButtons["Historia"].tap()
        let entry = app.descendants(matching: .any)["history-entry-ui-test-semantic-diaper"]
        for _ in 0..<3 where !entry.isHittable { app.swipeUp() }
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.tap()
        let editor = app.navigationBars["Editar registro"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        let multilineNote = app.textViews.firstMatch
        let note = multilineNote.waitForExistence(timeout: 2) ? multilineNote : app.textFields.firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 3))
        note.tap()
        note.typeText(" · Borrador que conservar")
        let draft = note.value as? String
        XCTAssertTrue(draft?.contains("Borrador que conservar") == true, "The note must actually contain the draft before testing cancellation")

        app.buttons["Cancelar"].tap()
        let cancellationScreenshot = XCTAttachment(screenshot: app.screenshot())
        cancellationScreenshot.name = "Editor after cancelling a changed note"
        cancellationScreenshot.lifetime = .keepAlways
        add(cancellationScreenshot)
        let cancellationHierarchy = XCTAttachment(string: app.debugDescription)
        cancellationHierarchy.name = "Editor cancellation accessibility hierarchy"
        cancellationHierarchy.lifetime = .keepAlways
        add(cancellationHierarchy)
        let keepEditing = app.buttons["Seguir editando"]
        XCTAssertTrue(keepEditing.waitForExistence(timeout: 3), "Cancelling a changed entry must protect its unsaved draft")
        keepEditing.tap()
        XCTAssertTrue(editor.exists)
        XCTAssertEqual(note.value as? String, draft, "Continuing must retain the exact edited note")

        app.buttons["Cancelar"].tap()
        let discard = app.buttons["Descartar cambios"]
        XCTAssertTrue(discard.waitForExistence(timeout: 3))
        discard.tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: editor)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
    }
}
