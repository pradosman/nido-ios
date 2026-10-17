import Foundation
import CoreGraphics
import XCTest

@testable import Nido

@MainActor
final class PediatricReportTests: XCTestCase {
    func testReportRendererRunsOutsideMainThread() async throws {
        let execution = RendererExecutionRecorder()
        let expectedURL = FileManager.default.temporaryDirectory.appending(path: "nido-report-test.pdf")
        let profile = Profile(caregiverName: "Marco", babyName: "Nido", birthDate: "2026-01-01")

        let result = try await PediatricReport.prepare(
            profile: profile,
            entries: [],
            days: 30,
            render: { _, _, _ in
                execution.recordCurrentThread()
                return expectedURL
            }
        )

        XCTAssertEqual(result, expectedURL)
        XCTAssertEqual(execution.wasMainThread, false, "PDF rendering must not run on the main thread")
    }

    func testReportPreparationProducesPDFData() async throws {
        let profile = Profile(caregiverName: "Marco", babyName: "Nido", birthDate: "2026-01-01")
        let timestamp = Int64(Date.now.timeIntervalSince1970 * 1_000)
        let entries: [Entry] = (0..<150).map { index -> Entry in
            let kind: EntryKind = switch index % 3 {
            case 0: .feed
            case 1: .sleep
            default: .diaper
            }
            return Entry(id: "report-\(index)", kind: kind,
                  title: "Registro \(index)",
                  detail: "Detalle del registro", occurredAt: timestamp - Int64(index * 60_000),
                  durationMinutes: kind == .sleep ? 45 : nil, amountMl: kind == .feed ? 120 : nil)
        }

        let url = try await PediatricReport.prepare(profile: profile, entries: entries, days: 30)
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try Data(contentsOf: url)
        XCTAssertTrue(data.starts(with: Data("%PDF-".utf8)))
        let document = try XCTUnwrap(CGPDFDocument(url as CFURL))
        XCTAssertGreaterThan(document.numberOfPages, 1, "A long report must paginate instead of dropping records")
        let page = try XCTUnwrap(document.page(at: document.numberOfPages))
        XCTAssertEqual(page.getBoxRect(CGPDFBox.mediaBox).size, CGSize(width: 595, height: 842))
    }
}

nonisolated private final class RendererExecutionRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var renderedOnMainThread = false

    var wasMainThread: Bool {
        lock.lock()
        defer { lock.unlock() }
        return renderedOnMainThread
    }

    func recordCurrentThread() {
        lock.lock()
        defer { lock.unlock() }
        renderedOnMainThread = Thread.isMainThread
    }
}
