import SwiftUI
import Vision
import XCTest

@testable import Nido

@MainActor
final class SettingsContrastTests: XCTestCase {
    func testActiveSleepCaptionMeetsRenderedSmallTextContrastInAllAppearanceModes() async throws {
        try await assertActiveCardCaptionContrast(scenario: "active-sleep", caption: "está durmiendo")
    }

    func testActiveFeedCaptionMeetsRenderedSmallTextContrastInAllAppearanceModes() async throws {
        try await assertActiveCardCaptionContrast(scenario: "active-feed", caption: "Lactancia en curso")
    }

    func testHistorySelectedFilterMeetsRenderedSmallTextContrastInDarkAppearanceModes() async throws {
        try await assertActiveCardCaptionContrast(
            scenario: "history-calendar", caption: "Todo", styles: [.dark]
        )
    }

    func testActivityListCaptionMeetsRenderedSmallTextContrastAtNormalAndLargestTextSizes() async throws {
        for size in [DynamicTypeSize.large, .accessibility5] {
            try await assertActiveCardCaptionContrast(
                scenario: "ready", caption: "Actividad del día", size: size
            )
        }
    }

    private func assertActiveCardCaptionContrast(
        scenario: String,
        caption: String,
        styles: [UIUserInterfaceStyle] = [.light, .dark],
        size: DynamicTypeSize = .large
    ) async throws {
        let identifier = UUID().uuidString
        let suiteName = "com.momentumia.nido.contrast.\(identifier)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let directory = FileManager.default.temporaryDirectory.appending(path: identifier)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: directory)
        }
        let now = Date(timeIntervalSince1970: 1_787_942_400)
        let eventHub = RegistrationMutationEventHub()
        let registrationService = NidoRegistrationServices.make(
            cache: LocalCache(fileURL: directory.appending(path: "cache.json")),
            stateDefaults: defaults,
            legacyDefaults: defaults,
            stateStore: RegistrationStateFileStore(fileURL: directory.appending(path: "state.json")),
            eventHub: eventHub,
            credentialOverride: SessionCredential(
                accessToken: "contrast-test-session",
                expiresAt: now.addingTimeInterval(3_600),
                appleUserID: nil
            )
        )
        let store = NidoStore(
            api: NidoAPI(baseURL: try XCTUnwrap(URL(string: "http://127.0.0.1:9"))),
            defaults: defaults,
            now: { now },
            shouldLoadCredential: false,
            registrationService: registrationService,
            registrationEventHub: eventHub
        )
        await store.prepareForUITesting(scenario: scenario)

        for style in styles {
            for contrast in [UIAccessibilityContrast.normal, .high] {
                let card = Group {
                    if scenario == "ready" {
                        DayTimelineActivity(
                            day: CircularTimeline.day(
                                on: now, entries: store.entries,
                                activeSleepStartedAt: nil, now: now
                            ),
                            isToday: true,
                            selectedEntryID: .constant(nil),
                            onEdit: { _ in }, onShowAll: {}
                        )
                    } else if scenario == "history-calendar" {
                        HistoryView()
                    } else if scenario == "active-sleep" {
                        SleepCard(compactHeight: false)
                    } else {
                        ActiveFeedCard()
                    }
                }
                .environment(store)
                .environment(\.locale, Locale(identifier: "es_ES"))
                .environment(\.dynamicTypeSize, size)
                .frame(width: 354, height: scenario == "history-calendar" ? 800 : nil)
                .padding(24)
                .background(NidoTheme.paper)
                let hosting = UIHostingController(rootView: card)
                hosting.traitOverrides.userInterfaceStyle = style
                hosting.traitOverrides.accessibilityContrast = contrast
                hosting.traitOverrides.preferredContentSizeCategory = size == .large
                    ? .large : .accessibilityExtraExtraExtraLarge
                let size = hosting.sizeThatFits(in: CGSize(width: 402, height: 1_000))
                let window = UIWindow(frame: CGRect(origin: .zero, size: size))
                window.rootViewController = hosting
                window.isHidden = false
                defer { window.isHidden = true }
                hosting.view.frame = window.bounds
                hosting.view.setNeedsLayout()
                hosting.view.layoutIfNeeded()
                XCTAssertEqual(hosting.traitCollection.userInterfaceStyle, style)
                XCTAssertEqual(hosting.traitCollection.accessibilityContrast, contrast)
                let format = UIGraphicsImageRendererFormat()
                format.scale = 3
                format.opaque = true
                let renderer = UIGraphicsImageRenderer(bounds: hosting.view.bounds, format: format)
                var renderedHierarchy = false
                let image = renderer.image { _ in
                    renderedHierarchy = hosting.view.drawHierarchy(in: hosting.view.bounds, afterScreenUpdates: true)
                }
                XCTAssertTrue(renderedHierarchy, "The real card hierarchy must finish rendering before contrast is measured.")
                let attachment = XCTAttachment(image: image)
                attachment.name = "\(scenario)-style\(style.rawValue)-contrast\(contrast.rawValue)"
                attachment.lifetime = .keepAlways
                add(attachment)
                let measured = try renderedCaptionContrast(image: image, containing: caption)
                XCTAssertGreaterThanOrEqual(
                    measured,
                    4.5,
                    "Actual \(scenario) caption must meet 4.5:1; rendered \(measured):1 for style \(style.rawValue), contrast \(contrast.rawValue)."
                )
            }
        }
    }

    private func renderedCaptionContrast(image: UIImage, containing caption: String) throws -> CGFloat {
        let cgImage = try XCTUnwrap(image.cgImage)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["es-ES"]
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        let observation = try XCTUnwrap(request.results?.first { result in
            result.topCandidates(1).first?.string.localizedCaseInsensitiveContains(caption) == true
        }, "The actual rendered caption must be recognized before measuring its contrast.")
        let recognized = try XCTUnwrap(observation.topCandidates(1).first)
        let captionRange = try XCTUnwrap(recognized.string.range(of: caption, options: .caseInsensitive))
        // Vision may merge several neighboring filter chips into one observation.
        // Measure only the requested word, so other chips cannot supply glyph pixels.
        let bounds = try XCTUnwrap(try recognized.boundingBox(for: captionRange)).boundingBox
        let cropRect = CGRect(
            x: bounds.minX * CGFloat(cgImage.width),
            y: (1 - bounds.maxY) * CGFloat(cgImage.height),
            width: bounds.width * CGFloat(cgImage.width),
            height: bounds.height * CGFloat(cgImage.height)
        ).integral
        let crop = try XCTUnwrap(cgImage.cropping(to: cropRect))
        let width = crop.width
        let height = crop.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        var frequencies: [UInt32: Int] = [:]
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let rgb = UInt32(pixels[index]) << 16 | UInt32(pixels[index + 1]) << 8 | UInt32(pixels[index + 2])
            frequencies[rgb, default: 0] += 1
        }
        let backgroundRGB = try XCTUnwrap(frequencies.max { $0.value < $1.value }?.key)
        func color(_ rgb: UInt32) -> UIColor {
            UIColor(
                red: CGFloat((rgb >> 16) & 255) / 255,
                green: CGFloat((rgb >> 8) & 255) / 255,
                blue: CGFloat(rgb & 255) / 255,
                alpha: 1
            )
        }
        let background = color(backgroundRGB)
        let minimumInteriorPixels = max(3, width * height / 1_000)
        // Discard isolated rasterization noise; measure the most contrasting recurring
        // interior glyph color, rather than antialiased edges. No threshold tolerance:
        // the real caption's composite pixels must reach the full small-text 4.5:1.
        let ratios = frequencies.compactMap { rgb, count -> CGFloat? in
            guard count >= minimumInteriorPixels else { return nil }
            return contrastRatio(color(rgb), background)
        }
        return try XCTUnwrap(ratios.max())
    }

    func testTextOnMossMeetsSmallTextContrastInAllAppearanceModes() {
        let variants: [(UIUserInterfaceStyle, UIAccessibilityContrast)] = [
            (.light, .normal),
            (.dark, .normal),
            (.light, .high),
            (.dark, .high),
        ]

        for (style, contrast) in variants {
            let traits = UITraitCollection(mutations: { traits in
                traits.userInterfaceStyle = style
                traits.accessibilityContrast = contrast
            })
            let foreground = UIColor(NidoTheme.textOnMoss).resolvedColor(with: traits)
            let background = UIColor(NidoTheme.moss).resolvedColor(with: traits)

            XCTAssertGreaterThanOrEqual(
                contrastRatio(foreground, background),
                4.5,
                "Text on moss must meet 4.5:1 for style \(style.rawValue), contrast \(contrast.rawValue)."
            )
        }
    }

    private func contrastRatio(_ first: UIColor, _ second: UIColor) -> CGFloat {
        let luminances = [relativeLuminance(first), relativeLuminance(second)].sorted(by: >)
        return (luminances[0] + 0.05) / (luminances[1] + 0.05)
    }

    private func relativeLuminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)

        func linearize(_ component: CGFloat) -> CGFloat {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
    }
}
