import Foundation

/// Which budget line an expense just crossed, if any.
public enum BudgetAlert: Equatable, Sendable {
    /// Spending reached 80% of the monthly limit.
    case nearLimit(percent: Int)
    /// Spending went over the monthly limit.
    case overLimit(percent: Int)

    public static let warningShare = 0.8

    /// Compares spending before and after one expense. Only a *crossing* alerts, so the user hears
    /// about each line once per month instead of on every expense above it.
    public static func crossing(beforeMinor: Int64, afterMinor: Int64, limitMinor: Int64) -> BudgetAlert? {
        guard limitMinor > 0, afterMinor > beforeMinor else { return nil }
        let before = Double(beforeMinor) / Double(limitMinor)
        let after = Double(afterMinor) / Double(limitMinor)
        let percent = Int((after * 100).rounded())
        if before <= 1, after > 1 { return .overLimit(percent: percent) }
        if before < warningShare, after >= warningShare { return .nearLimit(percent: percent) }
        return nil
    }
}

/// What the free tier includes; Pro removes the limits.
public enum ProLimits {
    /// Categories the user creates (the built-in ones don't count).
    public static let freeCustomCategories = 3
    /// Categories with a monthly limit.
    public static let freeBudgets = 1

    public static func canAddCategory(customCount: Int, isPro: Bool) -> Bool {
        isPro || customCount < freeCustomCategories
    }

    /// Changing or removing an existing limit is always allowed; only a new one counts.
    public static func canSetBudget(otherBudgets: Int, isPro: Bool) -> Bool {
        isPro || otherBudgets < freeBudgets
    }
}
