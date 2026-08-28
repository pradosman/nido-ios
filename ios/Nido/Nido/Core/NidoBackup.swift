import Foundation

nonisolated struct NidoBackup: Codable, Sendable {
    let version: Int
    let exportedAt: Date
    let profile: Profile?
    let caregivers: [Caregiver]
    let entries: [Entry]

    static func make(profile: Profile?, caregivers: [Caregiver], entries: [Entry]) throws -> URL {
        let safeCaregivers = caregivers.map {
            Caregiver(
                id: $0.id,
                name: $0.name,
                role: $0.role,
                status: $0.status,
                inviteCode: nil,
                createdAt: $0.createdAt,
                joinedAt: $0.joinedAt
            )
        }
        let backup = NidoBackup(version: 1, exportedAt: .now, profile: profile, caregivers: safeCaregivers, entries: entries)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let url = FileManager.default.temporaryDirectory.appending(path: "Copia-Nido-\(Date.now.formatted(.iso8601.year().month().day())).json")
        #if os(iOS)
        let writeOptions: Data.WritingOptions = [.atomic, .completeFileProtection]
        #else
        let writeOptions: Data.WritingOptions = [.atomic]
        #endif
        try encoder.encode(backup).write(to: url, options: writeOptions)
        return url
    }

    static func load(from url: URL) throws -> NidoBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(NidoBackup.self, from: Data(contentsOf: url))
    }
}
