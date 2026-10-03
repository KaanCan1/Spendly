import SpendlyCore
import SpendlyData
import SpendlyUI
import SwiftUI

/// Add, rename, recolor, reorder and archive categories. The free version allows
/// `ProLimits.freeCustomCategories` categories of the user's own.
struct CategoriesView: View {
    let store: any ExpenseStore
    let currencyCode: String

    @Environment(ProStore.self) private var pro
    @State private var kind: EntryKind = .expense
    @State private var editing: CategoryEditorView.Target?
    @State private var paywall: ProFeature?

    var body: some View {
        let categories = store.categories(kind: kind)
        List {
            Section {
                Picker("type", selection: $kind) {
                    Text("expenses").tag(EntryKind.expense)
                    Text("income").tag(EntryKind.income)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                ForEach(categories) { category in
                    Button { editing = .existing(category) } label: { row(category) }
                        .swipeActions(edge: .trailing) {
                            Button("archive", role: .destructive) {
                                withAnimation { try? store.archiveCategory(id: category.id) }
                            }
                            .tint(SpendlyColor.warning)
                        }
                }
                .onMove { from, to in
                    var ids = categories.map(\.id)
                    ids.move(fromOffsets: from, toOffset: to)
                    try? store.reorderCategories(ids)
                }

                Button {
                    if ProLimits.canAddCategory(customCount: customCount, isPro: pro.isPro) {
                        editing = .new(kind)
                    } else {
                        paywall = .categories
                    }
                } label: {
                    Label("new category", systemImage: "plus")
                        .foregroundStyle(SpendlyColor.signature)
                }
            } footer: {
                if !pro.isPro {
                    Text("\(customCount) of \(ProLimits.freeCustomCategories) categories of your own used. archived categories keep labeling past expenses.")
                } else {
                    Text("archived categories keep labeling past expenses.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(SpendlyColor.canvas.ignoresSafeArea())
        .navigationTitle(Text("categories"))
        .toolbar { EditButton() }
        .sheet(item: $editing) { target in
            CategoryEditorView(store: store, target: target, currencyCode: currencyCode)
        }
        .sheet(item: $paywall) { feature in
            PaywallView(feature: feature)
        }
    }

    /// User-made categories that are still in use, across both kinds.
    private var customCount: Int {
        EntryKind.allCases.flatMap { store.categories(kind: $0) }.filter { !$0.isDefault }.count
    }

    private func row(_ category: CategoryRecord) -> some View {
        HStack(spacing: 12) {
            Text(category.emoji)
                .frame(width: 34, height: 34)
                .background(Circle().fill(SpendlyColor.tint(category.colorHex, .strong).opacity(0.35)))
            Text(category.displayName)
                .foregroundStyle(SpendlyColor.ink)
            Spacer()
            if let limit = category.monthlyLimitMinor {
                Text(Money(minorUnits: limit, currencyCode: currencyCode).formatted(compact: true))
                    .font(SpendlyFont.number(15, .regular))
                    .foregroundStyle(SpendlyColor.muted)
            }
        }
    }
}

/// Name, emoji and color for a new or existing category, plus its monthly limit.
struct CategoryEditorView: View {
    enum Target: Identifiable {
        case new(EntryKind)
        case existing(CategoryRecord)

        var id: String {
            switch self {
            case .new(let kind): "new-\(kind.rawValue)"
            case .existing(let category): category.id.uuidString
            }
        }
    }

    let store: any ExpenseStore
    let target: Target
    let currencyCode: String

    @Environment(\.dismiss) private var dismiss
    @Environment(ProStore.self) private var pro
    @State private var name: String
    @State private var emoji: String
    @State private var colorHex: String
    @State private var limitTarget: CategoryRecord?
    @State private var paywall: ProFeature?
    @FocusState private var nameFocused: Bool

    static let emojis = [
        "🍔", "☕️", "🛒", "🍕", "🍺", "🚕", "🚇", "⛽️", "✈️", "🏠", "💡", "📱",
        "🧾", "🛍️", "👕", "💊", "🏋️", "🎬", "🎮", "🎉", "📚", "🐶", "🎁", "💼",
        "💻", "📦", "🚗", "🧴", "🍼", "💸",
    ]
    static let colors = [
        "#FF9F6B", "#C9A27E", "#6BB8FF", "#FF7EB6", "#A78BFA", "#FFD166",
        "#5FD3A2", "#9AA0A6", "#FF6B5E", "#4FD1C5", "#F6AD55", "#B794F4",
    ]

    init(store: any ExpenseStore, target: Target, currencyCode: String) {
        self.store = store
        self.target = target
        self.currencyCode = currencyCode
        switch target {
        case .new:
            _name = State(initialValue: "")
            _emoji = State(initialValue: Self.emojis[0])
            _colorHex = State(initialValue: Self.colors[0])
        case .existing(let category):
            _name = State(initialValue: category.displayName)
            _emoji = State(initialValue: category.emoji)
            _colorHex = State(initialValue: category.colorHex)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(spacing: 14) {
                        Text(emoji)
                            .font(.system(size: 30))
                            .frame(width: 64, height: 64)
                            .background(Circle().fill(SpendlyColor.tint(colorHex, .strong).opacity(0.35)))
                        TextField("name", text: $name)
                            .font(SpendlyFont.title)
                            .foregroundStyle(SpendlyColor.ink)
                            .focused($nameFocused)
                            .submitLabel(.done)
                    }

                    section("emoji") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                            ForEach(Self.emojis, id: \.self) { option in
                                Button { emoji = option } label: {
                                    Text(option)
                                        .font(.system(size: 24))
                                        .frame(width: 46, height: 46)
                                        .background(Circle().fill(option == emoji ? SpendlyColor.raised : .clear))
                                        .overlay(Circle().strokeBorder(SpendlyColor.signature, lineWidth: option == emoji ? 1.5 : 0))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    section("color") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(Self.colors, id: \.self) { option in
                                Button { colorHex = option } label: {
                                    Circle()
                                        .fill(SpendlyColor.tint(option, .strong))
                                        .frame(width: 34, height: 34)
                                        .padding(4)
                                        .overlay(Circle().strokeBorder(SpendlyColor.ink, lineWidth: option == colorHex ? 2 : 0))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text("color \(option)"))
                            }
                        }
                    }

                    if case .existing(let category) = target, category.kind == .expense {
                        section("monthly limit") {
                            Button {
                                let others = store.categories(kind: .expense)
                                    .filter { $0.monthlyLimitMinor != nil && $0.id != category.id }.count
                                if category.monthlyLimitMinor != nil || ProLimits.canSetBudget(otherBudgets: others, isPro: pro.isPro) {
                                    limitTarget = category
                                } else {
                                    paywall = .budgets
                                }
                            } label: {
                                HStack {
                                    Text(currentLimitText(category))
                                        .foregroundStyle(SpendlyColor.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(SpendlyColor.muted)
                                }
                                .padding(16)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SpendlyColor.surface))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(24)
            }
            .background(SpendlyColor.canvas.ignoresSafeArea())
            .navigationTitle(isNew ? Text("new category") : Text("edit category"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { if isNew { nameFocused = true } }
        }
        .sheet(item: $limitTarget) { category in
            LimitSheet(store: store, category: category, currencyCode: currencyCode)
        }
        .sheet(item: $paywall) { feature in
            PaywallView(feature: feature)
        }
        .presentationCornerRadius(SpendlyRadius.surface)
    }

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }

    private func currentLimitText(_ category: CategoryRecord) -> String {
        // Re-read so a limit set in the sheet shows up immediately.
        let latest = store.categories(kind: .expense).first { $0.id == category.id }
        guard let limit = latest?.monthlyLimitMinor else { return String(localized: "no limit") }
        return Money(minorUnits: limit, currencyCode: currencyCode).formatted(compact: true)
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(SpendlyFont.micro)
                .foregroundStyle(SpendlyColor.muted)
            content()
        }
    }

    private func save() {
        do {
            switch target {
            case .new(let kind):
                try store.addCategory(name: name, emoji: emoji, colorHex: colorHex, kind: kind)
            case .existing(let category):
                // Keep a built-in category's stored English name when the user didn't rename it,
                // so it keeps following the device language.
                let stored = category.isDefault && name == category.displayName ? category.name : name
                try store.updateCategory(id: category.id, name: stored, emoji: emoji, colorHex: colorHex)
            }
            dismiss()
        } catch {
            nameFocused = true
        }
    }
}
