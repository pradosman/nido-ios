enum EvolutionCareCoverage {
    static func chartFootnote(range: SleepEvolutionRange) -> String {
        if range == .day {
            return "Las horas sin registros se muestran sin valor."
        }
        return range == .sixMonths || range == .year
            ? "Los meses muestran la media por día con registros."
            : "Los días sin registros se muestran sin valor."
    }

    static func label(
        range: SleepEvolutionRange,
        recordedDayCount: Int,
        eligibleDayCount: Int,
        currentPeriod: Bool,
        selectedBucket: Bool
    ) -> String {
        if range == .day {
            if selectedBucket {
                return "Registros de la hora seleccionada"
            }
            return currentPeriod ? "Datos registrados hasta ahora" : "Datos registrados del día"
        }
        guard eligibleDayCount > 0 else {
            return "Aún no hay días terminados en este periodo"
        }
        let days = eligibleDayCount == 1 ? "día terminado" : "días terminados"
        return "\(recordedDayCount) de \(eligibleDayCount) \(days) con registros"
    }
}
