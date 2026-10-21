import Foundation

nonisolated enum SleepEvolutionRange: String, CaseIterable, Sendable {
    case day
    case week
    case month
    case sixMonths
    case year

    var title: String {
        switch self {
        case .day: "D"
        case .week: "S"
        case .month: "M"
        case .sixMonths: "6M"
        case .year: "A"
        }
    }
}

nonisolated struct SleepEvolutionPeriod: Equatable, Sendable {
    let range: SleepEvolutionRange
    let start: Date
    let end: Date

    static func period(containing date: Date, range: SleepEvolutionRange, calendar: Calendar) -> SleepEvolutionPeriod {
        let start: Date
        let end: Date
        switch range {
        case .day:
            start = calendar.startOfDay(for: date)
            end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        case .week:
            let interval = calendar.dateInterval(of: .weekOfYear, for: date)
            start = interval?.start ?? calendar.startOfDay(for: date)
            end = interval?.end ?? calendar.date(byAdding: .day, value: 7, to: start) ?? start
        case .month:
            let interval = calendar.dateInterval(of: .month, for: date)
            start = interval?.start ?? calendar.startOfDay(for: date)
            end = interval?.end ?? calendar.date(byAdding: .month, value: 1, to: start) ?? start
        case .sixMonths:
            let components = calendar.dateComponents([.year, .month], from: date)
            let month = components.month ?? 1
            let firstMonth = month <= 6 ? 1 : 7
            start = calendar.date(from: DateComponents(year: components.year, month: firstMonth, day: 1)) ?? calendar.startOfDay(for: date)
            end = calendar.date(byAdding: .month, value: 6, to: start) ?? start
        case .year:
            let interval = calendar.dateInterval(of: .year, for: date)
            start = interval?.start ?? calendar.startOfDay(for: date)
            end = interval?.end ?? calendar.date(byAdding: .year, value: 1, to: start) ?? start
        }
        return SleepEvolutionPeriod(range: range, start: start, end: end)
    }

    func shifted(by amount: Int, now: Date, calendar: Calendar) -> SleepEvolutionPeriod {
        let component: Calendar.Component
        let value: Int
        switch range {
        case .day: component = .day; value = amount
        case .week: component = .weekOfYear; value = amount
        case .month: component = .month; value = amount
        case .sixMonths: component = .month; value = amount * 6
        case .year: component = .year; value = amount
        }
        guard let shiftedDate = calendar.date(byAdding: component, value: value, to: start) else { return self }
        let result = Self.period(containing: shiftedDate, range: range, calendar: calendar)
        let current = Self.period(containing: now, range: range, calendar: calendar)
        return result.start > current.start ? self : result
    }

    func isCurrent(now: Date, calendar: Calendar) -> Bool {
        Self.period(containing: now, range: range, calendar: calendar).start == start
    }
}

nonisolated struct SleepEvolutionBucket: Equatable, Sendable {
    let start: Date
    let end: Date
    let valueSeconds: Double?
    let recordedDayCount: Int
    let eligibleDayCount: Int
    let recordIDs: [String]
}

nonisolated struct SleepEvolutionSnapshot: Equatable, Sendable {
    let period: SleepEvolutionPeriod
    let buckets: [SleepEvolutionBucket]
    let recordedDayCount: Int
    let eligibleDayCount: Int
    let totalSeconds: Int?
    let meanSeconds: Double?
    let recordIDs: [String]
    let periodRecordIDs: [String]
    let includesActiveSleep: Bool

    static func build(
        entries: [Entry],
        activeSleepStartedAt: Date?,
        range: SleepEvolutionRange,
        anchor: Date,
        now: Date,
        calendar: Calendar
    ) -> SleepEvolutionSnapshot {
        let period = SleepEvolutionPeriod.period(containing: anchor, range: range, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let isCurrentDay = range == .day && period.start == today
        let completedEnd = range == .day ? min(period.end, now) : min(period.end, today)
        let aggregateEnd = max(period.start, completedEnd)
        let step: Calendar.Component = range == .day ? .hour : (range == .week || range == .month ? .day : .month)

        var seenIDs = Set<String>()
        let uniqueEntries = entries.filter { seenIDs.insert($0.id).inserted }
        let savedIntervals: [(id: String, start: Date, end: Date)] = uniqueEntries.compactMap { entry in
            guard entry.kind == .sleep,
                  let duration = entry.durationMinutes,
                  duration > 0,
                  entry.date <= now else { return nil }
            let start = entry.date.addingTimeInterval(-TimeInterval(duration * 60))
            guard start < entry.date, start < aggregateEnd, entry.date > period.start else { return nil }
            return (entry.id, max(start, period.start), min(entry.date, aggregateEnd))
        }
        let periodRecordIDs = uniqueEntries.compactMap { entry -> String? in
            guard entry.kind == .sleep,
                  let duration = entry.durationMinutes,
                  duration > 0,
                  entry.date <= now else { return nil }
            let intervalStart = entry.date.addingTimeInterval(-TimeInterval(duration * 60))
            guard intervalStart < period.end, entry.date > period.start else { return nil }
            return entry.id
        }.sorted()
        let activeInterval: (Date, Date)? = {
            guard isCurrentDay, let activeSleepStartedAt else { return nil }
            let start = max(activeSleepStartedAt, period.start)
            let end = min(now, period.end)
            guard start < end else { return nil }
            return (start, end)
        }()

        let bucketEndLimit = period.end
        var bucketStarts: [Date] = []
        var cursor = period.start
        while cursor < bucketEndLimit, let next = calendar.date(byAdding: step, value: 1, to: cursor), next > cursor {
            bucketStarts.append(cursor)
            cursor = next
        }

        let buckets = bucketStarts.compactMap { bucketStart -> SleepEvolutionBucket? in
            guard let naturalEnd = calendar.date(byAdding: step, value: 1, to: bucketStart) else { return nil }
            let bucketEnd = min(naturalEnd, period.end)
            let dataEnd = max(bucketStart, min(bucketEnd, aggregateEnd))
            guard bucketStart < bucketEnd else { return nil }
            var intervals = savedIntervals.compactMap { interval -> (Date, Date)? in
                let start = max(bucketStart, interval.start)
                let end = min(dataEnd, interval.end)
                return start < end ? (start, end) : nil
            }
            if let activeInterval {
                let start = max(bucketStart, activeInterval.0)
                let end = min(dataEnd, activeInterval.1)
                if start < end { intervals.append((start, end)) }
            }
            let seconds = CircularTimeline.unionSeconds(intervals)
            let dayStarts = completedDays(in: bucketStart..<dataEnd, now: now, calendar: calendar)
            var recordedDays = dayStarts.filter { day in
                let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
                return savedIntervals.contains { $0.start < next && $0.end > day }
            }
            if range == .day,
               savedIntervals.contains(where: { $0.start < dataEnd && $0.end > bucketStart }) {
                recordedDays = [period.start]
            }
            let bucketIDs = savedIntervals
                .filter { $0.start < dataEnd && $0.end > bucketStart }
                .map(\.id)
                .sorted()
            let bucketHasActiveSleep = activeInterval.map { $0.0 < dataEnd && $0.1 > bucketStart } ?? false
            let isMonthlyMean = range == .sixMonths || range == .year
            let hasValue = range == .day
                ? seconds > 0 && (!bucketIDs.isEmpty || bucketHasActiveSleep)
                : !recordedDays.isEmpty || bucketHasActiveSleep
            let value: Double? = !hasValue ? nil : (isMonthlyMean ? Double(seconds) / Double(max(1, recordedDays.count)) : Double(seconds))
            let eligible = range == .day
                ? (bucketStart < today && period.start < today ? 1 : 0)
                : completedDays(in: bucketStart..<dataEnd, now: now, calendar: calendar).count
            return SleepEvolutionBucket(
                start: bucketStart,
                end: bucketEnd,
                valueSeconds: value,
                recordedDayCount: recordedDays.count,
                eligibleDayCount: eligible,
                recordIDs: bucketIDs
            )
        }

        let allIDs = Array(Set(buckets.flatMap(\.recordIDs))).sorted()
        var allRecordedDays = completedDays(in: period.start..<aggregateEnd, now: now, calendar: calendar).filter { day in
            let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            return savedIntervals.contains { $0.start < next && $0.end > day }
        }
        if range == .day, isCurrentDay, !savedIntervals.isEmpty {
            allRecordedDays = [period.start]
        }
        let total = allRecordedDays.isEmpty && activeInterval == nil ? nil : CircularTimeline.unionSeconds(
            savedIntervals.map { ($0.start, $0.end) } + (activeInterval.map { [$0] } ?? [])
        )
        let mean = range == .day || allRecordedDays.isEmpty ? nil : total.map { Double($0) / Double(allRecordedDays.count) }
        let eligible = completedDays(in: period.start..<aggregateEnd, now: now, calendar: calendar).count
        return SleepEvolutionSnapshot(
            period: period,
            buckets: buckets,
            recordedDayCount: allRecordedDays.count,
            eligibleDayCount: eligible,
            totalSeconds: total,
            meanSeconds: mean,
            recordIDs: allIDs,
            periodRecordIDs: periodRecordIDs,
            includesActiveSleep: activeInterval != nil
        )
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
