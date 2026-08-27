import Foundation

nonisolated struct LocalCache: Sendable {
    let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.fileURL = directory.appending(path: "Nido", directoryHint: .isDirectory).appending(path: "snapshot.json")
        }
    }

    func load() throws -> NidoSnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .empty }
        return try JSONDecoder().decode(NidoSnapshot.self, from: Data(contentsOf: fileURL))
    }

    func save(_ snapshot: NidoSnapshot) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        #if os(iOS)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: fileURL, options: .atomic)
        #endif
    }
}
