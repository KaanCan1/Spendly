import Foundation
import SpendlyCore
import SwiftData

// CloudKit-compatible from day one, so turning on iCloud sync later is just a capability toggle:
// - every stored property is optional or has a default value
// - no @Attribute(.unique) (CloudKit can't enforce it); `id` uniqueness is handled in code
// - relationships are optional and have an inverse
//
// Renaming or retyping a property after the CloudKit schema is deployed to production
// is not allowed — add new properties instead.

@Model
public final class Expense {
    public var id: UUID = UUID()
    public var amountMinor: Int64 = 0
    public var currencyCode: String = "USD"
    public var kindRaw: String = EntryKind.expense.rawValue
    public var note: String?
    public var occurredAt: Date = Date.now
    public var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify)
    public var category: ExpenseCategory?

    public init(
        id: UUID = UUID(),
        amount: Money,
        kind: EntryKind,
        category: ExpenseCategory?,
        note: String?,
        occurredAt: Date,
        createdAt: Date = .now
    ) {
        self.id = id
        self.amountMinor = amount.minorUnits
        self.currencyCode = amount.currencyCode
        self.kindRaw = kind.rawValue
        self.category = category
        self.note = note
        self.occurredAt = occurredAt
        self.createdAt = createdAt
    }

    public var amount: Money { Money(minorUnits: amountMinor, currencyCode: currencyCode) }
    public var kind: EntryKind { EntryKind(rawValue: kindRaw) ?? .expense }
}

/// Named `ExpenseCategory`, not `Category`: the Objective-C runtime already exports a `Category` type.
@Model
public final class ExpenseCategory {
    public var id: UUID = UUID()
    public var name: String = ""
    public var emoji: String = ""
    public var kindRaw: String = EntryKind.expense.rawValue
    public var sortOrder: Int = 0
    /// Identity hue as "#RRGGBB"; empty means "use the neutral gray".
    public var colorHex: String = ""
    /// Monthly budget in minor units of the user's currency; `nil` = no limit.
    public var monthlyLimitMinor: Int64?
    /// Categories are archived, never deleted, so past expenses keep their label.
    public var isArchived: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    public var expenses: [Expense]? = []

    public init(id: UUID = UUID(), name: String, emoji: String, colorHex: String = "", kind: EntryKind, sortOrder: Int) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.kindRaw = kind.rawValue
        self.sortOrder = sortOrder
    }

    public var kind: EntryKind { EntryKind(rawValue: kindRaw) ?? .expense }
}

public enum SpendlySchema {
    public static let models: [any PersistentModel.Type] = [Expense.self, ExpenseCategory.self]

    /// The on-disk container, shared through the App Group so the app, its widgets and its
    /// intents all read and write the same store.
    ///
    /// `cloudSync: true` (the app only) syncs to the user's private iCloud database as soon as the
    /// target has the iCloud (CloudKit) capability; without it, data simply stays on the device.
    /// Extensions pass `false`: they must not run CloudKit mirroring of their own.
    public static func makeContainer(cloudSync: Bool) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: Schema(models),
            groupContainer: .identifier(SharedSettings.appGroup),
            cloudKitDatabase: cloudSync ? .automatic : .none
        )
        return try ModelContainer(for: Schema(models), configurations: configuration)
    }

    /// Throwaway store for tests and previews.
    public static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: Schema(models), isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: Schema(models), configurations: configuration)
    }
}
