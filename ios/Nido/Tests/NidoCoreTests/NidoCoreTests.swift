import Foundation
import Testing
@testable import NidoCore

struct NidoCoreTests {
    @Test
    func sleepIntervalCalculatesACompletedSameDaySleep() throws {
        let calendar = utcCalendar
        let reference = try date(hour: 16, calendar: calendar)
        let interval = try #require(SleepInterval.validated(
            start: try date(hour: 9, calendar: calendar),
            end: try date(hour: 15, calendar: calendar),
            notAfter: reference
        ))

        #expect(interval.durationMinutes == 360)
        #expect(calendar.component(.hour, from: interval.start) == 9)
        #expect(calendar.component(.hour, from: interval.end) == 15)
    }

    @Test
    func sleepIntervalUnderstandsMidnight() throws {
        let calendar = utcCalendar
        let reference = try date(hour: 3, calendar: calendar)
        let interval = try #require(SleepInterval.validated(
            start: try date(day: 27, hour: 22, calendar: calendar),
            end: try date(hour: 2, calendar: calendar),
            notAfter: reference
        ))

        #expect(interval.durationMinutes == 240)
        #expect(calendar.isDate(interval.start, inSameDayAs: try date(day: 27, hour: 22, calendar: calendar)))
        #expect(calendar.isDate(interval.end, inSameDayAs: reference))
    }

    @Test
    func sleepIntervalRejectsAnUnfinishedOrEmptyRange() throws {
        let calendar = utcCalendar
        let reference = try date(hour: 14, calendar: calendar)
        let start = try date(hour: 9, calendar: calendar)

        #expect(SleepInterval.validated(
            start: start,
            end: try date(hour: 15, calendar: calendar),
            notAfter: reference
        ) == nil)
        #expect(SleepInterval.validated(
            start: start,
            end: start,
            notAfter: reference
        ) == nil)
    }

    @Test
    func editedSleepKeepsItsOriginalDay() throws {
        let calendar = utcCalendar
        let interval = try #require(SleepInterval.validated(
            start: try date(day: 20, hour: 10, calendar: calendar),
            end: try date(day: 20, hour: 16, calendar: calendar),
            notAfter: try date(hour: 18, calendar: calendar)
        ))

        #expect(calendar.component(.day, from: interval.end) == 20)
        #expect(calendar.component(.hour, from: interval.end) == 16)
    }

    @Test
    func editingSleepReplacesItsStoredTimes() throws {
        let calendar = utcCalendar
        let originalEnd = try date(day: 20, hour: 12, calendar: calendar)
        let newStart = try date(day: 20, hour: 9, calendar: calendar)
        let newEnd = try date(day: 20, hour: 15, calendar: calendar)
        let interval = try #require(SleepInterval.validated(
            start: newStart,
            end: newEnd,
            notAfter: try date(hour: 18, calendar: calendar)
        ))
        let original = entry(kind: .sleep, date: originalEnd, detail: "10:00–12:00", duration: 120)

        let edited = original.edited(
            detail: interval.detail(note: "Ventana abierta"),
            occurredAt: interval.end,
            durationMinutes: interval.durationMinutes,
            amountMl: nil
        )

        #expect(edited.date == newEnd)
        #expect(edited.durationMinutes == 360)
        #expect(edited.detail.contains("Ventana abierta"))
        #expect(edited.id == original.id)
    }

    @Test
    func pendingEditsWinOverAnOlderRemoteCopy() throws {
        let calendar = utcCalendar
        let original = entry(
            kind: .sleep,
            date: try date(day: 20, hour: 12, calendar: calendar),
            detail: "Anterior",
            duration: 120
        )
        let edited = original.edited(
            detail: "09:00–15:00",
            occurredAt: try date(day: 20, hour: 15, calendar: calendar),
            durationMinutes: 360,
            amountMl: nil
        )

        let merged = EntryReconciliation.merge(
            remote: [original],
            local: [edited],
            protectedIDs: [edited.id]
        )

        let result = try #require(merged.first)
        #expect(result.date == edited.date)
        #expect(result.durationMinutes == 360)
        #expect(result.detail == "09:00–15:00")
    }

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

    @Test
    func entryDefaultsFollowTheLatestBabyRecordsAcrossCaregivers() {
        let older = Date(timeIntervalSince1970: 1_000)
        let newer = Date(timeIntervalSince1970: 2_000)
        let entries = [
            entry(
                kind: .feed,
                date: older,
                detail: "Lactancia · Pecho derecho",
                duration: 22,
                caregiverID: "david"
            ),
            entry(
                kind: .feed,
                date: newer,
                detail: "Biberón · Fórmula",
                amount: 60,
                caregiverID: "ana"
            ),
            entry(kind: .sleep, date: older, duration: 45, caregiverID: "david"),
            entry(kind: .sleep, date: newer, duration: 95, caregiverID: "ana"),
        ]

        let defaults = EntryFormDefaults(entries: entries)

        #expect(defaults.feed.type == .bottle)
        #expect(defaults.feed.amountMl == 60)
        #expect(defaults.feed.milkType == "Fórmula")
        #expect(defaults.feed.breastSide == .right)
        #expect(defaults.sleepDurationMinutes == 95)
    }

    @Test
    func entryDefaultsUseTheLatestValuesForEachFeedType() {
        let entries = [
            entry(
                kind: .feed,
                date: Date(timeIntervalSince1970: 3_000),
                detail: "Lactancia · Pecho ambos",
                duration: 18
            ),
            entry(
                kind: .feed,
                date: Date(timeIntervalSince1970: 2_000),
                detail: "Biberón · Fórmula",
                amount: 120
            ),
        ]

        let defaults = EntryFormDefaults(entries: entries)

        #expect(defaults.feed.type == .nursing)
        #expect(defaults.feed.durationMinutes == 18)
        #expect(defaults.feed.breastSide == .both)
        #expect(defaults.feed.milkType == "Fórmula")
    }

    @Test
    func entryDefaultsUnderstandLegacyBottleRecords() {
        let defaults = EntryFormDefaults(entries: [
            entry(
                kind: .feed,
                date: Date(timeIntervalSince1970: 1_000),
                detail: "Le ha dado hipo",
                amount: 60
            ),
        ])

        #expect(defaults.feed.type == .bottle)
        #expect(defaults.feed.amountMl == 60)
    }

    private func entry(
        kind: EntryKind,
        date: Date,
        detail: String = "",
        duration: Int? = nil,
        amount: Int? = nil,
        caregiverID: String? = nil
    ) -> Entry {
        Entry(
            id: UUID().uuidString,
            kind: kind,
            title: kind.title,
            detail: detail,
            occurredAt: Int64(date.timeIntervalSince1970 * 1_000),
            durationMinutes: duration,
            amountMl: amount,
            caregiverID: caregiverID
        )
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(day: Int = 28, hour: Int, minute: Int = 0, calendar: Calendar) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour, minute: minute)))
    }
}
