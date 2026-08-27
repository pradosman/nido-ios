import ActivityKit
import Foundation
import os

#if os(iOS)
struct NidoActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let isActive: Bool
    }

    let babyName: String
    let kind: String
    let startedAt: Date
}

enum NidoLiveActivity {
    private static let logger = Logger(subsystem: "com.momentumia.nido", category: "live-activity")

    @discardableResult
    static func start(kind: String, babyName: String, startedAt: Date) -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.notice("Live Activities are disabled")
            return false
        }
        if Activity<NidoActivityAttributes>.activities.contains(where: {
            $0.attributes.kind == kind
                && abs($0.attributes.startedAt.timeIntervalSince(startedAt)) < 2
        }) {
            return true
        }
        let attributes = NidoActivityAttributes(babyName: babyName, kind: kind, startedAt: startedAt)
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: .init(isActive: true), staleDate: nil),
                pushType: nil
            )
            logger.notice("Live Activity started for \(kind, privacy: .public)")
            return true
        } catch {
            logger.error("Live Activity could not start: \(error.localizedDescription, privacy: .private(mask: .hash))")
            return false
        }
    }

    static func reconcile(sleepStartedAt: Date?, feedStartedAt: Date?, babyName: String) async {
        for activity in Activity<NidoActivityAttributes>.activities {
            let expectedStart = activity.attributes.kind == "sleep" ? sleepStartedAt : feedStartedAt
            let stillMatches = expectedStart.map {
                abs(activity.attributes.startedAt.timeIntervalSince($0)) < 2
            } ?? false
            if !stillMatches {
                await activity.end(
                    ActivityContent(state: .init(isActive: false), staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
        }

        if let sleepStartedAt {
            start(kind: "sleep", babyName: babyName, startedAt: sleepStartedAt)
        }
        if let feedStartedAt {
            start(kind: "feed", babyName: babyName, startedAt: feedStartedAt)
        }
    }

    static func end(kind: String) async {
        for activity in Activity<NidoActivityAttributes>.activities where activity.attributes.kind == kind {
            await activity.end(
                ActivityContent(state: .init(isActive: false), staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        logger.notice("Live Activity ended for \(kind, privacy: .public)")
    }
}
#endif
