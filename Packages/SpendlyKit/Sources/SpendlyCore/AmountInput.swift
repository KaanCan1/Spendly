import Foundation

/// Keypad state for typing an amount. Pure value type so it is trivially testable.
///
/// Rules:
/// - no leading zeros ("0" then "5" → "5")
/// - at most one decimal separator, and none for zero-decimal currencies (JPY)
/// - fraction length capped at the currency's minor-unit digits
/// - integer part capped at `maxIntegerDigits`
public struct AmountInput: Hashable, Sendable {
    public enum Key: Hashable, Sendable {
        case digit(Int)
        case decimalSeparator
        case delete
    }

    public static let maxIntegerDigits = 9

    public let maxFractionDigits: Int
    public private(set) var integerDigits = ""
    /// `nil` until the decimal separator is typed.
    public private(set) var fractionDigits: String?

    public init(maxFractionDigits: Int) {
        self.maxFractionDigits = maxFractionDigits
    }

    public init(currencyCode: String) {
        self.init(maxFractionDigits: Currency.fractionDigits(for: currencyCode))
    }

    /// Prefilled from a stored amount, for editing: 1250 TRY minor units → "12.50", 1200 → "12".
    public init(money: Money) {
        self.init(currencyCode: money.currencyCode)
        guard money.minorUnits > 0 else { return }
        var scale: Int64 = 1
        for _ in 0..<maxFractionDigits { scale *= 10 }
        integerDigits = String(money.minorUnits / scale)
        if integerDigits == "0" { integerDigits = "" }
        let fraction = money.minorUnits % scale
        if fraction != 0 {
            fractionDigits = String(fraction).leftPadding(toLength: maxFractionDigits, with: "0")
        }
    }

    /// Applies a key press. Returns `false` when the key was rejected, so the UI can
    /// give "nope" feedback instead of silently ignoring the tap.
    @discardableResult
    public mutating func press(_ key: Key) -> Bool {
        switch key {
        case .digit(let value):
            precondition((0...9).contains(value), "digit out of range")
            if var fraction = fractionDigits {
                guard fraction.count < maxFractionDigits else { return false }
                fraction.append(String(value))
                fractionDigits = fraction
                return true
            }
            if integerDigits.isEmpty && value == 0 { return false }
            guard integerDigits.count < Self.maxIntegerDigits else { return false }
            integerDigits.append(String(value))
            return true

        case .decimalSeparator:
            guard maxFractionDigits > 0, fractionDigits == nil else { return false }
            fractionDigits = ""
            return true

        case .delete:
            if let fraction = fractionDigits {
                fractionDigits = fraction.isEmpty ? nil : String(fraction.dropLast())
                return true
            }
            guard !integerDigits.isEmpty else { return false }
            integerDigits.removeLast()
            return true
        }
    }

    public mutating func clear() {
        integerDigits = ""
        fractionDigits = nil
    }

    /// Nothing typed at all (as opposed to a typed amount that happens to be zero, like "0.0").
    public var isBlank: Bool { integerDigits.isEmpty && fractionDigits == nil }

    public var minorUnits: Int64 {
        let integer = Int64(integerDigits) ?? 0
        let paddedFraction = (fractionDigits ?? "").padding(toLength: maxFractionDigits, withPad: "0", startingAt: 0)
        let fraction = Int64(paddedFraction) ?? 0
        var scale: Int64 = 1
        for _ in 0..<maxFractionDigits { scale *= 10 }
        return integer * scale + fraction
    }

    /// What the user has typed, with the locale's separators: "1.250,5" (tr) or "1,250.5" (en).
    /// Trailing zeros and a trailing separator are kept, so the display mirrors the keypad.
    public func displayString(locale: Locale = .current) -> String {
        let grouping = locale.groupingSeparator ?? ","
        let decimal = locale.decimalSeparator ?? "."

        let integer = integerDigits.isEmpty ? "0" : integerDigits
        var grouped = ""
        for (index, character) in integer.enumerated() {
            if index > 0 && (integer.count - index) % 3 == 0 { grouped += grouping }
            grouped.append(character)
        }

        guard let fraction = fractionDigits else { return grouped }
        return grouped + decimal + fraction
    }
}

private extension String {
    func leftPadding(toLength length: Int, with pad: Character) -> String {
        count >= length ? self : String(repeating: pad, count: length - count) + self
    }
}
