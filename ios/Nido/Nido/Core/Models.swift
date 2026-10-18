import Foundation

nonisolated struct Profile: Codable, Equatable, Sendable {
    var caregiverName: String
    var babyName: String
    var birthDate: String

    var initials: String {
        babyName.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init)?.uppercased() ?? "N"
    }
}

nonisolated enum CaregiverRole: String, Codable, Sendable {
    case owner
    case caregiver

    var displayName: String {
        switch self {
        case .owner: "Administrador del hogar"
        case .caregiver: "Familiar"
        }
    }
}

nonisolated enum CaregiverStatus: String, Codable, Sendable {
    case pending
    case active
}

nonisolated struct Caregiver: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let role: CaregiverRole
    let status: CaregiverStatus
    let inviteCode: String?
    let createdAt: String?
    let joinedAt: String?

    var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    var invitationText: String? {
        guard let inviteCode else { return nil }
        return "Te invito a compartir la información familiar en Nido. Abre la app e introduce el código \(inviteCode)."
    }
}

nonisolated enum EntryKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case sleep
    case feed
    case diaper
    case health

    var id: Self { self }

    var title: String {
        switch self {
        case .sleep: "Sueño"
        case .feed: "Toma"
        case .diaper: "Pañal"
        case .health: "Cuidados"
        }
    }

    var careCategory: CareCategory {
        switch self {
        case .sleep: .sleep
        case .feed: .feed
        case .diaper: .diaper
        case .health: .health
        }
    }

    /// SF Symbol fallback for APIs that cannot render the shared category glyph.
    var symbolName: String { careCategory.shortcutSystemImageName }
}

nonisolated enum FeedType: String, CaseIterable, Identifiable, Sendable {
    case nursing
    case bottle
    case pumping
    case solids

    var id: Self { self }
    var title: String {
        switch self {
        case .nursing: "Pecho"
        case .bottle: "Biberón"
        case .pumping: "Extracción"
        case .solids: "Sólidos"
        }
    }
    var symbolName: String {
        switch self {
        case .nursing: "figure.and.child.holdinghands"
        case .bottle: "waterbottle.fill"
        case .pumping: "drop.circle.fill"
        case .solids: "fork.knife"
        }
    }
}

nonisolated enum BreastSide: String, CaseIterable, Identifiable, Sendable {
    case left
    case right
    case both

    var id: Self { self }
    var title: String {
        switch self {
        case .left: "Izquierdo"
        case .right: "Derecho"
        case .both: "Ambos"
        }
    }
}

nonisolated struct Entry: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let kind: EntryKind
    let title: String
    let detail: String
    let occurredAt: Int64
    let durationMinutes: Int?
    let amountMl: Int?
    var caregiverID: String? = nil
    var caregiverName: String? = nil

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(occurredAt) / 1_000)
    }

    func edited(
        detail: String,
        occurredAt date: Date,
        durationMinutes: Int?,
        amountMl: Int?
    ) -> Entry {
        Entry(
            id: id,
            kind: kind,
            title: title,
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
            occurredAt: Int64(date.timeIntervalSince1970 * 1_000),
            durationMinutes: durationMinutes,
            amountMl: amountMl,
            caregiverID: caregiverID,
            caregiverName: caregiverName
        )
    }
}

extension Entry {
    nonisolated var summary: String {
        let pieces: [String?] = [
            durationMinutes.map(DurationLabel.minutes),
            amountMl.map { "\($0) ml" },
            detail.isEmpty ? nil : detail,
        ]
        return pieces.compactMap { $0 }.joined(separator: " · ")
    }
}

nonisolated enum DurationLabel {
    static func minutes(_ totalMinutes: Int) -> String {
        let totalMinutes = max(0, totalMinutes)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes) min" }
        if minutes == 0 { return "\(hours) h" }
        return "\(hours) h \(minutes) min"
    }
}

nonisolated enum EntryMoment {
    static func resolve(kind: EntryKind, selectedDate: Date, sleepInterval: SleepInterval?) -> Date {
        guard kind == .sleep else { return selectedDate }
        return sleepInterval?.end ?? selectedDate
    }
}

nonisolated enum EntryReconciliation {
    static func merge(
        remote: [Entry],
        local: [Entry],
        protectedIDs: Set<String>,
        excludedIDs: Set<String> = []
    ) -> [Entry] {
        var entriesByID: [String: Entry] = [:]
        for entry in remote where !excludedIDs.contains(entry.id) {
            entriesByID[entry.id] = entry
        }
        for entry in local where protectedIDs.contains(entry.id) && !excludedIDs.contains(entry.id) {
            entriesByID[entry.id] = entry
        }
        return entriesByID.values.sorted {
            $0.occurredAt == $1.occurredAt ? $0.id > $1.id : $0.occurredAt > $1.occurredAt
        }
    }
}

nonisolated struct SleepInterval: Equatable, Sendable {
    let start: Date
    let end: Date

    var durationMinutes: Int {
        max(1, Int(end.timeIntervalSince(start) / 60))
    }

    var durationLabel: String {
        DurationLabel.minutes(durationMinutes)
    }

    var label: String {
        let sameDay = Calendar.current.isDate(start, inSameDayAs: end)
        let startLabel = start.formatted(date: sameDay ? .omitted : .abbreviated, time: .shortened)
        let endLabel = end.formatted(date: sameDay ? .omitted : .abbreviated, time: .shortened)
        return "\(startLabel)–\(endLabel)"
    }

    func detail(note: String) -> String {
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanNote.isEmpty ? label : "\(label) · \(cleanNote)"
    }

    static func note(from detail: String) -> String {
        let parts = detail.components(separatedBy: " · ")
        guard let first = parts.first, first.contains(":"), first.contains("–") else {
            return detail == "Temporizador" ? "" : detail
        }
        return parts.dropFirst().joined(separator: " · ")
    }

    static func validated(start: Date, end: Date, notAfter latestEnd: Date = .now) -> SleepInterval? {
        guard end > start, end <= latestEnd else { return nil }
        return SleepInterval(start: start, end: end)
    }
}

nonisolated struct NidoSnapshot: Codable, Equatable, Sendable {
    var profile: Profile?
    var entries: [Entry]
    var pendingEntryIDs: Set<String>
    var profileNeedsSync: Bool

    static let empty = NidoSnapshot(profile: nil, entries: [], pendingEntryIDs: [], profileNeedsSync: false)
}

nonisolated struct DayMetrics: Equatable, Sendable {
    let sleepMinutes: Int
    let feeds: Int
    let feedMl: Int
    let diapers: Int
}

nonisolated struct LegacyGrowthMeasurement: Identifiable, Equatable, Sendable {
    let id: String
    let date: Date
    let weightKilograms: Double?
    let heightCentimeters: Double?
    let note: String

    init?(entry: Entry) {
        guard entry.kind == .health, entry.detail.hasPrefix("Medidas") else { return nil }
        let values = entry.detail.split(separator: "·").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        func measurement(ending unit: String) -> Double? {
            guard let value = values.first(where: { $0.contains(unit) }),
                  let unitRange = value.range(of: unit) else { return nil }
            return Double(value[..<unitRange.lowerBound].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
        }
        let weight = measurement(ending: "kg")
        let height = measurement(ending: "cm")
        guard weight != nil || height != nil else { return nil }
        id = entry.id
        date = entry.date
        weightKilograms = weight
        heightCentimeters = height
        if let details = CareEntryDetails.parse(entry.detail), details.activity == .measurements {
            note = details.note
        } else {
            note = values.dropFirst().filter { !$0.contains("kg") && !$0.contains("cm") }
                .joined(separator: " · ")
        }
    }
}

nonisolated struct DiaperContents: OptionSet, Equatable, Sendable {
    let rawValue: Int

    static let urine = DiaperContents(rawValue: 1 << 0)
    static let stool = DiaperContents(rawValue: 1 << 1)

    func detail(note: String) -> String {
        let contents = switch self {
        case [.urine, .stool]: "Pis y caca"
        case [.urine]: "Pis"
        case [.stool]: "Caca"
        default: "Cambio de pañal"
        }
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanNote.isEmpty ? contents : "\(contents) · \(cleanNote)"
    }
}

nonisolated struct FeedEntryDetails: Equatable, Sendable {
    var type: FeedType
    var breastSide: BreastSide
    var milkType: String
    var note: String

    var formatted: String {
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts: [String] = switch type {
        case .nursing: ["Lactancia", "Pecho \(breastSide.title.lowercased())", cleanNote]
        case .bottle: ["Biberón", milkType, cleanNote]
        case .pumping: ["Extracción", cleanNote]
        case .solids: ["Sólidos", cleanNote]
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    static func parse(_ detail: String) -> FeedEntryDetails? {
        let parts = detail.detailParts
        guard let activity = parts.first else { return nil }
        switch activity {
        case "Lactancia":
            guard parts.count >= 2, parts[1].hasPrefix("Pecho ") else { return nil }
            let sideLabel = String(parts[1].dropFirst("Pecho ".count))
            guard let side = BreastSide.allCases.first(where: {
                $0.title.lowercased() == sideLabel.lowercased()
            }) else { return nil }
            return FeedEntryDetails(
                type: .nursing,
                breastSide: side,
                milkType: "Leche materna",
                note: parts.dropFirst(2).joined(separator: " · ")
            )
        case "Biberón":
            guard parts.count >= 2, ["Leche materna", "Fórmula"].contains(parts[1]) else { return nil }
            return FeedEntryDetails(
                type: .bottle,
                breastSide: .left,
                milkType: parts[1],
                note: parts.dropFirst(2).joined(separator: " · ")
            )
        case "Extracción":
            return FeedEntryDetails(
                type: .pumping,
                breastSide: .left,
                milkType: "Leche materna",
                note: parts.dropFirst().joined(separator: " · ")
            )
        case "Sólidos":
            return FeedEntryDetails(
                type: .solids,
                breastSide: .left,
                milkType: "Leche materna",
                note: parts.dropFirst().joined(separator: " · ")
            )
        default:
            return nil
        }
    }
}

nonisolated struct DiaperEntryDetails: Equatable, Sendable {
    var contents: DiaperContents
    var note: String

    var formatted: String { contents.detail(note: note) }

    static func parse(_ detail: String) -> DiaperEntryDetails? {
        let parts = detail.detailParts
        guard let description = parts.first else { return nil }
        let contents: DiaperContents
        switch description {
        case "Pis y caca": contents = [.urine, .stool]
        case "Pis": contents = [.urine]
        case "Caca": contents = [.stool]
        case "Cambio de pañal": contents = []
        default: return nil
        }
        return DiaperEntryDetails(
            contents: contents,
            note: parts.dropFirst().joined(separator: " · ")
        )
    }
}

nonisolated enum CareActivity: String, CaseIterable, Identifiable, Sendable {
    case bath
    case temperature
    case medication
    case symptom
    case measurements
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .bath: "Baño"
        case .temperature: "Temperatura"
        case .medication: "Medicación"
        case .symptom: "Síntoma"
        case .measurements: "Medidas"
        case .other: "Otro"
        }
    }

    var symbolName: String {
        switch self {
        case .bath: "bathtub.fill"
        case .temperature: "thermometer.medium"
        case .medication: "pills.fill"
        case .symptom: "cross.case.fill"
        case .measurements: "ruler.fill"
        case .other: "ellipsis"
        }
    }

    func detail(
        note: String,
        temperatureCelsius: Double,
        medicationName: String,
        medicationDose: String,
        weightKilograms: Double,
        heightCentimeters: Double
    ) -> String {
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts: [String] = switch self {
        case .bath:
            [title, cleanNote]
        case .temperature:
            [title, Self.decimal(temperatureCelsius) + " °C", cleanNote]
        case .medication:
            [
                title,
                medicationName.trimmingCharacters(in: .whitespacesAndNewlines),
                medicationDose.trimmingCharacters(in: .whitespacesAndNewlines),
                cleanNote
            ]
        case .symptom, .other:
            [title, cleanNote]
        case .measurements:
            [
                title,
                Self.decimal(weightKilograms) + " kg",
                Self.decimal(heightCentimeters) + " cm",
                cleanNote
            ]
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private static func decimal(_ value: Double) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: "es_ES"))
                .precision(.fractionLength(1))
        )
    }
}

nonisolated struct CareEntryDetails: Equatable, Sendable {
    var activity: CareActivity
    var note: String
    var temperatureCelsius: Double
    var medicationName: String
    var medicationDose: String
    var weightKilograms: Double
    var heightCentimeters: Double

    var formatted: String {
        activity.detail(
            note: note,
            temperatureCelsius: temperatureCelsius,
            medicationName: medicationName,
            medicationDose: medicationDose,
            weightKilograms: weightKilograms,
            heightCentimeters: heightCentimeters
        )
    }

    static func parse(_ detail: String) -> CareEntryDetails? {
        let parts = detail.detailParts
        guard let title = parts.first,
              let activity = CareActivity.allCases.first(where: { $0.title == title })
        else { return nil }

        var result = CareEntryDetails(
            activity: activity,
            note: "",
            temperatureCelsius: 36.5,
            medicationName: "",
            medicationDose: "",
            weightKilograms: 4,
            heightCentimeters: 52
        )
        switch activity {
        case .bath, .symptom, .other:
            result.note = parts.dropFirst().joined(separator: " · ")
        case .temperature:
            guard parts.count >= 2,
                  let temperature = decimal(parts[1], unit: "°C")
            else { return nil }
            result.temperatureCelsius = temperature
            result.note = parts.dropFirst(2).joined(separator: " · ")
        case .medication:
            guard parts.count >= 2 else { return nil }
            result.medicationName = parts[1]
            if parts.count >= 3 { result.medicationDose = parts[2] }
            result.note = parts.dropFirst(min(parts.count, 3)).joined(separator: " · ")
        case .measurements:
            guard parts.count >= 3,
                  let weight = decimal(parts[1], unit: "kg"),
                  let height = decimal(parts[2], unit: "cm")
            else { return nil }
            result.weightKilograms = weight
            result.heightCentimeters = height
            result.note = parts.dropFirst(3).joined(separator: " · ")
        }
        return result
    }

    private static func decimal(_ value: String, unit: String) -> Double? {
        guard value.hasSuffix(unit) else { return nil }
        return Double(
            value.dropLast(unit.count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")
        )
    }
}

nonisolated enum EntryDetailPersistence {
    static func preserved(_ original: String, semanticDetail: String?) -> String {
        semanticDetail ?? original
    }
}

private nonisolated extension String {
    var detailParts: [String] {
        components(separatedBy: " · ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
