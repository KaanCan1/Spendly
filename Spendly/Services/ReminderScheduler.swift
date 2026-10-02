import Foundation
import SpendlyCore
import SpendlyData
import UserNotifications

/// Local notifications only — no server needed.
///
/// Notification content is fixed at scheduling time, so we reschedule after every change:
/// the pending "today you spent …" always carries the latest numbers, because the last thing that
/// happened before it fires is the last save we rescheduled on.
enum ReminderKeys {
    static let dailyEnabled = "reminders.dailyEnabled"
    static let dailyMinutes = "reminders.dailyMinutes"
    static let weeklyEnabled = "reminders.weeklyEnabled"
    static let defaultDailyMinutes = 21 * 60
}

@MainActor
enum ReminderScheduler {
    private static let dailyPrefix = "daily-"
    private static let weeklyID = "weekly"
    /// Days ahead to keep scheduled, so reminders keep coming even if the app isn't opened.
    private static let daysAhead = 7

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func reschedule(
        store: any ExpenseStore,
        currencyCode: String,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        locale: Locale = .current,
        now: Date = .now
    ) {
        let center = UNUserNotificationCenter.current()
        let ids = (0..<daysAhead).map { "\(dailyPrefix)\($0)" } + [weeklyID]
        center.removePendingNotificationRequests(withIdentifiers: ids)

        if defaults.bool(forKey: ReminderKeys.dailyEnabled) {
            let minutes = defaults.object(forKey: ReminderKeys.dailyMinutes) as? Int ?? ReminderKeys.defaultDailyMinutes
            for offset in 0..<daysAhead {
                guard
                    let day = calendar.date(byAdding: .day, value: offset, to: now),
                    let fireDate = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day),
                    fireDate > now
                else { continue }

                // Only today's numbers are known; later days get a gentle nudge.
                let body = calendar.isDate(fireDate, inSameDayAs: now)
                    ? dailySummary(store: store, currencyCode: currencyCode, calendar: calendar, locale: locale, now: now)
                    : "anything to log today? it takes two taps."
                schedule(id: "\(dailyPrefix)\(offset)", body: body, at: fireDate, calendar: calendar)
            }
        }

        if defaults.bool(forKey: ReminderKeys.weeklyEnabled), let sunday = nextSunday6pm(after: now, calendar: calendar) {
            let week = calendar.dateInterval(of: .weekOfYear, for: sunday) ?? DateInterval(start: now, end: sunday)
            schedule(
                id: weeklyID,
                body: weeklySummary(store: store, week: week, currencyCode: currencyCode, locale: locale),
                at: sunday,
                calendar: calendar
            )
        }
    }

    // MARK: Content

    private static func dailySummary(
        store: any ExpenseStore, currencyCode: String, calendar: Calendar, locale: Locale, now: Date
    ) -> String {
        let today = calendar.dayInterval(containing: now)
        let total = store.total(in: today, kind: .expense, currencyCode: currencyCode)
        guard !total.isZero else { return "nothing logged today — anything to add?" }
        let top = topCategory(store.expenses(in: today, kind: .expense), currencyCode: currencyCode)
        return "today you spent \(total.formatted(locale: locale, compact: true))" + (top.map { " — mostly \($0)" } ?? "")
    }

    private static func weeklySummary(store: any ExpenseStore, week: DateInterval, currencyCode: String, locale: Locale) -> String {
        let total = store.total(in: week, kind: .expense, currencyCode: currencyCode)
        guard !total.isZero else { return "a quiet week — nothing logged." }
        let top = topCategory(store.expenses(in: week, kind: .expense), currencyCode: currencyCode)
        return "this week: \(total.formatted(locale: locale, compact: true))" + (top.map { " — mostly \($0)" } ?? "")
    }

    private static func topCategory(_ entries: [ExpenseRecord], currencyCode: String) -> String? {
        var sums: [String: Int64] = [:]
        for entry in entries where entry.amount.currencyCode == currencyCode {
            guard let name = entry.category?.name else { continue }
            sums[name, default: 0] += entry.amount.minorUnits
        }
        return sums.max { $0.value < $1.value }?.key
    }

    // MARK: Scheduling

    private static func nextSunday6pm(after now: Date, calendar: Calendar) -> Date? {
        calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 18, minute: 0, second: 0, weekday: 1),
            matchingPolicy: .nextTime
        )
    }

    private static func schedule(id: String, body: String, at date: Date, calendar: Calendar) {
        let content = UNMutableNotificationContent()
        content.body = body
        content.sound = .default
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
}
