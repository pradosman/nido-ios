import Foundation

nonisolated struct BabyCareCacheSnapshot: Codable, Equatable, Sendable {
    var state: BabyCareState
    var baseState: BabyCareState?
    var conflictedRemoteState: BabyCareState?
    var needsSync: Bool
    var confirmedCaregiver: Caregiver? = nil
    var sessionBinding: String? = nil

    var hasConflict: Bool { conflictedRemoteState != nil }

    static let empty = BabyCareCacheSnapshot(state: BabyCareState(), baseState: nil, conflictedRemoteState: nil, needsSync: false)
}

nonisolated struct BabyCareCache: Sendable {
    let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.fileURL = directory.appending(path: "Nido", directoryHint: .isDirectory).appending(path: "baby-care.json")
        }
    }

    func load() throws -> BabyCareCacheSnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .empty }
        return try JSONDecoder().decode(BabyCareCacheSnapshot.self, from: Data(contentsOf: fileURL))
    }

    func save(_ snapshot: BabyCareCacheSnapshot) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        #if os(iOS)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: fileURL, options: .atomic)
        #endif
    }

    func remove() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
