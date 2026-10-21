import XCTest

extension XCUIApplication {
    /// The SwiftUI tab group exposes the `.isTabBar` accessibility trait as an `Other`
    /// element in XCUI snapshots, so query its stable public identifier instead of
    /// `tabBars`. Its four child buttons retain their existing labels and identifiers.
    var floatingNavigationTabBars: XCUIElementQuery {
        otherElements.matching(identifier: "floating-navigation-tabbar")
    }

    var floatingNavigationTabButtons: XCUIElementQuery {
        buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tab-"))
    }

    var floatingNavigationOverlay: XCUIElement {
        otherElements["floating-navigation-overlay"]
    }
}
