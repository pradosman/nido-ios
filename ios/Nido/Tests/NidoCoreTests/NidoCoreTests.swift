import Foundation
import Testing
@testable import NidoCore

struct NidoCoreTests {
    @Test func dailyMetricsIgnoreOtherDays() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 27, hour: 12)))
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let entries = [
            entry(kind: .sleep, date: today, duration: 80),
            entry(kind: .feed, date: today, amount: 120),
            entry(kind: .diaper, date: today),
            entry(kind: .sleep, date: yesterday, duration: 400),
        ]

        let metrics = NidoMetrics.day(today, entries: entries, calendar: calendar)
        #expect(metrics == DayMetrics(sleepMinutes: 80, feeds: 1, feedMl: 120, diapers: 1))
    }

    @Test(arguments: [(0, 60), (3, 90), (5, 120), (8, 150), (12, 180)])
    func wakeWindowsAreAgeAware(value: (age: Int, minutes: Int)) {
        #expect(NidoMetrics.wakeWindowMinutes(ageInMonths: value.age) == value.minutes)
    }

    @Test func localSnapshotRoundTrips() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let cache = LocalCache(fileURL: directory.appending(path: "snapshot.json"))
        let snapshot = NidoSnapshot(
            profile: Profile(caregiverName: "David", babyName: "Marco", birthDate: "2026-08-01"),
            entries: [entry(kind: .feed, date: .now, amount: 90)],
            pendingEntryIDs: ["entry"],
            profileNeedsSync: true
        )

        try cache.save(snapshot)
        #expect(try cache.load() == snapshot)
    }

    @Test(arguments: [
        (DiaperContents.urine, "", "Pis"),
        (DiaperContents.stool, "", "Caca"),
        (DiaperContents([.urine, .stool]), "", "Pis y caca"),
        (DiaperContents([.urine, .stool]), "  Normal  ", "Pis y caca · Normal"),
    ])
    func diaperContentsBuildAReadableDetail(value: (contents: DiaperContents, note: String, expected: String)) {
        #expect(value.contents.detail(note: value.note) == value.expected)
    }

    @Test(arguments: [
        (CareActivity.bath, "Baño"),
        (CareActivity.temperature, "Temperatura · 36,8 °C"),
        (CareActivity.medication, "Medicación · Apiretal · 1 ml"),
        (CareActivity.symptom, "Síntoma · Tos seca"),
        (CareActivity.measurements, "Medidas · 4,2 kg · 53,5 cm"),
        (CareActivity.other, "Otro · Primera sonrisa"),
    ])
    func careActivityBuildsAReadableDetail(value: (activity: CareActivity, expected: String)) {
        let note = switch value.activity {
        case .symptom: "Tos seca"
        case .other: "Primera sonrisa"
        default: ""
        }
        #expect(
            value.activity.detail(
                note: note,
                temperatureCelsius: 36.8,
                medicationName: "Apiretal",
                medicationDose: "1 ml",
                weightKilograms: 4.2,
                heightCentimeters: 53.5
            ) == value.expected
        )
    }

    @Test
    func caregiverInvitationExplainsHowToJoin() throws {
        let caregiver = Caregiver(
            id: "caregiver-1",
            name: "Ana López",
            role: .caregiver,
            status: .pending,
            inviteCode: "ABCD-1234",
            createdAt: nil,
            joinedAt: nil
        )
        #expect(caregiver.initials == "AL")
        #expect(caregiver.invitationText?.contains("ABCD-1234") == true)
    }

    @Test
    func legacyEntriesDecodeWithoutACaregiver() throws {
        let data = Data(#"{"id":"old","kind":"sleep","title":"Sueño","detail":"","occurredAt":1,"durationMinutes":10,"amountMl":null}"#.utf8)
        let entry = try JSONDecoder().decode(Entry.self, from: data)
        #expect(entry.caregiverID == nil)
        #expect(entry.caregiverName == nil)
    }

    @Test
    func growthMeasurementReadsSpanishDecimals() throws {
        let source = Entry(
            id: "growth",
            kind: .health,
            title: "Salud y cuidado",
            detail: "Medidas · 4,2 kg · 53,5 cm",
            occurredAt: 1_000,
            durationMinutes: nil,
            amountMl: nil
        )
        let measurement = try #require(GrowthMeasurement(entry: source))
        #expect(measurement.weightKilograms == 4.2)
        #expect(measurement.heightCentimeters == 53.5)
    }

    @Test
    func backupNeverExportsInvitationCodes() throws {
        let caregiver = Caregiver(
            id: "caregiver",
            name: "Ana",
            role: .owner,
            status: .pending,
            inviteCode: "SECRET-CODE",
            createdAt: nil,
            joinedAt: nil
        )
        let url = try NidoBackup.make(profile: nil, caregivers: [caregiver], entries: [])
        let backup = try NidoBackup.load(from: url)
        #expect(backup.caregivers.first?.inviteCode == nil)
    }

    @Test
    func caregiverCredentialDecodesThePrivateToken() throws {
        let data = Data(#"{"caregiver":{"id":"one","name":"Ana","role":"owner","status":"active","inviteCode":null,"createdAt":null,"joinedAt":null},"accessToken":"private-token"}"#.utf8)
        let credential = try JSONDecoder().decode(CaregiverCredential.self, from: data)
        #expect(credential.caregiver.id == "one")
        #expect(credential.accessToken == "private-token")
    }

    private func entry(kind: EntryKind, date: Date, duration: Int? = nil, amount: Int? = nil) -> Entry {
        Entry(
            id: "entry",
            kind: kind,
            title: kind.title,
            detail: "",
            occurredAt: Int64(date.timeIntervalSince1970 * 1_000),
            durationMinutes: duration,
            amountMl: amount
        )
    }
}
