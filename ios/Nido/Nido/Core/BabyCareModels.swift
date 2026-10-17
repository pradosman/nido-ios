import Foundation

nonisolated struct CareGoalVersion: Codable, Equatable, Sendable {
    let id: String
    let effectiveDate: String
    let sleepMinutes: Int?
    let feedCount: Int?
    let diaperCount: Int?
}

nonisolated struct GrowthMeasurement: Codable, Equatable, Sendable {
    let id: String
    let measuredAt: Int64
    let weightGrams: Int?
    let heightMillimeters: Int?
    let note: String

    init(id: String, measuredAt: Int64, weightGrams: Int? = nil, heightMillimeters: Int? = nil, note: String = "") {
        self.id = id
        self.measuredAt = measuredAt
        self.weightGrams = weightGrams
        self.heightMillimeters = heightMillimeters
        self.note = note
    }
}

nonisolated struct BabyCareState: Codable, Equatable, Sendable {
    let revision: Int
    let timeZoneID: String
    let goalVersions: [CareGoalVersion]
    let measurements: [GrowthMeasurement]

    init(revision: Int = 0, timeZoneID: String = TimeZone.current.identifier, goalVersions: [CareGoalVersion] = [], measurements: [GrowthMeasurement] = []) {
        self.revision = revision
        self.timeZoneID = timeZoneID
        self.goalVersions = goalVersions
        self.measurements = measurements
    }
}
