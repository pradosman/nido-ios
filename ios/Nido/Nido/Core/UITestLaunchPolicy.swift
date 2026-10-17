import Foundation

nonisolated enum UITestLaunchPolicy {
    enum LaunchError: Error {
        case malformedMarker
    }

    static let productionBaseURL = URL(string: "https://nido.momentumia.com")!
    // Port 1 deliberately has no Nido service. A missing fixture can fail locally, never in production.
    static let simulatorSafeBaseURL = URL(string: "http://127.0.0.1:1")!

    static func apiBaseURL(isDebugSimulator: Bool, allowsProduction: Bool) -> URL {
        isDebugSimulator && !allowsProduction ? simulatorSafeBaseURL : productionBaseURL
    }

    static func scenario(arguments: [String], environment: [String: String]) throws -> String? {
        let markers = arguments.enumerated().filter { $0.element == "-NIDO_UI_TEST_MARKER" }
        if markers.isEmpty {
            // A scenario argument without its marker is an incomplete test launch, not normal auth.
            if arguments.contains("-NIDO_UI_TEST_SCENARIO") { throw LaunchError.malformedMarker }
            return environment["NIDO_UI_TEST_SCENARIO"]
        }
        guard markers.count == 1,
              arguments.indices.contains(markers[0].offset + 1),
              arguments[markers[0].offset + 1] == "1" else {
            throw LaunchError.malformedMarker
        }
        let scenarios = arguments.enumerated().filter { $0.element == "-NIDO_UI_TEST_SCENARIO" }
        guard scenarios.count == 1,
              arguments.indices.contains(scenarios[0].offset + 1) else {
            throw LaunchError.malformedMarker
        }
        let scenario = arguments[scenarios[0].offset + 1]
        guard !scenario.isEmpty, !scenario.hasPrefix("-") else { throw LaunchError.malformedMarker }
        return scenario
    }
}
