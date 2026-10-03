import Foundation
import Observation
import SpendlyCore
import SwiftData

public enum ExpenseStoreError: Error, Equatable {
    case categoryNotFound(UUID)
    case nonPositiveAmount
    case expenseNotFound(UUID)
    case emptyCategoryName
}

@MainActor
@Observable
public final class SwiftDataExpenseStore: ExpenseStore {
    /// Bumped on every local write and every iCloud import; every read touches it.
    public private(set) var revision = 0

    /// Held so the container outlives the store: a context whose container was released crashes.
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored nonisolated(unsafe) private var observers: [any NSObjectProtocol] = []

    public init(container: ModelContainer, calendar: Calendar = .current) {
        self.container = container
        self.context = container.mainContext
        self.calendar = calendar

        // CloudKit imports land in the store behind our back; refresh readers when they do.
        let remoteChange = Notification.Name("NSPersistentStoreRemoteChangeNotification")
        observers.append(
            NotificationCenter.default.addObserver(forName: remoteChange, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.revision += 1 }
            }
        )
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    public func refresh() {
        revision += 1
    }

    // MARK: Reads

    public func categories(kind: EntryKind) -> [CategoryRecord] {
        _ = revision
        let kindRaw = kind.rawValue
        let descriptor = FetchDescriptor<ExpenseCategory>(
            predicate: #Predicate { $0.kindRaw == kindRaw && $0.isArchived == false },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        var seen = Set<UUID>()
        return rows.filter { seen.insert($0.id).inserted }.map(Self.record)
    }

    public func categoriesByUsage(kind: EntryKind) -> [CategoryRecord] {
        let categories = categories(kind: kind)
        let now = Date.now
        let start = calendar.date(byAdding: .day, value: -60, to: now) ?? now
        var counts: [UUID: Int] = [:]
        for expense in fetchExpenses(in: DateInterval(start: start, end: now.addingTimeInterval(1)), kind: kind) {
            if let id = expense.category?.id { counts[id, default: 0] += 1 }
        }
        // Stable sort: equal counts keep their seeded order.
        return categories.enumerated()
            .sorted { (counts[$0.element.id] ?? 0, -$0.offset) > (counts[$1.element.id] ?? 0, -$1.offset) }
            .map(\.element)
    }

    public func expenses(in interval: DateInterval, kind: EntryKind?) -> [ExpenseRecord] {
        _ = revision
        return fetchExpenses(in: interval, kind: kind).map(Self.record)
    }

    public func total(in interval: DateInterval, kind: EntryKind, currencyCode: String) -> Money {
        _ = revision
        let sum = fetchExpenses(in: interval, kind: kind)
            .filter { $0.currencyCode == currencyCode }
            .reduce(Int64(0)) { $0 + $1.amountMinor }
        return Money(minorUnits: sum, currencyCode: currencyCode)
    }

    public func frequentEntries(kind: EntryKind, currencyCode: String, limit: Int) -> [QuickEntry] {
        _ = revision
        let now = Date.now
        let start = calendar.date(byAdding: .day, value: -60, to: now) ?? now
        let recent = fetchExpenses(in: DateInterval(start: start, end: now.addingTimeInterval(1)), kind: kind)

        struct Tally {
            var entry: QuickEntry
            var count: Int
            var lastUsed: Date
        }
        var tallies: [String: Tally] = [:]
        for expense in recent where expense.currencyCode == currencyCode {
            guard let category = expense.category, !category.isArchived else { continue }
            let entry = QuickEntry(category: Self.record(category), amount: expense.amount)
            tallies[entry.id, default: Tally(entry: entry, count: 0, lastUsed: .distantPast)].count += 1
            tallies[entry.id]!.lastUsed = max(tallies[entry.id]!.lastUsed, expense.createdAt)
        }

        return tallies.values
            .sorted { ($0.count, $0.lastUsed) > ($1.count, $1.lastUsed) }
            .prefix(limit)
            .map(\.entry)
    }

    public func spent(categoryID: UUID, in interval: DateInterval, currencyCode: String) -> Money {
        _ = revision
        let sum = fetchExpenses(in: interval, kind: .expense)
            .filter { $0.category?.id == categoryID && $0.currencyCode == currencyCode }
            .reduce(Int64(0)) { $0 + $1.amountMinor }
        return Money(minorUnits: sum, currencyCode: currencyCode)
    }

    // MARK: Writes

    @discardableResult
    public func add(_ draft: ExpenseDraft) throws -> UUID {
        guard draft.amount.minorUnits > 0 else { throw ExpenseStoreError.nonPositiveAmount }

        var category: ExpenseCategory?
        if let categoryID = draft.categoryID {
            category = try fetchCategory(id: categoryID)
            guard category != nil else { throw ExpenseStoreError.categoryNotFound(categoryID) }
        }

        let expense = Expense(
            amount: draft.amount,
            kind: draft.kind,
            category: category,
            note: Self.cleanNote(draft.note),
            occurredAt: draft.occurredAt
        )
        context.insert(expense)
        try context.save()
        revision += 1
        return expense.id
    }

    public func update(id: UUID, with draft: ExpenseDraft) throws {
        guard draft.amount.minorUnits > 0 else { throw ExpenseStoreError.nonPositiveAmount }
        let descriptor = FetchDescriptor<Expense>(predicate: #Predicate { $0.id == id })
        guard let expense = try context.fetch(descriptor).first else { throw ExpenseStoreError.expenseNotFound(id) }

        var category: ExpenseCategory?
        if let categoryID = draft.categoryID {
            category = try fetchCategory(id: categoryID)
            guard category != nil else { throw ExpenseStoreError.categoryNotFound(categoryID) }
        }

        expense.amountMinor = draft.amount.minorUnits
        expense.currencyCode = draft.amount.currencyCode
        expense.kindRaw = draft.kind.rawValue
        expense.category = category
        expense.note = Self.cleanNote(draft.note)
        expense.occurredAt = draft.occurredAt
        try context.save()
        revision += 1
    }

    public func setMonthlyLimit(categoryID: UUID, limitMinor: Int64?) throws {
        guard let category = try fetchCategory(id: categoryID) else { throw ExpenseStoreError.categoryNotFound(categoryID) }
        category.monthlyLimitMinor = (limitMinor ?? 0) > 0 ? limitMinor : nil
        try context.save()
        revision += 1
    }

    public func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<Expense>(predicate: #Predicate { $0.id == id })
        for expense in try context.fetch(descriptor) {
            context.delete(expense)
        }
        try context.save()
        revision += 1
    }

    public func seedDefaultCategoriesIfNeeded() throws {
        let existing = try context.fetch(FetchDescriptor<ExpenseCategory>())
        let existingByID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var changed = false
        for (index, seed) in DefaultCategories.all.enumerated() {
            if let category = existingByID[seed.id] {
                // Users can recolor categories, so only fill in a color that was never set.
                if category.colorHex.isEmpty {
                    category.colorHex = seed.colorHex
                    changed = true
                }
                continue
            }
            context.insert(ExpenseCategory(
                id: seed.id, name: seed.name, emoji: seed.emoji, colorHex: seed.colorHex, kind: seed.kind, sortOrder: index
            ))
            changed = true
        }
        guard changed else { return }
        try context.save()
        revision += 1
    }

    // MARK: Category management

    @discardableResult
    public func addCategory(name: String, emoji: String, colorHex: String, kind: EntryKind) throws -> UUID {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ExpenseStoreError.emptyCategoryName }
        let kindRaw = kind.rawValue
        let siblings = try context.fetch(FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.kindRaw == kindRaw }))
        let category = ExpenseCategory(
            name: name,
            emoji: emoji,
            colorHex: colorHex,
            kind: kind,
            sortOrder: (siblings.map(\.sortOrder).max() ?? -1) + 1
        )
        context.insert(category)
        try context.save()
        revision += 1
        return category.id
    }

    public func updateCategory(id: UUID, name: String, emoji: String, colorHex: String) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ExpenseStoreError.emptyCategoryName }
        guard let category = try fetchCategory(id: id) else { throw ExpenseStoreError.categoryNotFound(id) }
        category.name = name
        category.emoji = emoji
        category.colorHex = colorHex
        try context.save()
        revision += 1
    }

    public func archiveCategory(id: UUID) throws {
        guard let category = try fetchCategory(id: id) else { throw ExpenseStoreError.categoryNotFound(id) }
        category.isArchived = true
        try context.save()
        revision += 1
    }

    public func reorderCategories(_ orderedIDs: [UUID]) throws {
        for (index, id) in orderedIDs.enumerated() {
            try fetchCategory(id: id)?.sortOrder = index
        }
        try context.save()
        revision += 1
    }

    // MARK: Helpers

    private func fetchExpenses(in interval: DateInterval, kind: EntryKind?) -> [Expense] {
        let start = interval.start
        let end = interval.end
        let predicate: Predicate<Expense>
        if let kindRaw = kind?.rawValue {
            predicate = #Predicate { $0.occurredAt >= start && $0.occurredAt < end && $0.kindRaw == kindRaw }
        } else {
            predicate = #Predicate { $0.occurredAt >= start && $0.occurredAt < end }
        }
        let descriptor = FetchDescriptor<Expense>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchCategory(id: UUID) throws -> ExpenseCategory? {
        var descriptor = FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func cleanNote(_ note: String?) -> String? {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private static func record(_ category: ExpenseCategory) -> CategoryRecord {
        CategoryRecord(
            id: category.id,
            name: category.name,
            emoji: category.emoji,
            colorHex: category.colorHex.isEmpty ? "#9AA0A6" : category.colorHex,
            kind: category.kind,
            monthlyLimitMinor: category.monthlyLimitMinor,
            isDefault: DefaultCategories.ids.contains(category.id)
        )
    }

    private static func record(_ expense: Expense) -> ExpenseRecord {
        ExpenseRecord(
            id: expense.id,
            amount: expense.amount,
            kind: expense.kind,
            category: expense.category.map(record),
            note: expense.note,
            occurredAt: expense.occurredAt
        )
    }
}
