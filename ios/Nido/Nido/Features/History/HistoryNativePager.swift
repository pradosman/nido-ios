import SwiftUI
import UIKit

/// A bounded, native horizontal pager for History's day detail.
/// The selected day is committed only after UIKit confirms that a swipe completed.
struct HistoryNativePager: UIViewControllerRepresentable {
    let store: NidoStore
    let dynamicTypeSize: DynamicTypeSize
    let colorScheme: ColorScheme

    let selection: Date
    let today: Date
    let calendar: Calendar
    let reduceMotion: Bool
    let onTransitionWillBegin: () -> Void
    let onTransitionCancelled: () -> Void
    let onPageCommitted: (Date) -> Void
    private let content: (Date, Bool) -> AnyView

    // Keep UIKit coordinator and controller classes independent of the page's
    // concrete SwiftUI type; pages are already hosted through AnyView.
    init<Content: View>(
        store: NidoStore,
        dynamicTypeSize: DynamicTypeSize,
        colorScheme: ColorScheme,
        selection: Date,
        today: Date,
        calendar: Calendar,
        reduceMotion: Bool,
        onTransitionWillBegin: @escaping () -> Void,
        onTransitionCancelled: @escaping () -> Void,
        onPageCommitted: @escaping (Date) -> Void,
        @ViewBuilder content: @escaping (Date, Bool) -> Content
    ) {
        self.store = store
        self.dynamicTypeSize = dynamicTypeSize
        self.colorScheme = colorScheme
        self.selection = selection
        self.today = today
        self.calendar = calendar
        self.reduceMotion = reduceMotion
        self.onTransitionWillBegin = onTransitionWillBegin
        self.onTransitionCancelled = onTransitionCancelled
        self.onPageCommitted = onPageCommitted
        self.content = { date, isCommitted in
            AnyView(content(date, isCommitted))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        context.coordinator.installInitialPage(in: controller)
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        context.coordinator.update(parent: self, in: controller)
    }

    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        private var parent: HistoryNativePager
        private var pages: [Date: PageController] = [:]
        private var currentDate: Date
        private var isTransitioning = false
        private var programmaticTargetDate: Date?
        private var pendingExternalSelection: Date?

        init(parent: HistoryNativePager) {
            self.parent = parent
            self.currentDate = parent.normalized(parent.selection)
        }

        func installInitialPage(in controller: UIPageViewController) {
            controller.setViewControllers([page(for: currentDate)], direction: .forward, animated: false)
        }

        func update(parent: HistoryNativePager, in controller: UIPageViewController) {
            self.parent = parent
            let requestedDate = parent.normalized(parent.selection)
            guard !isTransitioning else {
                pendingExternalSelection = requestedDate == currentDate ? nil : requestedDate
                return
            }
            pendingExternalSelection = nil

            guard requestedDate != currentDate else {
                refreshCachedPages()
                trimCachedPages()
                return
            }

            let direction: UIPageViewController.NavigationDirection = requestedDate > currentDate ? .forward : .reverse
            let isAdjacent = abs(parent.calendar.dateComponents([.day], from: currentDate, to: requestedDate).day ?? 0) == 1
            let shouldAnimate = isAdjacent && !parent.reduceMotion
            // Every programmatic selection uses the same completion path. A nonanimated
            // reconciliation still needs to commit the page and close any frozen anchor.
            programmaticTargetDate = requestedDate
            currentDate = requestedDate

            if shouldAnimate {
                isTransitioning = true
                parent.onTransitionWillBegin()
            }
            controller.setViewControllers(
                [page(for: requestedDate)],
                direction: direction,
                animated: shouldAnimate
            ) { [weak self] finished in
                self?.finishProgrammaticTransition(in: controller, finished: finished)
            }
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let page = viewController as? PageController,
                  let previousDate = parent.calendar.date(byAdding: .day, value: -1, to: page.date) else { return nil }
            return self.page(for: parent.normalized(previousDate))
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let page = viewController as? PageController,
                  let nextDate = parent.calendar.date(byAdding: .day, value: 1, to: page.date),
                  parent.normalized(nextDate) <= parent.normalized(parent.today) else { return nil }
            return self.page(for: parent.normalized(nextDate))
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            willTransitionTo pendingViewControllers: [UIViewController]
        ) {
            guard !pendingViewControllers.isEmpty else { return }
            isTransitioning = true
            if programmaticTargetDate == nil {
                parent.onTransitionWillBegin()
            }
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            if programmaticTargetDate != nil {
                finishProgrammaticTransition(in: pageViewController, finished: finished)
                return
            }

            if completed,
               let visiblePage = pageViewController.viewControllers?.first as? PageController {
                currentDate = visiblePage.date
                isTransitioning = false
                let hasPendingExternalSelection = pendingExternalSelection != nil
                pendingExternalSelection = nil
                if hasPendingExternalSelection && parent.normalized(parent.selection) != currentDate {
                    update(parent: parent, in: pageViewController)
                } else {
                    trimCachedPages()
                    parent.onPageCommitted(visiblePage.date)
                }
            } else {
                isTransitioning = false
                let hasPendingExternalSelection = pendingExternalSelection != nil
                pendingExternalSelection = nil
                refreshCachedPages()
                trimCachedPages()
                if hasPendingExternalSelection && parent.normalized(parent.selection) != currentDate {
                    update(parent: parent, in: pageViewController)
                } else {
                    parent.onTransitionCancelled()
                }
            }
        }

        private func finishProgrammaticTransition(in controller: UIPageViewController, finished: Bool) {
            guard programmaticTargetDate != nil else { return }
            programmaticTargetDate = nil
            isTransitioning = false
            pendingExternalSelection = nil
            if let visiblePage = controller.viewControllers?.first as? PageController {
                currentDate = visiblePage.date
            }

            refreshCachedPages()
            guard parent.normalized(parent.selection) == currentDate else {
                update(parent: parent, in: controller)
                return
            }

            trimCachedPages()
            parent.onPageCommitted(currentDate)
        }

        private func page(for date: Date) -> PageController {
            let date = parent.normalized(date)
            if let page = pages[date] {
                if !isTransitioning {
                    page.rootView = parent.hostedContent(for: date)
                }
                return page
            }

            let page = PageController(date: date, rootView: parent.hostedContent(for: date))
            page.view.backgroundColor = .clear
            pages[date] = page
            return page
        }

        private func refreshCachedPages() {
            for (date, page) in pages {
                page.rootView = parent.hostedContent(for: date)
            }
        }

        private func trimCachedPages() {
            pages = pages.filter { date, _ in
                guard let distance = parent.calendar.dateComponents([.day], from: currentDate, to: date).day else { return false }
                return (-1...1).contains(distance)
            }
        }
    }

    @MainActor
    final class PageController: UIHostingController<AnyView> {
        let date: Date

        init(date: Date, rootView: AnyView) {
            self.date = date
            super.init(rootView: rootView)
        }

        @available(*, unavailable)
        required dynamic init?(coder aDecoder: NSCoder) {
            fatalError("History pages are created in code.")
        }
    }

    private func hostedContent(for date: Date) -> AnyView {
        AnyView(
            content(date, calendar.isDate(date, inSameDayAs: selection))
                .environment(store)
                .environment(\.calendar, calendar)
                .environment(\.timeZone, calendar.timeZone)
                .environment(\.dynamicTypeSize, dynamicTypeSize)
                .environment(\.colorScheme, colorScheme)
        )
    }

    private func normalized(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
}
