import SpendlyCore
import SpendlyData
import SpendlyUI
import SwiftUI

/// The home screen. Three zones only:
/// 1. the "today ₺308" pill (opens the overview)
/// 2. the amount, a quiet "today ⌄ · note" line, and one habit suggestion
/// 3. a surface panel with the category row and the keypad
///
/// Logging is: type the amount → tap a category. The tap saves; undo replaces confirmation.
struct QuickAddView: View {
    let store: any ExpenseStore
    @Binding var currencyCode: String
    let showOverview: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    @State private var kind: EntryKind = .expense
    @State private var input = AmountInput(maxFractionDigits: 2)
    @State private var selectedDay = Date.now
    @State private var note = ""
    @State private var isEditingNote = false
    @FocusState private var noteFocused: Bool
    @State private var showingDayPicker = false

    @State private var toast: SavedToast?
    @State private var savedCount = 0
    @State private var rejectCount = 0

    /// Chip order is a snapshot taken when the app becomes active, so chips never reshuffle
    /// under the user's thumb right after a save.
    @State private var chipOrder: [EntryKind: [UUID]] = [:]

    // Save animation: the amount flies into the today pill, which then bounces.
    @State private var amountFrame = CGRect.zero
    @State private var pillFrame = CGRect.zero
    @State private var flight: Flight?
    @State private var pillBounce = 0

    private struct SavedToast: Identifiable, Equatable {
        let id = UUID()
        let expenseID: UUID
        let message: String
    }

    private static let space = "quickadd"

    var body: some View {
        VStack(spacing: 0) {
            todayPill
                .padding(.top, 8)

            // Swipe up only on the upper part: a drag recognizer over the keypad would swallow
            // fast repeated key taps while it decides whether a touch is a swipe.
            VStack(spacing: 0) {
                Spacer(minLength: 12)
                middleZone
                Spacer(minLength: 12)
            }
            .contentShape(Rectangle())
            .gesture(swipeUpForOverview)

            SurfacePanel {
                VStack(spacing: 16) {
                    categoryRow
                    Keypad(
                        decimalSeparator: input.maxFractionDigits > 0 ? (locale.decimalSeparator ?? ".") : nil,
                        onKey: press,
                        onClear: { withAnimation(.spendly) { input.clear() } }
                    )
                    .padding(.horizontal, 16)
                    .frame(maxHeight: 268)
                }
                .padding(.top, 20)
                .padding(.bottom, 8)
            }
        }
        .background((kind == .income ? SpendlyColor.incomeWash : SpendlyColor.canvas).ignoresSafeArea())
        .animation(.easeInOut(duration: 0.35), value: kind)
        .overlay { flightView }
        .coordinateSpace(.named(Self.space))
        .sheet(isPresented: $showingDayPicker) { dayPicker }
        .sensoryFeedback(.success, trigger: savedCount)
        .sensoryFeedback(.error, trigger: rejectCount)
        .sensoryFeedback(.selection, trigger: kind)
        .onChange(of: currencyCode, initial: true) { _, code in
            input = AmountInput(currencyCode: code)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            // Coming back means "log something now", not "keep logging last Tuesday".
            selectedDay = .now
            refreshChipOrder()
        }
        .task(id: toast) {
            guard toast != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.spendly) { toast = nil }
        }
        .task(id: flight) {
            guard flight != nil else { return }
            try? await Task.sleep(for: .milliseconds(450))
            flight = nil
            pillBounce += 1
        }
    }

    // MARK: Zone 1

    private var todayPill: some View {
        let total = store.total(in: calendar.dayInterval(containing: .now), kind: kind, currencyCode: currencyCode)
        let sign = kind == .income ? "+" : ""
        return Button(action: showOverview) {
            Text("today \(sign)\(total.formatted(locale: locale, compact: true))")
                .contentTransition(.numericText())
        }
        .buttonStyle(PillButtonStyle(.signature))
        .keyframeAnimator(initialValue: 1.0, trigger: pillBounce) { view, scale in
            view.scaleEffect(scale)
        } keyframes: { _ in
            SpringKeyframe(1.12, duration: 0.15, spring: .snappy)
            SpringKeyframe(1.0, duration: 0.35, spring: .bouncy)
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { pillFrame = $0 }
        .accessibilityHint("opens the overview")
    }

    // MARK: Zone 2

    private var middleZone: some View {
        VStack(spacing: 14) {
            ZStack {
                amountRow
                    .opacity(toast == nil && flight == nil ? 1 : 0)
                if let toast {
                    UndoToast(message: toast.message) { undo(toast) }
                        .fixedSize()
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .frame(height: 96)

            metaLine
                .frame(height: 28)

            // Fixed slot: the suggestion appearing or disappearing must not move the amount.
            Color.clear
                .frame(height: 40)
                .overlay { suggestion }
        }
        .padding(.horizontal, 20)
    }

    private var amountRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Button {
                withAnimation(.spendly) { kind = kind == .expense ? .income : .expense }
            } label: {
                Text(kind == .expense ? "−" : "+")
                    .font(SpendlyFont.number(34, .ultraLight))
                    .foregroundStyle(SpendlyColor.muted)
                    .frame(minWidth: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(kind == .expense ? "expense, switch to income" : "income, switch to expense")

            Menu {
                Picker("currency", selection: $currencyCode) {
                    ForEach(Currency.pickerOptions(locale: locale), id: \.self) { code in
                        Text("\(Currency.symbol(for: code, locale: locale))  \(code)").tag(code)
                    }
                }
            } label: {
                Text(Currency.symbol(for: currencyCode, locale: locale))
                    .font(SpendlyFont.number(34, .light))
                    .foregroundStyle(SpendlyColor.muted)
            }
            .accessibilityLabel("currency \(currencyCode)")

            Text(input.displayString(locale: locale))
                .font(SpendlyFont.amount)
                .tracking(SpendlyFont.tracking(for: 76))
                .foregroundStyle(input.isBlank ? SpendlyColor.muted.opacity(0.35) : SpendlyColor.ink)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.4)
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { amountFrame = $0 }
        .modifier(Shake(trigger: rejectCount))
    }

    @ViewBuilder
    private var metaLine: some View {
        if isEditingNote {
            TextField("note", text: $note)
                .font(SpendlyFont.label)
                .multilineTextAlignment(.center)
                .focused($noteFocused)
                .submitLabel(.done)
                .onSubmit { isEditingNote = false }
                .onAppear { noteFocused = true }
        } else {
            HStack(spacing: 8) {
                Button { showingDayPicker = true } label: {
                    HStack(spacing: 3) {
                        Text(dayLabel(selectedDay))
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(calendar.isDateInToday(selectedDay) ? SpendlyColor.muted : SpendlyColor.signature)
                }
                Text("·").foregroundStyle(SpendlyColor.muted.opacity(0.5))
                Button(note.isEmpty ? "note" : note) { isEditingNote = true }
                    .foregroundStyle(note.isEmpty ? SpendlyColor.muted : SpendlyColor.ink)
                    .lineLimit(1)
            }
            .font(SpendlyFont.label)
            .buttonStyle(.plain)
        }
    }

    /// One habit-based suggestion while nothing is typed; a one-line hint on first launch.
    @ViewBuilder
    private var suggestion: some View {
        if input.isBlank && toast == nil {
            if let entry = store.frequentEntries(kind: kind, currencyCode: currencyCode, limit: 1).first {
                Button("\(entry.category.emoji) \(entry.category.name) \(entry.amount.formatted(locale: locale, compact: true)) again?") {
                    save(amount: entry.amount, category: entry.category)
                }
                .buttonStyle(PillButtonStyle(.quiet))
                .transition(.opacity)
            } else {
                Text("type an amount, then tap a category")
                    .font(SpendlyFont.caption)
                    .foregroundStyle(SpendlyColor.muted)
            }
        }
    }

    // MARK: Zone 3

    private var categoryRow: some View {
        let order = chipOrder[kind] ?? []
        let categories = store.categories(kind: kind).sorted {
            (order.firstIndex(of: $0.id) ?? .max) < (order.firstIndex(of: $1.id) ?? .max)
        }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(categories) { category in
                    CategoryChip(
                        emoji: category.emoji,
                        name: category.name,
                        colorHex: category.colorHex,
                        isEnabled: input.minorUnits > 0
                    ) {
                        save(amount: Money(minorUnits: input.minorUnits, currencyCode: currencyCode), category: category)
                    }
                }
            }
        }
        .contentMargins(.horizontal, 14, for: .scrollContent)
        .scrollClipDisabled()
    }

    // MARK: Overlays & sheets

    @ViewBuilder
    private var flightView: some View {
        if let flight {
            FlyingAmount(flight: flight)
                .id(flight.id)
                .allowsHitTesting(false)
        }
    }

    private var dayPicker: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("which day?")
                .font(SpendlyFont.title)
                .foregroundStyle(SpendlyColor.ink)
            DayStrip(selection: $selectedDay, calendar: calendar) { showingDayPicker = false }
        }
        .padding(24)
        .presentationDetents([.height(190)])
        .presentationCornerRadius(SpendlyRadius.surface)
        .presentationBackground(SpendlyColor.surface)
    }

    private var swipeUpForOverview: some Gesture {
        DragGesture(minimumDistance: 40).onEnded { value in
            if value.translation.height < -80 && abs(value.translation.width) < 80 { showOverview() }
        }
    }

    // MARK: Actions

    private func dayLabel(_ day: Date) -> String {
        if calendar.isDateInToday(day) { return "today" }
        if calendar.isDateInYesterday(day) { return "yesterday" }
        return day.formatted(.dateTime.weekday(.abbreviated).day()).lowercased()
    }

    private func refreshChipOrder() {
        for kind in EntryKind.allCases {
            chipOrder[kind] = store.categoriesByUsage(kind: kind).map(\.id)
        }
    }

    private func press(_ key: AmountInput.Key) {
        var next = input
        guard next.press(key) else {
            rejectCount += 1
            return
        }
        withAnimation(.spendly) { input = next }
    }

    private func save(amount: Money, category: CategoryRecord) {
        let occurredAt = calendar.isDateInToday(selectedDay) ? Date.now : calendar.date(on: selectedDay, keepingTimeOf: .now)
        do {
            let id = try store.add(ExpenseDraft(
                amount: amount,
                kind: kind,
                categoryID: category.id,
                note: note,
                occurredAt: occurredAt
            ))
            let formatted = amount.formatted(locale: locale, compact: true)
            if !amountFrame.isEmpty && !pillFrame.isEmpty {
                flight = Flight(
                    text: formatted,
                    from: CGPoint(x: amountFrame.midX, y: amountFrame.midY),
                    to: CGPoint(x: pillFrame.midX, y: pillFrame.midY)
                )
            }
            withAnimation(.spendly) {
                toast = SavedToast(expenseID: id, message: "nice, logged \(category.emoji) \(formatted)")
                input.clear()
                note = ""
                isEditingNote = false
            }
            noteFocused = false
            savedCount += 1
        } catch {
            rejectCount += 1
        }
    }

    private func undo(_ toast: SavedToast) {
        try? store.delete(id: toast.expenseID)
        withAnimation(.spendly) { self.toast = nil }
    }
}

private struct Flight: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let from: CGPoint
    let to: CGPoint
}

/// The saved amount shrinking along a path into the today pill.
private struct FlyingAmount: View {
    let flight: Flight
    @State private var landed = false

    var body: some View {
        Text(flight.text)
            .font(SpendlyFont.number(52, .light))
            .tracking(SpendlyFont.tracking(for: 52))
            .foregroundStyle(SpendlyColor.ink)
            .fixedSize()
            .scaleEffect(landed ? 0.25 : 1)
            .opacity(landed ? 0 : 1)
            .position(landed ? flight.to : flight.from)
            .onAppear {
                withAnimation(.easeIn(duration: 0.42)) { landed = true }
            }
    }
}

/// Horizontal "nope" shake for rejected key presses and failed saves.
private struct Shake: ViewModifier {
    var trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: CGFloat.zero, trigger: trigger) { view, offset in
            view.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(8, duration: 0.05)
                LinearKeyframe(-8, duration: 0.08)
                LinearKeyframe(5, duration: 0.07)
                LinearKeyframe(0, duration: 0.06)
            }
        }
    }
}

#Preview {
    @Previewable @State var currency = "TRY"
    let store = SwiftDataExpenseStore(container: try! SpendlySchema.makeInMemoryContainer())
    let _ = try? store.seedDefaultCategoriesIfNeeded()
    QuickAddView(store: store, currencyCode: $currency, showOverview: {})
}
