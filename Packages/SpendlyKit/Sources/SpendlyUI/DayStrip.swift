import SwiftUI

/// The last `dayCount` days in one row, today on the right. Lives in a compact sheet opened from
/// the "today ⌄" line, so it costs no space on quick add.
public struct DayStrip: View {
    @Binding var selection: Date
    let dayCount: Int
    let calendar: Calendar
    let onPick: () -> Void

    public init(selection: Binding<Date>, dayCount: Int = 7, calendar: Calendar = .current, onPick: @escaping () -> Void = {}) {
        self._selection = selection
        self.dayCount = dayCount
        self.calendar = calendar
        self.onPick = onPick
    }

    private var days: [Date] {
        let today = calendar.startOfDay(for: .now)
        return (0..<dayCount).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(days, id: \.self) { day in
                cell(day)
            }
        }
    }

    private func cell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selection)
        return Button {
            withAnimation(.spendly) { selection = day }
            onPick()
        } label: {
            VStack(spacing: 2) {
                Text(day, format: .dateTime.day())
                    .font(SpendlyFont.number(18, .medium))
                (calendar.isDateInToday(day) ? Text("today") : Text(verbatim: day.formatted(.dateTime.weekday(.abbreviated)).lowercased()))
                    .font(SpendlyFont.micro)
                    .opacity(isSelected ? 0.9 : 0.6)
            }
            .foregroundStyle(isSelected ? SpendlyColor.onSignature : SpendlyColor.ink)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? SpendlyColor.signature : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
