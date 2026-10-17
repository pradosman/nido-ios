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
    let babyCareState: BabyCareState?

    private enum CodingKeys: String, CodingKey {
        case version, exportedAt, profile, caregivers, entries, babyCareState
    }

    init(version: Int, exportedAt: Date, profile: Profile?, caregivers: [Caregiver], entries: [Entry], babyCareState: BabyCareState? = nil) {
        self.version = version
        self.exportedAt = exportedAt
        self.profile = profile
        self.caregivers = caregivers
        self.entries = entries
        self.babyCareState = babyCareState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        profile = try container.decodeIfPresent(Profile.self, forKey: .profile)
        caregivers = try container.decode([Caregiver].self, forKey: .caregivers)
        entries = try container.decode([Entry].self, forKey: .entries)
        babyCareState = try container.decodeIfPresent(BabyCareState.self, forKey: .babyCareState)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(exportedAt, forKey: .exportedAt)
        try container.encodeIfPresent(profile, forKey: .profile)
        try container.encode(caregivers, forKey: .caregivers)
        try container.encode(entries, forKey: .entries)
        try container.encodeIfPresent(babyCareState, forKey: .babyCareState)
    }

    static func make(profile: Profile?, caregivers: [Caregiver], entries: [Entry], babyCareState: BabyCareState? = nil) throws -> URL {
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
        let backup = NidoBackup(version: 1, exportedAt: .now, profile: profile, caregivers: safeCaregivers, entries: entries, babyCareState: babyCareState)
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
        if let babyCareState = backup.babyCareState, !valid(babyCareState) {
            throw NidoBackupError.invalidBabyCareState
        }
        return backup
    }

    private static func valid(_ state: BabyCareState) -> Bool {
        guard state.revision >= 0,
              TimeZone(identifier: state.timeZoneID) != nil,
              state.goalVersions.count <= 500,
              state.measurements.count <= 5_000,
              Set(state.goalVersions.map(\.effectiveDate)).count == state.goalVersions.count,
              Set(state.measurements.map(\.id)).count == state.measurements.count
        else { return false }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let datesAreValid = state.goalVersions.allSatisfy { goal in
            guard let parsed = dateFormatter.date(from: goal.effectiveDate) else { return false }
            return dateFormatter.string(from: parsed) == goal.effectiveDate
                && (goal.sleepMinutes.map { (1...1_440).contains($0) } ?? true)
                && (goal.feedCount.map { (1...100).contains($0) } ?? true)
                && (goal.diaperCount.map { (1...100).contains($0) } ?? true)
        }
        guard datesAreValid else { return false }
        let earliest = Int64(946_684_800_000)
        let latest = Int64(Date.now.timeIntervalSince1970 * 1_000)
        return state.measurements.allSatisfy { item in
            !item.id.isEmpty && item.measuredAt >= earliest && item.measuredAt <= latest
                && ((item.weightGrams.map { (1...200_000).contains($0) } ?? true)
                    && (item.heightMillimeters.map { (1...2_500).contains($0) } ?? true))
                && (item.weightGrams != nil || item.heightMillimeters != nil)
                && item.note.count <= 500
        }
    }
}

nonisolated enum NidoBackupError: LocalizedError, Equatable {
    case importTooLarge
    case tooManyEntries
    case tooManyCaregivers
    case invalidBabyCareState
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .importTooLarge: "La copia de seguridad supera el tamaño permitido."
        case .tooManyEntries: "La copia contiene demasiados registros."
        case .tooManyCaregivers: "La copia contiene demasiados familiares."
        case .invalidBabyCareState: "La copia contiene datos de objetivos o crecimiento no válidos."
        case .unsupportedVersion: "Esta versión de la copia no es compatible."
        }
    }
}
