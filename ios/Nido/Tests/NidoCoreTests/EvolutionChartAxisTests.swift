import Testing
@testable import NidoCore

struct EvolutionChartAxisTests {
    @Test func selectsReadableEvenlySpacedTicksWithoutChangingBucketIndices() {
        #expect(EvolutionChartAxis.visibleIndices(bucketCount: 24, maximumLabels: 6) == [0, 4, 8, 12, 16, 20])
        #expect(EvolutionChartAxis.visibleIndices(bucketCount: 31, maximumLabels: 6) == [0, 6, 12, 18, 24, 30])
        #expect(EvolutionChartAxis.visibleIndices(bucketCount: 12, maximumLabels: 6) == [0, 2, 4, 6, 8, 10])
        #expect(EvolutionChartAxis.visibleIndices(bucketCount: 7, maximumLabels: 7) == Array(0..<7))
    }

    @Test func keepsIndicesUniqueInBoundsAndWithinTheLabelLimit() {
        for bucketCount in 0...40 {
            for maximumLabels in -1...10 {
                let indices = EvolutionChartAxis.visibleIndices(bucketCount: bucketCount, maximumLabels: maximumLabels)
                #expect(indices.count <= max(0, maximumLabels))
                #expect(indices == indices.sorted())
                #expect(Set(indices).count == indices.count)
                #expect(indices.allSatisfy { $0 >= 0 && $0 < bucketCount })
            }
        }
        #expect(EvolutionChartAxis.visibleIndices(bucketCount: 25, maximumLabels: 6).count <= 6)
        #expect(EvolutionChartAxis.visibleIndices(bucketCount: 24, maximumLabels: 0).isEmpty)
        #expect(EvolutionChartAxis.visibleIndices(bucketCount: 0, maximumLabels: 6).isEmpty)
    }
}
