import Foundation
import SpendlyCore
import SpendlyData
import UserNotifications

/// Compiled into the app and the widget extension: a budget can be crossed from the keypad,
/// from a widget button or from Siri, and each of them must warn.
enum BudgetAlerts {
    static let enabledKey = "budgetAlerts.enabled"

    /// On unless the user turned it off in settings.
    static var isEnabled: Bool {
        SharedSettings.defaults.object(forKey: enabledKey) as? Bool ?? true
    }

    /// Call right after an expense was added. Posts "food is at 87% of its monthly limit" when
    /// this expense crossed the 80% line, or "over its limit" when it crossed 100%.
    @MainActor
    static func notifyIfCrossed(by draft: ExpenseDraft, store: any ExpenseStore, calendar: Calendar = .current) {
        guard isEnabled, draft.kind == .expense, let categoryID = draft.categoryID else { return }
        guard let category = store.categories(kind: .expense).first(where: { $0.id == categoryID }),
              let limit = category.monthlyLimitMinor else { return }

        let month = calendar.monthInterval(containing: draft.occurredAt)
        let after = store.spent(categoryID: categoryID, in: month, currencyCode: draft.amount.currencyCode).minorUnits
        let before = after - draft.amount.minorUnits
        guard let alert = BudgetAlert.crossing(beforeMinor: before, afterMinor: after, limitMinor: limit) else { return }

        let name = category.displayName
        let spent = Money(minorUnits: after, currencyCode: draft.amount.currencyCode).formatted(compact: true)
        let cap = Money(minorUnits: limit, currencyCode: draft.amount.currencyCode).formatted(compact: true)
        let content = UNMutableNotificationContent()
        switch alert {
        case .nearLimit(let percent):
            content.title = String(localized: "\(category.emoji) \(name) is at \(percent)% of its budget")
        case .overLimit:
            content.title = String(localized: "\(category.emoji) \(name) is over budget")
        }
        content.body = String(localized: "\(spent) of \(cap) this month")
        content.sound = .default
        content.threadIdentifier = "budget"

        // Deliver now; one request per category and month so a newer alert replaces an older one.
        let monthKey = calendar.dateComponents([.year, .month], from: draft.occurredAt)
        let id = "budget-\(categoryID)-\(monthKey.year ?? 0)-\(monthKey.month ?? 0)"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}

extension CategoryRecord {
    /// Built-in categories are stored under their English name and shown in the user's language;
    /// a renamed or user-made category is shown exactly as typed.
    var displayName: String {
        isDefault ? String(localized: String.LocalizationValue(name)) : name
    }
}

enum NotificationPermission {
    /// Asks once; afterwards returns the stored answer without a prompt.
    static func request() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default: return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    static func isDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }
}
