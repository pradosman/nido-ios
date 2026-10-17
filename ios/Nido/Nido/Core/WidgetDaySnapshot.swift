import Foundation

nonisolated struct WidgetDaySnapshot: Codable, Sendable {
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
    let timeZoneID: String
    let dayIdentifier: String

    static func make(profile: Profile?, entries: [Entry], activeSleepStartedAt: Date?, activeFeedStartedAt: Date?, state: BabyCareState, now: Date) -> Self {
        let calendar = BabyCareMetrics.calendar(for: state)
        let totals = BabyCareMetrics.summary(on: now, entries: entries, activeSleepStartedAt: activeSleepStartedAt, now: now, calendar: calendar)
        let goals = BabyCareMetrics.goals(on: now, state: state)
        let latest = entries.filter { calendar.isDate($0.date, inSameDayAs: now) }.max { $0.occurredAt < $1.occurredAt }
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        return Self(babyName: profile?.babyName ?? "Bebé", sleepMinutes: totals.sleepSeconds / 60,
                    feeds: totals.feedCount, diapers: totals.diaperCount, latestKind: latest?.kind.rawValue,
                    latestDate: latest?.date, activeKind: activeSleepStartedAt != nil ? "sleep" : activeFeedStartedAt != nil ? "feed" : nil,
                    activeStartedAt: activeSleepStartedAt ?? activeFeedStartedAt, updatedAt: now,
                    sleepGoalMinutes: goals?.sleepMinutes, feedGoal: goals?.feedCount, diaperGoal: goals?.diaperCount,
                    timeZoneID: state.timeZoneID,
                    dayIdentifier: String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0))
    }
}
