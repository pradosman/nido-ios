import Foundation

nonisolated struct RegistrationDraft: Equatable, Sendable {
    let kind: EntryKind
    let detail: String
    let date: Date
    let durationMinutes: Int?
    let amountMl: Int?

    func makeEntry(
        id: String,
        caregiverID: String?,
        caregiverName: String?
    ) -> Entry {
        Entry(
            id: id,
            kind: kind,
            title: kind.title,
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
            occurredAt: Int64(date.timeIntervalSince1970 * 1_000),
            durationMinutes: durationMinutes,
            amountMl: amountMl,
            caregiverID: caregiverID,
            caregiverName: caregiverName
        )
    }
}

nonisolated enum RegistrationQuickAction {
    struct Choice: Equatable, Sendable {
        let label: String
        let summary: String
        let draft: RegistrationDraft
    }

    static func diaper(entries: [Entry], at date: Date) -> Choice {
        let latest = entries
            .filter { $0.kind == .diaper }
            .max { $0.occurredAt < $1.occurredAt }
        let reusableContents = latest
            .flatMap { DiaperEntryDetails.parse($0.detail)?.contents }
            .flatMap { $0.isEmpty ? nil : $0 }
        let contents = reusableContents ?? .urine
        let summary = contents.detail(note: "")
        let prefix = reusableContents == nil ? "Registrar pañal" : "Repetir pañal"

        return Choice(
            label: "\(prefix) · \(summary)",
            summary: summary,
            draft: RegistrationDraft(
                kind: .diaper,
                detail: summary,
                date: date,
                durationMinutes: nil,
                amountMl: nil
            )
        )
    }

    static func feed(entries: [Entry], at date: Date) -> Choice? {
        let reusable = entries
            .filter { $0.kind == .feed }
            .sorted { $0.occurredAt > $1.occurredAt }
            .compactMap { entry -> (Entry, FeedEntryDetails)? in
                FeedEntryDetails.parse(entry.detail).map { (entry, $0) }
            }
            .first
        guard let (entry, details) = reusable else { return nil }

        let copiedDetails = FeedEntryDetails(
            type: details.type,
            breastSide: details.breastSide,
            milkType: details.milkType,
            note: details.type == .solids ? details.note : ""
        )
        let detail = copiedDetails.formatted
        let summary = [detail, entry.amountMl.map { "\($0) ml" }]
            .compactMap { $0 }
            .joined(separator: " · ")

        return Choice(
            label: "Repetir última toma",
            summary: summary,
            draft: RegistrationDraft(
                kind: .feed,
                detail: detail,
                date: date,
                durationMinutes: nil,
                amountMl: entry.amountMl
            )
        )
    }
}
