import Foundation

nonisolated struct EvolutionCareBucket: Equatable, Sendable {
    let start: Date
    let end: Date
    let value: Double?
    let recordedDayCount: Int
    let eligibleDayCount: Int
    let recordIDs: [String]
}

nonisolated struct EvolutionCareSnapshot: Equatable, Sendable {
    let period: SleepEvolutionPeriod
    let buckets: [EvolutionCareBucket]
    let recordedDayCount: Int
    let eligibleDayCount: Int
    let totalValue: Double?
    let meanValue: Double?
    let recordIDs: [String]
    let periodRecordIDs: [String]
    let includesActiveSleep: Bool

    static func build(
        metric: EvolutionMetric,
        entries: [Entry],
        activeSleepStartedAt: Date?,
        range: SleepEvolutionRange,
        anchor: Date,
        now: Date,
        calendar: Calendar
    ) -> EvolutionCareSnapshot {
        precondition(metric == .sleep || metric == .feeds || metric == .diapers)
        let period = SleepEvolutionPeriod.period(containing: anchor, range: range, calendar: calendar)
        if metric == .sleep {
            let sleep = SleepEvolutionSnapshot.build(
                entries: entries,
                activeSleepStartedAt: activeSleepStartedAt,
                range: range,
                anchor: anchor,
                now: now,
                calendar: calendar
            )
            return EvolutionCareSnapshot(
                period: sleep.period,
                buckets: sleep.buckets.map {
                    EvolutionCareBucket(
                        start: $0.start,
                        end: $0.end,
                        value: $0.valueSeconds,
                        recordedDayCount: $0.recordedDayCount,
                        eligibleDayCount: $0.eligibleDayCount,
                        recordIDs: $0.recordIDs
                    )
                },
                recordedDayCount: sleep.recordedDayCount,
                eligibleDayCount: sleep.eligibleDayCount,
                totalValue: sleep.totalSeconds.map(Double.init),
                meanValue: sleep.meanSeconds,
                recordIDs: sleep.recordIDs,
                periodRecordIDs: sleep.periodRecordIDs,
                includesActiveSleep: sleep.includesActiveSleep
            )
        }

        let kind: EntryKind = metric == .feeds ? .feed : .diaper
        var seenIDs = Set<String>()
        let uniqueEntries = entries.filter { seenIDs.insert($0.id).inserted }
        let periodEntries = uniqueEntries.filter {
            $0.kind == kind && $0.date >= period.start && $0.date < period.end && $0.date <= now
        }
        let today = calendar.startOfDay(for: now)
        let aggregateEntries = periodEntries.filter { range == .day || $0.date < today }
        let buckets = makeBuckets(
            range: range,
            period: period,
            entries: aggregateEntries,
            now: now,
            calendar: calendar
        )
        let recordedDays = Set(aggregateEntries.map { calendar.startOfDay(for: $0.date) })
        let eligibleDayCount = completedDays(in: period.start..<period.end, now: now, calendar: calendar).count
        let total = aggregateEntries.isEmpty ? nil : Double(aggregateEntries.count)
        let mean = recordedDays.isEmpty ? nil : total.map { $0 / Double(recordedDays.count) }

        return EvolutionCareSnapshot(
            period: period,
            buckets: buckets,
            recordedDayCount: recordedDays.count,
            eligibleDayCount: eligibleDayCount,
            totalValue: total,
            meanValue: range == .day ? nil : mean,
            recordIDs: aggregateEntries.map(\.id).sorted(),
            periodRecordIDs: periodEntries.map(\.id).sorted(),
            includesActiveSleep: false
        )
    }

    private static func makeBuckets(
        range: SleepEvolutionRange,
        period: SleepEvolutionPeriod,
        entries: [Entry],
        now: Date,
        calendar: Calendar
    ) -> [EvolutionCareBucket] {
        let component: Calendar.Component = range == .day
            ? .hour
            : (range == .week || range == .month ? .day : .month)
        var starts: [Date] = []
        var cursor = period.start
        while cursor < period.end,
              let next = calendar.date(byAdding: component, value: 1, to: cursor),
              next > cursor {
            starts.append(cursor)
            cursor = next
        }
        let today = calendar.startOfDay(for: now)

        return starts.compactMap { start in
            guard let naturalEnd = calendar.date(byAdding: component, value: 1, to: start) else { return nil }
            let end = min(naturalEnd, period.end)
            let matchingEntries = entries.filter { $0.date >= start && $0.date < end }
            let recordedDays = Set(matchingEntries.map { calendar.startOfDay(for: $0.date) })
            let completedDays = completedDays(in: start..<end, now: now, calendar: calendar)
            let isMonthlyMean = range == .sixMonths || range == .year
            let count = Double(matchingEntries.count)
            let value: Double? = matchingEntries.isEmpty
                ? nil
                : (isMonthlyMean ? count / Double(recordedDays.count) : count)
            let eligibleCount = range == .day
                ? (start < today ? 1 : 0)
                : completedDays.count

            return EvolutionCareBucket(
                start: start,
                end: end,
                value: value,
                recordedDayCount: recordedDays.count,
                eligibleDayCount: eligibleCount,
                recordIDs: matchingEntries.map(\.id).sorted()
            )
        }
    }

    private static func completedDays(in interval: Range<Date>, now: Date, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: now)
        var days: [Date] = []
        var day = calendar.startOfDay(for: interval.lowerBound)
        while day < interval.upperBound, day < today {
            let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            if next <= today, day >= interval.lowerBound { days.append(day) }
            day = next
        }
        return days
    }
}
