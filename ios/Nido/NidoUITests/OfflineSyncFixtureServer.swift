import Foundation
import Network

final class OfflineSyncFixtureServer: @unchecked Sendable {
    private let stateLock = NSLock()
    private let readiness = DispatchSemaphore(value: 0)
    private var listener: NWListener?
    private var isAvailable = true
    private var attemptedEntries: [[String: Any]] = []
    private var acceptedEntries: [[String: Any]] = []
    private var remoteEntries: [[String: Any]] = []
    private var shouldFailLoadAfterAcceptedCreate = false
    private var shouldFailNextLoad = false
    private var remoteSleepStartedAt: Int64?
    private var appleChallengeRequests = 0
    private var appleSessionRequests = 0
    private var accountDeletionRequests = 0

    var baseURL: String {
        guard let port = listener?.port?.rawValue else {
            preconditionFailure("Start the fixture before reading its base URL.")
        }
        return "http://127.0.0.1:\(port)"
    }

    var acceptedEntryIDs: [String] {
        stateLock.lock()
        defer { stateLock.unlock() }
        return acceptedEntries.compactMap { $0["id"] as? String }
    }

    var attemptedEntryIDs: [String] {
        stateLock.lock()
        defer { stateLock.unlock() }
        return attemptedEntries.compactMap { $0["id"] as? String }
    }

    var remoteEntryIDs: [String] {
        stateLock.lock()
        defer { stateLock.unlock() }
        return remoteEntries.compactMap { $0["id"] as? String }
    }

    var appleChallengeRequestCount: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return appleChallengeRequests
    }

    var appleSessionRequestCount: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return appleSessionRequests
    }

    var accountDeletionRequestCount: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return accountDeletionRequests
    }

    func start() throws {
        let listener = try NWListener(using: .tcp, on: .any)
        self.listener = listener
        listener.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                self?.readiness.signal()
            } else if case .failed = state {
                self?.readiness.signal()
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            connection.start(queue: .global(qos: .userInitiated))
            self.receiveRequest(on: connection, accumulator: RequestAccumulator())
        }
        listener.start(queue: .global(qos: .userInitiated))
        readiness.wait()
        guard listener.port != nil else {
            throw NSError(domain: "OfflineSyncFixtureServer", code: 1)
        }
    }

    func setAvailable(_ available: Bool) {
        stateLock.lock()
        isAvailable = available
        stateLock.unlock()
    }

    func failNextLoadAfterAcceptedCreate() {
        stateLock.lock()
        shouldFailLoadAfterAcceptedCreate = true
        stateLock.unlock()
    }

    func setRemoteSleepStartedAt(_ date: Date?) {
        stateLock.lock()
        remoteSleepStartedAt = date.map { Int64(($0.timeIntervalSince1970 * 1_000).rounded()) }
        stateLock.unlock()
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func receiveRequest(on connection: NWConnection, accumulator: RequestAccumulator) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            if let data {
                accumulator.append(data)
            }
            if accumulator.hasCompleteRequest {
                let request = accumulator.request
                let response = self?.response(for: request) ?? Self.jsonResponse(status: 500, payload: ["error": "fixture stopped"])
                connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
            } else if error != nil || isComplete {
                connection.cancel()
            } else {
                self?.receiveRequest(on: connection, accumulator: accumulator)
            }
        }
    }

    private func response(for request: ParsedRequest) -> Data {
        let isAppleAuth = request.method == "POST"
            && (request.path == "/api/nido/auth/apple/challenge" || request.path == "/api/nido/auth/apple/session")
        guard isAppleAuth || request.headers["authorization"] == "Bearer offline-sync-test-token" else {
            return Self.jsonResponse(status: 401, payload: ["error": "unauthorized"])
        }

        stateLock.lock()
        defer { stateLock.unlock() }
        if request.method == "POST", request.path == "/api/nido/auth/apple/challenge" {
            appleChallengeRequests += 1
            return Self.jsonResponse(status: 201, payload: [
                "challengeID": "account-deletion-challenge-\(appleChallengeRequests)",
                "nonce": "account-deletion-raw-nonce",
                "expiresAt": "2030-01-01T00:00:00Z",
            ])
        }
        if request.method == "POST", request.path == "/api/nido/auth/apple/session" {
            appleSessionRequests += 1
            return Self.jsonResponse(status: 401, payload: ["error": "Unexpected session creation"])
        }
        if request.method == "DELETE", request.path == "/api/nido/auth/account" {
            accountDeletionRequests += 1
            return Self.jsonResponse(status: 200, payload: ["deleted": true])
        }
        if request.method == "POST", request.path == "/api/nido/entries",
           let body = request.body,
           let entry = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            attemptedEntries.append(entry)
            guard isAvailable else {
                return Self.jsonResponse(status: 503, payload: ["error": "fixture unavailable"])
            }
            acceptedEntries.append(entry)
            remoteEntries.removeAll { ($0["id"] as? String) == (entry["id"] as? String) }
            remoteEntries.insert(entry, at: 0)
            if shouldFailLoadAfterAcceptedCreate {
                shouldFailNextLoad = true
                shouldFailLoadAfterAcceptedCreate = false
            }
            return Self.jsonResponse(status: 201, payload: ["entry": entry])
        }
        if request.path == "/api/nido/sleep" {
            guard isAvailable else {
                return Self.jsonResponse(status: 503, payload: ["error": "fixture unavailable"])
            }
            if request.method == "PUT",
               let body = request.body,
               let payload = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                let expected = (payload["expectedStartedAt"] as? Int64)
                guard expected == remoteSleepStartedAt else {
                    return Self.jsonResponse(status: 409, payload: [
                        "activeSleepStartedAt": remoteSleepStartedAt.map { $0 as Any } ?? NSNull(),
                    ])
                }
                remoteSleepStartedAt = payload["startedAt"] as? Int64
            }
            guard request.method == "GET" || request.method == "PUT" else {
                return Self.jsonResponse(status: 404, payload: ["error": "not found"])
            }
            return Self.jsonResponse(status: 200, payload: [
                "activeSleepStartedAt": remoteSleepStartedAt.map { $0 as Any } ?? NSNull(),
            ])
        }
        if request.method == "GET", request.path == "/api/nido", shouldFailNextLoad {
            shouldFailNextLoad = false
            return Self.jsonResponse(status: 503, payload: ["error": "injected load failure"])
        }
        guard isAvailable else {
            return Self.jsonResponse(status: 503, payload: ["error": "fixture unavailable"])
        }

        if request.method == "GET", request.path == "/api/nido" {
            return Self.jsonResponse(status: 200, payload: [
                "profile": ["caregiverName": "David", "babyName": "Marco", "birthDate": "2026-08-01"],
                "entries": remoteEntries,
                "nextCursor": NSNull(),
                "caregivers": [[
                    "id": "caregiver-1", "name": "David", "role": "owner", "status": "active",
                    "inviteCode": NSNull(), "createdAt": NSNull(), "joinedAt": NSNull(),
                ]],
                "currentCaregiverID": "caregiver-1",
            ])
        }
        if request.method == "GET", request.path == "/api/nido/baby-care" {
            return Self.jsonResponse(status: 200, payload: ["state": NSNull()])
        }
        return Self.jsonResponse(status: 404, payload: ["error": "not found"])
    }

    private static func jsonResponse(status: Int, payload: [String: Any]) -> Data {
        let body = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data("{}".utf8)
        let reason = status == 200 ? "OK" : status == 201 ? "Created" : status == 401 ? "Unauthorized" : status == 404 ? "Not Found" : status == 503 ? "Service Unavailable" : "Error"
        let headers = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        return Data(headers.utf8) + body
    }
}

private struct ParsedRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data?
}

private final class RequestAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    var hasCompleteRequest: Bool {
        lock.lock()
        defer { lock.unlock() }
        return parse(data) != nil
    }

    var request: ParsedRequest {
        lock.lock()
        defer { lock.unlock() }
        guard let request = parse(data) else { preconditionFailure("HTTP request is incomplete.") }
        return request
    }

    private func parse(_ data: Data) -> ParsedRequest? {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = data[..<headerEnd.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let requestParts = requestLine.split(separator: " ")
        guard requestParts.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":") else { continue }
            headers[String(line[..<separator]).lowercased()] = line[line.index(after: separator)...]
                .trimmingCharacters(in: .whitespaces)
        }
        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        let bodyStart = headerEnd.upperBound
        guard data.count >= bodyStart + contentLength else { return nil }
        let body = contentLength == 0 ? nil : Data(data[bodyStart..<(bodyStart + contentLength)])
        return ParsedRequest(
            method: String(requestParts[0]),
            path: String(requestParts[1]),
            headers: headers,
            body: body
        )
    }
}
