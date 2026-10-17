import SwiftUI
import Vision
import XCTest

@testable import Nido

@MainActor
final class HistoryChartContentTests: XCTestCase {
    func testSelectedIntervalsRenderOriginalFeedVolumeAndDiaperTypeAndNotes() throws {
        let (image, _) = try render(entries: [
            entry(
                id: "feed",
                kind: .feed,
                date: dayStart.addingTimeInterval(10 * 3_600 + 5 * 60),
                detail: "Biberón · Fórmula · Tomó bien",
                amountMl: 120
            ),
            entry(
                id: "diaper",
                kind: .diaper,
                date: dayStart.addingTimeInterval(11 * 3_600 + 5 * 60),
                detail: "Pis y caca · Irritación leve"
            ),
        ], selectedKinds: [.feed, .diaper])

        let recognizedText = try recognizedText(in: image)
        XCTAssertTrue(recognizedText.contains("120 ml"), "The selected feed interval must show its original volume. OCR: \(recognizedText)")
        XCTAssertTrue(recognizedText.contains("Biberón"), "The selected feed interval must show its type. OCR: \(recognizedText)")
        XCTAssertTrue(recognizedText.localizedCaseInsensitiveContains("Tomó bien"), "The selected feed interval must show its note. OCR: \(recognizedText)")
        XCTAssertTrue(recognizedText.contains("Pis y caca"), "The selected diaper interval must show its type. OCR: \(recognizedText)")
        XCTAssertTrue(recognizedText.localizedCaseInsensitiveContains("Irritación leve"), "The selected diaper interval must show its note. OCR: \(recognizedText)")
    }

    func testSleepSectionExplainsWhenOverlappingDurationsAreSummed() throws {
        let (image, _) = try render(entries: [
            entry(
                id: "sleep-one",
                kind: .sleep,
                date: dayStart.addingTimeInterval(12 * 3_600),
                detail: "",
                durationMinutes: 60
            ),
            entry(
                id: "sleep-two",
                kind: .sleep,
                date: dayStart.addingTimeInterval(12 * 3_600 + 15 * 60),
                detail: "",
                durationMinutes: 60
            ),
        ], selectedKinds: [])

        let recognizedText = try recognizedText(in: image)
        XCTAssertTrue(
            recognizedText.localizedCaseInsensitiveContains("Algunos registros de sueño se solapan")
                && recognizedText.localizedCaseInsensitiveContains("sus duraciones se suman"),
            "The sleep chart must explain summed overlapping records. OCR: \(recognizedText)"
        )
    }

    private let dayStart = Date(timeIntervalSince1970: 1_777_593_600) // 2026-05-01 00:00 UTC

    private func render(
        entries: [Entry],
        selectedKinds: Set<EntryKind>
    ) throws -> (UIImage, HistoryAnalytics.Snapshot) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let snapshot = HistoryAnalytics.snapshot(
            on: dayStart,
            entries: entries,
            now: dayStart.addingTimeInterval(24 * 3_600),
            calendar: calendar
        )
        let selectedBins = Dictionary(uniqueKeysWithValues: selectedKinds.compactMap { kind in
            snapshot.bins.first(where: { !$0.entryIDs(for: kind).isEmpty }).map { (kind, $0.start) }
        })
        let view = HistoryDayCharts(snapshot: snapshot, selectedBins: .constant(selectedBins))
            .environment(NidoStore(
                now: { self.dayStart.addingTimeInterval(24 * 3_600) },
                shouldLoadCredential: false,
                allowsExternalEffects: false
            ))
            .environment(\.locale, Locale(identifier: "es_ES"))
            .frame(width: 354, alignment: .leading)
            .padding(16)
            .background(NidoTheme.paper)

        let hosting = UIHostingController(rootView: view)
        let size = CGSize(width: 386, height: 1_400)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = hosting
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        hosting.view.frame = window.bounds
        hosting.beginAppearanceTransition(true, animated: false)
        hosting.endAppearanceTransition()
        hosting.view.setNeedsLayout()
        hosting.view.layoutIfNeeded()
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        hosting.view.setNeedsLayout()
        hosting.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(bounds: hosting.view.bounds, format: format)
        var renderedHierarchy = false
        let image = renderer.image { _ in
            renderedHierarchy = hosting.view.drawHierarchy(in: hosting.view.bounds, afterScreenUpdates: true)
        }
        XCTAssertTrue(renderedHierarchy, "The actual history chart hierarchy must finish rendering before OCR.")
        let attachment = XCTAttachment(image: image)
        attachment.name = "history-chart-content-render"
        attachment.lifetime = .keepAlways
        add(attachment)
        return (image, snapshot)
    }

    private func recognizedText(in image: UIImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["es-ES"]
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            // Vision can classify the Latin y as its Cyrillic visual equivalent.
            .replacingOccurrences(of: "\u{0443}", with: "y")
    }

    private func entry(
        id: String,
        kind: EntryKind,
        date: Date,
        detail: String,
        durationMinutes: Int? = nil,
        amountMl: Int? = nil
    ) -> Entry {
        Entry(
            id: id,
            kind: kind,
            title: kind.title,
            detail: detail,
            occurredAt: Int64(date.timeIntervalSince1970 * 1_000),
            durationMinutes: durationMinutes,
            amountMl: amountMl
        )
    }
}
