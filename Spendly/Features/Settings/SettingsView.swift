import CoreTransferable
import SpendlyCore
import SpendlyData
import SpendlyUI
import SwiftUI
import UniformTypeIdentifiers

/// One quiet sheet: currency, reminders, categories (with limits), export.
struct SettingsView: View {
    let store: any ExpenseStore
    @Binding var currencyCode: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @AppStorage(ReminderKeys.dailyEnabled) private var dailyEnabled = false
    @AppStorage(ReminderKeys.dailyMinutes) private var dailyMinutes = ReminderKeys.defaultDailyMinutes
    @AppStorage(ReminderKeys.weeklyEnabled) private var weeklyEnabled = false
    @State private var notificationsDenied = false
    @State private var limitTarget: CategoryRecord?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("currency", selection: $currencyCode) {
                        ForEach(Currency.pickerOptions(locale: locale), id: \.self) { code in
                            Text("\(Currency.symbol(for: code, locale: locale))  \(code)").tag(code)
                        }
                    }
                }

                Section {
                    Toggle("daily recap", isOn: reminderBinding($dailyEnabled))
                    if dailyEnabled {
                        DatePicker("at", selection: dailyTime, displayedComponents: .hourAndMinute)
                    }
                    Toggle("weekly summary", isOn: reminderBinding($weeklyEnabled))
                } header: {
                    Text("reminders")
                } footer: {
                    if notificationsDenied {
                        Text("notifications are off for spendly — turn them on in iOS settings.")
                    } else {
                        Text("the weekly summary arrives on sunday at 18:00.")
                    }
                }

                Section("categories · monthly limits") {
                    ForEach(store.categories(kind: .expense)) { category in
                        Button { limitTarget = category } label: {
                            HStack(spacing: 12) {
                                Text(category.emoji)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(SpendlyColor.tint(category.colorHex)))
                                Text(category.name)
                                    .foregroundStyle(SpendlyColor.ink)
                                Spacer()
                                Text(category.monthlyLimitMinor.map {
                                    Money(minorUnits: $0, currencyCode: currencyCode).formatted(locale: locale, compact: true)
                                } ?? "no limit")
                                .foregroundStyle(SpendlyColor.muted)
                            }
                        }
                    }
                }

                Section {
                    ShareLink(
                        item: CSVExport(store: store, locale: locale),
                        preview: SharePreview("spendly.csv")
                    ) {
                        Label("export as csv", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .font(SpendlyFont.body)
            .tint(SpendlyColor.signature)
            .scrollContentBackground(.hidden)
            .background(SpendlyColor.canvas.ignoresSafeArea())
            .navigationTitle("settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") { dismiss() }
                }
            }
        }
        .sheet(item: $limitTarget) { category in
            LimitSheet(store: store, category: category, currencyCode: currencyCode)
        }
        .onChange(of: dailyMinutes) { reschedule() }
        .presentationCornerRadius(SpendlyRadius.surface)
    }

    /// Turning a reminder on asks for notification permission first (never at launch);
    /// if the user says no, the toggle stays off and the footer explains why.
    private func reminderBinding(_ setting: Binding<Bool>) -> Binding<Bool> {
        Binding {
            setting.wrappedValue
        } set: { isOn in
            guard isOn else {
                setting.wrappedValue = false
                reschedule()
                return
            }
            Task {
                let granted = await ReminderScheduler.requestAuthorization()
                notificationsDenied = !granted
                setting.wrappedValue = granted
                reschedule()
            }
        }
    }

    private var dailyTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: dailyMinutes / 60, minute: dailyMinutes % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            dailyMinutes = (parts.hour ?? 21) * 60 + (parts.minute ?? 0)
        }
    }

    private func reschedule() {
        ReminderScheduler.reschedule(store: store, currencyCode: currencyCode)
    }
}

/// Every entry as CSV, built when the share sheet asks for it.
struct CSVExport: Transferable {
    let rows: String

    @MainActor
    init(store: any ExpenseStore, locale: Locale) {
        let all = store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture), kind: nil)
        let formatter = ISO8601DateFormatter()
        var lines = ["date,kind,category,amount,currency,note"]
        for entry in all.reversed() {
            let fields = [
                formatter.string(from: entry.occurredAt),
                entry.kind.rawValue,
                entry.category?.name ?? "",
                "\(entry.amount.decimalValue)",
                entry.amount.currencyCode,
                entry.note ?? "",
            ]
            lines.append(fields.map(Self.escape).joined(separator: ","))
        }
        rows = lines.joined(separator: "\n") + "\n"
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { export in
            Data(export.rows.utf8)
        }
        .suggestedFileName("spendly.csv")
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
