import AppIntents
import SpendlyCore
import SpendlyData
import SpendlyUI
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct TodayEntry: TimelineEntry {
    let date: Date
    let total: Money
    /// The user's usual (category, amount) pairs — each becomes a one-tap log button.
    let usual: [QuickEntry]

    static let placeholder = TodayEntry(date: .now, total: Money(minorUnits: 30_800, currencyCode: "TRY"), usual: [])

    @MainActor
    static func current() -> TodayEntry {
        let store = SpendlyEnvironment.store
        store.refresh()
        let currencyCode = SharedSettings.currencyCode
        return TodayEntry(
            date: .now,
            total: store.total(in: Calendar.current.dayInterval(containing: .now), kind: .expense, currencyCode: currencyCode),
            usual: store.frequentEntries(kind: .expense, currencyCode: currencyCode, limit: 3)
        )
    }
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        let reply = UncheckedSendable(completion)
        let isPreview = context.isPreview
        Task { @MainActor in reply.value(isPreview ? .placeholder : .current()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let reply = UncheckedSendable(completion)
        Task { @MainActor in
            // "Today" resets at midnight; every write in between reloads the timeline explicitly.
            let midnight = Calendar.current.dayInterval(containing: .now).end
            reply.value(Timeline(entries: [.current()], policy: .after(midnight)))
        }
    }
}

/// WidgetKit's completion handlers predate strict concurrency; WidgetKit calls them from any thread.
private struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}

// MARK: - Home screen: today + one-tap usuals

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.kaancankurt.spendly.today", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(SpendlyColor.canvas, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Today's spending, and your usual expenses one tap away.")
        .supportedFamilies([.systemSmall])
    }
}

struct TodayWidgetView: View {
    let entry: TodayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(SpendlyColor.signature).frame(width: 6, height: 6)
                Text("today")
                    .font(SpendlyFont.micro)
                    .foregroundStyle(SpendlyColor.muted)
            }
            Text(entry.total.formatted(compact: true))
                .font(SpendlyFont.number(32, .light))
                .tracking(-1)
                .foregroundStyle(SpendlyColor.ink)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
                .padding(.top, 2)

            Spacer(minLength: 8)

            if entry.usual.isEmpty {
                Text("tap to log your first")
                    .font(SpendlyFont.caption)
                    .foregroundStyle(SpendlyColor.muted)
            } else {
                HStack(spacing: 6) {
                    ForEach(entry.usual) { usual in
                        Button(intent: QuickLogIntent(entry: usual)) {
                            VStack(spacing: 3) {
                                Text(usual.category.emoji)
                                    .font(.system(size: 17))
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(SpendlyColor.tint(usual.category.colorHex)))
                                Text(usual.amount.formatted(compact: true))
                                    .font(SpendlyFont.number(10, .medium))
                                    .foregroundStyle(SpendlyColor.muted)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("log \(usual.category.name) \(usual.amount.formatted(compact: true))")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "spendly://add"))
    }
}

// MARK: - Lock screen

struct LockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.kaancankurt.spendly.lock", provider: TodayProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Today's total, or a shortcut to the keypad.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct LockScreenWidgetView: View {
    let entry: TodayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
            }
            .widgetURL(URL(string: "spendly://add"))
            .accessibilityLabel("log an expense")
        case .accessoryInline:
            Text("\(entry.total.formatted(compact: true)) today")
        default:
            VStack(alignment: .leading, spacing: 0) {
                Text("spendly · today")
                    .font(SpendlyFont.micro)
                    .widgetAccentable()
                Text(entry.total.formatted(compact: true))
                    .font(SpendlyFont.number(26, .light))
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(URL(string: "spendly://add"))
        }
    }
}

// MARK: - Control Center / Action Button

struct QuickAddControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.kaancankurt.spendly.quickadd") {
            ControlWidgetButton(action: OpenQuickAddIntent()) {
                Label("Log expense", systemImage: "plus.circle")
            }
        }
        .displayName("Log expense")
        .description("Opens Spendly on the keypad.")
    }
}

@main
struct SpendlyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        LockScreenWidget()
        QuickAddControl()
    }
}
