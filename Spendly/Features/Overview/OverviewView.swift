import SpendlyCore
import SpendlyData
import SpendlyUI
import SwiftUI

/// Three zones:
/// 1. "‹ october ›" + gear, and the month total
/// 2. one stacked bar of this month's split by category, with tappable legend pills;
///    the selected category shows its budget ("₺2,400 of ₺3,000")
/// 3. entries grouped by day — swipe left to delete, tap to edit
struct OverviewView: View {
    let store: any ExpenseStore
    @Binding var currencyCode: String

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @State private var month = Date.now
    @State private var selectedCategoryID: UUID?
    @State private var editing: ExpenseRecord?
    @State private var limitTarget: CategoryRecord?
    @State private var showingSettings = false

    var body: some View {
        let interval = calendar.monthInterval(containing: month)
        let entries = store.expenses(in: interval, kind: nil)
        let spent = store.total(in: interval, kind: .expense, currencyCode: currencyCode)
        let earned = store.total(in: interval, kind: .income, currencyCode: currencyCode)
        let split = CategorySplit.make(from: entries, currencyCode: currencyCode)

        List {
            header(spent: spent, earned: earned)
                .plainRow(insets: EdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20))

            if !split.isEmpty {
                splitSection(split)
                    .plainRow(insets: EdgeInsets(top: 0, leading: 20, bottom: 24, trailing: 20))
            }

            if entries.isEmpty {
                Text("nothing logged in \(monthName) yet")
                    .font(SpendlyFont.body)
                    .foregroundStyle(SpendlyColor.muted)
                    .frame(maxWidth: .infinity)
                    .plainRow(insets: EdgeInsets(top: 40, leading: 20, bottom: 0, trailing: 20))
            }

            ForEach(DayGroup.make(from: entries, calendar: calendar)) { group in
                Section {
                    ForEach(group.entries) { entry in
                        Button { editing = entry } label: { EntryRow(entry: entry) }
                            .buttonStyle(.plain)
                            .plainRow(insets: EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                            .swipeActions(edge: .trailing) {
                                Button("delete", role: .destructive) {
                                    withAnimation { try? store.delete(id: entry.id) }
                                }
                                .tint(SpendlyColor.warning)
                            }
                    }
                } header: {
                    dayHeader(group)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(SpendlyColor.canvas.ignoresSafeArea())
        .sheet(item: $editing) { entry in
            EntryEditorView(store: store, entry: entry)
        }
        .sheet(item: $limitTarget) { category in
            LimitSheet(store: store, category: category, currencyCode: currencyCode)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(store: store, currencyCode: $currencyCode)
        }
    }

    // MARK: Zone 1

    private func header(spent: Money, earned: Money) -> some View {
        VStack(spacing: 18) {
            HStack {
                HStack(spacing: 2) {
                    monthButton("chevron.left", by: -1)
                    Text(monthName)
                        .font(SpendlyFont.pill)
                        .foregroundStyle(SpendlyColor.ink)
                        .frame(minWidth: 96)
                    monthButton("chevron.right", by: 1)
                        .disabled(isCurrentMonth)
                        .opacity(isCurrentMonth ? 0.25 : 1)
                }
                .background(Capsule().fill(SpendlyColor.surface))
                Spacer()
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(SpendlyColor.ink)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(SpendlyColor.surface))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("settings")
            }

            VStack(spacing: 4) {
                Text(spent.formatted(locale: locale, compact: true))
                    .font(SpendlyFont.total)
                    .tracking(SpendlyFont.tracking(for: 54))
                    .foregroundStyle(SpendlyColor.ink)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("spent \(isCurrentMonth ? "this month" : "in " + monthName)"
                    + (earned.isZero ? "" : " · +\(earned.formatted(locale: locale, compact: true)) earned"))
                    .font(SpendlyFont.caption)
                    .foregroundStyle(SpendlyColor.muted)
            }
        }
    }

    private func monthButton(_ symbol: String, by offset: Int) -> some View {
        Button {
            withAnimation(.spendly) {
                month = calendar.date(byAdding: .month, value: offset, to: month) ?? month
                selectedCategoryID = nil
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(SpendlyColor.ink)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
    }

    private var isCurrentMonth: Bool { calendar.isDate(month, equalTo: .now, toGranularity: .month) }

    private var monthName: String {
        isCurrentMonth ? "this month" : month.formatted(.dateTime.month(.wide)).lowercased()
    }

    // MARK: Zone 2

    private func splitSection(_ split: [CategorySplit]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SplitBar(split: split, selectedID: selectedCategoryID) { select($0) }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(split) { item in
                        Button { select(item.id) } label: {
                            HStack(spacing: 6) {
                                Circle().fill(SpendlyColor.tint(item.colorHex, .strong)).frame(width: 10, height: 10)
                                Text("\(item.emoji) \(Money(minorUnits: item.minor, currencyCode: currencyCode).formatted(locale: locale, compact: true))")
                                    .foregroundStyle(item.isNearLimit ? SpendlyColor.warning : (selectedCategoryID == item.id ? SpendlyColor.canvas : SpendlyColor.ink))
                            }
                        }
                        .buttonStyle(PillButtonStyle(selectedCategoryID == item.id ? .selected : .quiet))
                    }
                }
            }
            .scrollClipDisabled()

            if let selected = split.first(where: { $0.id == selectedCategoryID }), let category = selected.category {
                BudgetDetail(
                    category: category,
                    spent: Money(minorUnits: selected.minor, currencyCode: currencyCode),
                    onEditLimit: { limitTarget = category }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func select(_ id: UUID?) {
        withAnimation(.spendly) { selectedCategoryID = selectedCategoryID == id ? nil : id }
    }

    // MARK: Zone 3

    private func dayHeader(_ group: DayGroup) -> some View {
        let spent = group.entries
            .filter { $0.kind == .expense && $0.amount.currencyCode == currencyCode }
            .reduce(Int64(0)) { $0 + $1.amount.minorUnits }
        return HStack {
            Text(dayTitle(group.day))
            Spacer()
            if spent > 0 {
                Text("−\(Money(minorUnits: spent, currencyCode: currencyCode).formatted(locale: locale, compact: true))")
                    .monospacedDigit()
            }
        }
        .font(SpendlyFont.micro)
        .foregroundStyle(SpendlyColor.muted)
        .textCase(nil)
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(SpendlyColor.canvas)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
    }

    private func dayTitle(_ day: Date) -> String {
        if calendar.isDateInToday(day) { return "today" }
        if calendar.isDateInYesterday(day) { return "yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)).lowercased()
    }
}

// MARK: - Pieces

/// One category's share of the month, for the stacked bar and legend.
struct CategorySplit: Identifiable, Hashable {
    let id: UUID?
    let category: CategoryRecord?
    let minor: Int64

    var emoji: String { category?.emoji ?? "•" }
    var colorHex: String { category?.colorHex ?? "#9AA0A6" }
    var isNearLimit: Bool {
        guard let limit = category?.monthlyLimitMinor, limit > 0 else { return false }
        return Double(minor) / Double(limit) >= 0.8
    }

    static func make(from entries: [ExpenseRecord], currencyCode: String) -> [CategorySplit] {
        var sums: [UUID?: (CategoryRecord?, Int64)] = [:]
        for entry in entries where entry.kind == .expense && entry.amount.currencyCode == currencyCode {
            let key = entry.category?.id
            sums[key, default: (entry.category, 0)].1 += entry.amount.minorUnits
        }
        return sums.map { CategorySplit(id: $0.key, category: $0.value.0, minor: $0.value.1) }
            .sorted { $0.minor > $1.minor }
    }
}

private struct SplitBar: View {
    let split: [CategorySplit]
    let selectedID: UUID?
    let onSelect: (UUID?) -> Void

    var body: some View {
        let total = max(split.reduce(Int64(0)) { $0 + $1.minor }, 1)
        GeometryReader { proxy in
            let spacing: CGFloat = 3
            let usable = proxy.size.width - spacing * CGFloat(max(split.count - 1, 0))
            HStack(spacing: spacing) {
                ForEach(split) { item in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(SpendlyColor.tint(item.colorHex, .strong))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(SpendlyColor.ink, lineWidth: selectedID == item.id ? 1.5 : 0)
                        }
                        .frame(width: max(usable * CGFloat(item.minor) / CGFloat(total), 6))
                        .onTapGesture { onSelect(item.id) }
                }
            }
        }
        .frame(height: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("spending split by category")
    }
}

private struct BudgetDetail: View {
    let category: CategoryRecord
    let spent: Money
    let onEditLimit: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(category.emoji) \(category.name)")
                    .font(SpendlyFont.pill)
                    .foregroundStyle(SpendlyColor.ink)
                Spacer()
                if let limit = category.monthlyLimitMinor {
                    Text("\(spent.formatted(locale: locale, compact: true)) of \(Money(minorUnits: limit, currencyCode: spent.currencyCode).formatted(locale: locale, compact: true))")
                        .font(SpendlyFont.number(15, .semibold))
                        .foregroundStyle(progress(limit) >= 0.8 ? SpendlyColor.warning : SpendlyColor.ink)
                }
            }

            if let limit = category.monthlyLimitMinor {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(SpendlyColor.hairline)
                        Capsule()
                            .fill(progress(limit) >= 0.8 ? SpendlyColor.warning : SpendlyColor.signature)
                            .frame(width: proxy.size.width * min(progress(limit), 1))
                    }
                }
                .frame(height: 4)
                HStack {
                    if progress(limit) >= 0.8 {
                        Text("\(Int((progress(limit) * 100).rounded()))% used")
                            .foregroundStyle(SpendlyColor.warning)
                    }
                    Spacer()
                    Button("edit limit", action: onEditLimit)
                        .foregroundStyle(SpendlyColor.muted)
                }
                .font(SpendlyFont.caption)
            } else {
                Button("set a monthly limit", action: onEditLimit)
                    .buttonStyle(PillButtonStyle(.quiet))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(SpendlyColor.surface))
    }

    private func progress(_ limit: Int64) -> Double {
        limit > 0 ? Double(spent.minorUnits) / Double(limit) : 0
    }
}

struct EntryRow: View {
    let entry: ExpenseRecord
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 14) {
            Text(entry.category?.emoji ?? "•")
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
                .background(Circle().fill(SpendlyColor.tint(entry.category?.colorHex ?? "#9AA0A6")))
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.category?.name ?? "uncategorized")
                    .font(SpendlyFont.body)
                    .foregroundStyle(SpendlyColor.ink)
                if let note = entry.note {
                    Text(note)
                        .font(SpendlyFont.caption)
                        .foregroundStyle(SpendlyColor.muted)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text((entry.kind == .expense ? "−" : "+") + entry.amount.formatted(locale: locale, compact: true))
                .font(SpendlyFont.number(17, .medium))
                .foregroundStyle(entry.kind == .expense ? SpendlyColor.ink : SpendlyColor.signature)
        }
        .contentShape(Rectangle())
    }
}

struct DayGroup: Identifiable {
    let day: Date
    let entries: [ExpenseRecord]
    var id: Date { day }

    static func make(from entries: [ExpenseRecord], calendar: Calendar) -> [DayGroup] {
        Dictionary(grouping: entries) { calendar.startOfDay(for: $0.occurredAt) }
            .map { DayGroup(day: $0.key, entries: $0.value) }
            .sorted { $0.day > $1.day }
    }
}

extension View {
    /// List row with no separator, clear background and custom insets.
    func plainRow(insets: EdgeInsets) -> some View {
        listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(insets)
    }
}
