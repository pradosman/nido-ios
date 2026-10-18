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
                scenario: "ready", caption: "Actividad", size: size
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
                        HistoryFilterButton(title: "Todo", kind: nil, isSelected: true, action: {})
                    } else if scenario == "active-sleep" {
                        SleepCard(compactHeight: false)
                    } else {
                        ActiveFeedCard()
                    }
                }
                .environment(store)
                .environment(\.locale, Locale(identifier: "es_ES"))
                .environment(\.dynamicTypeSize, size)
                .frame(width: 354)
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

    func testChartAccentsUseTheNidoPaletteInSRGB() throws {
        let expected: [(CareCategory, EntryKind, UInt32)] = [
            (.sleep, .sleep, 0xF43B83),
            (.feed, .feed, 0xFFB02E),
            (.diaper, .diaper, 0x00BFAE),
            (.health, .health, 0xC26BFF),
        ]

        for (category, entryKind, hex) in expected {
            let paletteColor = NidoCarePalette.accent(for: category)
            XCTAssertEqual(paletteColor.hex, hex)
            XCTAssertEqual(paletteColor.red, Double((hex >> 16) & 0xFF) / 255, accuracy: 0.000_001)
            XCTAssertEqual(paletteColor.green, Double((hex >> 8) & 0xFF) / 255, accuracy: 0.000_001)
            XCTAssertEqual(paletteColor.blue, Double(hex & 0xFF) / 255, accuracy: 0.000_001)

            let actual = try sRGBComponents(of: UIColor(NidoTheme.chartAccent(for: entryKind)))
            XCTAssertEqual(actual[0], CGFloat(paletteColor.red), accuracy: 1 / 255, "\(category) chart accent must use the Core sRGB palette.")
            XCTAssertEqual(actual[1], CGFloat(paletteColor.green), accuracy: 1 / 255, "\(category) chart accent must use the Core sRGB palette.")
            XCTAssertEqual(actual[2], CGFloat(paletteColor.blue), accuracy: 1 / 255, "\(category) chart accent must use the Core sRGB palette.")
        }
    }

    func testStaticCategoryColorsMatchSmallTextPaletteInEveryAppearance() throws {
        let cases: [(CareCategory, Color)] = [
            (.sleep, NidoTheme.sleep),
            (.feed, NidoTheme.feed),
            (.diaper, NidoTheme.diaper),
            (.health, NidoTheme.care),
        ]
        let appearances: [(CareAppearance, UIUserInterfaceStyle, UIAccessibilityContrast)] = [
            (.light, .light, .normal),
            (.dark, .dark, .normal),
            (.highContrastLight, .light, .high),
            (.highContrastDark, .dark, .high),
        ]

        for (appearance, style, contrast) in appearances {
            let traits = UITraitCollection(mutations: { traits in
                traits.userInterfaceStyle = style
                traits.accessibilityContrast = contrast
            })
            for (category, color) in cases {
                let actual = try resolvedSRGB(color, with: traits)
                let expected = NidoCarePalette.ink(for: category, appearance: appearance)
                XCTAssertEqual(actual[0], CGFloat(expected.red), accuracy: 1 / 255, "\(category) static tint is stale in \(appearance).")
                XCTAssertEqual(actual[1], CGFloat(expected.green), accuracy: 1 / 255, "\(category) static tint is stale in \(appearance).")
                XCTAssertEqual(actual[2], CGFloat(expected.blue), accuracy: 1 / 255, "\(category) static tint is stale in \(appearance).")
            }
        }
    }

    func testCareCategoryGlyphsKeepShortcutFallbackSeparate() {
        XCTAssertEqual(CareCategory.sleep.glyph, .system("moon.fill"))
        XCTAssertEqual(CareCategory.feed.glyph, .system("waterbottle.fill"))
        XCTAssertEqual(CareCategory.diaper.glyph, .diaper)
        XCTAssertEqual(CareCategory.health.glyph, .system("heart.fill"))

        XCTAssertEqual(CareCategory.sleep.shortcutSystemImageName, "moon.fill")
        XCTAssertEqual(CareCategory.feed.shortcutSystemImageName, "waterbottle.fill")
        XCTAssertEqual(CareCategory.diaper.shortcutSystemImageName, "drop.fill")
        XCTAssertEqual(CareCategory.health.shortcutSystemImageName, "heart.fill")
    }

    func testCategorySmallTextInksMeetContrastForEveryAppearance() throws {
        let expectedInks: [(CareAppearance, UIUserInterfaceStyle, UIAccessibilityContrast, [CareCategory: UInt32])] = [
            (.light, .light, .normal, [.sleep: 0xB31557, .feed: 0x875000, .diaper: 0x006D63, .health: 0x8031BB]),
            (.dark, .dark, .normal, [.sleep: 0xF43B83, .feed: 0xFFB02E, .diaper: 0x00BFAE, .health: 0xD5A3FF]),
            (.highContrastLight, .light, .high, [.sleep: 0x85003B, .feed: 0x583000, .diaper: 0x004C45, .health: 0x5A168F]),
            (.highContrastDark, .dark, .high, [.sleep: 0xFF9ABB, .feed: 0xFFD18B, .diaper: 0x7DEBDD, .health: 0xE5C4FF]),
        ]
        let categories = CareCategory.allCases

        for (appearance, style, contrast, expected) in expectedInks {
            let traits = UITraitCollection(mutations: { traits in
                traits.userInterfaceStyle = style
                traits.accessibilityContrast = contrast
            })
            let background = try resolvedSRGB(NidoTheme.paper, with: traits)

            for category in categories {
                let ink = NidoCarePalette.ink(for: category, appearance: appearance)
                XCTAssertEqual(ink.hex, expected[category], "Unexpected \(category) ink for \(appearance).")
                let foreground = [CGFloat(ink.red), CGFloat(ink.green), CGFloat(ink.blue)]
                XCTAssertGreaterThanOrEqual(
                    contrastRatio(foreground, background),
                    4.5,
                    "Small \(category) labels need 4.5:1 against the \(appearance) page surface."
                )
            }
        }
    }

    private func contrastRatio(_ first: UIColor, _ second: UIColor) -> CGFloat {
        let luminances = [relativeLuminance(first), relativeLuminance(second)].sorted(by: >)
        return (luminances[0] + 0.05) / (luminances[1] + 0.05)
    }

    private func contrastRatio(_ first: [CGFloat], _ second: [CGFloat]) -> CGFloat {
        let luminances = [relativeLuminance(first), relativeLuminance(second)].sorted(by: >)
        return (luminances[0] + 0.05) / (luminances[1] + 0.05)
    }

    private func relativeLuminance(_ rgb: [CGFloat]) -> CGFloat {
        func linearize(_ component: CGFloat) -> CGFloat {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearize(rgb[0]) + 0.7152 * linearize(rgb[1]) + 0.0722 * linearize(rgb[2])
    }

    private func resolvedSRGB(_ color: Color, with traits: UITraitCollection) throws -> [CGFloat] {
        try sRGBComponents(of: UIColor(color).resolvedColor(with: traits))
    }

    private func sRGBComponents(of color: UIColor) throws -> [CGFloat] {
        let sRGB = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let converted = try XCTUnwrap(
            color.cgColor.converted(to: sRGB, intent: .relativeColorimetric, options: nil)
        )
        let components = try XCTUnwrap(converted.components)
        XCTAssertGreaterThanOrEqual(components.count, 3)
        return Array(components.prefix(3))
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
