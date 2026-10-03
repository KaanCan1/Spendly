import CoreTransferable
import SpendlyCore
import SpendlyData
import SpendlyUI
import SwiftUI
import UniformTypeIdentifiers

/// One quiet sheet: Pro, currency, reminders and alerts, categories, export.
struct SettingsView: View {
    let store: any ExpenseStore
    @Binding var currencyCode: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(ProStore.self) private var pro
    @AppStorage(ReminderKeys.dailyEnabled) private var dailyEnabled = false
    @AppStorage(ReminderKeys.dailyMinutes) private var dailyMinutes = ReminderKeys.defaultDailyMinutes
    @AppStorage(ReminderKeys.weeklyEnabled) private var weeklyEnabled = false
    @AppStorage(BudgetAlerts.enabledKey, store: SharedSettings.defaults) private var budgetAlerts = true
    @State private var notificationsDenied = false
    @State private var paywall: ProFeature?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if pro.isPro {
                        Label("spendly pro is active", systemImage: "checkmark.seal")
                            .foregroundStyle(SpendlyColor.signature)
                            .accessibilityIdentifier("proActive")
                    } else {
                        Button { paywall = .general } label: {
                            // Inline symbol so the line wraps as one at large text sizes.
                            Text("\(Image(systemName: "sparkles"))  upgrade to spendly pro")
                                .foregroundStyle(SpendlyColor.signature)
                        }
                        .accessibilityIdentifier("upgradeButton")
                    }
                }

                Section {
                    Picker("currency", selection: $currencyCode) {
                        ForEach(Currency.pickerOptions(locale: locale), id: \.self) { code in
                            Text(verbatim: "\(Currency.symbol(for: code, locale: locale))  \(code)").tag(code)
                        }
                    }
                }

                Section {
                    Toggle("daily recap", isOn: notificationBinding($dailyEnabled))
                        .accessibilityIdentifier("dailyToggle")
                    if dailyEnabled {
                        DatePicker("at", selection: dailyTime, displayedComponents: .hourAndMinute)
                    }
                    Toggle("weekly summary", isOn: notificationBinding($weeklyEnabled))
                        .accessibilityIdentifier("weeklyToggle")
                    Toggle("budget alerts", isOn: notificationBinding($budgetAlerts))
                        .accessibilityIdentifier("budgetAlertsToggle")
                } header: {
                    Text("notifications")
                } footer: {
                    if notificationsDenied {
                        Text("notifications are off for spendly. turn them on in ios settings.")
                    } else {
                        Text("the weekly summary arrives on sunday at 18:00. budget alerts come at 80% and 100% of a limit.")
                    }
                }

                Section {
                    NavigationLink {
                        CategoriesView(store: store, currencyCode: currencyCode)
                    } label: {
                        Label("categories and limits", systemImage: "square.grid.2x2")
                    }
                    .accessibilityIdentifier("categoriesLink")
                }

                Section {
                    if pro.isPro {
                        ShareLink(
                            item: CSVExport(store: store, locale: locale),
                            preview: SharePreview("spendly.csv")
                        ) {
                            Label("export as csv", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("exportShareLink")
                    } else {
                        Button { paywall = .export } label: {
                            HStack {
                                Label("export as csv", systemImage: "square.and.arrow.up")
                                Spacer()
                                Text("pro")
                                    .font(SpendlyFont.micro)
                                    .foregroundStyle(SpendlyColor.onSignature)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(SpendlyColor.signature))
                            }
                        }
                        .accessibilityIdentifier("exportLocked")
                    }
                }
            }
            .font(SpendlyFont.body)
            .tint(SpendlyColor.signature)
            .foregroundStyle(SpendlyColor.ink)
            .scrollContentBackground(.hidden)
            .background(SpendlyColor.canvas.ignoresSafeArea())
            .navigationTitle(Text("settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Not .confirmationAction: its prominent lime button puts white text on lime.
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(SpendlyColor.ink)
                        .accessibilityIdentifier("settingsDone")
                }
            }
        }
        .sheet(item: $paywall) { feature in
            PaywallView(feature: feature)
        }
        .onChange(of: dailyMinutes) { reschedule() }
        .task { notificationsDenied = await NotificationPermission.isDenied() }
        .presentationCornerRadius(SpendlyRadius.surface)
    }

    /// Turning a notification on asks for permission first (never at launch);
    /// if the user says no, the toggle stays off and the footer explains why.
    private func notificationBinding(_ setting: Binding<Bool>) -> Binding<Bool> {
        Binding {
            setting.wrappedValue
        } set: { isOn in
            guard isOn else {
                setting.wrappedValue = false
                reschedule()
                return
            }
            Task {
                let granted = await NotificationPermission.request()
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
                entry.category?.displayName ?? "",
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
