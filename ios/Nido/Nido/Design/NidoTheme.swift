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
    static let textOnMoss = Color(
        light: .white,
        dark: UIColor(red: 0.06, green: 0.07, blue: 0.065, alpha: 1),
        highContrastLight: .white,
        highContrastDark: .black
    )
    static let prominentActionFill = Color(
        light: UIColor(red: 0.32, green: 0.43, blue: 0.37, alpha: 1),
        dark: UIColor(red: 0.19, green: 0.29, blue: 0.23, alpha: 1),
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
    static let sleep = Color(
        light: UIColor(red: 0.32, green: 0.43, blue: 0.51, alpha: 1),
        dark: UIColor(red: 0.51, green: 0.66, blue: 0.77, alpha: 1)
    )
    static let feed = Color(
        light: UIColor(red: 0.70, green: 0.44, blue: 0.17, alpha: 1),
        dark: UIColor(red: 0.85, green: 0.58, blue: 0.30, alpha: 1)
    )
    static let activeSleepFill = Color(
        light: UIColor(red: 0.32, green: 0.43, blue: 0.51, alpha: 1),
        dark: UIColor(red: 0.28, green: 0.39, blue: 0.47, alpha: 1),
        highContrastLight: UIColor(red: 0.24, green: 0.34, blue: 0.42, alpha: 1),
        highContrastDark: UIColor(red: 0.24, green: 0.34, blue: 0.42, alpha: 1)
    )
    static let activeFeedFill = Color(
        light: UIColor(red: 0.54, green: 0.32, blue: 0.10, alpha: 1),
        dark: UIColor(red: 0.48, green: 0.29, blue: 0.10, alpha: 1),
        highContrastLight: UIColor(red: 0.42, green: 0.25, blue: 0.08, alpha: 1),
        highContrastDark: UIColor(red: 0.42, green: 0.25, blue: 0.08, alpha: 1)
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
    let role: NidoTitleRole

    func body(content: Content) -> some View {
        content
            .font(.system(textStyle, design: .serif, weight: .regular))
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
        glyph
            .frame(width: max(44, size + 20), height: max(44, size + 20))
            .contentShape(Rectangle())
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var glyph: some View {
        if kind == .diaper {
            DiaperGlyph(color: NidoTheme.diaper, size: size)
        } else {
            Image(systemName: kind.symbolName)
                .font(.system(size: size, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(NidoTheme.color(for: kind))
        }
    }
}

struct DiaperGlyph: View {
    let color: Color
    var size: CGFloat = 20

    var body: some View {
        Canvas { context, canvasSize in
            let point: (CGFloat, CGFloat) -> CGPoint = { x, y in
                CGPoint(x: canvasSize.width * x / 24, y: canvasSize.height * y / 24)
            }

            var silhouette = Path()
            silhouette.move(to: point(3.25, 5.4))
            silhouette.addLine(to: point(20.75, 5.4))
            silhouette.addLine(to: point(20.75, 12.65))
            silhouette.addCurve(
                to: point(12, 21.4),
                control1: point(20.75, 17.48),
                control2: point(16.83, 21.4)
            )
            silhouette.addCurve(
                to: point(3.25, 12.65),
                control1: point(7.17, 21.4),
                control2: point(3.25, 17.48)
            )
            silhouette.closeSubpath()
            context.fill(silhouette, with: .color(color))

            var frontPanel = Path()
            frontPanel.move(to: point(3.25, 8.45))
            frontPanel.addLine(to: point(7.45, 8.45))
            frontPanel.addLine(to: point(9.47, 10.47))
            frontPanel.addCurve(
                to: point(14.53, 10.47),
                control1: point(10.87, 11.87),
                control2: point(13.13, 11.87)
            )
            frontPanel.addLine(to: point(16.55, 8.45))
            frontPanel.addLine(to: point(20.75, 8.45))
            frontPanel.addLine(to: point(20.75, 12.65))
            frontPanel.addCurve(
                to: point(19.75, 16.67),
                control1: point(20.75, 14.1),
                control2: point(20.39, 15.47)
            )
            frontPanel.addCurve(
                to: point(4.25, 16.67),
                control1: point(15.22, 12.8),
                control2: point(8.78, 12.8)
            )
            frontPanel.addCurve(
                to: point(3.25, 12.65),
                control1: point(3.61, 15.47),
                control2: point(3.25, 14.1)
            )
            frontPanel.closeSubpath()
            context.fill(frontPanel, with: .color(.white.opacity(0.34)))

            for x in [6.6, 17.4] {
                let tab = Path(ellipseIn: CGRect(
                    x: canvasSize.width * (x - 0.85) / 24,
                    y: canvasSize.height * 6.15 / 24,
                    width: canvasSize.width * 1.7 / 24,
                    height: canvasSize.height * 1.7 / 24
                ))
                context.fill(tab, with: .color(.white.opacity(0.72)))
            }
        }
        .frame(width: size, height: size)
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
