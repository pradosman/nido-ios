import SnapshotTesting
import SwiftUI
import XCTest

@testable import Nido

@MainActor
final class CircularTimelineSnapshotTests: XCTestCase {
    func testCircularTimelineDial() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Madrid"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 28,
            hour: 22,
            minute: 40
        )))
        let suiteName = "com.momentumia.nido.snapshottests.circular-timeline"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let cacheURL = FileManager.default.temporaryDirectory
            .appending(path: "NidoSnapshotTests", directoryHint: .isDirectory)
            .appending(path: "circular-timeline.json")
        let store = NidoStore(
            cache: LocalCache(fileURL: cacheURL),
            defaults: defaults,
            now: { now },
            shouldLoadCredential: false
        )
        store.prepareForUITesting(scenario: "circular-timeline")
        let day = CircularTimeline.day(
            on: now,
            entries: store.entries,
            now: now,
            calendar: calendar
        )
        let view = CircularTimelineDayView(
            day: day,
            selectedEntryID: .constant(nil),
            expandedClusterID: .constant(nil)
        )
        .frame(width: 350, height: 350)
        .environment(store)
        .environment(\.locale, Locale(identifier: "es_ES"))
        .environment(\.dynamicTypeSize, .large)
        .preferredColorScheme(.light)
        let traits = UITraitCollection(mutations: { traits in
            traits.userInterfaceStyle = .light
            traits.preferredContentSizeCategory = .large
            traits.displayScale = 3
        })

        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.99,
                perceptualPrecision: 0.98,
                layout: .fixed(width: 350, height: 350),
                traits: traits
            ),
            named: "circular-timeline-350pt-light-es"
        )
    }
}
