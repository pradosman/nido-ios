import Foundation

/// The extension decodes the existing app-group payload without depending on the app store.
nonisolated struct NidoWidgetSnapshot: Codable, Sendable {
    let babyName: String
    let sleepMinutes: Int
    let feeds: Int
    let diapers: Int
    let latestKind: String?
    let latestDate: Date?
    let activeKind: String?
    let activeStartedAt: Date?
    let updatedAt: Date
    let sleepGoalMinutes: Int?
    let feedGoal: Int?
    let diaperGoal: Int?

    static let preview = NidoWidgetSnapshot(
        babyName: "Marco", sleepMinutes: 192, feeds: 4, diapers: 3,
        latestKind: "feed", latestDate: .now.addingTimeInterval(-1_800),
        activeKind: nil, activeStartedAt: nil, updatedAt: .now,
        sleepGoalMinutes: nil, feedGoal: nil, diaperGoal: nil
    )
}
