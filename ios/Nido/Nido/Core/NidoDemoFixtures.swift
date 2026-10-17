import Foundation

nonisolated struct NidoDemoSnapshot: Sendable {
    let profile: Profile
    let entries: [Entry]
    let caregivers: [Caregiver]
    let currentCaregiverID: String
    let sleepStartedAt: Date?
    let babyCareState: BabyCareState?
}

nonisolated enum NidoDemoFixtures {
    static let ownerID = "demo-owner"
    static let currentCaregiverID = ownerID
    static let profile = Profile(caregiverName: "Lucía", babyName: "Leo", birthDate: "2026-06-02")
    static let caregivers = [
        Caregiver(
            id: ownerID,
            name: "Lucía",
            role: .owner,
            status: .active,
            inviteCode: nil,
            createdAt: "2026-06-02T09:00:00Z",
            joinedAt: "2026-06-02T09:00:00Z"
        ),
        Caregiver(
            id: "demo-caregiver-ana",
            name: "Ana",
            role: .caregiver,
            status: .active,
            inviteCode: nil,
            createdAt: "2026-06-03T09:00:00Z",
            joinedAt: "2026-06-03T09:15:00Z"
        ),
        Caregiver(
            id: "demo-pending-caregiver",
            name: "Alex",
            role: .caregiver,
            status: .pending,
            inviteCode: "DEMO-1234",
            createdAt: "2026-06-04T09:00:00Z",
            joinedAt: nil
        ),
    ]

    static let entries: [Entry] = {
        let now = Date.now
        func timestamp(daysAgo: Double, hour: Int, minute: Int = 0) -> Int64 {
            let day = Calendar(identifier: .gregorian).date(byAdding: .day, value: -Int(daysAgo), to: now) ?? now
            let date = Calendar(identifier: .gregorian).date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
            return Int64((date.timeIntervalSince1970 * 1_000).rounded())
        }

        return [
            Entry(id: "demo-feed-yesterday", kind: .feed, title: "Toma", detail: "Pecho · lado izquierdo", occurredAt: timestamp(daysAgo: 1, hour: 8, minute: 20), durationMinutes: 18, amountMl: nil, caregiverID: ownerID, caregiverName: "Lucía"),
            Entry(id: "demo-diaper-yesterday", kind: .diaper, title: "Pañal", detail: "Pis y caca", occurredAt: timestamp(daysAgo: 1, hour: 9, minute: 5), durationMinutes: nil, amountMl: nil, caregiverID: "demo-caregiver-ana", caregiverName: "Ana"),
            Entry(id: "demo-sleep-yesterday", kind: .sleep, title: "Sueño", detail: "10:15–11:30", occurredAt: timestamp(daysAgo: 1, hour: 11, minute: 30), durationMinutes: 75, amountMl: nil, caregiverID: ownerID, caregiverName: "Lucía"),
            Entry(id: "demo-health-yesterday", kind: .health, title: "Cuidados", detail: "Medidas · 6,8 kg · 64 cm", occurredAt: timestamp(daysAgo: 1, hour: 12), durationMinutes: nil, amountMl: nil, caregiverID: ownerID, caregiverName: "Lucía"),
            Entry(id: "demo-feed-today", kind: .feed, title: "Toma", detail: "Biberón · leche extraída", occurredAt: timestamp(daysAgo: 0, hour: 7, minute: 40), durationMinutes: nil, amountMl: 120, caregiverID: "demo-caregiver-ana", caregiverName: "Ana"),
            Entry(id: "demo-diaper-today", kind: .diaper, title: "Pañal", detail: "Pis", occurredAt: timestamp(daysAgo: 0, hour: 8, minute: 10), durationMinutes: nil, amountMl: nil, caregiverID: ownerID, caregiverName: "Lucía"),
            Entry(id: "demo-sleep-today", kind: .sleep, title: "Sueño", detail: "09:00–09:42", occurredAt: timestamp(daysAgo: 0, hour: 9, minute: 42), durationMinutes: 42, amountMl: nil, caregiverID: "demo-caregiver-ana", caregiverName: "Ana"),
        ]
    }()

    static let sleepStartedAt: Date? = nil
    static let babyCareState: BabyCareState = {
        let now = Date.now
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return BabyCareState(
            revision: 1,
            timeZoneID: TimeZone.current.identifier,
            goalVersions: [CareGoalVersion(
                id: "demo-goal-today",
                effectiveDate: formatter.string(from: now),
                sleepMinutes: 720,
                feedCount: 8,
                diaperCount: 6
            )],
            measurements: [
                GrowthMeasurement(id: "demo-growth-birth", measuredAt: Int64(now.addingTimeInterval(-70 * 86_400).timeIntervalSince1970 * 1_000), weightGrams: 3_450, heightMillimeters: 510, note: "Nacimiento"),
                GrowthMeasurement(id: "demo-growth-recent", measuredAt: Int64(now.addingTimeInterval(-2 * 86_400).timeIntervalSince1970 * 1_000), weightGrams: 6_800, heightMillimeters: 645, note: "Control pediátrico"),
            ]
        )
    }()

    static func makeSnapshot() -> NidoDemoSnapshot {
        NidoDemoSnapshot(
            profile: profile,
            entries: entries,
            caregivers: caregivers,
            currentCaregiverID: currentCaregiverID,
            sleepStartedAt: sleepStartedAt,
            babyCareState: babyCareState
        )
    }
}
