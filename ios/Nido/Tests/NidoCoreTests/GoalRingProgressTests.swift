import Foundation
import Testing
@testable import NidoCore

struct GoalRingProgressTests {
    @Test
    func preservesActualProgressWhileClampingOnlyTheVisualRing() {
        let progress = GoalRingProgress(value: 15, goal: 10)

        #expect(progress.value == 15)
        #expect(progress.goal == 10)
        #expect(progress.fraction == 1.5)
        #expect(progress.visualFraction == 1)
        #expect(progress.terminalAngleDegrees == 90)
        #expect(progress.showsTerminalCap)
    }

    @Test
    func missingOrInvalidGoalsHaveNoProgressFraction() {
        for goal in [nil, 0, -1, .infinity, .nan] as [Double?] {
            let progress = GoalRingProgress(value: 4, goal: goal)

            #expect(progress.goal == nil)
            #expect(progress.fraction == nil)
            #expect(progress.visualFraction == 0)
            #expect(progress.terminalAngleDegrees == nil)
            #expect(!progress.showsTerminalCap)
        }
    }

    @Test
    func zeroProgressHasNoTerminalCap() {
        let progress = GoalRingProgress(value: 0, goal: 10)

        #expect(progress.fraction == 0)
        #expect(progress.visualFraction == 0)
        #expect(progress.terminalAngleDegrees == -90)
        #expect(!progress.showsTerminalCap)
    }

    @Test
    func sanitizesInvalidValuesAndKeepsAnglesFiniteForExtremeRatios() {
        for value: Double in [-1, .infinity, -.infinity, .nan] {
            let progress = GoalRingProgress(value: value, goal: 10)

            #expect(progress.value == 0)
            #expect(progress.fraction == 0)
            #expect(!progress.showsTerminalCap)
        }

        let extreme = GoalRingProgress(
            value: Double.greatestFiniteMagnitude,
            goal: Double.leastNonzeroMagnitude
        )
        #expect(extreme.fraction == Double.greatestFiniteMagnitude)
        #expect(extreme.visualFraction == 1)
        #expect(extreme.terminalAngleDegrees == 270)
    }

    @Test
    func retainsFractionalAnglesBelowGoal() {
        let progress = GoalRingProgress(value: 2.5, goal: 10)

        #expect(progress.fraction == 0.25)
        #expect(progress.visualFraction == 0.25)
        #expect(progress.terminalAngleDegrees == 0)
    }

    @Test
    func overshootTerminalAngleUsesFractionalPartOfActualProgress() {
        let progress = GoalRingProgress(value: 1.25, goal: 1)

        #expect(progress.fraction == 1.25)
        #expect(progress.visualFraction == 1)
        #expect(progress.terminalAngleDegrees == 0)
    }

    @Test
    func exactGoalEndsAtTopOfRing() {
        let progress = GoalRingProgress(value: 10, goal: 10)

        #expect(progress.visualFraction == 1)
        #expect(progress.terminalAngleDegrees == 270)
    }
}
