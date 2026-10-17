import Foundation

nonisolated enum GrowthInput {
    static func weightGrams(from text: String, locale: Locale = .current) -> Int? {
        scaledValue(from: text, locale: locale, maximum: 200, scale: 1_000, canonicalMaximum: 200_000)
    }

    static func heightMillimeters(from text: String, locale: Locale = .current) -> Int? {
        scaledValue(from: text, locale: locale, maximum: 250, scale: 10, canonicalMaximum: 2_500)
    }

    private static func scaledValue(
        from source: String,
        locale: Locale,
        maximum: Double,
        scale: Double,
        canonicalMaximum: Int
    ) -> Int? {
        guard let value = decimalValue(from: source, locale: locale),
              value.isFinite,
              value > 0,
              value <= maximum
        else { return nil }

        let scaled = (value * scale).rounded()
        guard scaled >= 1, scaled <= Double(canonicalMaximum) else { return nil }
        return Int(scaled)
    }

    private static func decimalValue(from source: String, locale: Locale) -> Double? {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let localeSeparator = locale.decimalSeparator ?? "."
        var normalized = text
        if localeSeparator != "." && localeSeparator != "," && normalized.contains(localeSeparator) {
            normalized = normalized.replacingOccurrences(of: localeSeparator, with: ".")
        }

        let separators = normalized.indices.filter { normalized[$0] == "." || normalized[$0] == "," }
        if let decimalIndex = separators.last {
            var result = String.UnicodeScalarView()
            for index in normalized.indices {
                let character = normalized[index]
                if character == "." || character == "," {
                    if index == decimalIndex { result.append(".") }
                } else {
                    result.append(contentsOf: character.unicodeScalars)
                }
            }
            normalized = String(result)
            // The final separator is treated as the decimal mark; earlier separators are grouping marks.
        }

        guard normalized.allSatisfy({ $0.isNumber || $0 == "." || $0 == "+" || $0 == "-" }),
              normalized.filter({ $0 == "." }).count <= 1,
              let value = Double(normalized)
        else { return nil }
        return value
    }
}
