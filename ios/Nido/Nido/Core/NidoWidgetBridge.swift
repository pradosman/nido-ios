import Foundation
import WidgetKit

nonisolated private struct NidoWidgetSnapshot: Codable, Sendable {
    let babyName: String
    let sleepMinutes: Int
    let feeds: Int
    let diapers: Int
    let latestKind: String?
    let latestDate: Date?
    let activeKind: String?
    let activeStartedAt: Date?
    let updatedAt: Date
}

nonisolated enum NidoWidgetBridge {
    static let appGroupIdentifier = "group.com.momentumia.nido"
    static let snapshotKey = "nido.widget.snapshot.v1"
    static let widgetKind = "NidoDayWidget"

    @MainActor
    static func update(
        profile: Profile?,
        entries: [Entry],
        activeSleepStartedAt: Date?,
        activeFeedStartedAt: Date?
    ) {
        guard let profile else {
            UserDefaults(suiteName: appGroupIdentifier)?.removeObject(forKey: snapshotKey)
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
            return
        }

        let today = NidoMetrics.entries(on: .now, from: entries)
        let metrics = NidoMetrics.day(.now, entries: entries)
        let activeKind: String?
        let activeStartedAt: Date?
        if let activeSleepStartedAt {
            activeKind = EntryKind.sleep.rawValue
            activeStartedAt = activeSleepStartedAt
        } else if let activeFeedStartedAt {
            activeKind = EntryKind.feed.rawValue
            activeStartedAt = activeFeedStartedAt
        } else {
            activeKind = nil
            activeStartedAt = nil
        }

        let snapshot = NidoWidgetSnapshot(
            babyName: profile.babyName,
            sleepMinutes: metrics.sleepMinutes,
            feeds: metrics.feeds,
            diapers: metrics.diapers,
            latestKind: today.first?.kind.rawValue,
            latestDate: today.first?.date,
            activeKind: activeKind,
            activeStartedAt: activeStartedAt,
            updatedAt: .now
        )

        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: appGroupIdentifier)?.set(encoded, forKey: snapshotKey)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
}
