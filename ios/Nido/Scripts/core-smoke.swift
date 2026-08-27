import Foundation

@main
struct CoreSmoke {
    static func main() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_787_852_800)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let entries = [
            Entry(id: "sleep", kind: .sleep, title: "Sueño", detail: "", occurredAt: Int64(now.timeIntervalSince1970 * 1_000), durationMinutes: 80, amountMl: nil),
            Entry(id: "feed", kind: .feed, title: "Toma", detail: "", occurredAt: Int64(now.timeIntervalSince1970 * 1_000), durationMinutes: nil, amountMl: 120),
            Entry(id: "old", kind: .sleep, title: "Sueño", detail: "", occurredAt: Int64(yesterday.timeIntervalSince1970 * 1_000), durationMinutes: 400, amountMl: nil),
        ]
        let metrics = NidoMetrics.day(now, entries: entries, calendar: calendar)
        precondition(metrics.sleepMinutes == 80)
        precondition(metrics.feeds == 1)
        precondition(metrics.feedMl == 120)

        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let cache = LocalCache(fileURL: directory.appending(path: "snapshot.json"))
        let snapshot = NidoSnapshot(profile: nil, entries: entries, pendingEntryIDs: ["feed"], profileNeedsSync: false)
        try cache.save(snapshot)
        let restored = try cache.load()
        precondition(restored == snapshot)

        print("NidoCore smoke checks passed")
    }
}
