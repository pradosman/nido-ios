import XCTest

@MainActor
final class NidoWidgetUITests: XCTestCase {
    func testSpringBoardGalleryAddsSmallNidoWidget() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["NIDO_WIDGET_GALLERY_TEST"] == "1"
                || environment["TEST_RUNNER_NIDO_WIDGET_GALLERY_TEST"] == "1" else {
            throw XCTSkip("Set NIDO_WIDGET_GALLERY_TEST=1 or TEST_RUNNER_NIDO_WIDGET_GALLERY_TEST=1 to opt into SpringBoard widget-gallery automation.")
        }

        guard let widget = addSmallNidoWidget() else { return }
        assertSmallWidgetFootprint(widget)
    }

    private func addSmallNidoWidget() -> XCUIElement? {
        let nido = XCUIApplication(bundleIdentifier: "com.momentumia.nido")
        nido.launchEnvironment["NIDO_UI_TEST_SCENARIO"] = "today"
        nido.launchArguments += ["-NIDO_UI_TEST_MARKER", "1", "-NIDO_UI_TEST_SCENARIO", "today"]
        nido.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        defer {
            let screenshot = XCTAttachment(screenshot: springboard.screenshot())
            screenshot.name = "Nido widget gallery and Home Screen state"
            screenshot.lifetime = .keepAlways
            add(screenshot)

            let hierarchy = XCTAttachment(string: springboard.debugDescription)
            hierarchy.name = "SpringBoard accessibility hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        XCUIDevice.shared.press(.home)

        let doneEditing = labeledElement(in: springboard, matching: ["Done", "OK", "Listo"])
        if doneEditing.waitForExistence(timeout: 2) {
            doneEditing.tap()
        }

        let nidoWidgetIconQuery = springboard.icons.matching(
            NSPredicate(format: "identifier == %@ AND value == %@", "Nido", "Widget")
        )
        let widgetCountBeforeGallery = nidoWidgetIconQuery.count

        let appIcons = springboard.icons.matching(
            NSPredicate(format: "identifier == %@ AND (value == nil OR value != %@)", "Nido", "Widget")
        )
        guard appIcons.firstMatch.waitForExistence(timeout: 10) else {
            XCTFail("Nido must be installed before opening the widget gallery.")
            return nil
        }
        let iconDeadline = Date().addingTimeInterval(10)
        var appIcon: XCUIElement?
        repeat {
            appIcon = appIcons.allElementsBoundByIndex.first(where: \.isHittable)
            if appIcon == nil {
                Thread.sleep(forTimeInterval: 0.25)
            }
        } while appIcon == nil && Date() < iconDeadline
        guard let appIcon else {
            XCTFail("SpringBoard must finish restoring the Home Screen before opening Nido's widget gallery.")
            return nil
        }
        appIcon.press(forDuration: 1.5)

        let editHomeScreen = labeledElement(in: springboard, matching: ["Edit Home Screen", "Editar pantalla de inicio"])
        guard editHomeScreen.waitForExistence(timeout: 5) else {
            XCTFail("SpringBoard should offer Home Screen editing for Nido.")
            return nil
        }
        editHomeScreen.tap()

        let editHomeMenu = labeledElement(in: springboard, matching: ["Edit", "Editar"])
        guard editHomeMenu.waitForExistence(timeout: 5) else {
            XCTFail("SpringBoard's edit menu should be available in Home Screen editing mode.")
            return nil
        }
        editHomeMenu.tap()

        let addWidget = labeledElement(in: springboard, matching: ["Add Widget", "Añadir widget", "Agregar widget"])
        guard addWidget.waitForExistence(timeout: 5) else {
            XCTFail("Home Screen editing should expose Add Widget.")
            return nil
        }
        addWidget.tap()

        let searchField = springboard.searchFields.firstMatch
        guard searchField.waitForExistence(timeout: 5) else {
            XCTFail("The widget gallery should expose its search field.")
            return nil
        }
        searchField.tap()
        searchField.typeText("Nido")

        // The gallery search result is the app row; the widget title and supported
        // family choices appear only after selecting that row.
        let nidoGalleryResult = springboard.cells.matching(
            NSPredicate(format: "label == %@", "Nido")
        ).firstMatch
        guard nidoGalleryResult.waitForExistence(timeout: 10) else {
            XCTFail("The system gallery should list the Nido app row for the Nido search.")
            return nil
        }
        nidoGalleryResult.tap()

        let smallWidgetPreview = springboard.buttons.matching(
            NSPredicate(format: "value CONTAINS[c] %@ OR label CONTAINS[c] %@", "Peque", "Small")
        ).firstMatch
        guard smallWidgetPreview.waitForExistence(timeout: 5) else {
            XCTFail("The widget gallery must expose a preview identified as the Small family before adding it.")
            return nil
        }

        let addSelectedWidget = labeledElement(in: springboard, matching: ["Add Widget", "Añadir widget", "Agregar widget"])
        guard addSelectedWidget.waitForExistence(timeout: 5) else {
            XCTFail("The widget detail page should offer Add Widget.")
            return nil
        }
        addSelectedWidget.tap()

        let widgetCountAfterAdd = nidoWidgetIconQuery.count
        guard widgetCountAfterAdd > widgetCountBeforeGallery else {
            XCTFail("Adding a widget should increase the visible Nido widget count from \(widgetCountBeforeGallery) to at least one more.")
            return nil
        }

        let newlyAddedWidget = nidoWidgetIconQuery.element(boundBy: widgetCountBeforeGallery)
        guard newlyAddedWidget.waitForExistence(timeout: 10) else {
            XCTFail("SpringBoard should expose the newly added Nido widget separately from existing widgets and its app icon.")
            return nil
        }
        return newlyAddedWidget
    }

    func testSpringBoardSmallNidoWidgetTintedAndClearAppearances() throws {
        guard ProcessInfo.processInfo.environment["TEST_RUNNER_NIDO_WIDGET_APPEARANCE_TEST"] == "1" else {
            throw XCTSkip("Set TEST_RUNNER_NIDO_WIDGET_APPEARANCE_TEST=1 to opt into SpringBoard appearance automation.")
        }

        guard let widget = addSmallNidoWidget() else { return }
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        defer { attachEvidence(named: "Nido widget appearance final state", from: springboard) }
        assertSmallWidgetFootprint(widget)

        let edit = labeledElement(in: springboard, matching: ["Edit", "Editar"])
        guard edit.waitForExistence(timeout: 5) else {
            attachEvidence(named: "Home Screen edit menu unavailable", from: springboard)
            XCTFail("SpringBoard did not expose Edit in Home Screen editing mode.")
            return
        }
        edit.tap()

        let customize = labeledElement(in: springboard, matching: ["Customize", "Personalizar"])
        guard customize.waitForExistence(timeout: 5) else {
            attachEvidence(named: "Home Screen customization unavailable", from: springboard)
            XCTFail("SpringBoard did not expose Customize after tapping Edit.")
            return
        }
        customize.tap()

        for appearance in [
            (name: "Tinted", labels: ["Tinted", "Tintado", "Tintados", "Teñido", "Teñidos"]),
            (name: "Clear", labels: ["Clear", "Translucent", "Traslúcido", "Transparent", "Transparente"])
        ] {
            let option = labeledElement(in: springboard, matching: appearance.labels)
            guard option.waitForExistence(timeout: 5) else {
                attachEvidence(named: "\(appearance.name) option unavailable", from: springboard)
                XCTFail("SpringBoard customization did not expose the \(appearance.name) appearance option.")
                return
            }
            option.tap()

            let selectedOption = labeledElement(in: springboard, matching: appearance.labels)
            attachEvidence(named: "Nido widget \(appearance.name) appearance", from: springboard)
            guard selectedOption.waitForExistence(timeout: 5) else {
                XCTFail("The \(appearance.name) appearance option disappeared after selection.")
                return
            }
            XCTAssertTrue(
                isObservablySelected(selectedOption),
                "SpringBoard did not expose a selected state for \(appearance.name); value: \(String(describing: selectedOption.value))."
            )
            XCTAssertTrue(widget.waitForExistence(timeout: 5), "Nido widget disappeared in \(appearance.name) appearance.")
            if widget.exists { assertSmallWidgetFootprint(widget) }
        }
    }

    private func assertSmallWidgetFootprint(_ widget: XCUIElement) {
        let frame = widget.frame
        XCTAssertTrue(
            (150...200).contains(frame.width) && (170...220).contains(frame.height),
            "The placed Nido widget should occupy the observed small-family footprint; got \(frame)."
        )
    }

    private func isObservablySelected(_ element: XCUIElement) -> Bool {
        if element.isSelected { return true }
        guard let value = element.value as? String else { return false }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["selected", "seleccionado", "seleccionada", "on", "activado", "activada"].contains(normalized)
    }

    private func attachEvidence(named name: String, from app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "\(name) accessibility hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }

    private func labeledElement(in app: XCUIApplication, matching fragments: [String]) -> XCUIElement {
        let alternatives = fragments.map { NSPredicate(format: "label CONTAINS[c] %@", $0) }
        return app.descendants(matching: .any)
            .matching(NSCompoundPredicate(orPredicateWithSubpredicates: alternatives))
            .firstMatch
    }
}
