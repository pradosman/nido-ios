import Foundation
import Testing
@testable import NidoCore

@Suite(.serialized)
@MainActor
struct ReportPreparationTests {
    @Test
    func preparationShowsProgressAndPublishesURLOnSuccess() async {
        let preparation = ReportPreparation()
        let gate = ReportPreparationGate()
        let expectedURL = URL(fileURLWithPath: "/tmp/nido-report.pdf")

        let task = Task {
            await preparation.prepare {
                await gate.pauseUntilReleased()
                return expectedURL
            }
        }

        await gate.waitUntilStarted()
        #expect(preparation.isPreparing)
        #expect(preparation.url == nil)
        #expect(preparation.errorMessage == nil)

        await gate.release()
        await task.value
        #expect(!preparation.isPreparing)
        #expect(preparation.url == expectedURL)
        #expect(preparation.errorMessage == nil)
    }

    @Test
    func repeatedRequestWhilePreparingDoesNotStartAnotherOperation() async {
        let preparation = ReportPreparation()
        let gate = ReportPreparationGate()
        let expectedURL = URL(fileURLWithPath: "/tmp/nido-report.pdf")

        let first = Task {
            await preparation.prepare {
                await gate.pauseUntilReleased()
                return expectedURL
            }
        }
        await gate.waitUntilStarted()

        await preparation.prepare {
            await gate.recordDuplicateStarted()
            return URL(fileURLWithPath: "/tmp/duplicate.pdf")
        }
        let duplicateWasStarted = await gate.duplicateWasStarted
        #expect(!duplicateWasStarted)
        #expect(preparation.isPreparing)

        await gate.release()
        await first.value
        #expect(preparation.url == expectedURL)
    }

    @Test
    func leavingSettingsDiscardsAndRemovesAPendingReport() async throws {
        let preparation = ReportPreparation()
        let gate = ReportPreparationGate()
        let file = FileManager.default.temporaryDirectory.appending(path: "report-\(UUID().uuidString).pdf")
        try Data("generated report".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let task = Task {
            await preparation.prepare {
                await gate.pauseUntilReleased()
                return file
            }
        }
        await gate.waitUntilStarted()
        preparation.reset()
        await gate.release()
        await task.value
        #expect(!preparation.isPreparing)
        #expect(preparation.url == nil)
        #expect(preparation.errorMessage == nil)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test
    func failedPreparationShowsErrorAndCanBeRetried() async {
        let preparation = ReportPreparation()
        let expectedURL = URL(fileURLWithPath: "/tmp/nido-report.pdf")

        await preparation.prepare {
            throw ReportPreparationTestError.expectedFailure
        }
        #expect(!preparation.isPreparing)
        #expect(preparation.url == nil)
        #expect(preparation.errorMessage == "No se pudo preparar el informe")

        await preparation.prepare { expectedURL }
        #expect(!preparation.isPreparing)
        #expect(preparation.url == expectedURL)
        #expect(preparation.errorMessage == nil)
    }
}

private actor ReportPreparationGate {
    private var started = false
    private var duplicateStarted = false
    private var continuation: CheckedContinuation<Void, Never>?
    private var startedContinuation: CheckedContinuation<Void, Never>?

    var duplicateWasStarted: Bool { duplicateStarted }

    func pauseUntilReleased() async {
        started = true
        startedContinuation?.resume()
        startedContinuation = nil
        await withCheckedContinuation { continuation = $0 }
    }

    func waitUntilStarted() async {
        guard !started else { return }
        await withCheckedContinuation { startedContinuation = $0 }
    }

    func recordDuplicateStarted() {
        duplicateStarted = true
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

private enum ReportPreparationTestError: Error, LocalizedError {
    case expectedFailure

    var errorDescription: String? { "No se pudo preparar el informe" }
}
