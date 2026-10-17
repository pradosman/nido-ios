import Foundation
import Testing
@testable import NidoCore

struct BabyCareCacheTests {
    @Test
    func cachePreservesPendingStateAndUnresolvedRemoteConflict() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = BabyCareCache(fileURL: directory.appending(path: "baby-care.json"))
        let original = BabyCareState(revision: 4, timeZoneID: "Europe/Madrid")
        let local = BabyCareState(revision: 4, timeZoneID: "Europe/Madrid", goalVersions: [
            CareGoalVersion(id: "goal-1", effectiveDate: "2026-10-18", sleepMinutes: 720, feedCount: nil, diaperCount: nil)
        ])
        let remote = BabyCareState(revision: 5, timeZoneID: "Europe/Madrid", measurements: [
            GrowthMeasurement(id: "measurement-1", measuredAt: 1_797_000_000_000, weightGrams: 6_500)
        ])

        try cache.save(BabyCareCacheSnapshot(state: local, baseState: original, conflictedRemoteState: remote, needsSync: true))

        #expect(try cache.load() == BabyCareCacheSnapshot(
            state: local,
            baseState: original,
            conflictedRemoteState: remote,
            needsSync: true
        ))
    }

    @Test
    func cachePersistsConfirmedRoleAndSessionBindingWithoutBreakingOldSnapshots() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = BabyCareCache(fileURL: directory.appending(path: "baby-care.json"))
        let owner = Caregiver(id: "owner", name: "David", role: .owner, status: .active, inviteCode: nil, createdAt: nil, joinedAt: nil)
        let snapshot = BabyCareCacheSnapshot(
            state: BabyCareState(revision: 0, timeZoneID: "Europe/Madrid"),
            baseState: nil,
            conflictedRemoteState: nil,
            needsSync: false,
            confirmedCaregiver: owner,
            sessionBinding: String(repeating: "a", count: 64)
        )

        try cache.save(snapshot)

        #expect(try cache.load() == snapshot)
        let legacyData = Data(#"{"state":{"revision":0,"timeZoneID":"Europe/Madrid","goalVersions":[],"measurements":[]},"baseState":null,"conflictedRemoteState":null,"needsSync":false}"#.utf8)
        let legacySnapshot = try JSONDecoder().decode(BabyCareCacheSnapshot.self, from: legacyData)
        #expect(legacySnapshot.confirmedCaregiver == nil)
        #expect(legacySnapshot.sessionBinding == nil)
    }
}
