import Foundation
import Testing
@testable import NidoCore

@Suite("UI test launch policy")
struct UITestLaunchPolicyTests {
    @Test func debugSimulatorDefaultsToLoopback() {
        #expect(UITestLaunchPolicy.apiBaseURL(isDebugSimulator: true, allowsProduction: false).host == "127.0.0.1")
    }

    @Test func productionRequiresExplicitSimulatorOptIn() {
        #expect(UITestLaunchPolicy.apiBaseURL(isDebugSimulator: true, allowsProduction: true).host == "nido.momentumia.com")
        #expect(UITestLaunchPolicy.apiBaseURL(isDebugSimulator: false, allowsProduction: false).host == "nido.momentumia.com")
    }

    @Test func argumentMarkerOverridesMissingEnvironment() throws {
        let scenario = try UITestLaunchPolicy.scenario(
            arguments: ["Nido", "-NIDO_UI_TEST_MARKER", "1", "-NIDO_UI_TEST_SCENARIO", "today"],
            environment: [:]
        )
        #expect(scenario == "today")
    }

    @Test func malformedMarkerNeverFallsBack() {
        #expect(throws: UITestLaunchPolicy.LaunchError.self) {
            try UITestLaunchPolicy.scenario(
                arguments: ["Nido", "-NIDO_UI_TEST_MARKER", "wrong"],
                environment: ["NIDO_UI_TEST_SCENARIO": "today"]
            )
        }
    }

    @Test func environmentFallbackRemainsAvailable() throws {
        #expect(try UITestLaunchPolicy.scenario(
            arguments: ["Nido"],
            environment: ["NIDO_UI_TEST_SCENARIO": "today"]
        ) == "today")
    }
}
