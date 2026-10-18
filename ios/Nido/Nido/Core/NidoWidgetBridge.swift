import Foundation
import WidgetKit

nonisolated enum NidoWidgetBridge {
    static let appGroupIdentifier = "group.com.momentumia.nido"
    static let snapshotKey = "nido.widget.snapshot.v1"
    static let widgetKind = "NidoDayWidget"

    @MainActor
    static func update(
        profile: Profile?,
        entries: [Entry],
        activeSleepStartedAt: Date?,
        activeFeedStartedAt: Date?,
        babyCareState: BabyCareState = BabyCareState(),
        now: Date = .now
    ) {
        guard let profile else {
            UserDefaults(suiteName: appGroupIdentifier)?.removeObject(forKey: snapshotKey)
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
            return
        }

        let snapshot = WidgetDaySnapshot.make(profile: profile, entries: entries,
            activeSleepStartedAt: activeSleepStartedAt, activeFeedStartedAt: activeFeedStartedAt,
            state: babyCareState, now: now)

        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: appGroupIdentifier)?.set(encoded, forKey: snapshotKey)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
}
