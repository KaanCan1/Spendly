import Foundation

public enum EntryKind: String, CaseIterable, Hashable, Sendable, Codable {
    case expense
    case income
}

public extension Calendar {
    /// [start of day, start of next day)
    func dayInterval(containing date: Date) -> DateInterval {
        let start = startOfDay(for: date)
        let end = self.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }

    /// [first day of month, first day of next month)
    func monthInterval(containing date: Date) -> DateInterval {
        dateInterval(of: .month, for: date) ?? dayInterval(containing: date)
    }

    /// `day`'s date combined with `time`'s hour/minute/second. Used when logging an
    /// expense on a past day: keeps entries in the order they were typed.
    func date(on day: Date, keepingTimeOf time: Date) -> Date {
        let clock = dateComponents([.hour, .minute, .second], from: time)
        return self.date(
            bySettingHour: clock.hour ?? 12,
            minute: clock.minute ?? 0,
            second: clock.second ?? 0,
            of: day
        ) ?? day
    }
}
