import Foundation

nonisolated struct EntryFormDefaults: Equatable, Sendable {
    let sleepDurationMinutes: Int
    let feed: FeedFormDefaults

    init(entries: [Entry]) {
        let newestFirst = entries.sorted { $0.occurredAt > $1.occurredAt }

        sleepDurationMinutes = newestFirst
            .first { $0.kind == .sleep && ($0.durationMinutes ?? 0) > 0 }
            .flatMap(\.durationMinutes)
            .map { min(max($0, 1), 720) }
            ?? 45

        feed = FeedFormDefaults(records: newestFirst.compactMap(FeedRecord.init))
    }
}

nonisolated struct FeedFormDefaults: Equatable, Sendable {
    let type: FeedType
    let amountMl: Int
    let durationMinutes: Int
    let breastSide: BreastSide
    let milkType: String

    fileprivate init(records: [FeedRecord]) {
        let selectedType = records.first?.type ?? .bottle
        type = selectedType

        let latestAmount = records.first {
            $0.type == selectedType && ($0.amountMl ?? 0) > 0
        }?.amountMl
        let maximumAmount = selectedType == .pumping ? 500 : 400
        amountMl = min(max(latestAmount ?? 90, 0), maximumAmount)

        let latestDuration = records.first {
            $0.type == selectedType && ($0.durationMinutes ?? 0) > 0
        }?.durationMinutes
        let maximumDuration = selectedType == .pumping ? 120 : 180
        durationMinutes = min(max(latestDuration ?? 15, 1), maximumDuration)

        breastSide = records.first {
            $0.type == .nursing && $0.breastSide != nil
        }?.breastSide ?? .left

        milkType = records.first {
            $0.type == .bottle && $0.milkType != nil
        }?.milkType ?? "Leche materna"
    }
}

fileprivate nonisolated struct FeedRecord: Sendable {
    let type: FeedType
    let amountMl: Int?
    let durationMinutes: Int?
    let breastSide: BreastSide?
    let milkType: String?

    init?(entry: Entry) {
        guard entry.kind == .feed else { return nil }

        let parts = entry.detail
            .split(separator: "·")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let category = parts.first?.lowercased() ?? ""

        if category == "lactancia" {
            type = .nursing
        } else if category == "biberón" {
            type = .bottle
        } else if category == "extracción" {
            type = .pumping
        } else if category == "sólidos" {
            type = .solids
        } else if entry.amountMl != nil {
            type = .bottle
        } else if entry.durationMinutes != nil {
            type = .nursing
        } else {
            type = .bottle
        }

        amountMl = entry.amountMl
        durationMinutes = entry.durationMinutes

        let normalizedDetail = entry.detail.lowercased()
        if normalizedDetail.contains("pecho derecho") {
            breastSide = .right
        } else if normalizedDetail.contains("pecho ambos") {
            breastSide = .both
        } else if normalizedDetail.contains("pecho izquierdo") {
            breastSide = .left
        } else {
            breastSide = nil
        }

        if parts.contains(where: { $0.caseInsensitiveCompare("Fórmula") == .orderedSame }) {
            milkType = "Fórmula"
        } else if parts.contains(where: { $0.caseInsensitiveCompare("Leche materna") == .orderedSame }) {
            milkType = "Leche materna"
        } else {
            milkType = nil
        }
    }
}
