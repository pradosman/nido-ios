import Foundation
import Testing
@testable import NidoCore

struct BabyCareMigrationTests {
    @Test func legacyHealthMeasurementsMergeByIDAndExplicitValuesWin() {
        let legacy = Entry(id: "m1", kind: .health, title: "Medidas", detail: "Medidas · 4,2 kg · 55 cm", occurredAt: 1_700_000_000_000, durationMinutes: nil, amountMl: nil)
        let state = BabyCareState(measurements: [GrowthMeasurement(id: "m1", measuredAt: 1_700_000_100_000, weightGrams: 4_500)])
        let merged = BabyCareReconciliation.mergedMeasurements(state: state, entries: [legacy])
        #expect(merged.count == 1)
        #expect(merged[0].weightGrams == 4_500)
        #expect(merged[0].heightMillimeters == nil)
    }

    @Test func canonicalLegacyGrowthNoteSurvivesMigrationIntoBabyCareState() {
        let legacy = Entry(
            id: "legacy-note", kind: .health, title: "Medidas",
            detail: "Medidas · 6 kg · 60 cm · Control pediátrico",
            occurredAt: 1_700_000_000_000, durationMinutes: nil, amountMl: nil
        )

        let migrated = BabyCareReconciliation.mergedMeasurements(state: BabyCareState(), entries: [legacy])
        let initial = migrated[0]
        let edited = GrowthMeasurement(
            id: initial.id,
            measuredAt: initial.measuredAt,
            weightGrams: 6_200,
            heightMillimeters: initial.heightMillimeters,
            note: initial.note
        )
        let reopened = BabyCareReconciliation.mergedMeasurements(
            state: BabyCareState(measurements: [edited]), entries: [legacy]
        )

        #expect(initial.note == "Control pediátrico")
        #expect(reopened.first?.weightGrams == 6_200)
        #expect(reopened.first?.note == "Control pediátrico")
    }
}
