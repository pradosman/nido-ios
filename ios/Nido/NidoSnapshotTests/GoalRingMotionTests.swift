import SwiftUI
import XCTest
@testable import Nido

@MainActor
final class GoalRingMotionTests: XCTestCase {
    func testAnimationInterpolatesActualQuantitiesAcrossOneFullTurn() throws {
        var rings = GoalRingsView(sleep: 99, sleepGoal: 100, feed: 7, feedGoal: 8, diaper: 5, diaperGoal: 6)
        let target = GoalRingsView(sleep: 110, sleepGoal: 100, feed: 9, feedGoal: 8, diaper: 7, diaperGoal: 6)
        var delta = target.animatableData - rings.animatableData
        delta.scale(by: 0.5)
        rings.animatableData += delta
        XCTAssertEqual(rings.sleep, 104.5)
        XCTAssertEqual(rings.feed, 8)
        XCTAssertEqual(rings.diaper, 6)
        let progress = GoalRingProgress(value: rings.sleep, goal: rings.sleepGoal)
        let fraction = try XCTUnwrap(progress.fraction)
        XCTAssertGreaterThan(fraction, 1)
        XCTAssertLessThan(fraction, 1.1)
    }
}
