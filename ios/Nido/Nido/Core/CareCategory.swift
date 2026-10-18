import Foundation

nonisolated enum CareCategory: String, CaseIterable, Identifiable, Sendable {
    case sleep
    case feed
    case diaper
    case health

    var id: Self { self }

    var glyph: CareCategoryGlyph {
        switch self {
        case .sleep: .system("moon.fill")
        case .feed: .system("waterbottle.fill")
        case .diaper: .diaper
        case .health: .system("heart.fill")
        }
    }

    /// SF Symbol fallback for App Shortcuts APIs that cannot render custom views.
    var shortcutSystemImageName: String {
        switch self {
        case .sleep: "moon.fill"
        case .feed: "waterbottle.fill"
        case .diaper: "drop.fill"
        case .health: "heart.fill"
        }
    }
}

nonisolated enum CareCategoryGlyph: Equatable, Sendable {
    case system(String)
    case diaper
}

nonisolated enum CareAppearance: String, CaseIterable, Sendable {
    case light
    case dark
    case highContrastLight
    case highContrastDark
}

nonisolated struct CarePaletteColor: Equatable, Sendable {
    let hex: UInt32
    let red: Double
    let green: Double
    let blue: Double

    init(hex: UInt32) {
        self.hex = hex
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }
}

nonisolated enum NidoCarePalette {
    static func accent(for category: CareCategory) -> CarePaletteColor {
        switch category {
        case .sleep: CarePaletteColor(hex: 0xF43B83)
        case .feed: CarePaletteColor(hex: 0xFFB02E)
        case .diaper: CarePaletteColor(hex: 0x00BFAE)
        case .health: CarePaletteColor(hex: 0xC26BFF)
        }
    }

    static func ink(for category: CareCategory, appearance: CareAppearance) -> CarePaletteColor {
        switch (category, appearance) {
        case (.sleep, .light): CarePaletteColor(hex: 0xB31557)
        case (.feed, .light): CarePaletteColor(hex: 0x875000)
        case (.diaper, .light): CarePaletteColor(hex: 0x006D63)
        case (.health, .light): CarePaletteColor(hex: 0x8031BB)
        case (.sleep, .dark): accent(for: .sleep)
        case (.feed, .dark): accent(for: .feed)
        case (.diaper, .dark): accent(for: .diaper)
        case (.health, .dark): CarePaletteColor(hex: 0xD5A3FF)
        case (.sleep, .highContrastLight): CarePaletteColor(hex: 0x85003B)
        case (.feed, .highContrastLight): CarePaletteColor(hex: 0x583000)
        case (.diaper, .highContrastLight): CarePaletteColor(hex: 0x004C45)
        case (.health, .highContrastLight): CarePaletteColor(hex: 0x5A168F)
        case (.sleep, .highContrastDark): CarePaletteColor(hex: 0xFF9ABB)
        case (.feed, .highContrastDark): CarePaletteColor(hex: 0xFFD18B)
        case (.diaper, .highContrastDark): CarePaletteColor(hex: 0x7DEBDD)
        case (.health, .highContrastDark): CarePaletteColor(hex: 0xE5C4FF)
        }
    }
}
