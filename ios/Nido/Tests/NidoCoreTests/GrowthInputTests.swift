import Foundation
import Testing
@testable import NidoCore

struct GrowthInputTests {
    @Test func parsesLocaleDecimalAndBoundsWeight() {
        let spanish = Locale(identifier: "es_ES")
        #expect(GrowthInput.weightGrams(from: "7,25", locale: spanish) == 7_250)
        #expect(GrowthInput.weightGrams(from: "0,001", locale: spanish) == 1)
        #expect(GrowthInput.weightGrams(from: "200,001", locale: spanish) == nil)
        #expect(GrowthInput.weightGrams(from: "0", locale: spanish) == nil)
    }

    @Test func parsesLocaleDecimalAndBoundsHeight() {
        let spanish = Locale(identifier: "es_ES")
        #expect(GrowthInput.heightMillimeters(from: "52,3", locale: spanish) == 523)
        #expect(GrowthInput.heightMillimeters(from: "0,1", locale: spanish) == 1)
        #expect(GrowthInput.heightMillimeters(from: "250,1", locale: spanish) == nil)
        #expect(GrowthInput.heightMillimeters(from: "abc", locale: spanish) == nil)
    }

    @Test func rejectsHugeFinitePastedValuesWithoutIntegerOverflow() {
        let huge = "9999999999999999999999"
        #expect(GrowthInput.weightGrams(from: huge, locale: Locale(identifier: "en_US")) == nil)
        #expect(GrowthInput.heightMillimeters(from: huge, locale: Locale(identifier: "en_US")) == nil)
    }
}
