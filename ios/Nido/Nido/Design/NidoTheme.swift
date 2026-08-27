import SwiftUI

enum NidoTheme {
    static let paper = Color(light: UIColor(red: 0.965, green: 0.941, blue: 0.898, alpha: 1), dark: UIColor(red: 0.09, green: 0.10, blue: 0.09, alpha: 1))
    static let paperLight = Color(light: UIColor(red: 0.992, green: 0.982, blue: 0.958, alpha: 1), dark: UIColor(red: 0.13, green: 0.14, blue: 0.13, alpha: 1))
    static let ink = Color(light: UIColor(red: 0.14, green: 0.13, blue: 0.11, alpha: 1), dark: UIColor(red: 0.94, green: 0.93, blue: 0.89, alpha: 1))
    static let secondaryInk = Color(light: UIColor(red: 0.48, green: 0.44, blue: 0.39, alpha: 1), dark: UIColor(red: 0.68, green: 0.67, blue: 0.63, alpha: 1))
    static let moss = Color(red: 0.32, green: 0.43, blue: 0.37)
    static let sleep = Color(red: 0.32, green: 0.43, blue: 0.51)
    static let feed = Color(red: 0.70, green: 0.44, blue: 0.17)
    static let diaper = Color(red: 0.25, green: 0.51, blue: 0.60)
    static let care = Color(red: 0.65, green: 0.32, blue: 0.44)

    static func color(for kind: EntryKind) -> Color {
        switch kind {
        case .sleep: sleep
        case .feed: feed
        case .diaper: diaper
        case .health: care
        }
    }
}

struct PaperBackground: View {
    var body: some View {
        LinearGradient(
            colors: [NidoTheme.paperLight, NidoTheme.paper, NidoTheme.paper.opacity(0.92)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(NidoTheme.moss.opacity(0.05))
                .frame(width: 320)
                .blur(radius: 40)
                .offset(x: 150, y: -170)
        }
        .ignoresSafeArea()
    }
}

struct NidoMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(NidoTheme.moss)
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
        }
        .accessibilityHidden(true)
    }
}

struct EditorialTitle: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 44

    init(size: CGFloat) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .largeTitle)
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .regular, design: .serif))
            .tracking(size > 40 ? -1.1 : -0.6)
            .foregroundStyle(NidoTheme.ink)
    }
}

extension View {
    func editorialTitle(_ size: CGFloat) -> some View {
        modifier(EditorialTitle(size: size))
    }

    func paperCard(cornerRadius: CGFloat = 22) -> some View {
        background(Color(uiColor: .secondarySystemBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.8), lineWidth: 0.7)
            }
            .shadow(color: NidoTheme.ink.opacity(0.055), radius: 18, y: 8)
    }
}

struct EntryGlyph: View {
    let kind: EntryKind
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: kind.symbolName)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(NidoTheme.color(for: kind))
            .frame(width: max(44, size + 20), height: max(44, size + 20))
            .contentShape(Rectangle())
            .accessibilityHidden(true)
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? .linear(duration: 0.08) : .snappy(duration: 0.14, extraBounce: 0), value: configuration.isPressed)
    }
}

private extension Color {
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }
}
