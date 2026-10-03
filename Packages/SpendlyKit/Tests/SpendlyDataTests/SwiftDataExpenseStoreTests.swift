import Foundation
import SpendlyCore
import SpendlyData
import Testing

@MainActor
struct SwiftDataExpenseStoreTests {
    let store: SwiftDataExpenseStore
    let calendar = Calendar(identifier: .gregorian)

    init() throws {
        store = SwiftDataExpenseStore(container: try SpendlySchema.makeInMemoryContainer(), calendar: calendar)
        try store.seedDefaultCategoriesIfNeeded()
    }

    private func category(_ name: String, _ kind: EntryKind = .expense) throws -> CategoryRecord {
        try #require(store.categories(kind: kind).first { $0.name == name })
    }

    private func lira(_ minor: Int64) -> Money { Money(minorUnits: minor, currencyCode: "TRY") }

    @Test func seedsOnceAndSplitsByKind() throws {
        try store.seedDefaultCategoriesIfNeeded()
        #expect(store.categories(kind: .expense).count == 8)
        #expect(store.categories(kind: .income).count == 4)
        #expect(store.categories(kind: .expense).first?.name == "food")
    }

    @Test func addThenReadBack() throws {
        let coffee = try category("coffee")
        let id = try store.add(ExpenseDraft(amount: lira(8_500), kind: .expense, categoryID: coffee.id, note: "  starbucks "))

        let today = calendar.dayInterval(containing: .now)
        let rows = store.expenses(in: today, kind: .expense)
        #expect(rows.map(\.id) == [id])
        #expect(rows.first?.category?.emoji == "☕️")
        #expect(rows.first?.note == "starbucks")
        #expect(store.total(in: today, kind: .expense, currencyCode: "TRY") == lira(8_500))
    }

    @Test func blankNoteIsStoredAsNil() throws {
        try store.add(ExpenseDraft(amount: lira(100), kind: .expense, categoryID: nil, note: "   "))
        #expect(store.expenses(in: calendar.dayInterval(containing: .now), kind: nil).first?.note == nil)
    }

    @Test func rejectsZeroAmountAndUnknownCategory() throws {
        #expect(throws: ExpenseStoreError.nonPositiveAmount) {
            try store.add(ExpenseDraft(amount: lira(0), kind: .expense, categoryID: nil))
        }
        let missing = UUID()
        #expect(throws: ExpenseStoreError.categoryNotFound(missing)) {
            try store.add(ExpenseDraft(amount: lira(100), kind: .expense, categoryID: missing))
        }
    }

    @Test func totalsSeparateKindsCurrenciesAndDays() throws {
        let food = try category("food")
        let salary = try category("salary", .income)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: .now)!

        try store.add(ExpenseDraft(amount: lira(1_000), kind: .expense, categoryID: food.id))
        try store.add(ExpenseDraft(amount: lira(2_000), kind: .expense, categoryID: food.id, occurredAt: yesterday))
        try store.add(ExpenseDraft(amount: Money(minorUnits: 500, currencyCode: "USD"), kind: .expense, categoryID: food.id))
        try store.add(ExpenseDraft(amount: lira(50_000), kind: .income, categoryID: salary.id))

        let today = calendar.dayInterval(containing: .now)
        #expect(store.total(in: today, kind: .expense, currencyCode: "TRY") == lira(1_000))
        #expect(store.total(in: today, kind: .income, currencyCode: "TRY") == lira(50_000))
        #expect(store.total(in: today, kind: .expense, currencyCode: "USD").minorUnits == 500)
    }

    @Test func deleteRemovesTheEntry() throws {
        let id = try store.add(ExpenseDraft(amount: lira(100), kind: .expense, categoryID: nil))
        try store.delete(id: id)
        #expect(store.expenses(in: calendar.dayInterval(containing: .now), kind: nil).isEmpty)
    }

    @Test func frequentEntriesRankByCountThenRecency() throws {
        let coffee = try category("coffee")
        let food = try category("food")
        let transport = try category("transport")

        try store.add(ExpenseDraft(amount: lira(8_500), kind: .expense, categoryID: coffee.id))
        try store.add(ExpenseDraft(amount: lira(8_500), kind: .expense, categoryID: coffee.id))
        try store.add(ExpenseDraft(amount: lira(25_000), kind: .expense, categoryID: food.id))
        try store.add(ExpenseDraft(amount: lira(4_000), kind: .expense, categoryID: transport.id))
        try store.add(ExpenseDraft(amount: Money(minorUnits: 300, currencyCode: "USD"), kind: .expense, categoryID: coffee.id))

        let entries = store.frequentEntries(kind: .expense, currencyCode: "TRY", limit: 2)
        #expect(entries.map(\.category.name) == ["coffee", "transport"])
        #expect(entries.first?.amount == lira(8_500))
    }

    @Test func seededCategoriesCarryTints() throws {
        #expect(try category("food").colorHex == "#FF9F6B")
    }

    @Test func updateRewritesTheEntry() throws {
        let coffee = try category("coffee")
        let food = try category("food")
        let id = try store.add(ExpenseDraft(amount: lira(8_500), kind: .expense, categoryID: coffee.id, note: "latte"))

        try store.update(id: id, with: ExpenseDraft(amount: lira(9_000), kind: .expense, categoryID: food.id, note: " "))

        let row = try #require(store.expenses(in: calendar.dayInterval(containing: .now), kind: .expense).first)
        #expect(row.amount == lira(9_000))
        #expect(row.category?.name == "food")
        #expect(row.note == nil)
        #expect(throws: ExpenseStoreError.expenseNotFound(UUID(uuid: UUID_NULL))) {
            try store.update(id: UUID(uuid: UUID_NULL), with: ExpenseDraft(amount: lira(1), kind: .expense, categoryID: nil))
        }
    }

    @Test func monthlyLimitCanBeSetAndCleared() throws {
        let food = try category("food")
        try store.setMonthlyLimit(categoryID: food.id, limitMinor: 300_000)
        #expect(try category("food").monthlyLimitMinor == 300_000)
        try store.setMonthlyLimit(categoryID: food.id, limitMinor: nil)
        #expect(try category("food").monthlyLimitMinor == nil)
    }

    @Test func usageRankingPutsFrequentCategoriesFirstAndKeepsTheRestInOrder() throws {
        let health = try category("health")
        let fun = try category("fun")
        try store.add(ExpenseDraft(amount: lira(100), kind: .expense, categoryID: health.id))
        try store.add(ExpenseDraft(amount: lira(100), kind: .expense, categoryID: health.id))
        try store.add(ExpenseDraft(amount: lira(100), kind: .expense, categoryID: fun.id))

        let names = store.categoriesByUsage(kind: .expense).map(\.name)
        #expect(names == ["health", "fun", "food", "coffee", "transport", "shopping", "bills", "other"])
    }

    @Test func customCategoriesCanBeAddedEditedReorderedAndArchived() throws {
        let id = try store.addCategory(name: "  gym ", emoji: "🏋️", colorHex: "#5FD3A2", kind: .expense)
        var categories = store.categories(kind: .expense)
        #expect(categories.last?.name == "gym")
        #expect(categories.last?.isDefault == false)
        #expect(categories.first?.isDefault == true)

        try store.updateCategory(id: id, name: "fitness", emoji: "💪", colorHex: "#6BB8FF")
        let edited = try category("fitness")
        #expect(edited.emoji == "💪")
        #expect(edited.colorHex == "#6BB8FF")

        try store.reorderCategories([id] + categories.dropLast().map(\.id))
        categories = store.categories(kind: .expense)
        #expect(categories.first?.id == id)

        try store.archiveCategory(id: id)
        #expect(!store.categories(kind: .expense).contains { $0.id == id })
    }

    @Test func archivedCategoryStillLabelsPastExpenses() throws {
        let id = try store.addCategory(name: "gym", emoji: "🏋️", colorHex: "#5FD3A2", kind: .expense)
        try store.add(ExpenseDraft(amount: lira(30_000), kind: .expense, categoryID: id))
        try store.archiveCategory(id: id)
        #expect(store.expenses(in: calendar.dayInterval(containing: .now), kind: .expense).first?.category?.name == "gym")
    }

    @Test func blankCategoryNamesAreRejected() {
        #expect(throws: ExpenseStoreError.emptyCategoryName) {
            try store.addCategory(name: "   ", emoji: "x", colorHex: "#000000", kind: .expense)
        }
    }

    @Test func recoloredDefaultsKeepTheirColorAfterReseeding() throws {
        let food = try category("food")
        try store.updateCategory(id: food.id, name: "food", emoji: "🍔", colorHex: "#123456")
        try store.seedDefaultCategoriesIfNeeded()
        #expect(try category("food").colorHex == "#123456")
    }

    @Test func spentSumsOneCategoryInOneCurrency() throws {
        let food = try category("food")
        let coffee = try category("coffee")
        try store.add(ExpenseDraft(amount: lira(10_000), kind: .expense, categoryID: food.id))
        try store.add(ExpenseDraft(amount: lira(5_000), kind: .expense, categoryID: food.id))
        try store.add(ExpenseDraft(amount: lira(9_900), kind: .expense, categoryID: coffee.id))
        try store.add(ExpenseDraft(amount: Money(minorUnits: 700, currencyCode: "USD"), kind: .expense, categoryID: food.id))
        let month = calendar.monthInterval(containing: .now)
        #expect(store.spent(categoryID: food.id, in: month, currencyCode: "TRY") == lira(15_000))
    }
}
