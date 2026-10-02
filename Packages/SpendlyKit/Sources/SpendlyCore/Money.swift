import Foundation

/// An amount of money stored in the currency's minor unit (kuruş, cent, …).
///
/// Never use `Double` for money: `0.1 + 0.2 != 0.3`. Everything that is persisted or summed
/// goes through `minorUnits`; `Decimal` is only used at the formatting edge.
public struct Money: Hashable, Sendable, Codable {
    public var minorUnits: Int64
    public var currencyCode: String

    public init(minorUnits: Int64, currencyCode: String) {
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode
    }

    /// From a decimal amount such as Siri's "12.5", rounded to the currency's minor unit.
    public init(amount: Double, currencyCode: String) {
        let scale = pow(10, Double(Currency.fractionDigits(for: currencyCode)))
        self.init(minorUnits: Int64((amount * scale).rounded()), currencyCode: currencyCode)
    }

    public static func zero(_ currencyCode: String) -> Money {
        Money(minorUnits: 0, currencyCode: currencyCode)
    }

    public var isZero: Bool { minorUnits == 0 }

    public var decimalValue: Decimal {
        Decimal(minorUnits) / pow(Decimal(10), Currency.fractionDigits(for: currencyCode))
    }

    /// "₺85.00", "$20.00", "€1,250.50" — narrow symbol, locale-aware separators.
    /// `compact` drops a zero fraction ("₺85" instead of "₺85.00") for glanceable totals.
    public func formatted(locale: Locale = .current, compact: Bool = false) -> String {
        var style = Decimal.FormatStyle.Currency(code: currencyCode, locale: locale).presentation(.narrow)
        if compact && decimalValue == decimalValue.rounded() {
            style = style.precision(.fractionLength(0))
        }
        return decimalValue.formatted(style)
    }
}

public enum Currency {
    /// Currencies offered in the quick picker, in addition to the device's own.
    public static let common = ["TRY", "USD", "EUR", "GBP"]

    /// Number of minor-unit digits: 2 for TRY/USD/EUR, 0 for JPY, 3 for KWD.
    public static func fractionDigits(for code: String) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.maximumFractionDigits
    }

    /// Narrow symbol for display next to the amount: "₺", "$", "€".
    public static func symbol(for code: String, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = code
        // Formatting zero and stripping digits/separators yields the narrow symbol, which
        // `currencySymbol` does not (it returns "TRY" for Turkish lira in English locales).
        let sample = Decimal(0).formatted(.currency(code: code).presentation(.narrow).locale(locale))
        let symbol = sample.filter { !$0.isNumber && !$0.isWhitespace && $0 != "." && $0 != "," }
        return symbol.isEmpty ? (formatter.currencySymbol ?? code) : symbol
    }

    /// The currency of the device's region, falling back to USD.
    public static func deviceDefault(locale: Locale = .current) -> String {
        locale.currency?.identifier ?? "USD"
    }

    /// Device currency first, then the common ones, without duplicates.
    public static func pickerOptions(locale: Locale = .current) -> [String] {
        var seen = Set<String>()
        return ([deviceDefault(locale: locale)] + common).filter { seen.insert($0).inserted }
    }
}

private extension Decimal {
    func rounded() -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, 0, .plain)
        return result
    }
}
