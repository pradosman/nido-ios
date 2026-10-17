import Foundation

/// Display-only progress math for a goal ring. Invalid goals mean no goal is set;
/// invalid or negative values are treated as zero so the renderer stays finite.
struct GoalRingProgress: Equatable, Sendable {
    let value: Double
    let goal: Double?

    /// Actual progress, which may exceed 1. A missing or invalid goal has no fraction.
    let fraction: Double?

    /// Progress used to draw the ring, bounded to one full revolution.
    let visualFraction: Double

    /// Degrees clockwise from the top, used for the local terminal cap.
    let terminalAngleDegrees: Double?

    var showsTerminalCap: Bool {
        fraction != nil && value > 0
    }

    init(value: Double, goal: Double?) {
        let safeValue = value.isFinite && value >= 0 ? value : 0
        let safeGoal = goal.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }

        self.value = safeValue
        self.goal = safeGoal

        guard let safeGoal else {
            fraction = nil
            visualFraction = 0
            terminalAngleDegrees = nil
            return
        }

        let ratio = safeValue / safeGoal
        // Finite inputs can still overflow when divided by a subnormal goal.
        let safeRatio = ratio.isFinite ? ratio : Double.greatestFiniteMagnitude
        let boundedRatio = min(max(safeRatio, 0), 1)

        fraction = safeRatio
        visualFraction = boundedRatio
        let terminalTurn = safeRatio > 1
            ? safeRatio.truncatingRemainder(dividingBy: 1)
            : safeRatio
        terminalAngleDegrees = terminalTurn == 0 && safeRatio > 1
            ? 270
            : -90 + terminalTurn * 360
    }
}
