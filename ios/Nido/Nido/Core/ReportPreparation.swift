import Observation
import Foundation

@MainActor
@Observable
final class ReportPreparation {
    private var generation = UUID()
    private(set) var isPreparing = false
    private(set) var url: URL?
    private(set) var errorMessage: String?

    func prepare(operation: @Sendable () async throws -> URL) async {
        guard !isPreparing else { return }

        isPreparing = true
        errorMessage = nil
        let requestGeneration = generation
        defer {
            if generation == requestGeneration { isPreparing = false }
        }

        do {
            let generatedURL = try await prepareOffMainActor(operation: operation)
            guard generation == requestGeneration else {
                try? FileManager.default.removeItem(at: generatedURL)
                return
            }
            url = generatedURL
        } catch {
            guard generation == requestGeneration else { return }
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        generation = UUID()
        if let url { try? FileManager.default.removeItem(at: url) }
        url = nil
        errorMessage = nil
        isPreparing = false
    }
}

@concurrent
private func prepareOffMainActor(
    operation: @Sendable () async throws -> URL
) async throws -> URL {
    try await operation()
}
