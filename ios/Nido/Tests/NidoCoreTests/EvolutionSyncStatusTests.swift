import Testing
@testable import NidoCore

struct EvolutionSyncStatusTests {
    @Test func loadingAndNoRecordsAreDistinctFromOfflineAndPending() {
        let loading = EvolutionSyncStatus(
            isLoading: true,
            hasRecords: false,
            isOffline: false,
            hasPendingChanges: false
        )
        let noRecords = EvolutionSyncStatus(
            isLoading: false,
            hasRecords: false,
            isOffline: false,
            hasPendingChanges: false
        )
        let offline = EvolutionSyncStatus(
            isLoading: false,
            hasRecords: true,
            isOffline: true,
            hasPendingChanges: false
        )
        let pending = EvolutionSyncStatus(
            isLoading: false,
            hasRecords: true,
            isOffline: false,
            hasPendingChanges: true
        )

        #expect(loading.availability == .loading)
        #expect(noRecords.availability == .noRecords)
        #expect(offline.availability == .hasRecords)
        #expect(offline.isOffline)
        #expect(pending.availability == .hasRecords)
        #expect(pending.hasPendingChanges)
    }

    @Test func cachedEmptyStateCanAlsoReportOfflineAndPending() {
        let status = EvolutionSyncStatus(
            isLoading: false,
            hasRecords: false,
            isOffline: true,
            hasPendingChanges: true
        )

        #expect(status.availability == .noRecords)
        #expect(status.isOffline)
        #expect(status.hasPendingChanges)
    }
}
