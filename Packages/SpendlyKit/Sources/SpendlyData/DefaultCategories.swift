import Foundation
import SpendlyCore

/// Seeded on first launch.
///
/// `colorHex` is each category's identity hue: one luminance, different hues, so the set reads as
/// a family on the dark canvas. Views draw it at low opacity for circles, high for chart segments.
///
/// The ids are fixed on purpose: two devices that both seed before their first iCloud sync end up
/// with rows that share an id, and the store collapses them into one when reading.
enum DefaultCategories {
    struct Seed {
        let id: UUID
        let name: String
        let emoji: String
        let colorHex: String
        let kind: EntryKind
    }

    static let all: [Seed] = [
        Seed(id: uuid("0001"), name: "food", emoji: "🍔", colorHex: "#FF9F6B", kind: .expense),
        Seed(id: uuid("0002"), name: "coffee", emoji: "☕️", colorHex: "#C9A27E", kind: .expense),
        Seed(id: uuid("0003"), name: "transport", emoji: "🚕", colorHex: "#6BB8FF", kind: .expense),
        Seed(id: uuid("0004"), name: "shopping", emoji: "🛍️", colorHex: "#FF7EB6", kind: .expense),
        Seed(id: uuid("0005"), name: "bills", emoji: "🧾", colorHex: "#A78BFA", kind: .expense),
        Seed(id: uuid("0006"), name: "fun", emoji: "🎉", colorHex: "#FFD166", kind: .expense),
        Seed(id: uuid("0007"), name: "health", emoji: "💊", colorHex: "#5FD3A2", kind: .expense),
        Seed(id: uuid("0008"), name: "other", emoji: "📦", colorHex: "#9AA0A6", kind: .expense),

        Seed(id: uuid("0101"), name: "salary", emoji: "💼", colorHex: "#5FD3A2", kind: .income),
        Seed(id: uuid("0102"), name: "freelance", emoji: "💻", colorHex: "#6BB8FF", kind: .income),
        Seed(id: uuid("0103"), name: "gift", emoji: "🎁", colorHex: "#FF7EB6", kind: .income),
        Seed(id: uuid("0104"), name: "other", emoji: "➕", colorHex: "#9AA0A6", kind: .income),
    ]

    static let ids = Set(all.map(\.id))

    private static func uuid(_ suffix: String) -> UUID {
        UUID(uuidString: "5BE0D1E5-0000-4000-8000-00000000\(suffix)")!
    }
}
