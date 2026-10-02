import AppIntents
import Foundation
import SpendlyCore
import SpendlyData

// Compiled into both the app and the widget extension, so Siri, Shortcuts, the Action Button,
// Spotlight, interactive widget buttons and the Control Center control all share one definition.

// MARK: - Category entity

struct CategoryEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    static let defaultQuery = CategoryQuery()

    let id: UUID
    let name: String
    let emoji: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(emoji) \(name)")
    }

    init(_ record: CategoryRecord) {
        id = record.id
        name = record.name
        emoji = record.emoji
    }
}

struct CategoryQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [CategoryEntity] {
        all().filter { identifiers.contains($0.id) }
    }

    /// Lets Siri resolve "coffee" or "Coffee" to the category.
    @MainActor
    func entities(matching string: String) async throws -> [CategoryEntity] {
        all().filter { $0.name.localizedCaseInsensitiveContains(string) }
    }

    @MainActor
    func suggestedEntities() async throws -> [CategoryEntity] {
        all()
    }

    @MainActor
    private func all() -> [CategoryEntity] {
        SpendlyEnvironment.store.categoriesByUsage(kind: .expense).map(CategoryEntity.init)
    }
}

// MARK: - Log an expense (Siri, Shortcuts, Action Button)

struct LogExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Log an expense"
    static let description = IntentDescription("Adds an expense to Spendly without opening the app.")

    @Parameter(title: "Amount", requestValueDialog: "How much did you spend?")
    var amount: Double

    @Parameter(title: "Category", requestValueDialog: "What was it for?")
    var category: CategoryEntity

    @Parameter(title: "Note")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) for \(\.$category)") {
            \.$note
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let currencyCode = SharedSettings.currencyCode
        let money = Money(amount: amount, currencyCode: currencyCode)
        guard money.minorUnits > 0 else {
            throw $amount.needsValueError("How much did you spend?")
        }

        let store = SpendlyEnvironment.store
        try store.add(ExpenseDraft(amount: money, kind: .expense, categoryID: category.id, note: note))
        SpendlyEnvironment.reloadWidgets()

        let today = store.total(in: Calendar.current.dayInterval(containing: .now), kind: .expense, currencyCode: currencyCode)
        return .result(dialog: IntentDialog(stringLiteral:
            "Logged \(category.emoji) \(money.formatted(compact: true)). Today: \(today.formatted(compact: true))."
        ))
    }
}

// MARK: - Log a usual entry (interactive widget buttons)

/// "☕️ ₺85 again" from a widget, without opening the app.
struct QuickLogIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a usual expense"
    static let isDiscoverable = false

    @Parameter(title: "Category")
    var categoryID: String

    @Parameter(title: "Amount in minor units")
    var amountMinor: Int

    @Parameter(title: "Currency")
    var currencyCode: String

    init() {}

    init(entry: QuickEntry) {
        categoryID = entry.category.id.uuidString
        amountMinor = Int(entry.amount.minorUnits)
        currencyCode = entry.amount.currencyCode
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: categoryID) else { return .result() }
        try SpendlyEnvironment.store.add(ExpenseDraft(
            amount: Money(minorUnits: Int64(amountMinor), currencyCode: currencyCode),
            kind: .expense,
            categoryID: id
        ))
        // Interactive widgets reload on their own after an intent; this covers the other widgets.
        SpendlyEnvironment.reloadWidgets()
        return .result()
    }
}

// MARK: - Open the keypad (Control Center, lock screen, Action Button)

struct OpenQuickAddIntent: AppIntent {
    static let title: LocalizedStringResource = "Open quick add"
    static let description = IntentDescription("Opens Spendly on the keypad, ready to log.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}
