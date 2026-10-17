import Foundation

nonisolated enum BabyCareReconciliation {
    static func mergedMeasurements(state: BabyCareState, entries: [Entry]) -> [GrowthMeasurement] {
        var valuesByID: [String: GrowthMeasurement] = [:]
        for entry in entries {
            guard let legacy = LegacyGrowthMeasurement(entry: entry) else { continue }
            valuesByID[legacy.id] = GrowthMeasurement(
                id: legacy.id,
                measuredAt: Int64(legacy.date.timeIntervalSince1970 * 1_000),
                weightGrams: legacy.weightKilograms.map { Int(($0 * 1_000).rounded()) },
                heightMillimeters: legacy.heightCentimeters.map { Int(($0 * 10).rounded()) },
                note: legacy.note
            )
        }
        for measurement in state.measurements { valuesByID[measurement.id] = measurement }
        return valuesByID.values.sorted {
            $0.measuredAt == $1.measuredAt ? $0.id < $1.id : $0.measuredAt < $1.measuredAt
        }
    }
    static func rebased(local: BabyCareState, base: BabyCareState, remote: BabyCareState) -> BabyCareState? {
        let localZoneChanged = local.timeZoneID != base.timeZoneID
        let remoteZoneChanged = remote.timeZoneID != base.timeZoneID
        if localZoneChanged && remoteZoneChanged && local.timeZoneID != remote.timeZoneID { return nil }
        let timeZoneID = localZoneChanged ? local.timeZoneID : remote.timeZoneID

        guard let baseGoals = uniqueMap(base.goalVersions, key: \.effectiveDate),
              let localGoals = uniqueMap(local.goalVersions, key: \.effectiveDate),
              let remoteGoals = uniqueMap(remote.goalVersions, key: \.effectiveDate),
              let baseMeasurements = uniqueMap(base.measurements, key: \.id),
              let localMeasurements = uniqueMap(local.measurements, key: \.id),
              let remoteMeasurements = uniqueMap(remote.measurements, key: \.id),
              let goals = mergeByKey(base: baseGoals, local: localGoals, remote: remoteGoals),
              let measurements = mergeByKey(base: baseMeasurements, local: localMeasurements, remote: remoteMeasurements)
        else { return nil }

        return BabyCareState(
            revision: remote.revision,
            timeZoneID: timeZoneID,
            goalVersions: goals.values.sorted { $0.effectiveDate < $1.effectiveDate },
            measurements: measurements.values.sorted {
                $0.measuredAt == $1.measuredAt ? $0.id < $1.id : $0.measuredAt < $1.measuredAt
            }
        )
    }

    private static func mergeByKey<Value: Equatable>(
        base: [String: Value],
        local: [String: Value],
        remote: [String: Value]
    ) -> [String: Value]? {
        let keys = Set(base.keys).union(local.keys).union(remote.keys)
        var result = remote
        for key in keys {
            let localChanged = local[key] != base[key]
            let remoteChanged = remote[key] != base[key]
            if localChanged && remoteChanged && local[key] != remote[key] { return nil }
            if localChanged {
                if let value = local[key] { result[key] = value }
                else { result.removeValue(forKey: key) }
            }
        }
        return result
    }

    private static func uniqueMap<Value, Key: Hashable>(
        _ values: [Value],
        key: KeyPath<Value, Key>
    ) -> [Key: Value]? {
        var result: [Key: Value] = [:]
        for value in values {
            let identifier = value[keyPath: key]
            guard result[identifier] == nil else { return nil }
            result[identifier] = value
        }
        return result
    }

}
