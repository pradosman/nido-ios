import Foundation

nonisolated enum HistoryAnalytics {
    struct Snapshot: Equatable, Sendable {
        let day: CircularTimeline.Day
        let bins: [Bin]
        let entries: [Entry]
    }

    struct Bin: Equatable, Identifiable, Sendable {
        let start: Date
        let end: Date
        let sleepSeconds: Int
        let hasOverlappingSleep: Bool
        let feedCount: Int
        let diaperCount: Int
        private let sleepIDs: [String]
        private let feedIDs: [String]
        private let diaperIDs: [String]
        private let healthIDs: [String]

        var id: Date { start }

        func entryIDs(for kind: EntryKind) -> [String] {
            switch kind {
            case .sleep: sleepIDs
            case .feed: feedIDs
            case .diaper: diaperIDs
            case .health: healthIDs
            }
        }

        fileprivate init(
            start: Date,
            end: Date,
            sleepSeconds: Int,
            hasOverlappingSleep: Bool,
            sleepIDs: [String],
            feedIDs: [String],
            diaperIDs: [String],
            healthIDs: [String]
        ) {
            self.start = start
            self.end = end
            self.sleepSeconds = sleepSeconds
            self.hasOverlappingSleep = hasOverlappingSleep
            self.sleepIDs = sleepIDs
            self.feedIDs = feedIDs
            self.diaperIDs = diaperIDs
            self.healthIDs = healthIDs
            self.feedCount = feedIDs.count
            self.diaperCount = diaperIDs.count
        }
    }

    static func snapshot(
        on date: Date,
        entries: [Entry],
        activeSleepStartedAt: Date? = nil,
        now: Date,
        calendar: Calendar
    ) -> Snapshot {
        let day = CircularTimeline.day(
            on: date,
            entries: entries,
            activeSleepStartedAt: activeSleepStartedAt,
            now: now,
            calendar: calendar
        )
        let dayStart = day.date
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return Snapshot(day: day, bins: [], entries: originalEntries(for: day.items, from: entries, dayStart: dayStart))
        }

        let bins = makeBins(start: dayStart, end: dayEnd, day: day, entries: entries,
                            activeSleepStartedAt: activeSleepStartedAt, now: now)
        return Snapshot(day: day, bins: bins, entries: originalEntries(for: day.items, from: entries, dayStart: dayStart))
    }

    private static func makeBins(
        start dayStart: Date,
        end dayEnd: Date,
        day: CircularTimeline.Day,
        entries: [Entry],
        activeSleepStartedAt: Date?,
        now: Date
    ) -> [Bin] {
        var intervals: [(id: String, start: Date, end: Date)] = entries.compactMap { entry in
            guard entry.kind == .sleep, let duration = entry.durationMinutes, duration > 0 else { return nil }
            let intervalStart = entry.date.addingTimeInterval(-TimeInterval(duration * 60))
            guard intervalStart < dayEnd, entry.date > dayStart else { return nil }
            return (entry.id, max(dayStart, intervalStart), min(dayEnd, entry.date))
        }
        if let activeSleepStartedAt {
            let clippedStart = max(dayStart, activeSleepStartedAt)
            let clippedEnd = min(dayEnd, now)
            if clippedStart < clippedEnd {
                intervals.append(("active-sleep", clippedStart, clippedEnd))
            }
        }

        let binCount = Int(ceil(dayEnd.timeIntervalSince(dayStart) / (15 * 60)))
        let binBounds = (0..<binCount).map { index in
            let start = dayStart.addingTimeInterval(TimeInterval(index * 15 * 60))
            return (start, min(start.addingTimeInterval(15 * 60), dayEnd))
        }
        var sleepSecondsByBin = Array(repeating: 0, count: binCount)
        for interval in mergedSleepIntervals(intervals) {
            let firstIndex = max(0, Int(interval.start.timeIntervalSince(dayStart) / (15 * 60)))
            let lastIndex = min(
                binCount - 1,
                Int(interval.end.timeIntervalSince(dayStart) / (15 * 60))
            )
            guard firstIndex <= lastIndex else { continue }

            var allocations: [(index: Int, seconds: Int, fractional: Double)] = []
            for index in firstIndex...lastIndex {
                let overlapStart = max(binBounds[index].0, interval.start)
                let overlapEnd = min(binBounds[index].1, interval.end)
                guard overlapStart < overlapEnd else { continue }
                let overlap = overlapEnd.timeIntervalSince(overlapStart)
                let wholeSeconds = Int(overlap)
                allocations.append((index, wholeSeconds, overlap - Double(wholeSeconds)))
            }

            let intervalSeconds = Int(interval.end.timeIntervalSince(interval.start))
            let allocatedSeconds = allocations.reduce(0) { $0 + $1.seconds }
            let remainingSeconds = intervalSeconds - allocatedSeconds
            let priority = allocations.sorted {
                if $0.fractional == $1.fractional { return $0.index < $1.index }
                return $0.fractional > $1.fractional
            }
            for allocation in allocations {
                sleepSecondsByBin[allocation.index] += allocation.seconds
            }
            for allocation in priority.prefix(max(0, remainingSeconds)) {
                sleepSecondsByBin[allocation.index] += 1
            }
        }

        var feedIDsByBin = Array(repeating: [String](), count: binCount)
        var diaperIDsByBin = Array(repeating: [String](), count: binCount)
        var healthIDsByBin = Array(repeating: [String](), count: binCount)
        for item in day.items where item.presentation == .point {
            let binIndex = Int(item.entry.date.timeIntervalSince(dayStart) / (15 * 60))
            guard feedIDsByBin.indices.contains(binIndex) else { continue }
            switch item.entry.kind {
            case .feed: feedIDsByBin[binIndex].append(item.entry.id)
            case .diaper: diaperIDsByBin[binIndex].append(item.entry.id)
            case .health: healthIDsByBin[binIndex].append(item.entry.id)
            case .sleep: break
            }
        }

        var result: [Bin] = []
        for (index, bounds) in binBounds.enumerated() {
            let (cursor, next) = bounds
            let sleepIntervalsInBin = intervals.compactMap { interval -> (id: String, start: Date, end: Date)? in
                let overlapStart = max(cursor, interval.start)
                let overlapEnd = min(next, interval.end)
                guard overlapStart < overlapEnd else { return nil }
                return (interval.id, overlapStart, overlapEnd)
            }
            result.append(Bin(
                start: cursor,
                end: next,
                sleepSeconds: sleepSecondsByBin[index],
                hasOverlappingSleep: hasTemporalOverlap(in: sleepIntervalsInBin.map { (start: $0.start, end: $0.end) }),
                sleepIDs: sleepIntervalsInBin.compactMap { $0.id == "active-sleep" ? nil : $0.id },
                feedIDs: feedIDsByBin[index],
                diaperIDs: diaperIDsByBin[index],
                healthIDs: healthIDsByBin[index]
            ))
        }
        return result
    }

    private static func mergedSleepIntervals(_ intervals: [(id: String, start: Date, end: Date)]) -> [(id: String, start: Date, end: Date)] {
        let sorted = intervals.sorted { $0.start < $1.start }
        guard var current = sorted.first else { return [] }
        var merged: [(id: String, start: Date, end: Date)] = []
        for interval in sorted.dropFirst() {
            if interval.start <= current.end {
                current.end = max(current.end, interval.end)
            } else {
                merged.append(current)
                current = interval
            }
        }
        merged.append(current)
        return merged
    }

    private static func hasTemporalOverlap(in intervals: [(start: Date, end: Date)]) -> Bool {
        let ordered = intervals.sorted { $0.start < $1.start }
        guard let first = ordered.first else { return false }
        var latestEnd = first.end
        for interval in ordered.dropFirst() {
            guard interval.start < latestEnd else {
                latestEnd = max(latestEnd, interval.end)
                continue
            }
            return true
        }
        return false
    }

    private static func originalEntries(
        for items: [CircularTimeline.Item],
        from entries: [Entry],
        dayStart: Date
    ) -> [Entry] {
        var byID: [String: Entry] = [:]
        for entry in entries where byID[entry.id] == nil {
            byID[entry.id] = entry
        }
        let ordered = items.compactMap { item -> (entry: Entry, date: Date)? in
            guard let entry = byID[item.entry.id] else { return nil }
            let date: Date
            if item.presentation == .sleepSegment, let duration = entry.durationMinutes {
                date = max(dayStart, entry.date.addingTimeInterval(-TimeInterval(duration * 60)))
            } else {
                date = entry.date
            }
            return (entry, date)
        }
        var seen = Set<String>()
        return ordered
            .sorted {
                if $0.date == $1.date { return $0.entry.id < $1.entry.id }
                return $0.date < $1.date
            }
            .compactMap { seen.insert($0.entry.id).inserted ? $0.entry : nil }
    }
}
