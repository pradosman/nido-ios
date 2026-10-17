import Foundation
import Testing
@testable import NidoCore

@Suite(.serialized)
struct NidoAccountDeletionAuthorizationTests {
    @Test
    func deletionSendsFreshAppleProofAndCurrentNidoBearerWithoutCreatingASession() async throws {
        let state = DeletionURLProtocol.State()
        state.enqueue(status: 201, body: #"{"challengeID":"challenge-17","nonce":"server-nonce","expiresAt":"2030-01-01T00:00:00Z"}"#)
        state.enqueue(status: 200, body: #"{"deleted":true}"#)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeletionURLProtocol.self]
        DeletionURLProtocol.state = state
        defer { DeletionURLProtocol.state = nil }

        let api = NidoAPI(baseURL: URL(string: "https://nido.example")!, session: URLSession(configuration: configuration))
        let challenge = try await api.appleSignInChallenge()
        try await api.deleteAccount(
            accessToken: "current-nido-token",
            challengeID: challenge.challengeID,
            identityToken: "fresh-identity-token",
            authorizationCode: "fresh-authorization-code"
        )

        let requests = state.requests
        #expect(requests.count == 2)
        #expect(requests.map(\.url?.path) == [
            "/api/nido/auth/apple/challenge",
            "/api/nido/auth/account",
        ])
        #expect(requests.map(\.httpMethod) == ["POST", "DELETE"])
        #expect(requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer current-nido-token")
        #expect(requests[1].timeoutInterval == 45)
        let bodyData = try #require(requests[1].httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: String])
        #expect(body == [
            "challengeID": "challenge-17",
            "identityToken": "fresh-identity-token",
            "authorizationCode": "fresh-authorization-code",
        ])
    }

    @Test
    func deletionDoesNotTreatAFalseServerResultAsSuccess() async throws {
        let state = DeletionURLProtocol.State()
        state.enqueue(status: 200, body: #"{"deleted":false}"#)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeletionURLProtocol.self]
        DeletionURLProtocol.state = state
        defer { DeletionURLProtocol.state = nil }

        let api = NidoAPI(baseURL: URL(string: "https://nido.example")!, session: URLSession(configuration: configuration))
        await #expect(throws: APIError.invalidData) {
            try await api.deleteAccount(
                accessToken: "current-nido-token",
                challengeID: "challenge-17",
                identityToken: "fresh-identity-token",
                authorizationCode: "fresh-authorization-code"
            )
        }
    }
}

private final class DeletionURLProtocol: URLProtocol, @unchecked Sendable {
    final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var queued: [(Int, Data)] = []
        private var captured: [URLRequest] = []

        var requests: [URLRequest] {
            lock.lock()
            defer { lock.unlock() }
            return captured
        }

        func enqueue(status: Int, body: String) {
            lock.lock()
            defer { lock.unlock() }
            queued.append((status, Data(body.utf8)))
        }

        func take(_ request: URLRequest) -> (Int, Data) {
            lock.lock()
            defer { lock.unlock() }
            captured.append(materializedRequest(request))
            return queued.removeFirst()
        }

        private func materializedRequest(_ request: URLRequest) -> URLRequest {
            guard request.httpBody == nil, let stream = request.httpBodyStream else { return request }
            stream.open()
            defer { stream.close() }
            var data = Data()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4_096)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let count = stream.read(buffer, maxLength: 4_096)
                guard count > 0 else { break }
                data.append(buffer, count: count)
            }
            var materialized = request
            materialized.httpBodyStream = nil
            materialized.httpBody = data
            return materialized
        }
    }

    nonisolated(unsafe) static var state: State?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let state = Self.state else { return }
        let (status, body) = state.take(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
