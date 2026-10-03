import SwiftUI

/// Shown where the amount was, right after saving: "nice, logged ☕️ ₺85   undo".
/// A thin line under it counts down the 4 seconds. Replaces confirmation dialogs.
public struct UndoToast: View {
    let message: String
    let duration: Double
    let onUndo: () -> Void

    @State private var remaining: CGFloat = 1

    public init(message: String, duration: Double = 4, onUndo: @escaping () -> Void) {
        self.message = message
        self.duration = duration
        self.onUndo = onUndo
    }

    public var body: some View {
        HStack(spacing: 16) {
            Text(message)
                .font(SpendlyFont.label)
                .foregroundStyle(SpendlyColor.ink)
                .lineLimit(1)
            Button("undo", action: onUndo)
                .font(SpendlyFont.pill)
                .foregroundStyle(SpendlyColor.signature)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityIdentifier("undoButton")
        }
        .padding(.horizontal, 20)
        .frame(height: 48)
        .background(Capsule().fill(SpendlyColor.raised))
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(SpendlyColor.signature.opacity(0.6))
                .frame(height: 2)
                .scaleEffect(x: remaining, anchor: .leading)
                .padding(.horizontal, 22)
                .padding(.bottom, 6)
        }
        .onAppear {
            withAnimation(.linear(duration: duration)) { remaining = 0 }
        }
    }
}
