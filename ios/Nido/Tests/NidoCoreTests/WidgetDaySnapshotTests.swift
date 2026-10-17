import Foundation
import Testing
@testable import NidoCore

@Suite struct WidgetDaySnapshotTests {
    @Test func activeSleepAndMidnightUseFamilyDayAndGoals() throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-17T00:30:00Z"))
        let start = now.addingTimeInterval(-7_200)
        let state = BabyCareState(timeZoneID: "Europe/Madrid", goalVersions: [
            CareGoalVersion(id: "goal", effectiveDate: "2026-10-17", sleepMinutes: 600, feedCount: 8, diaperCount: 6)
        ])
        let snapshot = WidgetDaySnapshot.make(profile: Profile(caregiverName: "", babyName: "Marco", birthDate: ""), entries: [], activeSleepStartedAt: start, activeFeedStartedAt: nil, state: state, now: now)
        #expect(snapshot.sleepMinutes == 120)
        #expect(snapshot.sleepGoalMinutes == 600)
        #expect(snapshot.feedGoal == 8)
        #expect(snapshot.diaperGoal == 6)
        #expect(snapshot.timeZoneID == "Europe/Madrid")
        #expect(snapshot.dayIdentifier == "2026-10-17")
    }

    @Test func absentGoalsAreNotInvented() {
        let snapshot = WidgetDaySnapshot.make(profile: nil, entries: [], activeSleepStartedAt: nil, activeFeedStartedAt: nil, state: BabyCareState(), now: .now)
        #expect(snapshot.sleepGoalMinutes == nil)
        #expect(snapshot.feedGoal == nil)
        #expect(snapshot.diaperGoal == nil)
    }
}
