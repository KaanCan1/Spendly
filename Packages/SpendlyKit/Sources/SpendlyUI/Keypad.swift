import SpendlyCore
import SwiftUI

/// 3×4 keypad of soft rounded-rect keys: 1–9, decimal separator, 0, delete.
/// Long-press delete clears. Meant to sit on a `SurfacePanel`.
///
/// There is intentionally no "done" key — tapping a category is what saves.
public struct Keypad: View {
    let decimalSeparator: String?
    let onKey: (AmountInput.Key) -> Void
    let onClear: () -> Void

    /// Pass `decimalSeparator: nil` for zero-decimal currencies; the key is then hidden.
    public init(
        decimalSeparator: String?,
        onKey: @escaping (AmountInput.Key) -> Void,
        onClear: @escaping () -> Void
    ) {
        self.decimalSeparator = decimalSeparator
        self.onKey = onKey
        self.onClear = onClear
    }

    private let rows: [[Int]] = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    public var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { digit in
                        key(.digit(digit)) { Text("\(digit)") }
                    }
                }
            }
            GridRow {
                if let decimalSeparator {
                    key(.decimalSeparator) { Text(decimalSeparator) }
                } else {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                key(.digit(0)) { Text("0") }
                key(.delete) { Image(systemName: "delete.left").font(.system(size: 21, weight: .medium)) }
                    .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in onClear() })
                    .accessibilityHint("long press to clear")
            }
        }
    }

    private func key(_ key: AmountInput.Key, @ViewBuilder label: () -> some View) -> some View {
        Button { onKey(key) } label: {
            label()
                .font(SpendlyFont.keypad)
                .foregroundStyle(SpendlyColor.ink)
                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 58)
                .background(RoundedRectangle(cornerRadius: SpendlyRadius.key, style: .continuous).fill(SpendlyColor.raised))
                .contentShape(RoundedRectangle(cornerRadius: SpendlyRadius.key, style: .continuous))
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityLabel(Self.accessibilityLabel(for: key))
    }

    private static func accessibilityLabel(for key: AmountInput.Key) -> String {
        switch key {
        case .digit(let value): "\(value)"
        case .decimalSeparator: "decimal point"
        case .delete: "delete"
        }
    }
}

private struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spendly, value: configuration.isPressed)
    }
}

/// The raised white panel the keypad (and chip row) sit on: rounded top corners, one soft shadow.
public struct SurfacePanel<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .background {
                UnevenRoundedRectangle(
                    topLeadingRadius: SpendlyRadius.surface,
                    topTrailingRadius: SpendlyRadius.surface,
                    style: .continuous
                )
                .fill(SpendlyColor.surface)
                .overlay {
                    // On a dark canvas a shadow disappears; a top hairline gives the edge instead.
                    UnevenRoundedRectangle(
                        topLeadingRadius: SpendlyRadius.surface,
                        topTrailingRadius: SpendlyRadius.surface,
                        style: .continuous
                    )
                    .strokeBorder(SpendlyColor.hairline, lineWidth: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
            }
    }
}
