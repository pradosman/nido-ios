import Foundation
import Testing
@testable import NidoCore

struct NidoDomainCharacterizationTests {
    @Test(arguments: [
        (EntryKind.sleep, "Sueño", "moon.fill"),
        (EntryKind.feed, "Toma", "waterbottle.fill"),
        (EntryKind.diaper, "Pañal", "drop.fill"),
        (EntryKind.health, "Cuidados", "heart.fill"),
    ])
    func entryKindsKeepTheirUserFacingIdentity(value: (kind: EntryKind, title: String, symbol: String)) {
        #expect(value.kind.id == value.kind)
        #expect(value.kind.title == value.title)
        #expect(value.kind.symbolName == value.symbol)
    }

    @Test(arguments: [
        (FeedType.nursing, "Pecho"),
        (FeedType.bottle, "Biberón"),
        (FeedType.pumping, "Extracción"),
        (FeedType.solids, "Sólidos"),
    ])
    func feedTypesKeepTheirLabels(value: (type: FeedType, title: String)) {
        #expect(value.type.id == value.type)
        #expect(value.type.title == value.title)
        #expect(!value.type.symbolName.isEmpty)
    }

    @Test
    func namesProduceStableInitials() {
        #expect(Profile(caregiverName: "David", babyName: "  marco ", birthDate: "").initials == "M")
        #expect(Profile(caregiverName: "David", babyName: "   ", birthDate: "").initials == "N")
        #expect(caregiver(name: "Ana López García").initials == "AL")
        #expect(caregiver(name: "ana").initials == "A")
    }

    @Test
    func invitationCopyOnlyExistsWhileThereIsACode() {
        #expect(caregiver(name: "Ana", inviteCode: nil).invitationText == nil)
        let text = caregiver(name: "Ana", inviteCode: "ABCD-1234").invitationText
        #expect(text?.contains("ABCD-1234") == true)
        #expect(text?.contains("Nido") == true)
    }

    @Test
    func entryEditingPreservesIdentityAndAttribution() {
        let original = entry(id: "one", kind: .feed, timestamp: 1_000, caregiverName: "David")
        let edited = original.edited(
            detail: "  Biberón · Fórmula  ",
            occurredAt: Date(timeIntervalSince1970: 2),
            durationMinutes: nil,
            amountMl: 90
        )

        #expect(edited.id == "one")
        #expect(edited.kind == .feed)
        #expect(edited.detail == "Biberón · Fórmula")
        #expect(edited.occurredAt == 2_000)
        #expect(edited.amountMl == 90)
        #expect(edited.caregiverName == "David")
    }

    @Test
    func reconciliationKeepsRemoteDataExceptForProtectedLocalChanges() throws {
        let remoteCurrent = entry(id: "current", kind: .feed, timestamp: 3_000)
        let remoteOld = entry(id: "edited", kind: .sleep, timestamp: 1_000, detail: "Antiguo")
        let localEdit = entry(id: "edited", kind: .sleep, timestamp: 2_000, detail: "Corregido")
        let localUnprotected = entry(id: "current", kind: .feed, timestamp: 4_000, detail: "No confirmado")

        let merged = EntryReconciliation.merge(
            remote: [remoteOld, remoteCurrent],
            local: [localEdit, localUnprotected],
            protectedIDs: [localEdit.id]
        )

        #expect(merged.map(\.id) == ["current", "edited"])
        #expect(try #require(merged.first { $0.id == "edited" }).detail == "Corregido")
        #expect(try #require(merged.first { $0.id == "current" }).detail.isEmpty)
    }

    @Test
    func completeReconciliationRemovesStaleRemoteItemsAndExcludesPendingDeletions() {
        let remoteCurrent = entry(id: "current", kind: .feed, timestamp: 4_000)
        let remotePendingDeletion = entry(id: "deleting", kind: .diaper, timestamp: 3_000)
        let staleLocal = entry(id: "server-deleted", kind: .sleep, timestamp: 2_000)
        let pendingCreate = entry(id: "creating", kind: .feed, timestamp: 5_000)
        let pendingUpdate = entry(id: "updating", kind: .health, timestamp: 1_000, detail: "Local edit")

        let merged = EntryReconciliation.merge(
            remote: [remoteCurrent, remotePendingDeletion],
            local: [staleLocal, pendingCreate, pendingUpdate],
            protectedIDs: [pendingCreate.id, pendingUpdate.id],
            excludedIDs: [remotePendingDeletion.id]
        )

        #expect(merged.map(\.id) == ["creating", "current", "updating"])
    }

    @Test
    func sleepCopySeparatesGeneratedScheduleFromTheOptionalNote() throws {
        let interval = try #require(SleepInterval.validated(
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 4_600),
            notAfter: Date(timeIntervalSince1970: 5_000)
        ))

        #expect(interval.durationMinutes == 60)
        #expect(interval.durationLabel == "1 h")
        #expect(SleepInterval.note(from: interval.detail(note: "  Se despertó tranquilo  ")) == "Se despertó tranquilo")
        #expect(SleepInterval.note(from: "Temporizador").isEmpty)
        #expect(SleepInterval.note(from: "Nota antigua") == "Nota antigua")
    }

    @Test(arguments: [
        (0, "0 min"),
        (45, "45 min"),
        (60, "1 h"),
        (75, "1 h 15 min"),
    ])
    func entrySummaryFormatsDurationsAsHoursAndMinutes(value: (minutes: Int, expected: String)) {
        let entryValue = entry(
            id: "duration",
            kind: .sleep,
            timestamp: 1_000,
            durationMinutes: value.minutes
        )

        #expect(entryValue.summary == value.expected)
    }

    @Test
    func growthMeasurementsAcceptPartialValuesAndRejectOtherCareEntries() throws {
        let weightOnly = entry(id: "weight", kind: .health, timestamp: 1_000, detail: "Medidas · 4,8 kg")
        let measurement = try #require(LegacyGrowthMeasurement(entry: weightOnly))

        #expect(measurement.id == "weight")
        #expect(measurement.weightKilograms == 4.8)
        #expect(measurement.heightCentimeters == nil)
        #expect(LegacyGrowthMeasurement(entry: entry(id: "bath", kind: .health, timestamp: 1_000, detail: "Baño")) == nil)
        #expect(LegacyGrowthMeasurement(entry: entry(id: "feed", kind: .feed, timestamp: 1_000, detail: "Medidas · 4,8 kg")) == nil)
    }

    @Test
    func emptyDiaperSelectionStillProducesALegacySafeDescription() {
        #expect(DiaperContents().detail(note: "").contains("Cambio de pañal"))
        #expect(DiaperContents.urine.union(.stool).detail(note: "  Normal  ") == "Pis y caca · Normal")
    }

    @Test
    func semanticEntryDetailsRoundTripStoredCreationFormats() throws {
        let nursing = try #require(FeedEntryDetails.parse("Lactancia · Pecho derecho · Buen agarre"))
        #expect(nursing.type == .nursing)
        #expect(nursing.breastSide == .right)
        #expect(nursing.note == "Buen agarre")
        #expect(nursing.formatted == "Lactancia · Pecho derecho · Buen agarre")

        let bottle = try #require(FeedEntryDetails.parse("Biberón · Fórmula · Sin incidencias"))
        #expect(bottle.type == .bottle)
        #expect(bottle.milkType == "Fórmula")
        #expect(bottle.formatted == "Biberón · Fórmula · Sin incidencias")

        let diaper = try #require(DiaperEntryDetails.parse("Pis y caca · Normal"))
        #expect(diaper.contents == [.urine, .stool])
        #expect(diaper.note == "Normal")
        #expect(diaper.formatted == "Pis y caca · Normal")

        let care = try #require(CareEntryDetails.parse("Medicación · Paracetamol · 2 ml · Fiebre"))
        #expect(care.activity == .medication)
        #expect(care.medicationName == "Paracetamol")
        #expect(care.medicationDose == "2 ml")
        #expect(care.note == "Fiebre")
        #expect(care.formatted == "Medicación · Paracetamol · 2 ml · Fiebre")
    }

    @Test
    func semanticEntryDetailsRejectUnknownLegacyCopyWithoutChangingIt() {
        let legacyFeed = "Texto importado · con · separadores"
        let legacyCare = "Consulta pediátrica externa"

        #expect(FeedEntryDetails.parse(legacyFeed) == nil)
        #expect(CareEntryDetails.parse(legacyCare) == nil)
        #expect(EntryDetailPersistence.preserved(legacyFeed, semanticDetail: nil) == legacyFeed)
        #expect(EntryDetailPersistence.preserved(legacyCare, semanticDetail: nil) == legacyCare)
    }

    private func caregiver(name: String, inviteCode: String? = nil) -> Caregiver {
        Caregiver(
            id: "caregiver",
            name: name,
            role: .caregiver,
            status: .active,
            inviteCode: inviteCode,
            createdAt: nil,
            joinedAt: nil
        )
    }

    private func entry(
        id: String,
        kind: EntryKind,
        timestamp: Int64,
        detail: String = "",
        durationMinutes: Int? = nil,
        caregiverName: String? = nil
    ) -> Entry {
        Entry(
            id: id,
            kind: kind,
            title: kind.title,
            detail: detail,
            occurredAt: timestamp,
            durationMinutes: durationMinutes,
            amountMl: nil,
            caregiverID: caregiverName == nil ? nil : "caregiver",
            caregiverName: caregiverName
        )
    }
}
