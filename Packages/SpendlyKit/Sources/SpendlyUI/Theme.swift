import SwiftUI

/// Design tokens — "night + lime".
///
/// Dark by design (the app sets `UIUserInterfaceStyle = Dark`). One signature color, lime, for the
/// today pill, selection and focus; one warning color for over-budget and delete. Everything else
/// is graphite neutrals plus a muted tint per category.
public enum SpendlyColor {
    public static let canvas = Color(hex: 0x131417)
    public static let surface = Color(hex: 0x1D1E23)
    /// Keypad keys and other controls raised on `surface`.
    public static let raised = Color(hex: 0x26272D)
    public static let ink = Color(hex: 0xF1F0EB)
    public static let muted = Color(hex: 0x8B8C94)
    public static let hairline = Color(hex: 0x2C2D33)
    public static let signature = Color(hex: 0xCDEB6B)
    /// Text/icons drawn on top of `signature`.
    public static let onSignature = Color(hex: 0x131417)
    public static let warning = Color(hex: 0xFF6B5E)
    /// Income mode washes the canvas with a hint of green.
    public static let incomeWash = Color(hex: 0x131A15)

    /// Category tint from its stored pastel "#RRGGBB", laid over the dark surface.
    /// `.soft` for emoji circles, `.strong` for chart segments that must read at a glance.
    public static func tint(_ hex: String, _ strength: TintStrength = .soft) -> Color {
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x9AA0A6
        return Color(hex: value).opacity(strength.rawValue)
    }

    public enum TintStrength: Double {
        case soft = 0.18
        case strong = 0.85
    }
}

/// SF Pro throughout. Large numbers are light-weight with tight tracking — the quiet, expensive
/// look of Apple's own Wallet and Stocks — while labels stay small and medium-weight.
public enum SpendlyFont {
    // Display numerals keep a fixed size: they are already large and the layout is built on them.
    public static let amount = number(76, .light)
    public static let total = number(54, .light)
    public static let keypad = number(30, .light)

    // Everything else follows the user's text size (Dynamic Type).
    public static let title = Font.system(.title2, weight: .semibold)
    public static let pill = Font.system(.subheadline, weight: .semibold)
    public static let body = Font.system(.body)
    public static let label = Font.system(.subheadline, weight: .medium)
    public static let caption = Font.system(.footnote)
    public static let micro = Font.system(.caption, weight: .medium)

    /// Fixed-size tabular figures, for display numerals only.
    public static func number(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }

    /// Tabular figures that scale with Dynamic Type, for amounts in rows, pills and lists.
    public static func number(_ style: Font.TextStyle, _ weight: Font.Weight) -> Font {
        .system(style, weight: weight).monospacedDigit()
    }

    /// Display-size numbers get tighter tracking, like SF Pro Display in Apple's apps.
    public static func tracking(for size: CGFloat) -> CGFloat {
        size >= 40 ? -size * 0.035 : 0
    }
}

public enum SpendlyRadius {
    public static let surface: CGFloat = 28
    public static let key: CGFloat = 18
}

/// Full pill. `.quiet` is an option (raised fill), `.selected` the chosen one (ink fill),
/// `.signature` the one lime element on a screen.
public struct PillButtonStyle: ButtonStyle {
    public enum Variant { case quiet, selected, signature }

    public var variant: Variant

    public init(_ variant: Variant = .quiet) {
        self.variant = variant
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SpendlyFont.pill)
            // Wraps at the largest text sizes rather than cutting the label off.
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .frame(minHeight: 44)
            .foregroundStyle(foreground)
            .background(Capsule().fill(background))
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spendly, value: configuration.isPressed)
    }

    private var foreground: Color {
        switch variant {
        case .quiet: SpendlyColor.ink
        case .selected: SpendlyColor.canvas
        case .signature: SpendlyColor.onSignature
        }
    }

    private var background: Color {
        switch variant {
        case .quiet: SpendlyColor.raised
        case .selected: SpendlyColor.ink
        case .signature: SpendlyColor.signature
        }
    }
}

public extension Animation {
    /// The one spring used for presses and appearances, so motion feels consistent.
    static let spendly = Animation.spring(response: 0.32, dampingFraction: 0.78)
}

public extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
