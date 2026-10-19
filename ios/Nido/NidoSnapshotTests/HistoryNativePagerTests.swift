import SwiftUI
import UIKit
import XCTest
@testable import Nido

@MainActor
final class HistoryNativePagerTests: XCTestCase {
    func testNonanimatedLatestSelectionClosesTheTransitionLifecycle() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let today = try date(day: 28, calendar: calendar)
        let adjacentSelection = try date(day: 27, calendar: calendar)
        let latestSelection = try date(day: 20, calendar: calendar)
        let store = NidoApp.makeLocalUITestStore(
            runID: UUID().uuidString,
            referenceNow: today,
            isSimulator: false
        )
        var transitionIsOpen = false
        var committedDates: [Date] = []
        var cancelledCount = 0

        let initialPager = makePager(
            store: store,
            selection: today,
            today: today,
            calendar: calendar,
            onTransitionWillBegin: { transitionIsOpen = true },
            onTransitionCancelled: {
                transitionIsOpen = false
                cancelledCount += 1
            },
            onPageCommitted: { date in
                transitionIsOpen = false
                committedDates.append(date)
            }
        )
        let coordinator = initialPager.makeCoordinator()
        let controller = DeferredCompletionPageViewController()
        controller.dataSource = coordinator
        controller.delegate = coordinator
        controller.loadViewIfNeeded()

        coordinator.installInitialPage(in: controller)
        controller.holdNextAnimatedCompletion = true
        coordinator.update(
            parent: makePager(store: store, selection: adjacentSelection, today: today, calendar: calendar),
            in: controller
        )
        coordinator.update(
            parent: makePager(
                store: store,
                selection: latestSelection,
                today: today,
                calendar: calendar,
                onTransitionWillBegin: { transitionIsOpen = true },
                onTransitionCancelled: {
                    transitionIsOpen = false
                    cancelledCount += 1
                },
                onPageCommitted: { date in
                    transitionIsOpen = false
                    committedDates.append(date)
                }
            ),
            in: controller
        )

        controller.finishHeldTransition()

        XCTAssertEqual(displayedDate(in: controller), latestSelection)
        XCTAssertEqual(committedDates, [latestSelection])
        XCTAssertEqual(cancelledCount, 0)
        XCTAssertFalse(transitionIsOpen)
    }

    func testLatestExternalSelectionIsAppliedAfterAnAnimatedSelectionSettles() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let today = try date(day: 28, calendar: calendar)
        let firstSelection = try date(day: 27, calendar: calendar)
        let latestSelection = try date(day: 26, calendar: calendar)
        let store = NidoApp.makeLocalUITestStore(
            runID: UUID().uuidString,
            referenceNow: today,
            isSimulator: false
        )
        let initialPager = makePager(store: store, selection: today, today: today, calendar: calendar)
        let coordinator = initialPager.makeCoordinator()
        let controller = DeferredCompletionPageViewController()
        controller.dataSource = coordinator
        controller.delegate = coordinator
        controller.loadViewIfNeeded()

        coordinator.installInitialPage(in: controller)
        controller.holdNextAnimatedCompletion = true

        coordinator.update(
            parent: makePager(store: store, selection: firstSelection, today: today, calendar: calendar),
            in: controller
        )
        XCTAssertEqual(displayedDate(in: controller), firstSelection)

        coordinator.update(
            parent: makePager(store: store, selection: latestSelection, today: today, calendar: calendar),
            in: controller
        )
        controller.finishHeldTransition()

        XCTAssertEqual(displayedDate(in: controller), latestSelection)
    }

    private func makePager(
        store: NidoStore,
        selection: Date,
        today: Date,
        calendar: Calendar,
        onTransitionWillBegin: @escaping () -> Void = {},
        onTransitionCancelled: @escaping () -> Void = {},
        onPageCommitted: @escaping (Date) -> Void = { _ in }
    ) -> HistoryNativePager {
        HistoryNativePager(
            store: store,
            dynamicTypeSize: .large,
            colorScheme: .light,
            selection: selection,
            today: today,
            calendar: calendar,
            reduceMotion: false,
            onTransitionWillBegin: onTransitionWillBegin,
            onTransitionCancelled: onTransitionCancelled,
            onPageCommitted: onPageCommitted
        ) { date, isCommitted in
            Text("\(date.timeIntervalSince1970)-\(isCommitted)")
        }
    }

    private func date(day: Int, calendar: Calendar) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: day)))
    }

    private func displayedDate(in controller: UIPageViewController) -> Date? {
        (controller.viewControllers?.first as? HistoryNativePager.PageController)?.date
    }
}

@MainActor
private final class DeferredCompletionPageViewController: UIPageViewController {
    var holdNextAnimatedCompletion = false
    private var heldCompletion: ((Bool) -> Void)?

    override func setViewControllers(
        _ viewControllers: [UIViewController]?,
        direction: UIPageViewController.NavigationDirection,
        animated: Bool,
        completion: ((Bool) -> Void)? = nil
    ) {
        if animated && holdNextAnimatedCompletion {
            holdNextAnimatedCompletion = false
            heldCompletion = completion
            super.setViewControllers(viewControllers, direction: direction, animated: false)
        } else {
            super.setViewControllers(viewControllers, direction: direction, animated: false, completion: completion)
        }
    }

    func finishHeldTransition() {
        let completion = heldCompletion
        heldCompletion = nil
        completion?(true)
    }
}
