import Foundation
import Testing
@testable import NidoCore

struct RegistrationQuickActionTests {
    @Test
    func diaperUsesTheLatestReusableContentsAndFallsBackSafely() {
        let now = Date(timeIntervalSince1970: 10_000)
        let entries = [
            entry(id: "older", kind: .diaper, detail: "Caca", timestamp: 1_000),
            entry(id: "latest", kind: .diaper, detail: "Pis y caca · Normal", timestamp: 2_000),
        ]

        let repeated = RegistrationQuickAction.diaper(entries: entries, at: now)
        let fallback = RegistrationQuickAction.diaper(entries: [], at: now)

        #expect(repeated.label == "Repetir pañal · Pis y caca")
        #expect(repeated.draft.detail == "Pis y caca")
        #expect(repeated.draft.date == now)
        #expect(fallback.label == "Registrar pañal · Pis")
        #expect(fallback.draft.detail == "Pis")
    }

    @Test
    func feedCopiesOnlyReusableSemanticsIntoANewEntry() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let original = entry(
            id: "original-feed",
            kind: .feed,
            detail: "Biberón · Fórmula · Tomó despacio",
            timestamp: 2_000,
            durationMinutes: 18,
            amountMl: 120,
            caregiverID: "other-caregiver",
            caregiverName: "Otra persona"
        )

        let choice = try #require(RegistrationQuickAction.feed(entries: [original], at: now))
        let copy = choice.draft.makeEntry(
            id: "new-feed",
            caregiverID: "current-caregiver",
            caregiverName: "David"
        )

        #expect(choice.label == "Repetir última toma")
        #expect(choice.summary == "Biberón · Fórmula · 120 ml")
        #expect(copy.id == "new-feed")
        #expect(copy.id != original.id)
        #expect(copy.occurredAt == 10_000_000)
        #expect(copy.occurredAt != original.occurredAt)
        #expect(copy.detail == "Biberón · Fórmula")
        #expect(copy.amountMl == 120)
        #expect(copy.durationMinutes == nil)
        #expect(copy.caregiverID == "current-caregiver")
        #expect(copy.caregiverName == "David")
    }

    @Test
    func feedRequiresACompletedSemanticallyReusableEntry() {
        let now = Date(timeIntervalSince1970: 10_000)
        let unrelated = entry(id: "diaper", kind: .diaper, detail: "Pis", timestamp: 3_000)
        let unsupported = entry(id: "legacy-feed", kind: .feed, detail: "Texto importado", timestamp: 2_000)

        #expect(RegistrationQuickAction.feed(entries: [unrelated, unsupported], at: now) == nil)
    }

    private func entry(
        id: String,
        kind: EntryKind,
        detail: String,
        timestamp: Int64,
        durationMinutes: Int? = nil,
        amountMl: Int? = nil,
        caregiverID: String? = nil,
        caregiverName: String? = nil
    ) -> Entry {
        Entry(
            id: id,
            kind: kind,
            title: kind.title,
            detail: detail,
            occurredAt: timestamp,
            durationMinutes: durationMinutes,
            amountMl: amountMl,
            caregiverID: caregiverID,
            caregiverName: caregiverName
        )
    }
}
