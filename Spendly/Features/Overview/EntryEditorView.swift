import SpendlyCore
import SpendlyData
import SpendlyUI
import SwiftUI

/// Edit an entry with the same keypad as quick add, prefilled. The current category has a ring;
/// tapping any category commits the change — same gesture as saving a new one.
struct EntryEditorView: View {
    let store: any ExpenseStore
    let entry: ExpenseRecord

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var input: AmountInput
    @State private var note: String
    @State private var rejectCount = 0

    init(store: any ExpenseStore, entry: ExpenseRecord) {
        self.store = store
        self.entry = entry
        _input = State(initialValue: AmountInput(money: entry.amount))
        _note = State(initialValue: entry.note ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("cancel") { dismiss() }
                    .foregroundStyle(SpendlyColor.muted)
                Spacer()
                Text("editing")
                    .font(SpendlyFont.pill)
                    .foregroundStyle(SpendlyColor.ink)
                Spacer()
                Button {
                    try? store.delete(id: entry.id)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
                .foregroundStyle(SpendlyColor.warning)
                .accessibilityLabel("delete")
            }
            .font(SpendlyFont.label)
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer(minLength: 12)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Currency.symbol(for: entry.amount.currencyCode, locale: locale))
                    .font(SpendlyFont.number(32, .light))
                    .foregroundStyle(SpendlyColor.muted)
                Text(input.displayString(locale: locale))
                    .font(SpendlyFont.number(64, .light))
                    .tracking(SpendlyFont.tracking(for: 64))
                    .foregroundStyle(SpendlyColor.ink)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
            }
            .padding(.horizontal, 20)
            TextField("note", text: $note)
                .font(SpendlyFont.label)
                .multilineTextAlignment(.center)
                .foregroundStyle(SpendlyColor.ink)
                .padding(.top, 8)
            Spacer(minLength: 12)

            SurfacePanel {
                VStack(spacing: 16) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(store.categories(kind: entry.kind)) { category in
                                CategoryChip(
                                    emoji: category.emoji,
                                    name: category.name,
                                    colorHex: category.colorHex,
                                    isEnabled: input.minorUnits > 0,
                                    isCurrent: category.id == entry.category?.id
                                ) { commit(category) }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .contentMargins(.horizontal, 14, for: .scrollContent)
                    .scrollClipDisabled()

                    Keypad(
                        decimalSeparator: input.maxFractionDigits > 0 ? (locale.decimalSeparator ?? ".") : nil,
                        onKey: { key in
                            var next = input
                            if next.press(key) { withAnimation(.spendly) { input = next } } else { rejectCount += 1 }
                        },
                        onClear: { withAnimation(.spendly) { input.clear() } }
                    )
                    .padding(.horizontal, 16)
                    .frame(maxHeight: 250)
                }
                .padding(.top, 20)
                .padding(.bottom, 8)
            }
        }
        .background(SpendlyColor.canvas.ignoresSafeArea())
        .sensoryFeedback(.error, trigger: rejectCount)
        .presentationCornerRadius(SpendlyRadius.surface)
    }

    private func commit(_ category: CategoryRecord) {
        do {
            try store.update(id: entry.id, with: ExpenseDraft(
                amount: Money(minorUnits: input.minorUnits, currencyCode: entry.amount.currencyCode),
                kind: entry.kind,
                categoryID: category.id,
                note: note,
                occurredAt: entry.occurredAt
            ))
            dismiss()
        } catch {
            rejectCount += 1
        }
    }
}

/// Monthly limit for one category, typed on the same keypad. There is no category to tap here,
/// so a single "set limit" pill commits.
struct LimitSheet: View {
    let store: any ExpenseStore
    let category: CategoryRecord
    let currencyCode: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var input: AmountInput

    init(store: any ExpenseStore, category: CategoryRecord, currencyCode: String) {
        self.store = store
        self.category = category
        self.currencyCode = currencyCode
        let current = Money(minorUnits: category.monthlyLimitMinor ?? 0, currencyCode: currencyCode)
        _input = State(initialValue: AmountInput(money: current))
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text(category.emoji)
                    .font(.system(size: 28))
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(SpendlyColor.tint(category.colorHex)))
                Text("\(category.name) · monthly limit")
                    .font(SpendlyFont.pill)
                    .foregroundStyle(SpendlyColor.ink)
            }
            .padding(.top, 24)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Currency.symbol(for: currencyCode, locale: locale))
                    .font(SpendlyFont.number(30, .light))
                    .foregroundStyle(SpendlyColor.muted)
                Text(input.displayString(locale: locale))
                    .font(SpendlyFont.number(56, .light))
                    .tracking(SpendlyFont.tracking(for: 56))
                    .foregroundStyle(input.isBlank ? SpendlyColor.muted.opacity(0.35) : SpendlyColor.ink)
                    .contentTransition(.numericText())
            }

            Keypad(
                decimalSeparator: input.maxFractionDigits > 0 ? (locale.decimalSeparator ?? ".") : nil,
                onKey: { key in
                    var next = input
                    if next.press(key) { withAnimation(.spendly) { input = next } }
                },
                onClear: { input.clear() }
            )
            .frame(maxHeight: 250)

            HStack(spacing: 12) {
                if category.monthlyLimitMinor != nil {
                    Button("remove limit") { save(nil) }
                        .buttonStyle(PillButtonStyle(.quiet))
                }
                Button("set limit") { save(input.minorUnits) }
                    .buttonStyle(PillButtonStyle(.signature))
                    .disabled(input.minorUnits == 0)
                    .opacity(input.minorUnits == 0 ? 0.4 : 1)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .background(SpendlyColor.surface.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationCornerRadius(SpendlyRadius.surface)
    }

    private func save(_ limit: Int64?) {
        try? store.setMonthlyLimit(categoryID: category.id, limitMinor: limit)
        dismiss()
    }
}
