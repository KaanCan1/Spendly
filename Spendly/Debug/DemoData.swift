#if DEBUG
import Foundation
import SpendlyCore
import SpendlyData

/// Realistic sample data for screenshots: launch with the `-demo` argument on an empty store.
///
///     xcrun simctl launch <device> com.kaancankurt.spendly -demo
enum DemoData {
    @MainActor
    static func seedIfRequested(_ store: any ExpenseStore) {
        guard ProcessInfo.processInfo.arguments.contains("-demo") else { return }
        let everything = DateInterval(start: .distantPast, end: .distantFuture)
        guard store.expenses(in: everything, kind: nil).isEmpty else { return }

        let calendar = Calendar.current
        let expense = Dictionary(store.categories(kind: .expense).map { ($0.name, $0.id) }, uniquingKeysWith: { a, _ in a })
        let income = Dictionary(store.categories(kind: .income).map { ($0.name, $0.id) }, uniquingKeysWith: { a, _ in a })

        func log(_ lira: Int, _ category: String, _ note: String? = nil, daysAgo: Int, hour: Int, kind: EntryKind = .expense) {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
            let at = calendar.date(bySettingHour: hour, minute: 10 + lira % 40, second: 0, of: day) ?? day
            let id = (kind == .expense ? expense : income)[category]
            try? store.add(ExpenseDraft(
                amount: Money(minorUnits: Int64(lira) * 100, currencyCode: "TRY"),
                kind: kind,
                categoryID: id,
                note: note,
                occurredAt: at
            ))
        }

        // Today and yesterday.
        log(85, "coffee", "flat white", daysAgo: 0, hour: 8)
        log(42, "transport", "metro", daysAgo: 0, hour: 9)
        log(245, "food", "lunch with ece", daysAgo: 0, hour: 13)
        log(85, "coffee", "flat white", daysAgo: 0, hour: 16)
        log(275, "food", "groceries", daysAgo: 1, hour: 19)
        log(180, "fun", "cinema", daysAgo: 1, hour: 21)
        log(420, "bills", "electricity", daysAgo: 1, hour: 10)
        log(649, "shopping", "running socks", daysAgo: 1, hour: 17)
        log(42_000, "salary", daysAgo: 1, hour: 9, kind: .income)

        // The weeks before, so last month and the habit suggestions have something to show.
        let history: [(Int, String, String?, Int)] = [
            (85, "coffee", "flat white", 3), (310, "food", "groceries", 3), (42, "transport", "metro", 4),
            (85, "coffee", "flat white", 5), (520, "food", "dinner out", 6), (1_250, "bills", "internet + phone", 7),
            (85, "coffee", nil, 8), (95, "transport", "taxi", 9), (380, "health", "pharmacy", 10),
            (85, "coffee", "flat white", 11), (260, "food", "groceries", 12), (450, "fun", "concert", 13),
            (42, "transport", "metro", 14), (1_180, "shopping", "jacket", 16), (85, "coffee", nil, 18),
        ]
        for (lira, category, note, daysAgo) in history {
            log(lira, category, note, daysAgo: daysAgo, hour: 12)
        }

        if let food = expense["food"] { try? store.setMonthlyLimit(categoryID: food, limitMinor: 60_000) }
        if let coffee = expense["coffee"] { try? store.setMonthlyLimit(categoryID: coffee, limitMinor: 40_000) }
        SharedSettings.defaults.set("TRY", forKey: SharedSettings.currencyCodeKey)
    }
}
#endif
