import Foundation
import Testing
@testable import NidoCore

@Suite(.serialized)
struct NidoAPICharacterizationTests {
    @Test
    func statusUsesThePublicStatusEndpoint() async throws {
        let recorder = RequestRecorder()
        let api = makeAPI(recorder: recorder) { request in
            response(for: request, body: #"{"configured":true}"#)
        }

        #expect(try await api.status())

        let request = try #require(recorder.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path == "/api/nido/status")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
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
            case ("POST", "/api/nido/caregivers/bootstrap"), ("POST", "/api/nido/caregivers/join"):
                response(for: request, body: Self.credentialResponse)
            case ("POST", "/api/nido/caregivers/invite"):
                response(for: request, body: Self.caregiverResponse)
            case ("DELETE", "/api/nido/caregivers/invite"):
                response(for: request, body: #"{"deleted":"caregiver-1"}"#)
            default:
                response(for: request, status: 404, body: #"{"error":"Ruta inesperada"}"#)
            }
        }

        let profile = Profile(caregiverName: "David", babyName: "Marco", birthDate: "2026-08-27")
        _ = try await api.bootstrapCaregiver(name: "David", legacyProfile: profile)
        _ = try await api.inviteCaregiver(name: "Ana", accessToken: "token")
        _ = try await api.joinCaregiver(code: "ABCD-1234")
        try await api.removeCaregiver(id: "caregiver-1", accessToken: "token")

        #expect(recorder.requests.map { $0.url?.path } == [
            "/api/nido/caregivers/bootstrap",
            "/api/nido/caregivers/invite",
            "/api/nido/caregivers/join",
            "/api/nido/caregivers/invite",
        ])
        #expect(try decodedBody(recorder.requests[0])["babyName"] as? String == "Marco")
        #expect(try decodedBody(recorder.requests[1])["name"] as? String == "Ana")
        #expect(try decodedBody(recorder.requests[2])["code"] as? String == "ABCD-1234")
        #expect(recorder.requests[3].url?.query == "id=caregiver-1")
    }

    @Test
    func serverAndDecodingFailuresBecomeStableDomainErrors() async throws {
        let serverAPI = makeAPI(recorder: RequestRecorder()) { request in
            response(for: request, status: 409, body: #"{"error":"Este espacio ya existe"}"#)
        }
        await #expect(throws: APIError.server(status: 409, message: "Este espacio ya existe")) {
            try await serverAPI.status()
        }

        let invalidDataAPI = makeAPI(recorder: RequestRecorder()) { request in
            response(for: request, body: #"{"configured":"sí"}"#)
        }
        await #expect(throws: APIError.invalidData) {
            try await invalidDataAPI.status()
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
