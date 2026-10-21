import Foundation

nonisolated enum EvolutionChartAxis {
    static func visibleIndices(bucketCount: Int, maximumLabels: Int) -> [Int] {
        guard bucketCount > 0, maximumLabels > 0 else { return [] }
        let quotient = bucketCount / maximumLabels
        let remainder = bucketCount % maximumLabels
        let step = max(1, quotient + (remainder == 0 ? 0 : 1))

        var indices: [Int] = []
        var index = 0
        while index < bucketCount, indices.count < maximumLabels {
            indices.append(index)
            guard index <= Int.max - step else { break }
            index += step
        }
        return indices
    }
}
