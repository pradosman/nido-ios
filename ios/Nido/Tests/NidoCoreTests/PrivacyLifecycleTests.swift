import Foundation
import Testing
@testable import NidoCore

@Suite
struct PrivacyLifecycleTests {
    @Test
    func localCacheCanRemoveAStoredHouseholdSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = LocalCache(fileURL: directory.appending(path: "snapshot.json"))
        try cache.save(.empty)

        try cache.remove()

        #expect(!FileManager.default.fileExists(atPath: cache.fileURL.path))
    }

    @Test
    func backupRejectsFilesLargerThanTheImportLimitBeforeDecoding() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "nido-oversized-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(repeating: 0x20, count: NidoBackup.maximumImportBytes + 1).write(to: url)

        #expect(throws: NidoBackupError.importTooLarge) {
            try NidoBackup.load(from: url)
        }
    }

    @Test
    func backupRejectsAnUnboundedNumberOfEntries() throws {
        let profile = Profile(caregiverName: "David", babyName: "Marco", birthDate: "2026-08-27")
        let entry = Entry(
            id: "entry",
            kind: .feed,
            title: "Toma",
            detail: "",
            occurredAt: 1_787_918_400_000,
            durationMinutes: nil,
            amountMl: nil
        )
        let backup = NidoBackup(
            version: 1,
            exportedAt: .now,
            profile: profile,
            caregivers: [],
            entries: Array(repeating: entry, count: NidoBackup.maximumEntryCount + 1)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let url = FileManager.default.temporaryDirectory.appending(path: "nido-many-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try encoder.encode(backup).write(to: url)

        #expect(throws: NidoBackupError.tooManyEntries) {
            try NidoBackup.load(from: url)
        }
    }
}
