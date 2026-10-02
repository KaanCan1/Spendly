import SwiftUI

/// Emoji on its own pastel circle with a small label. Tapping it saves (or, when editing, commits).
public struct CategoryChip: View {
    let emoji: String
    let name: String
    let colorHex: String
    let isEnabled: Bool
    let isCurrent: Bool
    let action: () -> Void

    public init(
        emoji: String,
        name: String,
        colorHex: String,
        isEnabled: Bool = true,
        isCurrent: Bool = false,
        action: @escaping () -> Void
    ) {
        self.emoji = emoji
        self.name = name
        self.colorHex = colorHex
        self.isEnabled = isEnabled
        self.isCurrent = isCurrent
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 24))
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(SpendlyColor.tint(colorHex)))
                    .overlay {
                        // "current" ring when editing an entry: shows which category it has now.
                        Circle()
                            .strokeBorder(SpendlyColor.signature, lineWidth: isCurrent ? 2 : 0)
                            .padding(-4)
                    }
                Text(name)
                    .font(SpendlyFont.micro)
                    .foregroundStyle(SpendlyColor.ink)
                    .lineLimit(1)
            }
            .frame(width: 68)
            .contentShape(Rectangle())
        }
        .buttonStyle(SquishStyle())
        .opacity(isEnabled ? 1 : 0.35)
        .animation(.spendly, value: isEnabled)
        .disabled(!isEnabled)
        .accessibilityLabel("save as \(name)")
    }
}

/// Chips squish when pressed and spring back.
public struct SquishStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: configuration.isPressed)
    }
}
