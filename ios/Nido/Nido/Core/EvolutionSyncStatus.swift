import Foundation

struct EvolutionSyncStatus: Equatable {
    enum Availability: Equatable {
        case loading
        case noRecords
        case hasRecords
    }

    let availability: Availability
    let isOffline: Bool
    let hasPendingChanges: Bool

    init(isLoading: Bool, hasRecords: Bool, isOffline: Bool, hasPendingChanges: Bool) {
        if isLoading {
            availability = .loading
        } else {
            availability = hasRecords ? .hasRecords : .noRecords
        }
        self.isOffline = isOffline
        self.hasPendingChanges = hasPendingChanges
    }
}
