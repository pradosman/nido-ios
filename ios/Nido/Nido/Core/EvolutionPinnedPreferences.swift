import Foundation
import CryptoKit

nonisolated struct EvolutionPreferenceScope: Equatable, Hashable, Sendable {
    let caregiverID: String
    let babyID: String

    init(caregiverID: String, babyID: String) {
        self.caregiverID = caregiverID
        self.babyID = babyID
    }

    var defaultsKey: String {
        "com.momentumia.nido.evolution-pinned.v1.\(Self.fingerprint(caregiverID: caregiverID, babyID: babyID))"
    }

    private static func fingerprint(caregiverID: String, babyID: String) -> String {
        var bytes = Data()
        for identifier in [caregiverID, babyID] {
            let encoded = Data(identifier.utf8)
            var length = UInt64(encoded.count).bigEndian
            withUnsafeBytes(of: &length) { bytes.append(contentsOf: $0) }
            bytes.append(encoded)
        }
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}

nonisolated struct EvolutionPinnedPreferences: Equatable, Sendable {
    static let defaultOrder: [EvolutionMetric] = [.sleep, .feeds, .diapers, .weight, .height]

    private(set) var pinnedMetrics: [EvolutionMetric]

    init() {
        pinnedMetrics = Self.defaultOrder
    }

    init(pinnedMetrics: [EvolutionMetric]) {
        var seen = Set<EvolutionMetric>()
        self.pinnedMetrics = pinnedMetrics.filter { seen.insert($0).inserted }
    }

    init(metricIDs: [String]) {
        let knownMetrics = Dictionary(uniqueKeysWithValues: EvolutionMetric.allCases.map { ($0.rawValue, $0) })
        var seen = Set<EvolutionMetric>()
        pinnedMetrics = metricIDs.compactMap { knownMetrics[$0] }.filter { seen.insert($0).inserted }
    }

    var metricIDs: [String] { pinnedMetrics.map(\.rawValue) }

    mutating func toggle(_ metric: EvolutionMetric) {
        if let index = pinnedMetrics.firstIndex(of: metric) {
            pinnedMetrics.remove(at: index)
        } else {
            pinnedMetrics.append(metric)
        }
    }

    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let validOffsets = source.filter { pinnedMetrics.indices.contains($0) }
        guard !validOffsets.isEmpty else { return }

        let moving = validOffsets.map { pinnedMetrics[$0] }
        for offset in validOffsets.reversed() {
            pinnedMetrics.remove(at: offset)
        }

        let removedBeforeDestination = validOffsets.filter { $0 < destination }.count
        let insertionIndex = min(max(0, destination - removedBeforeDestination), pinnedMetrics.count)
        pinnedMetrics.insert(contentsOf: moving, at: insertionIndex)
    }
}

nonisolated struct EvolutionPinnedPreferencesStore {
    private struct StoredPreferences: Codable {
        let schemaVersion: Int
        let pinnedMetricIDs: [String]
    }

    private let defaults: UserDefaults
    private let scope: EvolutionPreferenceScope

    init(defaults: UserDefaults, scope: EvolutionPreferenceScope) {
        self.defaults = defaults
        self.scope = scope
    }

    func load() -> EvolutionPinnedPreferences {
        guard let data = defaults.data(forKey: scope.defaultsKey),
              let stored = try? JSONDecoder().decode(StoredPreferences.self, from: data),
              stored.schemaVersion == 1
        else { return EvolutionPinnedPreferences() }
        return EvolutionPinnedPreferences(metricIDs: stored.pinnedMetricIDs)
    }

    func save(_ preferences: EvolutionPinnedPreferences) {
        let stored = StoredPreferences(schemaVersion: 1, pinnedMetricIDs: preferences.metricIDs)
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: scope.defaultsKey)
    }
}
