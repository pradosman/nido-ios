import Foundation

nonisolated struct NidoAPI: Sendable {
    let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func load(accessToken: String) async throws -> (profile: Profile?, entries: [Entry], caregivers: [Caregiver], currentCaregiverID: String) {
        let request = request(path: "/api/nido", method: "GET", accessToken: accessToken)
        let response: LoadResponse = try await perform(request)
        var allEntries = response.entries
        var cursor = response.nextCursor
        var seenCursors: Set<String> = []
        var pageCount = 1
        while let currentCursor = cursor {
            guard pageCount < 10_000, seenCursors.insert(currentCursor).inserted else {
                throw APIError.invalidResponse
            }
            var components = URLComponents(
                url: baseURL.appending(path: "/api/nido/entries"),
                resolvingAgainstBaseURL: false
            )
            components?.queryItems = [
                URLQueryItem(name: "cursor", value: currentCursor),
                URLQueryItem(name: "limit", value: "100"),
            ]
            guard let url = components?.url else { throw APIError.invalidResponse }
            var pageRequest = URLRequest(url: url)
            configure(&pageRequest, method: "GET", accessToken: accessToken)
            let page: EntriesPageResponse = try await perform(pageRequest)
            allEntries.append(contentsOf: page.entries)
            cursor = page.nextCursor
            pageCount += 1
        }
        var seenEntryIDs: Set<String> = []
        let completeEntries = allEntries
            .filter { seenEntryIDs.insert($0.id).inserted }
            .sorted {
                $0.occurredAt == $1.occurredAt
                    ? $0.id > $1.id
                    : $0.occurredAt > $1.occurredAt
            }
        return (response.profile, completeEntries, response.caregivers ?? [], response.currentCaregiverID)
    }

    func save(profile: Profile, accessToken: String) async throws -> Profile {
        var request = request(path: "/api/nido/profile", method: "PUT", accessToken: accessToken)
        request.httpBody = try encoder.encode(profile)
        let response: ProfileResponse = try await perform(request)
        return response.profile
    }

    func create(entry: Entry, accessToken: String) async throws -> Entry {
        var request = request(path: "/api/nido/entries", method: "POST", accessToken: accessToken)
        request.httpBody = try encoder.encode(entry)
        let response: EntryResponse = try await perform(request)
        return response.entry
    }

    func update(entry: Entry, accessToken: String) async throws -> Entry {
        var request = request(path: "/api/nido/entries", method: "PUT", accessToken: accessToken)
        request.httpBody = try encoder.encode(entry)
        let response: EntryResponse = try await perform(request)
        return response.entry
    }

    func delete(entryID: String, accessToken: String) async throws {
        var components = URLComponents(url: baseURL.appending(path: "/api/nido/entries"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "id", value: entryID)]
        guard let url = components?.url else { throw APIError.invalidResponse }
        var request = URLRequest(url: url)
        configure(&request, method: "DELETE", accessToken: accessToken)
        let _: DeleteResponse = try await perform(request)
    }

    func appleSignInChallenge() async throws -> AppleSignInChallenge {
        let request = request(path: "/api/nido/auth/apple/challenge", method: "POST")
        return try await perform(request)
    }

    func createAppleSession(identityToken: String, challengeID: String) async throws -> AppleSession {
        var request = request(path: "/api/nido/auth/apple/session", method: "POST")
        request.httpBody = try encoder.encode(AppleSessionRequest(
            identityToken: identityToken,
            challengeID: challengeID
        ))
        let response: AppleSessionResponse = try await perform(request)
        return AppleSession(
            credential: SessionCredential(accessToken: response.token, expiresAt: response.expiresAt, appleUserID: nil),
            hasMembership: response.membership != nil
        )
    }

    func bootstrapCaregiver(name: String, profile: Profile, accessToken: String) async throws -> Caregiver {
        var request = request(path: "/api/nido/caregivers/bootstrap", method: "POST", accessToken: accessToken)
        request.httpBody = try encoder.encode(BootstrapCaregiverRequest(
            name: name,
            babyName: profile.babyName,
            birthDate: profile.birthDate
        ))
        let response: CaregiverResponse = try await perform(request)
        return response.caregiver
    }

    func inviteCaregiver(name: String, accessToken: String) async throws -> Caregiver {
        var request = request(path: "/api/nido/caregivers/invite", method: "POST", accessToken: accessToken)
        request.httpBody = try encoder.encode(CaregiverNameRequest(name: name))
        let response: CaregiverResponse = try await perform(request)
        return response.caregiver
    }

    func removeCaregiver(id: String, accessToken: String) async throws {
        var components = URLComponents(url: baseURL.appending(path: "/api/nido/caregivers/invite"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "id", value: id)]
        guard let url = components?.url else { throw APIError.invalidResponse }
        var request = URLRequest(url: url)
        configure(&request, method: "DELETE", accessToken: accessToken)
        let _: DeleteResponse = try await perform(request)
    }

    func joinCaregiver(code: String, accessToken: String) async throws -> Caregiver {
        var request = request(path: "/api/nido/caregivers/join", method: "POST", accessToken: accessToken)
        request.httpBody = try encoder.encode(CaregiverCodeRequest(code: code))
        let response: CaregiverResponse = try await perform(request)
        return response.caregiver
    }

    func logout(accessToken: String) async throws {
        let request = request(path: "/api/nido/auth/logout", method: "POST", accessToken: accessToken)
        let _: LoggedOutResponse = try await perform(request)
    }

    func deleteAccount(accessToken: String) async throws {
        let request = request(path: "/api/nido/auth/account", method: "DELETE", accessToken: accessToken)
        let _: AccountDeletedResponse = try await perform(request)
    }

    private func request(path: String, method: String, accessToken: String? = nil) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: path))
        configure(&request, method: method, accessToken: accessToken)
        return request
    }

    private func configure(_ request: inout URLRequest, method: String, accessToken: String?) {
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        if let accessToken { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let body = try? decoder.decode(ErrorResponse.self, from: data)
            throw APIError.server(status: http.statusCode, message: body?.error ?? "No hemos podido completar la operación.")
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.invalidData
        }
    }
}

nonisolated enum APIError: LocalizedError, Equatable {
    case invalidResponse
    case invalidData
    case missingCredential
    case server(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "No se ha podido completar la operación."
        case .invalidData: "No se han podido leer los datos."
        case .missingCredential: "No hay una sesión local disponible."
        case .server(_, let message): message
        }
    }
}

nonisolated enum PendingMutationKind: CaseIterable, Sendable {
    case create
    case update
    case delete
}

nonisolated enum SessionFailureDisposition: Equatable, Sendable {
    case queueOffline
    case invalidateSession
}

nonisolated enum SessionFailurePolicy {
    static func disposition(
        for error: any Error,
        during _: PendingMutationKind
    ) -> SessionFailureDisposition {
        guard case APIError.server(status: 401, message: _) = error else {
            return .queueOffline
        }
        return .invalidateSession
    }
}

nonisolated private struct LoadResponse: Decodable {
    let profile: Profile?
    let entries: [Entry]
    let nextCursor: String?
    let caregivers: [Caregiver]?
    let currentCaregiverID: String
}

nonisolated private struct EntriesPageResponse: Decodable {
    let entries: [Entry]
    let nextCursor: String?
}

nonisolated enum StartupDestination: Equatable, Sendable {
    case signInWithApple

    static let withoutCredential = StartupDestination.signInWithApple
}
nonisolated private struct AppleSessionRequest: Encodable {
    let identityToken: String
    let challengeID: String
}

nonisolated private struct AppleSessionResponse: Decodable {
    let token: String
    let expiresAt: Date
    let membership: AppleSessionMembership?
}

nonisolated private struct AppleSessionMembership: Decodable {
    let caregiverID: String
    let householdID: String
    let role: String
}

nonisolated private struct ProfileResponse: Decodable {
    let profile: Profile
}

nonisolated private struct EntryResponse: Decodable {
    let entry: Entry
}

nonisolated private struct CaregiverResponse: Decodable {
    let caregiver: Caregiver
}

nonisolated private struct DeleteResponse: Decodable {
    let deleted: String
}

nonisolated private struct LoggedOutResponse: Decodable {
    let loggedOut: Bool
}

nonisolated private struct AccountDeletedResponse: Decodable {
    let deleted: Bool
}

nonisolated private struct CaregiverNameRequest: Encodable {
    let name: String
}

nonisolated private struct BootstrapCaregiverRequest: Encodable {
    let name: String
    let babyName: String?
    let birthDate: String?
}

nonisolated private struct CaregiverCodeRequest: Encodable {
    let code: String
}

nonisolated private struct ErrorResponse: Decodable {
    let error: String
}
