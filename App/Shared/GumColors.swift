import SwiftUI

/// The bubble's color choices. Stored in the shared App Group so the widgets follow the app.
enum GumPalette: String, CaseIterable, Sendable {
    /// Classic bubblegum pink.
    case bubblegum
    /// The original coral.
    case coral
    /// Pro: a pastel rainbow bubble that bursts into confetti.
    case unicorn

    var isPro: Bool { self == .unicorn }

    /// Unicorn mode's rainbow, strong enough to read on white: tangerine, lemon, mint, sky, violet.
    /// Used for the sheen and rim on the pink bubble, and for the confetti.
    static let rainbow: [Color] = [rgb(0xFF8A3D), rgb(0xFFD43B), rgb(0x3DDC97), rgb(0x3DA5FF), rgb(0x9B5CFF)]

    var label: String {
        switch self {
        case .bubblegum: "Bubblegum"
        case .coral: "Coral"
        case .unicorn: "Unicorn"
        }
    }

    static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    var base: Color {
        switch self {
        case .bubblegum: Self.rgb(0xFF7FB0)
        case .coral: Self.rgb(0xE8553A)
        case .unicorn: Self.rgb(0xFF7FB0)
        }
    }

    var light: Color {
        switch self {
        case .bubblegum: Self.rgb(0xFFD3E5)
        case .coral: Self.rgb(0xFFB8A0)
        case .unicorn: Self.rgb(0xFFD3E5)
        }
    }

    var dark: Color {
        switch self {
        case .bubblegum: Self.rgb(0xE04F8C)
        case .coral: Self.rgb(0xC8361C)
        case .unicorn: Self.rgb(0xD0508A)
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
                if GumPalette.current == .unicorn {
                    UnicornSheen(phase: 0.5).clipShape(Ellipse())
                    UnicornRim(lineWidth: max(1.5, s * 0.04))
                }
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

/// Unicorn mode's holographic band: a soft diagonal rainbow that slides across the pink gum. `phase` 0...1 moves it
/// from the upper left to the lower right.
struct UnicornSheen: View {
    var phase: Double

    var body: some View {
        let c = GumPalette.rainbow
        let mid = -0.35 + phase * 1.7
        func stop(_ color: Color, _ offset: Double, _ opacity: Double) -> Gradient.Stop {
            .init(color: color.opacity(opacity), location: min(1, max(0, mid + offset)))
        }
        return LinearGradient(stops: [
            stop(c[1], -0.24, 0), stop(c[0], -0.16, 0.42), stop(c[1], -0.08, 0.5), stop(c[2], 0, 0.46),
            stop(c[3], 0.08, 0.5), stop(c[4], 0.16, 0.42), stop(c[4], 0.24, 0),
        ], startPoint: UnitPoint(x: 0, y: 0.15), endPoint: UnitPoint(x: 1, y: 0.85))
    }
}

/// A thin rainbow edge so the unicorn bubble keeps a crisp outline against white.
struct UnicornRim: View {
    var lineWidth: CGFloat

    var body: some View {
        Ellipse()
            .strokeBorder(AngularGradient(colors: GumPalette.rainbow + [GumPalette.rainbow[0]], center: .center,
                                          angle: .degrees(-60)), lineWidth: lineWidth)
            .opacity(0.9)
    }
}
