import Foundation

enum GrowthRange: String, CaseIterable, Identifiable, Hashable {
    case day
    case week
    case month
    case sixMonths
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: "Día"
        case .week: "Semana"
        case .month: "Mes"
        case .sixMonths: "6 meses"
        case .year: "Año"
        }
    }

    var shortTitle: String {
        switch self {
        case .day: "D"
        case .week: "S"
        case .month: "M"
        case .sixMonths: "6M"
        case .year: "A"
        }
    }

    var accessibilityID: String {
        switch self {
        case .day: "growth.range.day"
        case .week: "growth.range.week"
        case .month: "growth.range.month"
        case .sixMonths: "growth.range.sixMonths"
        case .year: "growth.range.year"
        }
    }

    func startDate(endingAt date: Date, calendar: Calendar) -> Date? {
        switch self {
        case .day: calendar.date(byAdding: .day, value: -1, to: date)
        case .week: calendar.date(byAdding: .day, value: -7, to: date)
        case .month: calendar.date(byAdding: .month, value: -1, to: date)
        case .sixMonths: calendar.date(byAdding: .month, value: -6, to: date)
        case .year: calendar.date(byAdding: .year, value: -1, to: date)
        }
    }
}
