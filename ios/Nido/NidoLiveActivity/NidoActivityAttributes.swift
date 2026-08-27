import ActivityKit
import Foundation

struct NidoActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let isActive: Bool
    }

    let babyName: String
    let kind: String
    let startedAt: Date
}
