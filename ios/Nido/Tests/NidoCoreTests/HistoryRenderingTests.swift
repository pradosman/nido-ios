import Foundation
import Testing
@testable import NidoCore

struct HistoryRenderingTests {
    @Test
    func repeatedAndMaterializedHistoryRowsKeepTheSameOrderAndSeparators() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let entries = historyFixture(day: day, calendar: calendar)
        let resolveRows = {
            HistoryPresentation.entries(on: day, entries: entries, filter: nil, calendar: calendar)
        }

        let materializedRows = resolveRows()
        let expectedIDs = materializedRows.map(\.id)
        let expectedDividerAfter = Array(expectedIDs.dropLast())

        #expect(!materializedRows.isEmpty)
        #expect(repeatedRendering(entries: resolveRows) == (expectedIDs, expectedDividerAfter))
        #expect(materializedRendering(entries: resolveRows) == (expectedIDs, expectedDividerAfter))
    }

    @Test
    func measuresRepeatedResolutionAgainstOneMaterializedHistorySnapshot() throws {
        let calendar = utcCalendar
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 28)))
        let entries = historyFixture(day: day, calendar: calendar)
        let resolveRows = {
            HistoryPresentation.entries(on: day, entries: entries, filter: nil, calendar: calendar)
        }
        let expected = materializedRendering(entries: resolveRows)

        var repeatedDurations: [Duration] = []
        var materializedDurations: [Duration] = []
        for _ in 0..<5 {
            let repeatedStart = ContinuousClock.now
            let repeatedResult = repeatedRendering(entries: resolveRows)
            repeatedDurations.append(repeatedStart.duration(to: .now))

            let materializedStart = ContinuousClock.now
            let materializedResult = materializedRendering(entries: resolveRows)
            materializedDurations.append(materializedStart.duration(to: .now))

            #expect(repeatedResult == expected)
            #expect(materializedResult == expected)
        }

        print("HistoryRendering benchmark fixture: 3,000 entries, 100 selected rows, 5 samples")
        print("Repeated filter/sort per row median: \(median(repeatedDurations))")
        print("One materialized filter/sort median: \(median(materializedDurations))")
    }

    private func repeatedRendering(entries: () -> [Entry]) -> ([String], [String]) {
        let count = entries().count
        let isEmpty = entries().isEmpty
        guard !isEmpty else { return ([], []) }

        let rows = entries()
        let dividerAfter = rows.compactMap { row in
            row.id != entries().last?.id ? row.id : nil
        }
        return (count == rows.count ? rows.map(\.id) : [], dividerAfter)
    }

    private func materializedRendering(entries: () -> [Entry]) -> ([String], [String]) {
        let rows = entries()
        guard !rows.isEmpty else { return ([], []) }
        let lastID = rows.last?.id
        let dividerAfter = rows.compactMap { row in row.id != lastID ? row.id : nil }
        return (rows.map(\.id), dividerAfter)
    }

    private func historyFixture(day: Date, calendar: Calendar) -> [Entry] {
        let days = (0..<30).flatMap { dayOffset in
            (0..<100).map { index in
                let date = calendar.date(byAdding: .day, value: dayOffset - 15, to: day)!
                    .addingTimeInterval(TimeInterval(index * 60))
                return entry(id: "entry-\(dayOffset)-\(index)", date: date)
            }
        }
        return days.reversed()
    }

    private func entry(id: String, date: Date) -> Entry {
        Entry(
            id: id,
            kind: .feed,
            title: EntryKind.feed.title,
            detail: "",
            occurredAt: Int64(date.timeIntervalSince1970 * 1_000),
            durationMinutes: nil,
            amountMl: nil
        )
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func median(_ values: [Duration]) -> Duration {
        values.sorted { $0 < $1 }[values.count / 2]
    }
}
