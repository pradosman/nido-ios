import SwiftUI
import Vision
import WidgetKit
import XCTest

@testable import Nido

@MainActor
final class NidoDayWidgetContentTests: XCTestCase {
    func testLegacyWidgetSnapshotPayloadDecodesWithoutNewGoalFields() throws {
        let legacyPayload = Data(#"{"babyName":"Marco","sleepMinutes":192,"feeds":4,"diapers":3,"latestKind":"feed","latestDate":0,"activeKind":null,"activeStartedAt":null,"updatedAt":0}"#.utf8)
        let decoder = JSONDecoder()

        let snapshot = try decoder.decode(NidoWidgetSnapshot.self, from: legacyPayload)

        XCTAssertEqual(snapshot.babyName, "Marco")
        XCTAssertEqual(snapshot.sleepMinutes, 192)
        XCTAssertEqual(snapshot.feeds, 4)
        XCTAssertEqual(snapshot.diapers, 3)
        XCTAssertEqual(snapshot.latestDate, Date(timeIntervalSinceReferenceDate: 0))
        XCTAssertEqual(snapshot.updatedAt, Date(timeIntervalSinceReferenceDate: 0))
        XCTAssertNil(snapshot.sleepGoalMinutes)
        XCTAssertNil(snapshot.feedGoal)
        XCTAssertNil(snapshot.diaperGoal)
    }

    func testWidgetSnapshotKeepsTheV1PayloadKeysAndValues() throws {
        let snapshot = NidoWidgetSnapshot(
            babyName: "Marco", sleepMinutes: 192, feeds: 4, diapers: 3,
            latestKind: "feed", latestDate: Date(timeIntervalSince1970: 1_800),
            activeKind: nil, activeStartedAt: nil, updatedAt: Date(timeIntervalSince1970: 3_600),
            sleepGoalMinutes: 480, feedGoal: 8, diaperGoal: 6
        )
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(snapshot)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let decoded = try JSONDecoder().decode(NidoWidgetSnapshot.self, from: encoded)

        XCTAssertEqual(Set(object.keys), Set([
            "babyName", "sleepMinutes", "feeds", "diapers", "latestKind", "latestDate",
            "updatedAt", "sleepGoalMinutes", "feedGoal", "diaperGoal",
        ]))
        XCTAssertEqual(object["diapers"] as? Int, 3)
        XCTAssertEqual(object["diaperGoal"] as? Int, 6)
        XCTAssertEqual(decoded.latestDate, snapshot.latestDate)
        XCTAssertEqual(decoded.updatedAt, snapshot.updatedAt)
    }

    func testSmallAndMediumWidgetsRenderAllCareCategoryLabels() throws {
        let snapshot = NidoWidgetSnapshot(
            babyName: "Marco", sleepMinutes: 192, feeds: 4, diapers: 3,
            latestKind: "diaper", latestDate: Date(timeIntervalSince1970: 1_800),
            activeKind: nil, activeStartedAt: nil, updatedAt: Date(timeIntervalSince1970: 3_600),
            sleepGoalMinutes: 480, feedGoal: 8, diaperGoal: 6
        )

        let families: [(WidgetFamily, CGFloat, CGFloat)] = [
            (.systemSmall, 170, 170),
            (.systemMedium, 360, 170),
            (.accessoryRectangular, 160, 36),
        ]
        for (family, width, height) in families {
            let modes: [WidgetRenderingMode] = family == .accessoryRectangular
                ? [.fullColor]
                : [.fullColor, .accented, .vibrant]
            for mode in modes {
                let inset: CGFloat = family == .accessoryRectangular ? 0 : 12
                let view = NidoDayWidgetContent(snapshot: snapshot, family: family, renderingMode: mode)
                    .environment(\.locale, Locale(identifier: "es_ES"))
                    .environment(\.colorScheme, .light)
                    .frame(width: width, height: height)
                    .padding(inset)
                    .background(Color.white)
                let hosting = UIHostingController(rootView: view)
                hosting.safeAreaRegions = []
                hosting.view.frame = CGRect(x: 0, y: 0, width: width + inset * 2, height: height + inset * 2)
                hosting.view.setNeedsLayout()
                hosting.view.layoutIfNeeded()
                let format = UIGraphicsImageRendererFormat()
                format.scale = 3
                format.opaque = true
                let image = UIGraphicsImageRenderer(size: hosting.view.bounds.size, format: format).image { _ in
                    hosting.view.drawHierarchy(in: hosting.view.bounds, afterScreenUpdates: true)
                }
                let attachment = XCTAttachment(image: image)
                attachment.name = "widget-\(family)-\(mode)-care-categories-light"
                attachment.lifetime = .keepAlways
                add(attachment)

                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["es-ES"]
                try VNImageRequestHandler(cgImage: try XCTUnwrap(image.cgImage)).perform([request])
                let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")
                    .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
                XCTAssertTrue(text.contains("sueno"), "The \(family)/\(mode) widget should render the sleep category label; OCR saw: \(text).")
                XCTAssertTrue(text.contains("tomas"), "The \(family)/\(mode) widget should render the feeding category label; OCR saw: \(text).")
                XCTAssertTrue(text.contains("panales"), "The \(family)/\(mode) widget should render the diaper category label; OCR saw: \(text).")
            }
        }

        let circularScenarios: [(name: String, activeKind: String?, startedAt: Date?, expectedText: String)] = [
            ("idle-sleep", nil, nil, "3h12m"),
            ("active-sleep", "sleep", Date().addingTimeInterval(-600), "10"),
            ("active-feed", "feed", Date().addingTimeInterval(-600), "10"),
        ]
        for scenario in circularScenarios {
            let circularSnapshot = NidoWidgetSnapshot(
                babyName: "Marco", sleepMinutes: 192, feeds: 4, diapers: 3,
                latestKind: "feed", latestDate: Date(), activeKind: scenario.activeKind,
                activeStartedAt: scenario.startedAt, updatedAt: Date(),
                sleepGoalMinutes: 480, feedGoal: 8, diaperGoal: 6
            )
            let circularView = NidoDayWidgetContent(
                snapshot: circularSnapshot,
                family: .accessoryCircular,
                renderingMode: .fullColor
            )
            .environment(\.locale, Locale(identifier: "es_ES"))
            .environment(\.colorScheme, .light)
            .frame(width: 72, height: 72)
            .background(Color.white)
            let hosting = UIHostingController(rootView: circularView)
            hosting.safeAreaRegions = []
            hosting.view.frame = CGRect(x: 0, y: 0, width: 72, height: 72)
            hosting.view.setNeedsLayout()
            hosting.view.layoutIfNeeded()
            let format = UIGraphicsImageRendererFormat()
            format.scale = 3
            format.opaque = true
            let image = UIGraphicsImageRenderer(size: hosting.view.bounds.size, format: format).image { _ in
                hosting.view.drawHierarchy(in: hosting.view.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "widget-accessory-circular-\(scenario.name)"
            attachment.lifetime = .keepAlways
            add(attachment)

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["es-ES"]
            try VNImageRequestHandler(cgImage: try XCTUnwrap(image.cgImage)).perform([request])
            let recognized = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
                .filter { $0.isLetter || $0.isNumber }
            XCTAssertTrue(
                recognized.contains(scenario.expectedText),
                "The accessory-circular \(scenario.name) view should render its duration/timer; OCR saw: \(recognized)."
            )
            XCTAssertGreaterThan(
                saturatedPixelCount(in: try XCTUnwrap(image.cgImage), xRange: 78..<138, yRange: 63..<129),
                4,
                "The accessory-circular \(scenario.name) view should render a visible category glyph."
            )
        }
    }

    private func saturatedPixelCount(in image: CGImage, xRange: Range<Int>, yRange: Range<Int>) -> Int {
        guard let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return 0 }
        let bytesPerPixel = image.bitsPerPixel / 8
        guard bytesPerPixel >= 3 else { return 0 }
        var count = 0
        for y in yRange where y < image.height {
            for x in xRange where x < image.width {
                let offset = y * image.bytesPerRow + x * bytesPerPixel
                let red = Int(bytes[offset])
                let green = Int(bytes[offset + 1])
                let blue = Int(bytes[offset + 2])
                if max(red, green, blue) - min(red, green, blue) > 24 && max(red, green, blue) > 60 {
                    count += 1
                }
            }
        }
        return count
    }
}
