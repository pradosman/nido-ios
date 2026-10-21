import Foundation

nonisolated enum EvolutionMetric: String, CaseIterable, Sendable {
    case sleep
    case feeds
    case diapers
    case weight
    case height
}

nonisolated struct EvolutionSample: Equatable, Sendable {
    /// A local calendar day for care metrics, or the actual measurement time for growth.
    let date: Date
    let value: Double?
}

nonisolated struct EvolutionMetricSnapshot: Equatable, Sendable {
    let metric: EvolutionMetric
    let periodStart: Date
    let periodEnd: Date
    let periodDays: Int
    let daysWithRecords: Int
    let meanValue: Double?
    let latestValue: Double?
    let latestMeasurementDate: Date?
    let samples: [EvolutionSample]
}

nonisolated struct EvolutionSummary: Equatable, Sendable {
    let metrics: [EvolutionMetricSnapshot]

    subscript(_ metric: EvolutionMetric) -> EvolutionMetricSnapshot {
        metrics.first { $0.metric == metric }!
    }

    static func build(
        entries: [Entry],
        measurements: [GrowthMeasurement],
        now: Date,
        calendar: Calendar
    ) -> EvolutionSummary {
        let today = calendar.startOfDay(for: now)
        let periodStart = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        let periodEnd = today
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: periodStart) }
        let completedEntries = entries.filter { $0.date <= now }

        let careMetrics = [EvolutionMetric.sleep, .feeds, .diapers].map { metric in
            let samples = days.map { day -> EvolutionSample in
                let values = completedEntries.filter { entry in
                    switch metric {
                    case .sleep:
                        guard entry.kind == .sleep, let duration = entry.durationMinutes, duration > 0 else { return false }
                        let intervalStart = entry.date.addingTimeInterval(-Double(duration * 60))
                        let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
                        return intervalStart < nextDay && entry.date > day
                    case .feeds:
                        return entry.kind == .feed && calendar.isDate(entry.date, inSameDayAs: day)
                    case .diapers:
                        return entry.kind == .diaper && calendar.isDate(entry.date, inSameDayAs: day)
                    case .weight, .height:
                        return false
                    }
                }
                let value: Double
                switch metric {
                case .sleep:
                    value = Double(BabyCareMetrics.summary(on: day, entries: completedEntries, now: now, calendar: calendar).sleepSeconds)
                case .feeds, .diapers:
                    value = Double(values.count)
                case .weight, .height:
                    value = 0
                }
                return EvolutionSample(date: day, value: values.isEmpty ? nil : value)
            }
            let recorded = samples.compactMap(\.value)
            return EvolutionMetricSnapshot(
                metric: metric,
                periodStart: periodStart,
                periodEnd: periodEnd,
                periodDays: 7,
                daysWithRecords: recorded.count,
                meanValue: recorded.isEmpty ? nil : recorded.reduce(0, +) / Double(recorded.count),
                latestValue: recorded.last,
                latestMeasurementDate: nil,
                samples: samples
            )
        }

        let validMeasurements = measurements
            .filter { Date(timeIntervalSince1970: Double($0.measuredAt) / 1_000) <= now }
            .sorted { $0.measuredAt < $1.measuredAt }
        let growthMetrics: [EvolutionMetric] = [.weight, .height]
        let growthSnapshots = growthMetrics.map { metric -> EvolutionMetricSnapshot in
            let observations: [EvolutionSample] = validMeasurements.compactMap { measurement in
                let rawValue: Double?
                switch metric {
                case .weight: rawValue = measurement.weightGrams.map { Double($0) / 1_000 }
                case .height: rawValue = measurement.heightMillimeters.map { Double($0) / 10 }
                case .sleep, .feeds, .diapers: rawValue = nil
                }
                guard let rawValue else { return nil }
                return EvolutionSample(date: Date(timeIntervalSince1970: Double(measurement.measuredAt) / 1_000), value: rawValue)
            }
            let visible = Array(observations.suffix(7))
            return EvolutionMetricSnapshot(
                metric: metric,
                periodStart: periodStart,
                periodEnd: periodEnd,
                periodDays: 7,
                daysWithRecords: visible.count,
                meanValue: nil,
                latestValue: observations.last?.value,
                latestMeasurementDate: observations.last?.date,
                samples: visible
            )
        }

        return EvolutionSummary(metrics: careMetrics + growthSnapshots)
    }
}
