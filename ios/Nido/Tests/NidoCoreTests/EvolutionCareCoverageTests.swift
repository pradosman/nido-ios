import Testing
@testable import NidoCore

struct EvolutionCareCoverageTests {
    @Test func chartFootnoteUsesItsBucketUnit() {
        #expect(EvolutionCareCoverage.chartFootnote(range: .day)
                == "Las horas sin registros se muestran sin valor.")
        #expect(EvolutionCareCoverage.chartFootnote(range: .week)
                == "Los días sin registros se muestran sin valor.")
        #expect(EvolutionCareCoverage.chartFootnote(range: .sixMonths)
                == "Los meses muestran la media por día con registros.")
    }

    @Test func currentDayDoesNotClaimCompletedDayCoverage() {
        #expect(EvolutionCareCoverage.label(
            range: .day, recordedDayCount: 1, eligibleDayCount: 0,
            currentPeriod: true, selectedBucket: false
        ) == "Datos registrados hasta ahora")
    }

    @Test func historicalDayDescribesOnlyItsRegisteredData() {
        #expect(EvolutionCareCoverage.label(
            range: .day, recordedDayCount: 1, eligibleDayCount: 1,
            currentPeriod: false, selectedBucket: false
        ) == "Datos registrados del día")
    }

    @Test func selectedHourDoesNotClaimCompletedDayCoverage() {
        #expect(EvolutionCareCoverage.label(
            range: .day, recordedDayCount: 1, eligibleDayCount: 0,
            currentPeriod: true, selectedBucket: true
        ) == "Registros de la hora seleccionada")
    }

    @Test func completedPeriodsPreserveTheirCoverage() {
        #expect(EvolutionCareCoverage.label(
            range: .week, recordedDayCount: 1, eligibleDayCount: 1,
            currentPeriod: true, selectedBucket: false
        ) == "1 de 1 día terminado con registros")
    }

    @Test func newPeriodWithoutCompletedDaysDoesNotShowAZeroDenominator() {
        #expect(EvolutionCareCoverage.label(
            range: .week, recordedDayCount: 0, eligibleDayCount: 0,
            currentPeriod: true, selectedBucket: false
        ) == "Aún no hay días terminados en este periodo")
    }
}
