import Foundation
import Observation
import SpendlyCore

// The UI only talks to `ExpenseStore` and these value types — never to SwiftData models.
// Moving to a server (Vapor / Supabase) later means writing another `ExpenseStore`,
// not touching the screens.

public struct CategoryRecord: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let emoji: String
    public let colorHex: String
    public let kind: EntryKind
    public let monthlyLimitMinor: Int64?
    /// One of the built-in categories. Their names are shown translated; the user's are shown as typed.
    public let isDefault: Bool

    public init(
        id: UUID, name: String, emoji: String, colorHex: String, kind: EntryKind,
        monthlyLimitMinor: Int64? = nil, isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.kind = kind
        self.monthlyLimitMinor = monthlyLimitMinor
        self.isDefault = isDefault
    }
}

public struct ExpenseRecord: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let amount: Money
    public let kind: EntryKind
    public let category: CategoryRecord?
    public let note: String?
    public let occurredAt: Date

    public init(id: UUID, amount: Money, kind: EntryKind, category: CategoryRecord?, note: String?, occurredAt: Date) {
        self.id = id
        self.amount = amount
        self.kind = kind
        self.category = category
        self.note = note
        self.occurredAt = occurredAt
    }
}

/// What the quick-add screen hands to the store.
public struct ExpenseDraft: Hashable, Sendable {
    public var amount: Money
    public var kind: EntryKind
    public var categoryID: UUID?
    public var note: String?
    public var occurredAt: Date

    public init(amount: Money, kind: EntryKind, categoryID: UUID?, note: String? = nil, occurredAt: Date = .now) {
        self.amount = amount
        self.kind = kind
        self.categoryID = categoryID
        self.note = note
        self.occurredAt = occurredAt
    }
}

/// A "log it again" suggestion: same category, same amount.
public struct QuickEntry: Identifiable, Hashable, Sendable {
    public let category: CategoryRecord
    public let amount: Money

    public var id: String { "\(category.id)-\(amount.minorUnits)-\(amount.currencyCode)" }
}

/// Reads are plain method calls; implementations are `Observable` and touch a change counter
/// inside every read, so SwiftUI views that call them re-render after any write or sync import.
@MainActor
public protocol ExpenseStore: AnyObject, Observable {
    /// Increases on every change (local write or sync import). Observe it to react to "something changed".
    var revision: Int { get }
    /// Re-read after another process (a widget, an intent) wrote to the shared store.
    func refresh()

    func categories(kind: EntryKind) -> [CategoryRecord]
    /// Same categories, most used in the last 60 days first (ties keep `categories(kind:)` order).
    func categoriesByUsage(kind: EntryKind) -> [CategoryRecord]
    /// Newest first.
    func expenses(in interval: DateInterval, kind: EntryKind?) -> [ExpenseRecord]
    /// Sum of entries in `currencyCode`; other currencies are ignored until conversion exists.
    func total(in interval: DateInterval, kind: EntryKind, currencyCode: String) -> Money
    /// Most frequently logged (category, amount) pairs recently, most frequent first.
    func frequentEntries(kind: EntryKind, currencyCode: String, limit: Int) -> [QuickEntry]
    /// Spending of one category within `interval`, in `currencyCode`.
    func spent(categoryID: UUID, in interval: DateInterval, currencyCode: String) -> Money

    @discardableResult
    func add(_ draft: ExpenseDraft) throws -> UUID
    /// Replaces amount, kind, category, note and date of an existing entry.
    func update(id: UUID, with draft: ExpenseDraft) throws
    func delete(id: UUID) throws
    /// `nil` removes the limit.
    func setMonthlyLimit(categoryID: UUID, limitMinor: Int64?) throws
    func seedDefaultCategoriesIfNeeded() throws

    // Category management
    @discardableResult
    func addCategory(name: String, emoji: String, colorHex: String, kind: EntryKind) throws -> UUID
    func updateCategory(id: UUID, name: String, emoji: String, colorHex: String) throws
    /// Hides the category from pickers; past expenses keep showing it.
    func archiveCategory(id: UUID) throws
    /// Persists a new order for the categories of one kind.
    func reorderCategories(_ orderedIDs: [UUID]) throws
}
