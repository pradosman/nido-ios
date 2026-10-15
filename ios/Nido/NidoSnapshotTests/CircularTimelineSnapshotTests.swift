import SnapshotTesting
import SwiftUI
import XCTest

@testable import Nido

@MainActor
final class CircularTimelineSnapshotTests: XCTestCase {
    func testUITestLargestDynamicTypeOverrideReachesLargestAccessibilitySize() async throws {
        let observed = expectation(description: "The hosted child reads the overridden Dynamic Type environment")
        var actualSize: DynamicTypeSize?
        let probe = DynamicTypeEnvironmentProbe { size in
            actualSize = size
            observed.fulfill()
        }
        .modifier(UITestDynamicTypeOverride(
            requestedSize: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ))
        let host = UIHostingController(rootView: probe)
        let previousKeyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        let scene = try XCTUnwrap(previousKeyWindow?.windowScene ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        defer {
            window.isHidden = true
            previousKeyWindow?.makeKey()
        }

        await fulfillment(of: [observed], timeout: 2)
        XCTAssertEqual(try XCTUnwrap(actualSize), .accessibility5)
    }

    func testCircularTimelineDial() async throws {
        try await assertDialSnapshots(
            dynamicTypeSize: .large,
            contentSizeCategory: .large,
            suffix: "light-es",
            testName: "testCircularTimelineDial"
        )
    }

    func testCircularTimelineDialAtLargestStandardText() async throws {
        try await assertDialSnapshots(
            dynamicTypeSize: .xxxLarge,
            contentSizeCategory: .extraExtraExtraLarge,
            suffix: "xxxl-light-es",
            testName: "testCircularTimelineDialAtLargestStandardText"
        )
    }

    func testSelectedEntrySettlesImmediatelyWithReduceMotion() async throws {
        try XCTSkipUnless(
            UIAccessibility.isReduceMotionEnabled,
            "Enable Reduce Motion on the iPhone 16 Pro simulator before running this test."
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Madrid"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 28, hour: 22, minute: 40
        )))
        let identifier = UUID().uuidString
        let suiteName = "com.momentumia.nido.snapshottests.reduce-motion.\(identifier)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "NidoReduceMotion-\(identifier)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let eventHub = RegistrationMutationEventHub()
        let registrationService = NidoRegistrationServices.make(
            cache: LocalCache(fileURL: directory.appending(path: "cache.json")),
            stateDefaults: defaults,
            legacyDefaults: defaults,
            stateStore: RegistrationStateFileStore(fileURL: directory.appending(path: "state.json")),
            eventHub: eventHub,
            credentialOverride: SessionCredential(
                accessToken: "snapshot-test-session",
                expiresAt: now.addingTimeInterval(3_600),
                appleUserID: nil
            )
        )
        let store = NidoStore(
            defaults: defaults,
            now: { now },
            shouldLoadCredential: false,
            registrationService: registrationService,
            registrationEventHub: eventHub
        )
        await store.prepareForUITesting(scenario: "circular-timeline")
        let day = CircularTimeline.day(on: now, entries: store.entries, now: now, calendar: calendar)
        let first = try XCTUnwrap(day.items.first { $0.entry.kind == .feed })
        let second = try XCTUnwrap(day.items.first { $0.entry.kind == .diaper })
        let selection = TimelineSelection(first.entry.id)
        let host = UIHostingController(rootView: ReducedMotionTimeline(
            day: day, selection: selection
        ).environment(store))
        let previousKeyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        let scene = try XCTUnwrap(previousKeyWindow?.windowScene ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        defer {
            window.isHidden = true
            previousKeyWindow?.makeKey()
        }
        try await Task.sleep(for: .milliseconds(300))
        let initial = timelineImage(host.view)

        selection.selectedEntryID = second.entry.id
        try await Task.sleep(for: .milliseconds(20))
        let early = timelineImage(host.view)
        try await Task.sleep(for: .milliseconds(300))
        let settled = timelineImage(host.view)
        for (name, image) in [("initial", initial), ("early", early), ("settled", settled)] {
            let attachment = XCTAttachment(image: image)
            attachment.name = "Reduce Motion selected entry — \(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        let diffing = Diffing<UIImage>.image(precision: 0.995, perceptualPrecision: 0.99)
        XCTAssertNotNil(diffing.diff(initial, settled), "The selected entry must visibly change.")
        XCTAssertNil(
            diffing.diff(early, settled),
            "Reduce Motion must render the selected entry without an intermediate animated state."
        )
    }

    private func timelineImage(_ view: UIView) -> UIImage {
        view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        // Compare the changing dial detail rather than diluting it with the static window.
        let center = CGRect(x: view.bounds.midX - 100, y: view.bounds.midY - 100, width: 200, height: 200)
        guard let cropped = image.cgImage?.cropping(to: center) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    private func assertDialSnapshots(
        dynamicTypeSize: DynamicTypeSize,
        contentSizeCategory: UIContentSizeCategory,
        suffix: String,
        testName: String
    ) async throws {
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
        let cache = LocalCache(fileURL: cacheURL)
        let eventHub = RegistrationMutationEventHub()
        let registrationService = NidoRegistrationServices.make(
            cache: cache,
            stateDefaults: defaults,
            legacyDefaults: defaults,
            stateStore: RegistrationStateFileStore(
                fileURL: cacheURL.deletingLastPathComponent().appending(path: "registration-state.json")
            ),
            eventHub: eventHub,
            credentialOverride: SessionCredential(
                accessToken: "snapshot-test-session",
                expiresAt: now.addingTimeInterval(3_600),
                appleUserID: nil
            )
        )
        let store = NidoStore(
            defaults: defaults,
            now: { now },
            shouldLoadCredential: false,
            registrationService: registrationService,
            registrationEventHub: eventHub
        )
        await store.prepareForUITesting(scenario: "circular-timeline")
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
        .environment(store)
        .environment(\.locale, Locale(identifier: "es_ES"))
        .environment(\.dynamicTypeSize, dynamicTypeSize)
        .preferredColorScheme(.light)
        let traits = UITraitCollection(mutations: { traits in
            traits.userInterfaceStyle = .light
            traits.preferredContentSizeCategory = contentSizeCategory
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
            named: "circular-timeline-350pt-\(suffix)",
            testName: testName
        )
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.99,
                perceptualPrecision: 0.98,
                layout: .fixed(width: 280, height: 280),
                traits: traits
            ),
            named: "circular-timeline-280pt-\(suffix)",
            testName: testName
        )
    }
}

private struct DynamicTypeEnvironmentProbe: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let observe: (DynamicTypeSize) -> Void

    var body: some View {
        Text("Tamaño de texto")
            .onAppear { observe(dynamicTypeSize) }
    }
}

@MainActor
private final class TimelineSelection: ObservableObject {
    @Published var selectedEntryID: String?

    init(_ selectedEntryID: String) {
        self.selectedEntryID = selectedEntryID
    }
}

private struct ReducedMotionTimeline: View {
    let day: CircularTimeline.Day
    @ObservedObject var selection: TimelineSelection

    var body: some View {
        CircularTimelineDayView(
            day: day,
            selectedEntryID: $selection.selectedEntryID,
            expandedClusterID: .constant(nil)
        )
        .frame(width: 350, height: 350)
        .environment(\.locale, Locale(identifier: "es_ES"))
        .environment(\.dynamicTypeSize, .large)
        .preferredColorScheme(.light)
    }
}
