import SwiftUI

enum NidoTheme {
    static let paper = Color(
        light: UIColor(red: 0.965, green: 0.941, blue: 0.898, alpha: 1),
        dark: UIColor(red: 0.075, green: 0.082, blue: 0.078, alpha: 1),
        highContrastLight: UIColor(red: 0.985, green: 0.972, blue: 0.943, alpha: 1),
        highContrastDark: UIColor(red: 0.035, green: 0.04, blue: 0.037, alpha: 1)
    )
    static let paperLight = Color(
        light: UIColor(red: 0.992, green: 0.982, blue: 0.958, alpha: 1),
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
    static let ink = Color(uiColor: .label)
    static let secondaryInk = Color(uiColor: .secondaryLabel)
    static let separator = Color(uiColor: .separator)
    static let error = Color(uiColor: .systemRed)
    static let warning = Color(uiColor: .systemOrange)
    static let moss = Color(
        light: UIColor(red: 0.32, green: 0.43, blue: 0.37, alpha: 1),
        dark: UIColor(red: 0.50, green: 0.64, blue: 0.55, alpha: 1)
    )
    static let sleep = Color(
        light: UIColor(red: 0.32, green: 0.43, blue: 0.51, alpha: 1),
        dark: UIColor(red: 0.51, green: 0.66, blue: 0.77, alpha: 1)
    )
    static let feed = Color(
        light: UIColor(red: 0.70, green: 0.44, blue: 0.17, alpha: 1),
        dark: UIColor(red: 0.85, green: 0.58, blue: 0.30, alpha: 1)
    )
    static let diaper = Color(
        light: UIColor(red: 0.25, green: 0.51, blue: 0.60, alpha: 1),
        dark: UIColor(red: 0.39, green: 0.68, blue: 0.78, alpha: 1)
    )
    static let care = Color(
        light: UIColor(red: 0.65, green: 0.32, blue: 0.44, alpha: 1),
        dark: UIColor(red: 0.80, green: 0.47, blue: 0.59, alpha: 1)
    )

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
        Canvas { context, size in
            let unit = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            var crescent = Path()
            crescent.addEllipse(in: CGRect(
                x: center.x - unit * 0.20,
                y: center.y - unit * 0.28,
                width: unit * 0.42,
                height: unit * 0.42
            ))
            crescent.addEllipse(in: CGRect(
                x: center.x - unit * 0.09,
                y: center.y - unit * 0.32,
                width: unit * 0.38,
                height: unit * 0.38
            ))
            context.fill(crescent, with: .color(.white), style: FillStyle(eoFill: true))

            for radius in [unit * 0.24, unit * 0.34] {
                var nest = Path()
                nest.addArc(
                    center: CGPoint(x: center.x, y: center.y + unit * 0.03),
                    radius: radius,
                    startAngle: .degrees(28),
                    endAngle: .degrees(152),
                    clockwise: false
                )
                context.stroke(
                    nest,
                    with: .color(.white.opacity(radius > unit * 0.3 ? 0.58 : 0.82)),
                    style: StrokeStyle(lineWidth: max(1.5, unit * 0.055), lineCap: .round)
                )
            }
        }
        .padding(5)
        .background(NidoTheme.moss, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityHidden(true)
    }
}

enum NidoTitleRole {
    case hero
    case screen
}

struct NidoTitle: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let role: NidoTitleRole

    func body(content: Content) -> some View {
        content
            .font(.system(textStyle, design: .serif, weight: .regular))
            .foregroundStyle(NidoTheme.ink)
    }

    private var textStyle: Font.TextStyle {
        if dynamicTypeSize.isAccessibilitySize {
            return role == .hero ? .title : .title2
        }
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
        Image(systemName: kind.symbolName)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(NidoTheme.color(for: kind))
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
    init(
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
