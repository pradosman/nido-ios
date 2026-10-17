import Foundation
import Testing
@testable import NidoCore

@Suite(.serialized)
struct NidoAPICharacterizationTests {
    @Test
    func sharedSleepRequestsUseMillisecondsAndCompareThePreviousStart() async throws {
        let recorder = RequestRecorder()
        let api = makeAPI(recorder: recorder) { request in
            response(for: request, body: #"{"activeSleepStartedAt":1792000000123}"#)
        }
        let start = Date(timeIntervalSince1970: 1792000000.123)
        #expect(try await api.loadSleep(accessToken: "token") == start)
        #expect(try await api.syncSleep(startedAt: start, expectedStartedAt: nil, accessToken: "token") == start)
        _ = try await api.syncSleep(startedAt: nil, expectedStartedAt: start, accessToken: "token")
        #expect(recorder.requests.map(\.httpMethod) == ["GET", "PUT", "PUT"])
        #expect(recorder.requests.allSatisfy { $0.url?.path == "/api/nido/sleep" })
        let begin = try decodedBody(recorder.requests[1])
        #expect(begin["startedAt"] as? Int64 == 1792000000123)
        #expect(begin["expectedStartedAt"] is NSNull)
        let end = try decodedBody(recorder.requests[2])
        #expect(end["startedAt"] is NSNull)
        #expect(end["expectedStartedAt"] as? Int64 == 1792000000123)
    }

    @Test
    func sharedSleepConflictReturnsTheCurrentFamilyStart() async throws {
        let api = makeAPI(recorder: RequestRecorder()) { request in
            response(for: request, status: 409, body: #"{"activeSleepStartedAt":1792000000000}"#)
        }
        let current = try await api.syncSleep(startedAt: nil, expectedStartedAt: .distantPast, accessToken: "token")
        #expect(current == Date(timeIntervalSince1970: 1792000000))
    }

    @Test
    func babyCareUsesItsOwnAuthenticatedRoutesAndCompareAndSetPayload() async throws {
        let recorder = RequestRecorder()
        let api = makeAPI(recorder: recorder) { request in
            switch request.httpMethod {
            case "GET":
                response(for: request, body: #"{"state":{"revision":4,"timeZoneID":"Europe/Madrid","goalVersions":[],"measurements":[]}}"#)
            case "PUT":
                response(for: request, body: #"{"state":{"revision":5,"timeZoneID":"Europe/Madrid","goalVersions":[],"measurements":[]}}"#)
            default:
                response(for: request, status: 405, body: #"{"error":"method"}"#)
            }
        }

        let state = try await api.loadBabyCare(accessToken: "private-token")
        #expect(state?.revision == 4)
        let updated = BabyCareState(revision: 4, timeZoneID: "Europe/Madrid")
        let result = try await api.saveBabyCare(updated, expectedRevision: 4, accessToken: "private-token")
        #expect(result == .saved(BabyCareState(revision: 5, timeZoneID: "Europe/Madrid")))
        #expect(recorder.requests.map(\.url?.path) == ["/api/nido/baby-care", "/api/nido/baby-care"])
        #expect(recorder.requests.map(\.httpMethod) == ["GET", "PUT"])
        #expect(recorder.requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer private-token" })
        let payload = try decodedBody(recorder.requests[1])
        #expect(payload["expectedRevision"] as? Int == 4)
        #expect(payload["timeZoneID"] as? String == "Europe/Madrid")
        #expect(payload["goalVersions"] != nil)
        #expect(payload["measurements"] != nil)
    }

    @Test
    func babyCareWriteSurfacesCasConflictState() async throws {
        let current = BabyCareState(revision: 8, timeZoneID: "Europe/Madrid")
        let api = makeAPI(recorder: RequestRecorder()) { request in
            response(for: request, status: 409, body: #"{"error":"conflict","state":{"revision":8,"timeZoneID":"Europe/Madrid","goalVersions":[],"measurements":[]}}"#)
        }

        let result = try await api.saveBabyCare(current, expectedRevision: 7, accessToken: "token")
        #expect(result == .conflict(current))
    }

    @Test
    func startupRequiresAppleIdentityBeforeCreatingOrJoiningAHome() {
        #expect(StartupDestination.withoutCredential == .signInWithApple)
    }

    @Test
    func loadSendsTheCredentialAndDecodesTheSharedSpace() async throws {
        let recorder = RequestRecorder()
        let api = makeAPI(recorder: recorder) { request in
            response(
                for: request,
                body: #"{"profile":{"caregiverName":"David","babyName":"Marco","birthDate":"2026-08-27"},"entries":[],"caregivers":null,"currentCaregiverID":"caregiver-1"}"#
            )
        }

        let result = try await api.load(accessToken: "private-token")

        #expect(result.profile?.babyName == "Marco")
        #expect(result.entries.isEmpty)
        #expect(result.caregivers.isEmpty)
        #expect(result.currentCaregiverID == "caregiver-1")
        let request = try #require(recorder.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path == "/api/nido")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer private-token")
    }

    @Test
    func loadTraversesEveryPageWithAuthorizationAndReturnsAStableDeduplicatedSnapshot() async throws {
        let recorder = RequestRecorder()
        let api = makeAPI(recorder: recorder) { request in
            switch request.url?.path {
            case "/api/nido":
                response(
                    for: request,
                    body: #"{"profile":{"caregiverName":"David","babyName":"Marco","birthDate":"2026-08-27"},"entries":[{"id":"new","kind":"feed","title":"Toma","detail":"","occurredAt":3000,"durationMinutes":null,"amountMl":null},{"id":"tie-z","kind":"feed","title":"Toma","detail":"","occurredAt":2000,"durationMinutes":null,"amountMl":null}],"nextCursor":"page-2","caregivers":[],"currentCaregiverID":"caregiver-1"}"#
                )
            case "/api/nido/entries":
                response(
                    for: request,
                    body: #"{"entries":[{"id":"tie-z","kind":"feed","title":"Toma","detail":"","occurredAt":2000,"durationMinutes":null,"amountMl":null},{"id":"tie-a","kind":"diaper","title":"Pañal","detail":"","occurredAt":2000,"durationMinutes":null,"amountMl":null},{"id":"old","kind":"sleep","title":"Sueño","detail":"","occurredAt":1000,"durationMinutes":30,"amountMl":null}],"nextCursor":null}"#
                )
            default:
                response(for: request, status: 404, body: #"{"error":"Ruta inesperada"}"#)
            }
        }

        let result = try await api.load(accessToken: "private-token")

        #expect(result.entries.map(\.id) == ["new", "tie-z", "tie-a", "old"])
        #expect(recorder.requests.map { $0.url?.path } == ["/api/nido", "/api/nido/entries"])
        #expect(recorder.requests.allSatisfy {
            $0.value(forHTTPHeaderField: "Authorization") == "Bearer private-token"
        })
        let secondURL = try #require(recorder.requests.last?.url)
        #expect(URLComponents(url: secondURL, resolvingAgainstBaseURL: false)?.queryItems?.contains(
            URLQueryItem(name: "cursor", value: "page-2")
        ) == true)
    }

    @Test
    func loadRejectsARepeatedCursorInsteadOfLoopingForever() async throws {
        let api = makeAPI(recorder: RequestRecorder()) { request in
            if request.url?.path == "/api/nido" {
                return response(
                    for: request,
                    body: #"{"profile":null,"entries":[],"nextCursor":"repeat","caregivers":[],"currentCaregiverID":"caregiver-1"}"#
                )
            }
            return response(for: request, body: #"{"entries":[],"nextCursor":"repeat"}"#)
        }

        await #expect(throws: APIError.invalidResponse) {
            try await api.load(accessToken: "private-token")
        }
    }

    @Test
    func loadReturnsNoPartialSnapshotWhenALaterPageFails() async throws {
        let api = makeAPI(recorder: RequestRecorder()) { request in
            if request.url?.path == "/api/nido" {
                return response(
                    for: request,
                    body: #"{"profile":null,"entries":[{"id":"partial","kind":"feed","title":"Toma","detail":"","occurredAt":3000,"durationMinutes":null,"amountMl":null}],"nextCursor":"page-2","caregivers":[],"currentCaregiverID":"caregiver-1"}"#
                )
            }
            return response(for: request, status: 503, body: #"{"error":"Unavailable"}"#)
        }

        await #expect(throws: APIError.server(status: 503, message: "Unavailable")) {
            try await api.load(accessToken: "private-token")
        }
    }

    @Test
    func profileAndEntryWritesPreserveTheirPayloads() async throws {
        let recorder = RequestRecorder()
        let profile = Profile(caregiverName: "David", babyName: "Marco", birthDate: "2026-08-27")
        let entry = sampleEntry
        let api = makeAPI(recorder: recorder) { request in
            switch (request.httpMethod, request.url?.path) {
            case ("PUT", "/api/nido/profile"):
                response(for: request, body: #"{"profile":{"caregiverName":"David","babyName":"Marco","birthDate":"2026-08-27"}}"#)
            case ("POST", "/api/nido/entries"), ("PUT", "/api/nido/entries"):
                response(for: request, body: Self.entryResponse)
            default:
                response(for: request, status: 404, body: #"{"error":"Ruta inesperada"}"#)
            }
        }

        _ = try await api.save(profile: profile, accessToken: "token")
        _ = try await api.create(entry: entry, accessToken: "token")
        _ = try await api.update(entry: entry, accessToken: "token")

        #expect(recorder.requests.map(\.httpMethod) == ["PUT", "POST", "PUT"])
        let profileBody = try decodedBody(recorder.requests[0])
        #expect(profileBody["babyName"] as? String == "Marco")
        for request in recorder.requests.dropFirst() {
            let body = try decodedBody(request)
            #expect(body["id"] as? String == entry.id)
            #expect(body["occurredAt"] as? Int64 == entry.occurredAt)
            #expect(body["durationMinutes"] as? Int == 45)
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        }
    }

    @Test
    func deletePercentEncodesTheEntryIdentifier() async throws {
        let recorder = RequestRecorder()
        let api = makeAPI(recorder: recorder) { request in
            response(for: request, body: #"{"deleted":"sleep / one"}"#)
        }

        try await api.delete(entryID: "sleep / one", accessToken: "token")

        let request = try #require(recorder.requests.first)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.path == "/api/nido/entries")
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems == [URLQueryItem(name: "id", value: "sleep / one")])
    }

    @Test
    func caregiverRequestsUseTheExpectedContracts() async throws {
        let recorder = RequestRecorder()
        let api = makeAPI(recorder: recorder) { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/nido/auth/apple/challenge"):
                response(for: request, status: 201, body: #"{"challengeID":"challenge-1","nonce":"raw-nonce","expiresAt":"2030-01-01T00:00:00Z"}"#)
            case ("POST", "/api/nido/auth/apple/session"):
                response(for: request, status: 201, body: #"{"token":"private-token","expiresAt":"2030-02-01T00:00:00Z","membership":null}"#)
            case ("POST", "/api/nido/caregivers/bootstrap"), ("POST", "/api/nido/caregivers/join"):
                response(for: request, status: 201, body: Self.caregiverResponse)
            case ("POST", "/api/nido/caregivers/invite"):
                response(for: request, body: Self.caregiverResponse)
            case ("DELETE", "/api/nido/caregivers/invite"):
                response(for: request, body: #"{"deleted":"caregiver-1"}"#)
            case ("POST", "/api/nido/auth/logout"):
                response(for: request, body: #"{"loggedOut":true}"#)
            case ("DELETE", "/api/nido/auth/account"):
                response(for: request, body: #"{"deleted":true}"#)
            default:
                response(for: request, status: 404, body: #"{"error":"Ruta inesperada"}"#)
            }
        }

        let profile = Profile(caregiverName: "David", babyName: "Marco", birthDate: "2026-08-27")
        let challenge = try await api.appleSignInChallenge()
        let session = try await api.createAppleSession(
            identityToken: "apple-identity-token",
            challengeID: challenge.challengeID
        )
        _ = try await api.bootstrapCaregiver(name: "David", profile: profile, accessToken: session.credential.accessToken)
        _ = try await api.inviteCaregiver(name: "Ana", accessToken: "token")
        _ = try await api.joinCaregiver(code: "ABCD-1234", accessToken: "token")
        try await api.removeCaregiver(id: "caregiver-1", accessToken: "token")
        try await api.logout(accessToken: "token")
        try await api.deleteAccount(
            accessToken: "token",
            challengeID: "deletion-challenge",
            identityToken: "fresh-deletion-identity-token",
            authorizationCode: "fresh-deletion-authorization-code"
        )

        #expect(recorder.requests.map { $0.url?.path } == [
            "/api/nido/auth/apple/challenge",
            "/api/nido/auth/apple/session",
            "/api/nido/caregivers/bootstrap",
            "/api/nido/caregivers/invite",
            "/api/nido/caregivers/join",
            "/api/nido/caregivers/invite",
            "/api/nido/auth/logout",
            "/api/nido/auth/account",
        ])
        #expect(try decodedBody(recorder.requests[1])["identityToken"] as? String == "apple-identity-token")
        #expect(try decodedBody(recorder.requests[1])["challengeID"] as? String == "challenge-1")
        #expect(try decodedBody(recorder.requests[2])["babyName"] as? String == "Marco")
        #expect(recorder.requests[2].value(forHTTPHeaderField: "Authorization") == "Bearer private-token")
        #expect(try decodedBody(recorder.requests[3])["name"] as? String == "Ana")
        #expect(try decodedBody(recorder.requests[4])["code"] as? String == "ABCD-1234")
        #expect(recorder.requests[4].value(forHTTPHeaderField: "Authorization") == "Bearer token")
        #expect(recorder.requests[5].url?.query == "id=caregiver-1")
        #expect(recorder.requests[6].value(forHTTPHeaderField: "Authorization") == "Bearer token")
        #expect(recorder.requests[7].value(forHTTPHeaderField: "Authorization") == "Bearer token")
        let deletionBody = try decodedBody(recorder.requests[7])
        #expect(deletionBody["challengeID"] as? String == "deletion-challenge")
        #expect(deletionBody["identityToken"] as? String == "fresh-deletion-identity-token")
        #expect(deletionBody["authorizationCode"] as? String == "fresh-deletion-authorization-code")
    }

    @Test
    func serverAndDecodingFailuresBecomeStableDomainErrors() async throws {
        let profile = Profile(caregiverName: "David", babyName: "Marco", birthDate: "2026-08-27")
        let serverAPI = makeAPI(recorder: RequestRecorder()) { request in
            response(for: request, status: 409, body: #"{"error":"Este espacio ya existe"}"#)
        }
        await #expect(throws: APIError.server(status: 409, message: "Este espacio ya existe")) {
            try await serverAPI.bootstrapCaregiver(name: "David", profile: profile, accessToken: "token")
        }

        let invalidDataAPI = makeAPI(recorder: RequestRecorder()) { request in
            response(for: request, body: #"{"accessToken":42}"#)
        }
        await #expect(throws: APIError.invalidData) {
            try await invalidDataAPI.bootstrapCaregiver(name: "David", profile: profile, accessToken: "token")
        }
    }

    private func makeAPI(
        recorder: RequestRecorder,
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> NidoAPI {
        StubURLProtocol.install { request in
            recorder.record(request)
            return try handler(request)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return NidoAPI(
            baseURL: URL(string: "https://nido.test")!,
            session: URLSession(configuration: configuration)
        )
    }

    private func decodedBody(_ request: URLRequest) throws -> [String: Any] {
        let data = try #require(request.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private var sampleEntry: Entry {
        Entry(
            id: "sleep-1",
            kind: .sleep,
            title: "Sueño",
            detail: "09:00–09:45",
            occurredAt: 1_787_918_400_000,
            durationMinutes: 45,
            amountMl: nil,
            caregiverID: "caregiver-1",
            caregiverName: "David"
        )
    }

    private static let entryResponse = #"{"entry":{"id":"sleep-1","kind":"sleep","title":"Sueño","detail":"09:00–09:45","occurredAt":1787918400000,"durationMinutes":45,"amountMl":null,"caregiverID":"caregiver-1","caregiverName":"David"}}"#
    private static let caregiverResponse = #"{"caregiver":{"id":"caregiver-1","name":"Ana","role":"caregiver","status":"active","inviteCode":null,"createdAt":null,"joinedAt":null}}"#
    private static let credentialResponse = #"{"caregiver":{"id":"caregiver-1","name":"David","role":"owner","status":"active","inviteCode":null,"createdAt":null,"joinedAt":null},"accessToken":"private-token"}"#
}

private final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URLRequest] = []

    var requests: [URLRequest] {
        lock.withLock { storage }
    }

    func record(_ request: URLRequest) {
        lock.withLock { storage.append(request) }
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var installedHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func install(_ handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) {
        lock.withLock { installedHandler = handler }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let handler = Self.lock.withLock { Self.installedHandler }
        do {
            let handler = try #require(handler)
            let request = try materializedRequest(request)
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private func materializedRequest(_ request: URLRequest) throws -> URLRequest {
        guard request.httpBody == nil, let stream = request.httpBodyStream else { return request }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4_096)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: 4_096)
            guard count >= 0 else { throw stream.streamError ?? URLError(.cannotDecodeContentData) }
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }

        var materialized = request
        materialized.httpBodyStream = nil
        materialized.httpBody = data
        return materialized
    }
}

private func response(
    for request: URLRequest,
    status: Int = 200,
    body: String
) -> (HTTPURLResponse, Data) {
    (
        HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!,
        Data(body.utf8)
    )
}
