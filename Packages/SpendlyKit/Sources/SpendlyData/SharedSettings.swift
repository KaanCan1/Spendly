import Foundation
import SpendlyCore

/// Settings the app shares with its widgets and intents, kept in the App Group's defaults.
public enum SharedSettings {
    public static let appGroup = "group.com.kaancankurt.spendly"

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    public static let currencyCodeKey = "currencyCode"

    /// The user's currency; the device region's until they pick one.
    public static var currencyCode: String {
        defaults.string(forKey: currencyCodeKey) ?? Currency.deviceDefault()
    }
}
