import Foundation
import Testing
@testable import NidoCore

@Suite(.serialized)
struct NidoDemoTransportTests {
    @Test
    func demoBabyCareRequestsStayOnTheInMemoryRepository() async throws {
        let repository = NidoDemoRepository()
        let api = NidoDemoRepository.makeAPI(repository: repository)

        let initial = try await api.loadBabyCare(accessToken: NidoDemoRepository.demoAccessToken)
        let draft = BabyCareState(revision: initial?.revision ?? 0, timeZoneID: "Europe/Madrid", goalVersions: [
            CareGoalVersion(id: "demo-goal", effectiveDate: "2026-10-17", sleepMinutes: 720, feedCount: 8, diaperCount: 6)
        ])
        let result = try await api.saveBabyCare(draft, expectedRevision: initial?.revision ?? 0, accessToken: NidoDemoRepository.demoAccessToken)
        let expected = BabyCareState(revision: (initial?.revision ?? 0) + 1, timeZoneID: "Europe/Madrid", goalVersions: draft.goalVersions)
        #expect(result == .saved(expected))
        #expect(try await api.loadBabyCare(accessToken: NidoDemoRepository.demoAccessToken) == expected)
    }

    @Test
    func injectedTransportReceivesAPIRequests() async throws {
        let recorder = DemoRequestRecorder()
        let baseURL = URL(string: "https://demo.nido.invalid")!
        let api = NidoAPI(baseURL: baseURL) { request in
            await recorder.append(request)
            let body = request.url?.path == "/api/nido/sleep"
                ? #"{"activeSleepStartedAt":1792000000123}"#
                : #"{"profile":{"caregiverName":"Ada","babyName":"Luz","birthDate":"2026-07-01"},"entries":[],"caregivers":[],"currentCaregiverID":"demo-owner"}"#
            return (
                Data(body.utf8),
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            )
        }

        let snapshot = try await api.load(accessToken: "demo-token")
        let sleep = try await api.loadSleep(accessToken: "demo-token")

        #expect(snapshot.profile?.babyName == "Luz")
        #expect(sleep == Date(timeIntervalSince1970: 1_792_000_000.123))
        #expect(await recorder.requests.map(\.url?.host) == ["demo.nido.invalid", "demo.nido.invalid"])
    }
}

private actor DemoRequestRecorder {
    private(set) var requests: [URLRequest] = []

    func append(_ request: URLRequest) {
        requests.append(request)
    }
}
