import SwiftUI

/// The bubble's color choices. Stored in the shared App Group so the widgets follow the app.
enum GumPalette: String, CaseIterable, Sendable {
    /// Classic bubblegum pink.
    case bubblegum
    /// The original coral.
    case coral
    /// Pro: a pink bubble with a rainbow sheen that bursts into confetti.
    case unicorn
    /// Pro: black glass with a violet glow; pops into mist and star sparks; shows a meeting fortune.
    case fortune
    /// Pro: a silver cratered moon; pops into space dust, a UFO and aliens.
    case moon
    /// Pro: an olive drab grenade; "pull the pin" pops it into a puff of smoke and confetti.
    case grenade
    /// Pro, seasonal (saved for later): a frosted snowball; pops into powder and snowflakes.
    case snowball
    /// Pro, seasonal (saved for later): a red holiday ornament; pops into gold glitter.
    case ornament
    /// Pro, seasonal (saved for later): a ribbed pumpkin; pops into cinnamon and leaves.
    case pumpkin

    var isPro: Bool { !(self == .bubblegum || self == .coral) }

    /// The holiday themes are built but held back until the owner turns them on for their season.
    static let seasonsReady = false
    var isSeasonal: Bool { self == .snowball || self == .ornament || self == .pumpkin }
    /// The colors offered in Settings.
    static var available: [GumPalette] { allCases.filter { seasonsReady || !$0.isSeasonal } }

    /// Fortune's violets.
    static let violet = rgb(0x8B5CF6)
    static let violetDeep = rgb(0x6D3FD6)

    /// Unicorn mode's rainbow, strong enough to read on white: tangerine, lemon, mint, sky, violet.
    /// Used for the sheen and rim on the pink bubble, and for the confetti.
    static let rainbow: [Color] = [rgb(0xFF8A3D), rgb(0xFFD43B), rgb(0x3DDC97), rgb(0x3DA5FF), rgb(0x9B5CFF)]

    var label: String {
        switch self {
        case .bubblegum: "Bubblegum"
        case .coral: "Coral"
        case .unicorn: "Unicorn"
        case .fortune: "Fortune"
        case .moon: "Moon"
        case .grenade: "Grenade"
        case .snowball: "Snowball"
        case .ornament: "Ornament"
        case .pumpkin: "Pumpkin spice"
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
        case .fortune: Self.rgb(0x16161C)
        case .moon: Self.rgb(0xD3D7E0)
        case .grenade: Self.rgb(0x55622F)
        case .snowball: Self.rgb(0xD9EDFA)
        case .ornament: Self.rgb(0xC8102E)
        case .pumpkin: Self.rgb(0xE8731A)
        }
    }

    var light: Color {
        switch self {
        case .bubblegum: Self.rgb(0xFFD3E5)
        case .coral: Self.rgb(0xFFB8A0)
        case .unicorn: Self.rgb(0xFFD3E5)
        case .fortune: Self.rgb(0x5A5866)
        case .moon: Self.rgb(0xF7F8FB)
        case .grenade: Self.rgb(0x9AA866)
        case .snowball: Self.rgb(0xFFFFFF)
        case .ornament: Self.rgb(0xFF8A8A)
        case .pumpkin: Self.rgb(0xFFC27A)
        }
    }

    var dark: Color {
        switch self {
        case .bubblegum: Self.rgb(0xE04F8C)
        case .coral: Self.rgb(0xC8361C)
        case .unicorn: Self.rgb(0xD0508A)
        case .fortune: Self.rgb(0x030305)
        case .moon: Self.rgb(0x7E8494)
        case .grenade: Self.rgb(0x1E260E)
        case .snowball: Self.rgb(0x86B6DA)
        case .ornament: Self.rgb(0x5C0412)
        case .pumpkin: Self.rgb(0x7A3108)
        }
    }

    /// The color for buttons, tints and small marks: the bubble's own color, or violet for Fortune (black is the
    /// bubble, not an accent).
    var accent: Color {
        switch self {
        case .fortune: Self.violet
        case .moon: Self.rgb(0x6366F1)
        case .grenade: Self.rgb(0x6B7A35)
        case .snowball: Self.rgb(0x38A3E0)
        default: base
        }
    }
    var accentDark: Color {
        switch self {
        case .fortune: Self.violetDeep
        case .moon: Self.rgb(0x4F46E5)
        case .grenade: Self.rgb(0x4A5A1E)
        case .snowball: Self.rgb(0x0E74B8)
        default: dark
        }
    }
    var accentLight: Color {
        switch self {
        case .fortune: Self.rgb(0xDDD0FB)
        case .moon: Self.rgb(0xE0E7FF)
        case .grenade: Self.rgb(0xDCE3C0)
        default: light
        }
    }
    /// Small words on white in this theme (links, labels): dark enough to read.
    var accentText: Color {
        switch self {
        case .fortune: Self.rgb(0x5B33C2)
        case .moon: Self.rgb(0x4338CA)
        case .grenade: Self.rgb(0x4A5A1E)
        case .snowball: Self.rgb(0x0B5E95)
        case .ornament: Self.rgb(0xA30D25)
        case .pumpkin: Self.rgb(0xA4440F)
        default: Self.rgb(0xB02E68)
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
    static var accent: Color { GumPalette.current.accent }
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
                if GumPalette.current == .fortune {
                    FortuneRim(lineWidth: max(1.5, s * 0.05))
                }
                ThemeMarks(palette: GumPalette.current, w: s, h: s)
                ThemeTopper(palette: GumPalette.current, w: s)
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
    /// Where the colors start around the edge; the bubble turns this slowly so the rim seems to spin.
    var angle: Double = -60

    var body: some View {
        Ellipse()
            .strokeBorder(AngularGradient(colors: GumPalette.rainbow + [GumPalette.rainbow[0]], center: .center,
                                          angle: .degrees(angle)), lineWidth: lineWidth)
            .opacity(0.9)
    }
}

/// Fortune's edge: a violet glow brightest on one side; `angle` turns it so the light circles the ball.
struct FortuneRim: View {
    var lineWidth: CGFloat
    var angle: Double = 0

    var body: some View {
        Ellipse()
            .strokeBorder(AngularGradient(colors: [GumPalette.violet, GumPalette.rgb(0xC4B5FD), GumPalette.violetDeep.opacity(0.4),
                                                   GumPalette.violetDeep.opacity(0.15), GumPalette.violet],
                                          center: .center, angle: .degrees(angle)), lineWidth: lineWidth)
    }
}

/// A four-point star, for Fortune's drifting light and its sparks.
struct FourPointStar: Shape {
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY), w = r.width / 2, h = r.height / 2, k: CGFloat = 0.22
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - h))
        p.addLine(to: CGPoint(x: c.x + w * k, y: c.y - h * k))
        p.addLine(to: CGPoint(x: c.x + w, y: c.y))
        p.addLine(to: CGPoint(x: c.x + w * k, y: c.y + h * k))
        p.addLine(to: CGPoint(x: c.x, y: c.y + h))
        p.addLine(to: CGPoint(x: c.x - w * k, y: c.y + h * k))
        p.addLine(to: CGPoint(x: c.x - w, y: c.y))
        p.addLine(to: CGPoint(x: c.x - w * k, y: c.y - h * k))
        p.closeSubpath()
        return p
    }
}
