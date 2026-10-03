#if DEBUG
import SpendlyData
import UIKit

/// Puts the app in a known state for UI tests (`-uitest`): fixed currency, default settings,
/// no animations. The store itself is in-memory (see `SpendlyEnvironment.isUITest`).
enum UITestSupport {
    static func prepare() {
        UIView.setAnimationsEnabled(false)
        let shared = SharedSettings.defaults
        shared.set("TRY", forKey: SharedSettings.currencyCodeKey)
        shared.removeObject(forKey: BudgetAlerts.enabledKey)
        for key in [ReminderKeys.dailyEnabled, ReminderKeys.dailyMinutes, ReminderKeys.weeklyEnabled] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
#endif
