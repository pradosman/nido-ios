import Foundation

actor NidoDemoRepository {
    static let baseURL = URL(string: "https://demo.nido.invalid")!
    static let demoAccessToken = "nido-local-demo-session"
    static let accessToken = demoAccessToken
    static let shared = NidoDemoRepository()

    private var profile: Profile
    private var entries: [String: Entry]
    private var caregivers: [String: Caregiver]
    private var currentCaregiverID: String
    private var sleepStartedAt: Date?
    private var babyCareState: BabyCareState?
    private var invitationSequence = 0
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fixtures: NidoDemoSnapshot = NidoDemoFixtures.makeSnapshot()) {
        profile = fixtures.profile
        entries = Dictionary(uniqueKeysWithValues: fixtures.entries.map { ($0.id, $0) })
        caregivers = Dictionary(uniqueKeysWithValues: fixtures.caregivers.map { ($0.id, $0) })
        currentCaregiverID = fixtures.currentCaregiverID
        sleepStartedAt = fixtures.sleepStartedAt
        babyCareState = fixtures.babyCareState
    }

    static func makeAPI() -> NidoAPI {
        makeAPI(repository: shared)
    }

    static func makeAPI(repository: NidoDemoRepository) -> NidoAPI {
        NidoAPI(baseURL: baseURL) { request in
            try await repository.handle(request)
        }
    }

    static func resetDemo() async {
        await shared.reset()
    }

    func reset() {
        resetState()
    }

    func snapshot() -> NidoDemoSnapshot {
        NidoDemoSnapshot(
            profile: profile,
            entries: sortedEntries,
            caregivers: sortedCaregivers,
            currentCaregiverID: currentCaregiverID,
            sleepStartedAt: sleepStartedAt,
            babyCareState: babyCareState
        )
    }

    func handle(_ request: URLRequest) throws -> (Data, URLResponse) {
        guard let url = request.url,
              url.scheme == "https",
              url.host == Self.baseURL.host,
              url.port == nil,
              url.user == nil,
              url.password == nil,
              url.fragment == nil else {
            return try response(status: 403, body: DemoErrorResponse(error: "La demo solo funciona en el entorno local."), for: request)
        }

        let path = url.path
        if path == "/api/nido/auth/apple/challenge"
            || path == "/api/nido/auth/apple/session"
            || path == "/api/nido/auth/account" {
            return try response(status: 403, body: DemoErrorResponse(error: "La autenticación y el borrado de Apple no están disponibles en la demo."), for: request)
        }

            guard request.value(forHTTPHeaderField: "Authorization") == "Bearer \(Self.demoAccessToken)" else {
            return try response(status: 401, body: DemoErrorResponse(error: "La sesión de demostración no es válida."), for: request)
        }

        switch (request.httpMethod, path) {
        case ("GET", "/api/nido"):
            return try response(status: 200, body: DemoLoadResponse(
                profile: profile,
                entries: sortedEntries,
                nextCursor: nil,
                caregivers: sortedCaregivers,
                currentCaregiverID: currentCaregiverID
            ), for: request)
        case ("GET", "/api/nido/entries"):
            return try response(status: 200, body: DemoEntriesResponse(entries: sortedEntries, nextCursor: nil), for: request)
        case ("POST", "/api/nido/entries"):
            guard var entry = decode(Entry.self, from: request.httpBody) else { return try badRequest(request) }
            guard entries[entry.id] == nil else { return try errorResponse(409, "El registro ya existe.", for: request) }
            entry.caregiverID = currentCaregiverID
            entry.caregiverName = caregivers[currentCaregiverID]?.name
            entries[entry.id] = entry
            return try response(status: 201, body: DemoEntryResponse(entry: entry), for: request)
        case ("PUT", "/api/nido/entries"):
            guard var entry = decode(Entry.self, from: request.httpBody), entries[entry.id] != nil else {
                return try errorResponse(404, "No se ha encontrado el registro.", for: request)
            }
            entry.caregiverID = currentCaregiverID
            entry.caregiverName = caregivers[currentCaregiverID]?.name
            entries[entry.id] = entry
            return try response(status: 200, body: DemoEntryResponse(entry: entry), for: request)
        case ("DELETE", "/api/nido/entries"):
            guard let id = queryValue("id", in: url), entries.removeValue(forKey: id) != nil else {
                return try errorResponse(404, "No se ha encontrado el registro.", for: request)
            }
            return try response(status: 200, body: DemoDeleteResponse(deleted: id), for: request)
        case ("PUT", "/api/nido/profile"):
            guard let updated = decode(Profile.self, from: request.httpBody) else { return try badRequest(request) }
            profile = updated
            if var owner = caregivers[currentCaregiverID] {
                owner = Caregiver(id: owner.id, name: updated.caregiverName, role: owner.role, status: owner.status, inviteCode: owner.inviteCode, createdAt: owner.createdAt, joinedAt: owner.joinedAt)
                caregivers[currentCaregiverID] = owner
            }
            return try response(status: 200, body: DemoProfileResponse(profile: profile), for: request)
        case ("GET", "/api/nido/sleep"):
            return try response(status: 200, body: DemoSleepResponse(startedAt: milliseconds(sleepStartedAt)), for: request)
        case ("PUT", "/api/nido/sleep"):
            guard let payload = decode(DemoSleepMutation.self, from: request.httpBody) else { return try badRequest(request) }
            guard milliseconds(sleepStartedAt) == payload.expectedStartedAt else {
                return try response(status: 409, body: DemoSleepResponse(startedAt: milliseconds(sleepStartedAt)), for: request)
            }
            sleepStartedAt = payload.startedAt.map { Date(timeIntervalSince1970: Double($0) / 1_000) }
            return try response(status: 200, body: DemoSleepResponse(startedAt: milliseconds(sleepStartedAt)), for: request)
        case ("GET", "/api/nido/baby-care"):
            return try response(status: 200, body: DemoBabyCareResponse(state: babyCareState), for: request)
        case ("PUT", "/api/nido/baby-care"):
            guard let payload = decode(DemoBabyCareMutation.self, from: request.httpBody) else { return try badRequest(request) }
            let currentRevision = babyCareState?.revision ?? 0
            guard payload.expectedRevision == currentRevision else {
                return try response(status: 409, body: DemoBabyCareResponse(state: babyCareState), for: request)
            }
            guard TimeZone(identifier: payload.timeZoneID) != nil,
                  payload.goalVersions.count <= 500,
                  payload.measurements.count <= 5_000,
                  Self.valid(payload.goalVersions),
                  Self.valid(payload.measurements) else { return try badRequest(request) }
            let isOwner = caregivers[currentCaregiverID]?.role == .owner
            if !isOwner,
               (payload.goalVersions != babyCareState?.goalVersions || payload.timeZoneID != babyCareState?.timeZoneID) {
                return try errorResponse(403, "Solo el responsable puede cambiar los objetivos.", for: request)
            }
            babyCareState = BabyCareState(
                revision: currentRevision + 1,
                timeZoneID: payload.timeZoneID,
                goalVersions: payload.goalVersions,
                measurements: payload.measurements
            )
            return try response(status: 200, body: DemoBabyCareResponse(state: babyCareState), for: request)
        case ("POST", "/api/nido/caregivers/bootstrap"):
            guard let payload = decode(DemoBootstrapRequest.self, from: request.httpBody) else { return try badRequest(request) }
            profile = Profile(
                caregiverName: payload.name,
                babyName: payload.babyName ?? profile.babyName,
                birthDate: payload.birthDate ?? profile.birthDate
            )
            let owner = Caregiver(id: currentCaregiverID, name: payload.name, role: .owner, status: .active, inviteCode: nil, createdAt: nil, joinedAt: nil)
            caregivers[currentCaregiverID] = owner
            return try response(status: 201, body: DemoCaregiverResponse(caregiver: owner), for: request)
        case ("POST", "/api/nido/caregivers/invite"):
            guard let payload = decode(DemoCaregiverNameRequest.self, from: request.httpBody), !payload.name.isEmpty else { return try badRequest(request) }
            invitationSequence += 1
            let invitee = Caregiver(
                id: "demo-invite-\(invitationSequence)",
                name: payload.name,
                role: .caregiver,
                status: .pending,
                inviteCode: "NIDO-DEMO-\(String(format: "%04d", invitationSequence))",
                createdAt: nil,
                joinedAt: nil
            )
            caregivers[invitee.id] = invitee
            return try response(status: 201, body: DemoCaregiverResponse(caregiver: invitee), for: request)
        case ("DELETE", "/api/nido/caregivers/invite"):
            guard let id = queryValue("id", in: url), id != currentCaregiverID,
                  caregivers.removeValue(forKey: id) != nil else {
                return try errorResponse(404, "No se ha encontrado el familiar.", for: request)
            }
            return try response(status: 200, body: DemoDeleteResponse(deleted: id), for: request)
        case ("POST", "/api/nido/caregivers/join"):
            guard caregivers[currentCaregiverID]?.status != .active else {
                return try errorResponse(409, "Ya formas parte de este hogar.", for: request)
            }
            guard let payload = decode(DemoCaregiverCodeRequest.self, from: request.httpBody),
                  var invitee = caregivers.values.first(where: { $0.inviteCode == payload.code && $0.status == .pending }) else {
                return try errorResponse(404, "El código de invitación no es válido.", for: request)
            }
            invitee = Caregiver(id: invitee.id, name: invitee.name, role: .caregiver, status: .active, inviteCode: nil, createdAt: invitee.createdAt, joinedAt: ISO8601DateFormatter().string(from: .now))
            caregivers[invitee.id] = invitee
            currentCaregiverID = invitee.id
            return try response(status: 200, body: DemoCaregiverResponse(caregiver: invitee), for: request)
        case ("POST", "/api/nido/auth/logout"):
            resetState()
            return try response(status: 200, body: DemoLoggedOutResponse(loggedOut: true), for: request)
        default:
            return try errorResponse(404, "La operación no está disponible en la demo.", for: request)
        }
    }

    private var sortedEntries: [Entry] {
        entries.values.sorted { $0.occurredAt == $1.occurredAt ? $0.id > $1.id : $0.occurredAt > $1.occurredAt }
    }

    private var sortedCaregivers: [Caregiver] {
        caregivers.values.sorted { $0.id < $1.id }
    }

    private func resetState() {
        let fixtures = NidoDemoFixtures.makeSnapshot()
        profile = fixtures.profile
        entries = Dictionary(uniqueKeysWithValues: fixtures.entries.map { ($0.id, $0) })
        caregivers = Dictionary(uniqueKeysWithValues: fixtures.caregivers.map { ($0.id, $0) })
        currentCaregiverID = fixtures.currentCaregiverID
        sleepStartedAt = fixtures.sleepStartedAt
        babyCareState = fixtures.babyCareState
        invitationSequence = 0
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from data: Data?) -> Value? {
        guard let data else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func milliseconds(_ date: Date?) -> Int64? {
        date.map { Int64(($0.timeIntervalSince1970 * 1_000).rounded()) }
    }

    private static func valid(_ goals: [CareGoalVersion]) -> Bool {
        let keys = goals.map(\.effectiveDate)
        guard Set(keys).count == keys.count else { return false }
        let formatter = ISO8601DateFormatter()
        return goals.allSatisfy { goal in
            goal.effectiveDate.count == 10
                && formatter.date(from: goal.effectiveDate + "T00:00:00Z") != nil
                && (goal.sleepMinutes.map { (1...1_440).contains($0) } ?? true)
                && (goal.feedCount.map { (1...100).contains($0) } ?? true)
                && (goal.diaperCount.map { (1...100).contains($0) } ?? true)
        }
    }

    private static func valid(_ measurements: [GrowthMeasurement]) -> Bool {
        let ids = measurements.map(\.id)
        let earliest = Int64(Date(timeIntervalSince1970: 946_684_800).timeIntervalSince1970 * 1_000)
        let now = Int64(Date.now.timeIntervalSince1970 * 1_000)
        return Set(ids).count == ids.count && measurements.allSatisfy { item in
            !item.id.isEmpty && item.measuredAt >= earliest && item.measuredAt <= now
                && ((item.weightGrams.map { (1...200_000).contains($0) } ?? true)
                    && (item.heightMillimeters.map { (1...2_500).contains($0) } ?? true))
                && (item.weightGrams != nil || item.heightMillimeters != nil)
                && item.note.count <= 500
        }
    }

    private func queryValue(_ name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == name })?.value
    }

    private func badRequest(_ request: URLRequest) throws -> (Data, URLResponse) {
        try errorResponse(400, "La solicitud de demostración no es válida.", for: request)
    }

    private func errorResponse(_ status: Int, _ message: String, for request: URLRequest) throws -> (Data, URLResponse) {
        try response(status: status, body: DemoErrorResponse(error: message), for: request)
    }

    private func response<Body: Encodable>(status: Int, body: Body, for request: URLRequest) throws -> (Data, URLResponse) {
        let data = try encoder.encode(body)
        let url = request.url ?? Self.baseURL
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        return (data, response)
    }
}

nonisolated private struct DemoLoadResponse: Encodable {
    let profile: Profile?
    let entries: [Entry]
    let nextCursor: String?
    let caregivers: [Caregiver]
    let currentCaregiverID: String
}

nonisolated private struct DemoEntriesResponse: Encodable {
    let entries: [Entry]
    let nextCursor: String?
}

nonisolated private struct DemoProfileResponse: Encodable { let profile: Profile }
nonisolated private struct DemoEntryResponse: Encodable { let entry: Entry }
nonisolated private struct DemoCaregiverResponse: Encodable { let caregiver: Caregiver }
nonisolated private struct DemoDeleteResponse: Encodable { let deleted: String }
nonisolated private struct DemoLoggedOutResponse: Encodable { let loggedOut: Bool }
nonisolated private struct DemoSleepResponse: Encodable { let activeSleepStartedAt: Int64?; init(startedAt: Int64?) { activeSleepStartedAt = startedAt } }
nonisolated private struct DemoErrorResponse: Encodable { let error: String }
nonisolated private struct DemoSleepMutation: Decodable { let startedAt: Int64?; let expectedStartedAt: Int64? }
nonisolated private struct DemoBabyCareResponse: Encodable { let state: BabyCareState? }
nonisolated private struct DemoBabyCareMutation: Decodable {
    let expectedRevision: Int
    let timeZoneID: String
    let goalVersions: [CareGoalVersion]
    let measurements: [GrowthMeasurement]
}
nonisolated private struct DemoBootstrapRequest: Decodable { let name: String; let babyName: String?; let birthDate: String? }
nonisolated private struct DemoCaregiverNameRequest: Decodable { let name: String }
nonisolated private struct DemoCaregiverCodeRequest: Decodable { let code: String }
