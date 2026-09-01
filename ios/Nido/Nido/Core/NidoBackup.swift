import Foundation

nonisolated struct NidoBackup: Codable, Sendable {
    static let maximumImportBytes = 10 * 1_024 * 1_024
    static let maximumEntryCount = 50_000
    static let maximumCaregiverCount = 500

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
        let url = FileManager.default.temporaryDirectory.appending(path: "Copia-Nido-\(UUID().uuidString).json")
        #if os(iOS)
        let writeOptions: Data.WritingOptions = [.atomic, .completeFileProtection]
        #else
        let writeOptions: Data.WritingOptions = [.atomic]
        #endif
        try encoder.encode(backup).write(to: url, options: writeOptions)
        return url
    }

    static func load(from url: URL) throws -> NidoBackup {
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = resourceValues.fileSize, size <= maximumImportBytes else {
            throw NidoBackupError.importTooLarge
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(NidoBackup.self, from: Data(contentsOf: url, options: .mappedIfSafe))
        guard backup.entries.count <= maximumEntryCount else { throw NidoBackupError.tooManyEntries }
        guard backup.caregivers.count <= maximumCaregiverCount else { throw NidoBackupError.tooManyCaregivers }
        guard backup.version == 1 else { throw NidoBackupError.unsupportedVersion }
        return backup
    }
}

nonisolated enum NidoBackupError: LocalizedError, Equatable {
    case importTooLarge
    case tooManyEntries
    case tooManyCaregivers
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .importTooLarge: "La copia de seguridad supera el tamaño permitido."
        case .tooManyEntries: "La copia contiene demasiados registros."
        case .tooManyCaregivers: "La copia contiene demasiados familiares."
        case .unsupportedVersion: "Esta versión de la copia no es compatible."
        }
    }
}
