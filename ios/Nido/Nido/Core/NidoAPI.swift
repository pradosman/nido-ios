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
    }

    func status() async throws -> Bool {
        let request = request(path: "/api/nido/status", method: "GET")
        let response: StatusResponse = try await perform(request)
        return response.configured
    }

    func load(accessToken: String) async throws -> (profile: Profile?, entries: [Entry], caregivers: [Caregiver], currentCaregiverID: String) {
        let request = request(path: "/api/nido", method: "GET", accessToken: accessToken)
        let response: LoadResponse = try await perform(request)
        return (response.profile, response.entries, response.caregivers ?? [], response.currentCaregiverID)
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

    func bootstrapCaregiver(name: String, legacyProfile: Profile? = nil) async throws -> CaregiverCredential {
        var request = request(path: "/api/nido/caregivers/bootstrap", method: "POST")
        request.httpBody = try encoder.encode(BootstrapCaregiverRequest(
            name: name,
            babyName: legacyProfile?.babyName,
            birthDate: legacyProfile?.birthDate
        ))
        return try await perform(request)
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

    func joinCaregiver(code: String) async throws -> CaregiverCredential {
        var request = request(path: "/api/nido/caregivers/join", method: "POST")
        request.httpBody = try encoder.encode(CaregiverCodeRequest(code: code))
        return try await perform(request)
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
    case server(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "La respuesta del servidor no es válida."
        case .invalidData: "Los datos recibidos no se pueden leer."
        case .server(_, let message): message
        }
    }
}

nonisolated enum NidoAPIEndpoint {
    static let productionURL = URL(string: "https://nido.momentumia.com")!

    static func resolve(configuredValue: String?, isSimulator: Bool) -> URL {
        guard
            let configuredValue,
            let configuredURL = URL(string: configuredValue),
            configuredURL.scheme != nil,
            configuredURL.host != nil
        else {
            return productionURL
        }

        if !isSimulator, configuredURL.isLoopback {
            return productionURL
        }
        return configuredURL
    }
}

private extension URL {
    nonisolated var isLoopback: Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
    }
}

nonisolated private struct LoadResponse: Decodable {
    let profile: Profile?
    let entries: [Entry]
    let caregivers: [Caregiver]?
    let currentCaregiverID: String
}

nonisolated private struct StatusResponse: Decodable {
    let configured: Bool
}

nonisolated struct CaregiverCredential: Decodable, Sendable {
    let caregiver: Caregiver
    let accessToken: String
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
