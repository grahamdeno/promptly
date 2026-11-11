import SwiftUI

/// The bubble's color choices. Stored in the shared App Group so the widgets follow the app.
enum GumPalette: String, CaseIterable, Sendable {
    /// Classic bubblegum pink.
    case bubblegum
    /// Bright hot pink.
    case hotPink
    /// The original coral.
    case coral

    var label: String {
        switch self {
        case .bubblegum: "Bubblegum"
        case .hotPink: "Hot pink"
        case .coral: "Coral"
        }
    }

    private static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    var base: Color {
        switch self {
        case .bubblegum: Self.rgb(0xFF7FB0)
        case .hotPink: Self.rgb(0xFF2E88)
        case .coral: Self.rgb(0xE8553A)
        }
    }

    var light: Color {
        switch self {
        case .bubblegum: Self.rgb(0xFFD3E5)
        case .hotPink: Self.rgb(0xFFB0D4)
        case .coral: Self.rgb(0xFFB8A0)
        }
    }

    var dark: Color {
        switch self {
        case .bubblegum: Self.rgb(0xE04F8C)
        case .hotPink: Self.rgb(0xC41168)
        case .coral: Self.rgb(0xC8361C)
        }
    }

    static let key = "gumColor"

    static var current: GumPalette {
        GumPalette(rawValue: UserDefaults(suiteName: "group.com.grahamdeno.promptly")?.string(forKey: key) ?? "") ?? .bubblegum
    }
}

/// The bubble's colors in the chosen palette, shared by the app and the widget extension.
/// (`coral` is the main bubble color, whatever the palette.)
enum GumColors {
    static var coral: Color { GumPalette.current.base }
    static var light: Color { GumPalette.current.light }
    static var dark: Color { GumPalette.current.dark }
}

/// A still gum ball with its gloss, for small places (Lock Screen card, Dynamic Island).
struct GumBall: View {
    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width
            ZStack {
                Ellipse()
                    .fill(RadialGradient(colors: [GumColors.light, GumColors.coral, GumColors.dark],
                                         center: UnitPoint(x: 0.38, y: 0.26), startRadius: 0, endRadius: s * 0.8))
                Ellipse()
                    .fill(.white.opacity(0.5))
                    .frame(width: s * 0.32, height: s * 0.18)
                    .rotationEffect(.degrees(-24))
                    .position(x: s * 0.34, y: s * 0.22)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
