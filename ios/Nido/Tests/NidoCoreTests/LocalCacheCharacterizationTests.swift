import Foundation
import Testing
@testable import NidoCore

struct LocalCacheCharacterizationTests {
    @Test
    func missingCacheStartsWithAnEmptySnapshot() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let cache = LocalCache(fileURL: directory.appending(path: "snapshot.json"))

        #expect(try cache.load() == .empty)
    }

    @Test
    func saveCreatesItsDirectoryAndPersistsPendingState() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = LocalCache(fileURL: directory.appending(path: "nested/snapshot.json"))
        let snapshot = NidoSnapshot(
            profile: Profile(caregiverName: "David", babyName: "Marco", birthDate: "2026-08-27"),
            entries: [],
            pendingEntryIDs: ["pending-entry"],
            profileNeedsSync: true
        )

        try cache.save(snapshot)

        #expect(FileManager.default.fileExists(atPath: cache.fileURL.path))
        #expect(try cache.load() == snapshot)
    }

    @Test
    func corruptCacheIsReportedInsteadOfSilentlyDiscardingData() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appending(path: "snapshot.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: fileURL)
        let cache = LocalCache(fileURL: fileURL)

        #expect(throws: DecodingError.self) {
            try cache.load()
        }
    }
}
