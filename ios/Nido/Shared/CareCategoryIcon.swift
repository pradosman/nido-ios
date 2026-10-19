import SwiftUI
import UIKit

extension Color {
    init(_ paletteColor: CarePaletteColor) {
        self.init(
            .sRGB,
            red: paletteColor.red,
            green: paletteColor.green,
            blue: paletteColor.blue,
            opacity: 1
        )
    }
}

struct CareCategoryIcon: View {
    let category: CareCategory
    let tint: Color?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @ScaledMetric(relativeTo: .body) private var scaledSize: CGFloat = 20

    init(category: CareCategory, size: CGFloat = 20, tint: Color? = nil) {
        self.category = category
        self.tint = tint
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    /// Returns a native `Image` for system menus, which don't reliably render custom `View` icons.
    /// The diaper bitmap is generated from the same vector path used by the SwiftUI glyph and remains a template.
    static func menuImage(for category: CareCategory, size: CGFloat = 20) -> Image {
        switch category.glyph {
        case .system(let name):
            return Image(systemName: name)
        case .diaper:
            return Image(uiImage: menuDiaperImage(size: size)).renderingMode(.template)
        }
    }

    static func menuDiaperImage(size: CGFloat = 20) -> UIImage {
        let pixelSize = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: pixelSize)
        return renderer.image { context in
            let path = DiaperCategoryShape().path(in: CGRect(origin: .zero, size: pixelSize))
            context.cgContext.addPath(path.cgPath)
            context.cgContext.setFillColor(UIColor.black.cgColor)
            context.cgContext.drawPath(using: .eoFill)
        }.withRenderingMode(.alwaysTemplate)
    }

    var body: some View {
        glyph
            .frame(width: scaledSize, height: scaledSize)
            .foregroundStyle(resolvedTint)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var glyph: some View {
        switch category.glyph {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: scaledSize, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
        case .diaper:
            DiaperCategoryShape()
                .fill(resolvedTint, style: FillStyle(eoFill: true))
        }
    }

    private var resolvedTint: Color {
        if let tint { return tint }
        let appearance: CareAppearance
        switch (colorScheme, colorSchemeContrast) {
        case (.light, .increased): appearance = .highContrastLight
        case (.dark, .increased): appearance = .highContrastDark
        case (.dark, _): appearance = .dark
        default: appearance = .light
        }
        return Color(NidoCarePalette.ink(for: category, appearance: appearance))
    }
}

private struct DiaperCategoryShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x / 24, y: rect.minY + rect.height * y / 24)
        }

        var path = Path()
        path.move(to: point(3.25, 5.4))
        path.addLine(to: point(20.75, 5.4))
        path.addLine(to: point(20.75, 12.65))
        path.addCurve(to: point(12, 21.4), control1: point(20.75, 17.48), control2: point(16.83, 21.4))
        path.addCurve(to: point(3.25, 12.65), control1: point(7.17, 21.4), control2: point(3.25, 17.48))
        path.closeSubpath()

        var panel = Path()
        panel.move(to: point(3.25, 8.45))
        panel.addLine(to: point(7.45, 8.45))
        panel.addLine(to: point(9.47, 10.47))
        panel.addCurve(to: point(14.53, 10.47), control1: point(10.87, 11.87), control2: point(13.13, 11.87))
        panel.addLine(to: point(16.55, 8.45))
        panel.addLine(to: point(20.75, 8.45))
        panel.addLine(to: point(20.75, 12.65))
        panel.addCurve(to: point(19.75, 16.67), control1: point(20.75, 14.1), control2: point(20.39, 15.47))
        panel.addCurve(to: point(4.25, 16.67), control1: point(15.22, 12.8), control2: point(8.78, 12.8))
        panel.addCurve(to: point(3.25, 12.65), control1: point(3.61, 15.47), control2: point(3.25, 14.1))
        panel.closeSubpath()
        path.addPath(panel)

        for x in [6.6, 17.4] {
            path.addEllipse(in: CGRect(
                x: rect.minX + rect.width * (x - 0.85) / 24,
                y: rect.minY + rect.height * 6.15 / 24,
                width: rect.width * 1.7 / 24,
                height: rect.height * 1.7 / 24
            ))
        }
        return path
    }
}

struct NidoBrandSymbol: View {
    let tint: Color

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
            context.fill(crescent, with: .color(tint), style: FillStyle(eoFill: true))

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
                    with: .color(tint.opacity(radius > unit * 0.3 ? 0.58 : 0.82)),
                    style: StrokeStyle(lineWidth: max(1.5, unit * 0.055), lineCap: .round)
                )
            }
        }
        .accessibilityHidden(true)
    }
}
