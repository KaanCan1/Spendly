import SpendlyCore
import Testing

struct BudgetAlertTests {
    private let limit: Int64 = 60_000 // ₺600

    @Test func alertsOnceWhenCrossingEightyPercent() {
        #expect(BudgetAlert.crossing(beforeMinor: 40_000, afterMinor: 52_000, limitMinor: limit) == .nearLimit(percent: 87))
        // Already above 80%: no second warning.
        #expect(BudgetAlert.crossing(beforeMinor: 52_000, afterMinor: 55_000, limitMinor: limit) == nil)
    }

    @Test func alertsWhenGoingOverTheLimit() {
        #expect(BudgetAlert.crossing(beforeMinor: 55_000, afterMinor: 64_000, limitMinor: limit) == .overLimit(percent: 107))
        // Jumping straight from under 80% to over 100% reports the bigger news.
        #expect(BudgetAlert.crossing(beforeMinor: 10_000, afterMinor: 70_000, limitMinor: limit) == .overLimit(percent: 117))
        // Already over: quiet.
        #expect(BudgetAlert.crossing(beforeMinor: 64_000, afterMinor: 70_000, limitMinor: limit) == nil)
    }

    @Test func exactlyAtTheLimitIsAWarningNotOver() {
        #expect(BudgetAlert.crossing(beforeMinor: 40_000, afterMinor: 60_000, limitMinor: limit) == .nearLimit(percent: 100))
    }

    @Test func noLimitOrNoIncreaseMeansNoAlert() {
        #expect(BudgetAlert.crossing(beforeMinor: 0, afterMinor: 90_000, limitMinor: 0) == nil)
        #expect(BudgetAlert.crossing(beforeMinor: 50_000, afterMinor: 50_000, limitMinor: limit) == nil)
    }
}

struct ProLimitsTests {
    @Test func freeTierAllowsThreeCustomCategories() {
        #expect(ProLimits.canAddCategory(customCount: 2, isPro: false))
        #expect(!ProLimits.canAddCategory(customCount: 3, isPro: false))
        #expect(ProLimits.canAddCategory(customCount: 50, isPro: true))
    }

    @Test func freeTierAllowsOneBudget() {
        #expect(ProLimits.canSetBudget(otherBudgets: 0, isPro: false))
        #expect(!ProLimits.canSetBudget(otherBudgets: 1, isPro: false))
        #expect(ProLimits.canSetBudget(otherBudgets: 5, isPro: true))
    }
}
