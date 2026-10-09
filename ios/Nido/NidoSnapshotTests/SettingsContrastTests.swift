import SwiftUI
import XCTest

@testable import Nido

@MainActor
final class SettingsContrastTests: XCTestCase {
    func testTextOnMossMeetsSmallTextContrastInAllAppearanceModes() {
        let variants: [(UIUserInterfaceStyle, UIAccessibilityContrast)] = [
            (.light, .normal),
            (.dark, .normal),
            (.light, .high),
            (.dark, .high),
        ]

        for (style, contrast) in variants {
            let traits = UITraitCollection(mutations: { traits in
                traits.userInterfaceStyle = style
                traits.accessibilityContrast = contrast
            })
            let foreground = UIColor(NidoTheme.textOnMoss).resolvedColor(with: traits)
            let background = UIColor(NidoTheme.moss).resolvedColor(with: traits)

            XCTAssertGreaterThanOrEqual(
                contrastRatio(foreground, background),
                4.5,
                "Text on moss must meet 4.5:1 for style \(style.rawValue), contrast \(contrast.rawValue)."
            )
        }
    }

    private func contrastRatio(_ first: UIColor, _ second: UIColor) -> CGFloat {
        let luminances = [relativeLuminance(first), relativeLuminance(second)].sorted(by: >)
        return (luminances[0] + 0.05) / (luminances[1] + 0.05)
    }

    private func relativeLuminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)

        func linearize(_ component: CGFloat) -> CGFloat {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
    }
}
