import SwiftUI

enum NidoTheme {
    static let paper = Color(
        light: UIColor(red: 0.969, green: 0.973, blue: 0.961, alpha: 1),
        dark: UIColor(red: 0.075, green: 0.082, blue: 0.078, alpha: 1),
        highContrastLight: UIColor(red: 0.99, green: 0.99, blue: 0.98, alpha: 1),
        highContrastDark: UIColor(red: 0.035, green: 0.04, blue: 0.037, alpha: 1)
    )
    static let paperLight = Color(
        light: UIColor(red: 0.99, green: 0.99, blue: 0.98, alpha: 1),
        dark: UIColor(red: 0.105, green: 0.115, blue: 0.108, alpha: 1),
        highContrastLight: .white,
        highContrastDark: UIColor(red: 0.07, green: 0.075, blue: 0.072, alpha: 1)
    )
    static let surface = Color(
        light: UIColor(white: 1, alpha: 0.72),
        dark: UIColor(red: 0.14, green: 0.15, blue: 0.145, alpha: 0.94),
        highContrastLight: .white,
        highContrastDark: UIColor(red: 0.18, green: 0.19, blue: 0.185, alpha: 1)
    )
    static let ink = Color(
        light: UIColor(red: 0.129, green: 0.224, blue: 0.176, alpha: 1),
        dark: .label,
        highContrastLight: .black,
        highContrastDark: .white
    )
    static let secondaryInk = Color(uiColor: .secondaryLabel)
    static let separator = Color(uiColor: .separator)
    static let error = Color(uiColor: .systemRed)
    static let warning = Color(uiColor: .systemOrange)
    static let moss = Color(
        light: UIColor(red: 0.149, green: 0.463, blue: 0.357, alpha: 1),
        dark: UIColor(red: 0.48, green: 0.80, blue: 0.63, alpha: 1)
    )
    static let textOnMoss = Color(
        light: .white,
        dark: UIColor(red: 0.06, green: 0.07, blue: 0.065, alpha: 1),
        highContrastLight: .white,
        highContrastDark: .black
    )
    static let prominentActionFill = Color(
        light: UIColor(red: 0.157, green: 0.400, blue: 0.306, alpha: 1),
        dark: UIColor(red: 0.14, green: 0.37, blue: 0.27, alpha: 1),
        highContrastLight: UIColor(red: 0.20, green: 0.31, blue: 0.24, alpha: 1),
        highContrastDark: UIColor(red: 0.12, green: 0.22, blue: 0.16, alpha: 1)
    )
    static let sectionHeadingInk = Color(
        light: UIColor(red: 0.37, green: 0.37, blue: 0.34, alpha: 1),
        dark: UIColor(red: 0.76, green: 0.78, blue: 0.74, alpha: 1),
        highContrastLight: UIColor(red: 0.27, green: 0.28, blue: 0.26, alpha: 1),
        highContrastDark: UIColor(red: 0.86, green: 0.88, blue: 0.84, alpha: 1)
    )
    static let readableSupportingInk = Color(
        light: UIColor(red: 0.34, green: 0.34, blue: 0.32, alpha: 1),
        dark: UIColor(red: 0.72, green: 0.74, blue: 0.71, alpha: 1),
        highContrastLight: UIColor(red: 0.27, green: 0.28, blue: 0.26, alpha: 1),
        highContrastDark: UIColor(red: 0.86, green: 0.88, blue: 0.84, alpha: 1)
    )
    static let tabSelection = Color(
        light: UIColor(red: 0.12, green: 0.22, blue: 0.16, alpha: 1),
        dark: UIColor(red: 0.72, green: 0.87, blue: 0.76, alpha: 1),
        highContrastLight: UIColor(red: 0.08, green: 0.17, blue: 0.12, alpha: 1),
        highContrastDark: UIColor(red: 0.79, green: 0.94, blue: 0.83, alpha: 1)
    )
    static let sleep = categoryInk(.sleep)
    static let feed = categoryInk(.feed)
    static let diaper = categoryInk(.diaper)
    static let care = categoryInk(.health)
    static let textOnEvent = Color(
        light: UIColor(red: 0.06, green: 0.07, blue: 0.065, alpha: 1),
        dark: UIColor(red: 0.06, green: 0.07, blue: 0.065, alpha: 1)
    )

    static func chartAccent(for kind: EntryKind) -> Color {
        Color(NidoCarePalette.accent(for: kind.careCategory))
    }

    static let backdropLavender = Color(
        light: UIColor(red: 0.863, green: 0.839, blue: 1, alpha: 1),
        dark: UIColor(red: 0.17, green: 0.14, blue: 0.28, alpha: 1),
        highContrastLight: UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1),
        highContrastDark: UIColor(red: 0.07, green: 0.075, blue: 0.085, alpha: 1)
    )
    static let backdropPeach = Color(
        light: UIColor(red: 1, green: 0.812, blue: 0.710, alpha: 1),
        dark: UIColor(red: 0.31, green: 0.17, blue: 0.14, alpha: 1),
        highContrastLight: UIColor(red: 0.99, green: 0.97, blue: 0.95, alpha: 1),
        highContrastDark: UIColor(red: 0.08, green: 0.07, blue: 0.065, alpha: 1)
    )
    static let backdropMint = Color(
        light: UIColor(red: 0.753, green: 0.922, blue: 0.831, alpha: 1),
        dark: UIColor(red: 0.10, green: 0.25, blue: 0.19, alpha: 1),
        highContrastLight: UIColor(red: 0.95, green: 0.98, blue: 0.96, alpha: 1),
        highContrastDark: UIColor(red: 0.06, green: 0.08, blue: 0.07, alpha: 1)
    )

    static func color(for kind: EntryKind) -> Color {
        categoryInk(kind.careCategory)
    }

    private static func categoryInk(_ category: CareCategory) -> Color {
        Color(uiColor: UIColor { traits in
            let appearance: CareAppearance
            switch (traits.userInterfaceStyle, traits.accessibilityContrast) {
            case (.light, .high): appearance = .highContrastLight
            case (.dark, .high): appearance = .highContrastDark
            case (.dark, _): appearance = .dark
            default: appearance = .light
            }
            let ink = NidoCarePalette.ink(for: category, appearance: appearance)
            return UIColor(red: ink.red, green: ink.green, blue: ink.blue, alpha: 1)
        })
    }
}

struct MaximumContrastForeground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
    }
}

struct PaperBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: NidoTheme.backdropLavender, location: 0),
                .init(color: NidoTheme.paper, location: 0.78),
                .init(color: NidoTheme.paper, location: 1)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .topLeading) {
            RadialGradient(
                colors: [NidoTheme.backdropPeach, NidoTheme.backdropPeach.opacity(0)],
                center: .topLeading,
                startRadius: 0,
                endRadius: 430
            )
            .frame(width: 480, height: 590)
        }
        .overlay(alignment: .topTrailing) {
            RadialGradient(
                colors: [NidoTheme.backdropMint, NidoTheme.backdropMint.opacity(0)],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 460
            )
            .frame(width: 500, height: 620)
        }
        .ignoresSafeArea()
    }
}

struct NidoMark: View {
    var body: some View {
        NidoBrandSymbol(tint: .white)
        .padding(5)
        .background(NidoTheme.moss, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

enum NidoTitleRole {
    case hero
    case screen
}

struct NidoTitle: ViewModifier {
    let role: NidoTitleRole

    func body(content: Content) -> some View {
        content
            .font(.system(textStyle, design: .default, weight: .bold))
            .foregroundStyle(NidoTheme.ink)
    }

    private var textStyle: Font.TextStyle {
        return role == .hero ? .largeTitle : .title
    }
}

extension View {
    func nidoTitle(_ role: NidoTitleRole = .screen) -> some View {
        modifier(NidoTitle(role: role))
    }

    func paperCard(cornerRadius: CGFloat = 22) -> some View {
        background(NidoTheme.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(NidoTheme.separator.opacity(0.55), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.045), radius: 14, y: 6)
    }
}

struct EntryGlyph: View {
    let kind: EntryKind
    var size: CGFloat = 20

    var body: some View {
        CareCategoryIcon(category: kind.careCategory, size: size, tint: NidoTheme.color(for: kind))
            .frame(width: max(44, size + 20), height: max(44, size + 20))
            .contentShape(Rectangle())
            .accessibilityHidden(true)
    }
}

struct NidoDurationInput: View {
    let title: String
    @Binding var totalMinutes: Int
    let range: ClosedRange<Int>

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                Picker("Horas", selection: hours) {
                    ForEach(0...max(0, range.upperBound / 60), id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.menu)
                Text("h")
                    .foregroundStyle(NidoTheme.secondaryInk)

                Picker("Minutos", selection: minutes) {
                    ForEach(0..<60, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.menu)
                Text("min")
                    .foregroundStyle(NidoTheme.secondaryInk)
            }
            .monospacedDigit()
        }
    }

    private var hours: Binding<Int> {
        Binding(
            get: { totalMinutes / 60 },
            set: { update(hours: $0, minutes: totalMinutes % 60) }
        )
    }

    private var minutes: Binding<Int> {
        Binding(
            get: { totalMinutes % 60 },
            set: { update(hours: totalMinutes / 60, minutes: $0) }
        )
    }

    private func update(hours: Int, minutes: Int) {
        totalMinutes = min(max(hours * 60 + minutes, range.lowerBound), range.upperBound)
    }
}

struct NidoIntegerInput: View {
    let title: String
    let unit: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                TextField(title, value: $value, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(minWidth: 52, maxWidth: 76)
                Text(unit)
                    .foregroundStyle(NidoTheme.secondaryInk)
                Stepper("", value: $value, in: range, step: step)
                    .labelsHidden()
            }
        }
        .onChange(of: value) { _, newValue in
            value = min(max(newValue, range.lowerBound), range.upperBound)
        }
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
    // UIKit can resolve dynamic colors from SwiftUI's asynchronous renderer.
    // Keep this initializer nonisolated so the provider never inherits MainActor.
    nonisolated init(
        light: UIColor,
        dark: UIColor,
        highContrastLight: UIColor? = nil,
        highContrastDark: UIColor? = nil
    ) {
        self.init(uiColor: UIColor { traits in
            if traits.accessibilityContrast == .high {
                return traits.userInterfaceStyle == .dark
                    ? highContrastDark ?? dark
                    : highContrastLight ?? light
            }
            return traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}
