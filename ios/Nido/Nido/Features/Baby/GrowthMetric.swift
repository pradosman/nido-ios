import SwiftUI

extension GrowthMeasurement: Identifiable {}

enum GrowthMetric: String, CaseIterable, Identifiable {
    case weight
    case height

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: "Peso"
        case .height: "Talla"
        }
    }

    var unit: String {
        switch self {
        case .weight: "kg"
        case .height: "cm"
        }
    }

    var color: Color {
        switch self {
        case .weight: NidoTheme.chartAccent(for: .health)
        case .height: NidoTheme.moss
        }
    }

    func value(in measurement: GrowthMeasurement) -> Double? {
        switch self {
        case .weight: measurement.weightGrams.map { Double($0) / 1_000 }
        case .height: measurement.heightMillimeters.map { Double($0) / 10 }
        }
    }

    func formattedValue(in measurement: GrowthMeasurement) -> String? {
        guard let amount = formattedAmount(in: measurement) else { return nil }
        return "\(amount) \(unit)"
    }

    func formattedAmount(in measurement: GrowthMeasurement) -> String? {
        guard let value = value(in: measurement) else { return nil }
        let digits = self == .weight ? 3 : 1
        return value.formatted(.number.precision(.fractionLength(0...digits)).locale(.current))
    }

    var rangeAccessibilityID: String {
        switch self {
        case .weight: "growth.chart.weight"
        case .height: "growth.chart.height"
        }
    }
}
