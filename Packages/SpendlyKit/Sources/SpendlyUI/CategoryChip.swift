import SwiftUI

/// Emoji on its own pastel circle with a small label. Tapping it saves (or, when editing, commits).
public struct CategoryChip: View {
    let emoji: String
    let name: String
    let colorHex: String
    let isEnabled: Bool
    let isCurrent: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .title2) private var circle: CGFloat = 54
    @ScaledMetric(relativeTo: .title2) private var width: CGFloat = 68

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
                    .font(.title2)
                    .opacity(isEnabled ? 1 : 0.45)
                    .frame(width: circle, height: circle)
                    .background(Circle().fill(SpendlyColor.tint(colorHex)).opacity(isEnabled ? 1 : 0.5))
                    .overlay {
                        // "current" ring when editing an entry: shows which category it has now.
                        Circle()
                            .strokeBorder(SpendlyColor.signature, lineWidth: isCurrent ? 2 : 0)
                            .padding(-4)
                    }
                // Dimmed to the muted gray, not by opacity, so the name stays readable.
                Text(name)
                    .font(SpendlyFont.micro)
                    .foregroundStyle(isEnabled ? SpendlyColor.ink : SpendlyColor.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
            }
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(SquishStyle())
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
