import Foundation
import Testing
@testable import NidoCore

struct BabyCareReconciliationTests {
    @Test func rebasePreservesDisjointGoalAndMeasurementChanges() throws {
        let baseGoal = goal(id: "g0", date: "2026-08-28", sleep: 600, feeds: nil)
        let base = BabyCareState(revision: 4, timeZoneID: "Europe/Madrid", goalVersions: [baseGoal], measurements: [measurement("m0", weight: 4_000)])
        let localGoal = goal(id: "g0", date: "2026-08-28", sleep: 660, feeds: nil)
        let local = BabyCareState(revision: 4, timeZoneID: "Europe/Madrid", goalVersions: [localGoal], measurements: [measurement("m0", weight: 4_000)])
        let remoteMeasurement = measurement("m0", weight: 4_100)
        let remote = BabyCareState(revision: 5, timeZoneID: "Europe/Madrid", goalVersions: [baseGoal], measurements: [remoteMeasurement])

        let rebased = try #require(BabyCareReconciliation.rebased(local: local, base: base, remote: remote))

        #expect(rebased.revision == 5)
        #expect(rebased.goalVersions == [localGoal])
        #expect(rebased.measurements == [remoteMeasurement])
    }

    @Test func rebaseRejectsConflictingEditsToTheSameMeasurement() {
        let baseMeasurement = measurement("m0", weight: 4_000)
        let base = BabyCareState(goalVersions: [], measurements: [baseMeasurement])
        let local = BabyCareState(goalVersions: [], measurements: [measurement("m0", weight: 4_200)])
        let remote = BabyCareState(revision: 1, goalVersions: [], measurements: [measurement("m0", weight: 4_300)])

        #expect(BabyCareReconciliation.rebased(local: local, base: base, remote: remote) == nil)
    }

    private func goal(id: String, date: String, sleep: Int?, feeds: Int?) -> CareGoalVersion {
        CareGoalVersion(id: id, effectiveDate: date, sleepMinutes: sleep, feedCount: feeds, diaperCount: nil)
    }

    private func measurement(_ id: String, weight: Int) -> GrowthMeasurement {
        GrowthMeasurement(id: id, measuredAt: 1_800_000_000_000, weightGrams: weight)
    }
}
