import Foundation
import SpendlyCore
import Testing

struct AmountInputTests {
    private func typed(_ keys: String, fractionDigits: Int = 2) -> AmountInput {
        var input = AmountInput(maxFractionDigits: fractionDigits)
        for character in keys {
            switch character {
            case ".": input.press(.decimalSeparator)
            case "<": input.press(.delete)
            default: input.press(.digit(Int(String(character))!))
            }
        }
        return input
    }

    @Test func convertsToMinorUnits() {
        #expect(typed("85").minorUnits == 8_500)
        #expect(typed("12.5").minorUnits == 1_250)
        #expect(typed("12.05").minorUnits == 1_205)
        #expect(typed("0.99").minorUnits == 99)
        #expect(typed("").minorUnits == 0)
    }

    @Test func ignoresLeadingZeros() {
        #expect(typed("0005").minorUnits == 500)
        #expect(typed("0005").displayString(locale: Locale(identifier: "en_US")) == "5")
    }

    @Test func capsFractionAtCurrencyDigits() {
        var input = typed("1.99")
        #expect(input.press(.digit(9)) == false)
        #expect(input.minorUnits == 199)
    }

    @Test func rejectsSecondSeparatorAndSeparatorForZeroDecimalCurrencies() {
        var twoDecimals = typed("1.")
        #expect(twoDecimals.press(.decimalSeparator) == false)

        var yen = AmountInput(maxFractionDigits: 0)
        #expect(yen.press(.decimalSeparator) == false)
        yen.press(.digit(5))
        #expect(yen.minorUnits == 5)
    }

    @Test func capsIntegerDigits() {
        var input = typed("999999999")
        #expect(input.press(.digit(9)) == false)
        #expect(input.minorUnits == 99_999_999_900)
    }

    @Test func deleteWalksBackThroughSeparator() {
        #expect(typed("12.5<").displayString(locale: Locale(identifier: "en_US")) == "12.")
        #expect(typed("12.5<<").displayString(locale: Locale(identifier: "en_US")) == "12")
        #expect(typed("12.5<<<<<").isBlank)
        var empty = AmountInput(maxFractionDigits: 2)
        #expect(empty.press(.delete) == false)
    }

    @Test func displayUsesLocaleSeparators() {
        let input = typed("1250.5")
        #expect(input.displayString(locale: Locale(identifier: "en_US")) == "1,250.5")
        #expect(input.displayString(locale: Locale(identifier: "tr_TR")) == "1.250,5")
        #expect(typed("1234567").displayString(locale: Locale(identifier: "en_US")) == "1,234,567")
        #expect(AmountInput(maxFractionDigits: 2).displayString(locale: Locale(identifier: "en_US")) == "0")
    }
}

struct AmountInputPrefillTests {
    private let en = Locale(identifier: "en_US")

    @Test func prefillsWholeAndFractionalAmounts() {
        #expect(AmountInput(money: Money(minorUnits: 1_200, currencyCode: "TRY")).displayString(locale: en) == "12")
        #expect(AmountInput(money: Money(minorUnits: 1_250, currencyCode: "TRY")).displayString(locale: en) == "12.50")
        #expect(AmountInput(money: Money(minorUnits: 1_205, currencyCode: "TRY")).displayString(locale: en) == "12.05")
        #expect(AmountInput(money: Money(minorUnits: 99, currencyCode: "TRY")).displayString(locale: en) == "0.99")
        #expect(AmountInput(money: Money(minorUnits: 500, currencyCode: "JPY")).displayString(locale: en) == "500")
    }

    @Test func prefillRoundTripsMinorUnits() {
        for minor: Int64 in [1, 99, 100, 1_205, 123_456_789] {
            #expect(AmountInput(money: Money(minorUnits: minor, currencyCode: "USD")).minorUnits == minor)
        }
    }
}

struct MoneyTests {
    @Test func formatsWithNarrowSymbol() {
        let lira = Money(minorUnits: 8_500, currencyCode: "TRY")
        #expect(lira.formatted(locale: Locale(identifier: "en_US")) == "₺85.00")
        #expect(Money(minorUnits: 2_000, currencyCode: "USD").formatted(locale: Locale(identifier: "en_US")) == "$20.00")
    }

    @Test func compactDropsOnlyZeroFractions() {
        let en = Locale(identifier: "en_US")
        #expect(Money(minorUnits: 30_800, currencyCode: "TRY").formatted(locale: en, compact: true) == "₺308")
        #expect(Money(minorUnits: 30_850, currencyCode: "TRY").formatted(locale: en, compact: true) == "₺308.50")
    }

    @Test func convertsDecimalAmountsWithoutFloatingPointDrift() {
        #expect(Money(amount: 12.3, currencyCode: "TRY").minorUnits == 1_230)
        #expect(Money(amount: 0.29, currencyCode: "USD").minorUnits == 29)
        #expect(Money(amount: 500, currencyCode: "JPY").minorUnits == 500)
    }

    @Test func knowsMinorUnitDigits() {
        #expect(Currency.fractionDigits(for: "TRY") == 2)
        #expect(Currency.fractionDigits(for: "JPY") == 0)
        #expect(Money(minorUnits: 500, currencyCode: "JPY").decimalValue == 500)
    }

    @Test func symbolIsNarrow() {
        #expect(Currency.symbol(for: "TRY", locale: Locale(identifier: "en_US")) == "₺")
        #expect(Currency.symbol(for: "EUR", locale: Locale(identifier: "tr_TR")) == "€")
    }

    @Test func pickerPutsDeviceCurrencyFirst() {
        #expect(Currency.pickerOptions(locale: Locale(identifier: "tr_TR")) == ["TRY", "USD", "EUR", "GBP"])
        #expect(Currency.pickerOptions(locale: Locale(identifier: "ja_JP")) == ["JPY", "TRY", "USD", "EUR", "GBP"])
    }
}
