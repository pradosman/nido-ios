import SwiftUI
import UIKit

private struct FloatingNavigationClearanceKey: EnvironmentKey {
    static let defaultValue: CGFloat = 12
}

extension EnvironmentValues {
    var floatingNavigationClearance: CGFloat {
        get { self[FloatingNavigationClearanceKey.self] }
        set { self[FloatingNavigationClearanceKey.self] = newValue }
    }
}

struct FloatingNavigationDock<Action: View, Notice: View>: UIViewControllerRepresentable {
    @Binding var selection: AppTab
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    let clearanceChanged: (CGFloat) -> Void
    let trendsTitle: String
    let action: Action
    let notice: Notice

    init(
        selection: Binding<AppTab>,
        clearanceChanged: @escaping (CGFloat) -> Void,
        trendsTitle: String = "Ritmos",
        @ViewBuilder action: () -> Action,
        @ViewBuilder notice: () -> Notice
    ) {
        _selection = selection
        self.clearanceChanged = clearanceChanged
        self.trendsTitle = trendsTitle
        self.action = action()
        self.notice = notice()
    }

    func makeUIViewController(context: Context) -> FloatingNavigationDockController {
        let controller = FloatingNavigationDockController()
        controller.onClearanceChanged = clearanceChanged
        controller.setContent(content)
        return controller
    }

    func updateUIViewController(_ controller: FloatingNavigationDockController, context: Context) {
        controller.onClearanceChanged = clearanceChanged
        withTransaction(context.transaction) {
            controller.setContent(content)
        }
    }

    private var content: AnyView {
        AnyView(
            FloatingDockContent(selection: $selection, trendsTitle: trendsTitle, action: action, notice: notice)
                .environment(\.dynamicTypeSize, dynamicTypeSize)
                .environment(\.colorScheme, colorScheme)
        )
    }
}

private struct FloatingDockContent<Action: View, Notice: View>: View {
    @Binding var selection: AppTab
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let trendsTitle: String
    let action: Action
    let notice: Notice

    private struct Tab: Identifiable {
        let selection: AppTab
        let title: String
        let image: String
        let selectedImage: String

        var id: AppTab { selection }
    }

    private var tabs: [Tab] { [
        Tab(selection: .today, title: "Hoy", image: "house", selectedImage: "house.fill"),
        Tab(selection: .history, title: "Historia", image: "clock.arrow.circlepath", selectedImage: "clock.arrow.circlepath"),
        Tab(selection: .trends, title: trendsTitle, image: "waveform.path", selectedImage: "waveform.path"),
        Tab(selection: .settings, title: "Ajustes", image: "gearshape", selectedImage: "gearshape.fill"),
    ] }

    var body: some View {
        VStack(spacing: 8) {
            notice

            HStack(spacing: 10) {
                tabBar
                action
                    .frame(width: 54, height: 54)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var tabBar: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 4) {
                    ForEach(tabs) { tab in
                        tabRow([tab])
                    }
                }
            } else {
                tabRow(tabs)
            }
        }
        .padding(4)
        .frame(minHeight: 62)
        .modifier(FloatingDockMaterial(accessibilityLayout: dynamicTypeSize.isAccessibilitySize))
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isTabBar)
        .accessibilityIdentifier("floating-navigation-tabbar")
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func tabRow(_ row: [Tab]) -> some View {
        HStack(spacing: 4) {
            ForEach(row) { tab in
                tabButton(
                    tab.selection,
                    title: tab.title,
                    image: tab.image,
                    selectedImage: tab.selectedImage
                )
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    @ViewBuilder
    private func tabButton(
        _ tab: AppTab,
        title: String,
        image: String,
        selectedImage: String
    ) -> some View {
        let isSelected = selection == tab
        FloatingDockTabButton(
            title: title,
            image: isSelected ? selectedImage : image,
            selected: isSelected,
            identifier: "tab-\(tabID(for: tab))"
        ) {
            selection = tab
        }
        .background {
            if isSelected {
                if dynamicTypeSize.isAccessibilitySize {
                    RoundedRectangle(cornerRadius: 16).fill(NidoTheme.tabSelection.opacity(0.14))
                } else {
                    Capsule().fill(NidoTheme.tabSelection.opacity(0.14))
                }
            }
        }
    }

    private func tabID(for tab: AppTab) -> String {
        switch tab {
        case .today: "today"
        case .history: "history"
        case .more: "more"
        case .trends: "trends"
        case .settings: "settings"
        }
    }
}

private struct FloatingDockTabButton: UIViewRepresentable {
    let title: String
    let image: String
    let selected: Bool
    let identifier: String
    let onTap: () -> Void
    @Environment(\.self) private var environment
    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 11
    @ScaledMetric(relativeTo: .title3) private var iconSize: CGFloat = 20

    @MainActor
    final class Coordinator {
        var onTap: () -> Void
        init(onTap: @escaping () -> Void) { self.onTap = onTap }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .custom)
        button.addAction(UIAction { [weak coordinator = context.coordinator] _ in
            coordinator?.onTap()
        }, for: .touchUpInside)
        button.isAccessibilityElement = true
        button.accessibilityIdentifier = identifier
        button.showsLargeContentViewer = true
        button.addInteraction(UILargeContentViewerInteraction())
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        context.coordinator.onTap = onTap
        let accessibilityLayout = environment.dynamicTypeSize.isAccessibilitySize
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.image = UIImage(systemName: image)
        configuration.imagePlacement = accessibilityLayout ? .leading : .top
        configuration.imagePadding = accessibilityLayout ? 8 : 3
        configuration.titleAlignment = accessibilityLayout ? .leading : .center
        configuration.contentInsets = accessibilityLayout
            ? NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            : .zero
        configuration.titleLineBreakMode = .byWordWrapping
        // Resolve against the app's SwiftUI appearance before configuring the UIKit control.
        let ink = (selected ? NidoTheme.tabSelection : NidoTheme.readableSupportingInk).resolve(in: environment)
        configuration.baseForegroundColor = UIColor(
            red: CGFloat(ink.red), green: CGFloat(ink.green),
            blue: CGFloat(ink.blue), alpha: CGFloat(ink.opacity)
        )
        let foreground = configuration.baseForegroundColor ?? .label
        configuration.background.backgroundColor = .clear
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: accessibilityLayout ? min(iconSize, 32) : iconSize,
            weight: .regular
        )
        let font = UIFont.systemFont(ofSize: labelSize, weight: .semibold)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var result = incoming
            result.font = font
            result.foregroundColor = foreground
            return result
        }
        button.configuration = configuration
        button.contentHorizontalAlignment = accessibilityLayout ? .leading : .center
        button.tintColor = foreground
        button.setTitleColor(foreground, for: .normal)
        button.setTitleColor(foreground, for: .selected)
        button.titleLabel?.numberOfLines = 0
        button.isSelected = selected
        button.accessibilityLabel = title
        button.accessibilityTraits = selected ? [.button, .selected] : [.button]
        button.largeContentTitle = title
        button.largeContentImage = configuration.image
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIButton, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.intrinsicContentSize.width
        uiView.titleLabel?.preferredMaxLayoutWidth = width
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(44, size.height))
    }
}

private struct FloatingDockMaterial: ViewModifier {
    let accessibilityLayout: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        content.background {
            if #available(iOS 26, *) {
                if accessibilityLayout {
                    Color.clear.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
                } else {
                    Color.clear.glassEffect(.regular, in: .capsule)
                }
            } else {
                if accessibilityLayout {
                    RoundedRectangle(cornerRadius: 28).fill(.thinMaterial)
                } else {
                    Capsule().fill(.thinMaterial)
                }
            }
        }
    }
}

@MainActor
final class FloatingNavigationDockController: UIViewController {
    private let host = UIHostingController(rootView: AnyView(EmptyView()))
    private var hostBottomConstraint: NSLayoutConstraint?
    private var hostHeightConstraint: NSLayoutConstraint?
    private var lastReportedClearance: CGFloat?

    var onClearanceChanged: ((CGFloat) -> Void)?

    override func loadView() {
        let passthroughView = DockPassthroughView()
        passthroughView.backgroundColor = .clear
        passthroughView.accessibilityIdentifier = "floating-navigation-overlay"
        passthroughView.accessibilityContainerType = .semanticGroup
        view = passthroughView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 16.4, *) {
            // The outer dock owns container-safe-area spacing; keep only keyboard avoidance in this host.
            host.safeAreaRegions = [.keyboard]
        }
        addChild(host)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        host.didMove(toParent: self)

        let height = host.view.heightAnchor.constraint(equalToConstant: 0)
        hostHeightConstraint = height
        let bottom = host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        hostBottomConstraint = bottom
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            bottom,
            height,
        ])
        updateHostBottomInset()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateHostBottomInset()
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHostBottomInset()
        updateHostedHeight()
        view.layoutIfNeeded()
        updateHitTesting()
        reportClearanceIfNeeded()
    }

    func setContent(_ content: AnyView) {
        host.rootView = content
        viewIfLoaded?.setNeedsLayout()
    }

    private func updateHostBottomInset() {
        guard let hostBottomConstraint else { return }
        let bottomInset: CGFloat = view.safeAreaInsets.bottom > 0 ? 20 : 8
        let constant = -bottomInset
        guard hostBottomConstraint.constant != constant else { return }
        hostBottomConstraint.constant = constant
    }

    private func updateHostedHeight() {
        let width = max(0, view.bounds.width - 40)
        let size = host.sizeThatFits(
            in: CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        hostHeightConstraint?.constant = size.height
    }

    private func updateHitTesting() {
        guard let passthroughView = view as? DockPassthroughView else { return }
        passthroughView.activeRegion = host.view.convert(host.view.bounds, to: view)
    }

    private func reportClearanceIfNeeded() {
        let hostedFrame = host.view.convert(host.view.bounds, to: view)
        let viewportBottom = view.safeAreaLayoutGuide.layoutFrame.maxY
        let clearance = max(0, viewportBottom - hostedFrame.minY) + 12
        guard lastReportedClearance.map({ abs($0 - clearance) > 0.5 }) ?? true else { return }
        lastReportedClearance = clearance
        Task { @MainActor [weak self] in
            self?.onClearanceChanged?(clearance)
        }
    }
}

@MainActor
private final class DockPassthroughView: UIView {
    var activeRegion: CGRect = .zero

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        activeRegion.contains(point) && super.point(inside: point, with: event)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard activeRegion.contains(point) else { return nil }
        return super.hitTest(point, with: event)
    }
}
