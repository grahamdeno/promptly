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
    /// The novelty set (built 2026-11-12; held from the App Store with the holiday themes until released).
    case disco, soap, planet, basketball, donut, waterBalloon, eyeball, fishbowl, moodRing, lavaLamp
    /// Soccer: the classic black and white ball (held; for the big tournaments).
    case soccer
    /// Sports and arcade set (held): hockey puck, tennis, golf, baseball, bowling, 8-bit.
    case hockey, tennis, golf, baseball, bowling, pixel
    /// Food, nature, fun objects, more holidays and calm (held).
    case gumball, cherry, orange, macaron, cakePop, earth, sun, dandelion, atom, geode, yarn, arcadeButton, clock, marble, duck, easterEgg, valentine, fireworks, beachBall, zen

    var isPro: Bool { !(self == .bubblegum || self == .coral) }

    /// The holiday themes are held back from the App Store until the owner decides how to release them. TestFlight
    /// and Xcode builds show them so they can be tried. Set `seasonsInStore` to true to release them everywhere.
    static let seasonsInStore = false
    static var seasonsReady: Bool {
        if seasonsInStore { return true }
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }
    var isSeasonal: Bool { [.snowball, .ornament, .pumpkin, .easterEgg, .valentine, .fireworks, .beachBall].contains(self) }
    static let novelty: [GumPalette] = [.disco, .soap, .planet, .basketball, .donut, .waterBalloon, .eyeball, .fishbowl, .moodRing, .lavaLamp, .soccer, .hockey, .tennis, .golf, .baseball, .bowling, .pixel, .gumball, .cherry, .orange, .macaron, .cakePop, .earth, .sun, .dandelion, .atom, .geode, .yarn, .arcadeButton, .clock, .marble, .duck, .zen]
    /// Held back from the App Store (shown in TestFlight) until the owner decides how to release it.
    var isHeld: Bool { isSeasonal || Self.novelty.contains(self) }
    /// The colors offered in Settings.
    static var available: [GumPalette] { allCases.filter { seasonsReady || !$0.isHeld } }
    /// Groups for the theme gallery.
    var group: ThemeGroup {
        switch self {
        case .bubblegum, .coral: .classic
        case .unicorn, .fortune, .moon, .grenade, .disco, .soap, .lavaLamp, .moodRing, .eyeball, .fishbowl, .donut, .waterBalloon, .planet: .favorites
        case .soccer, .hockey, .tennis, .golf, .baseball, .bowling, .basketball, .pixel: .sports
        case .gumball, .cherry, .orange, .macaron, .cakePop: .food
        case .earth, .sun, .dandelion, .atom, .geode: .nature
        case .yarn, .arcadeButton, .clock, .marble, .duck, .zen: .objects
        case .snowball, .ornament, .pumpkin, .easterEgg, .valentine, .fireworks, .beachBall: .seasons
        }
    }

    /// Themes with their own app icon (AppIcon-<Name>).
    var hasIcon: Bool { !(self == .bubblegum) && !Self.novelty.contains(self) }
    /// The theme's own pop sound (Sounds/<name>.wav), used by "Match the theme".
    var popFile: String {
        switch self {
        case .bubblegum, .coral: "pop"
        case .unicorn, .moodRing: "unicorn_pop"
        case .fortune: "fortune_pop"
        case .moon: "moon_pop"
        case .grenade: "grenade_pop"
        case .snowball: "snow_pop"
        case .ornament: "ornament_pop"
        case .pumpkin: "pumpkin_pop"
        case .disco: "disco_pop"
        case .soap: "soap_pop"
        case .planet: "planet_pop"
        case .basketball: "basketball_pop"
        case .donut: "donut_pop"
        case .waterBalloon: "water_pop"
        case .eyeball: "eyeball_pop"
        case .fishbowl: "fishbowl_pop"
        case .lavaLamp: "lava_pop"
        case .soccer: "soccer_pop"
        case .hockey: "hockey_pop"
        case .tennis: "tennis_pop"
        case .golf: "golf_pop"
        case .baseball: "baseball_pop"
        case .bowling: "bowling_pop"
        case .pixel: "pixel_pop"
        case .gumball: "gumball_pop"
        case .cherry: "juicy_pop"
        case .orange: "juicy_pop"
        case .macaron: "snow_pop"
        case .cakePop: "donut_pop"
        case .earth: "planet_pop"
        case .sun: "fortune_pop"
        case .dandelion: "puff_pop"
        case .atom: "moon_pop"
        case .geode: "crack_pop"
        case .yarn: "donut_pop"
        case .arcadeButton: "click_pop"
        case .clock: "bell_pop"
        case .marble: "ornament_pop"
        case .duck: "squeak_pop"
        case .easterEgg: "pop"
        case .valentine: "unicorn_pop"
        case .fireworks: "firework_pop"
        case .beachBall: "donut_pop"
        case .zen: "zen_pop"
        }
    }

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
        case .disco: "Disco"
        case .soap: "Soap bubble"
        case .planet: "Planet"
        case .basketball: "Basketball"
        case .donut: "Donut"
        case .waterBalloon: "Water balloon"
        case .eyeball: "Eyeball"
        case .fishbowl: "Fishbowl"
        case .moodRing: "Mood ring"
        case .lavaLamp: "Lava lamp"
        case .soccer: "Soccer"
        case .hockey: "Hockey puck"
        case .tennis: "Tennis ball"
        case .golf: "Golf ball"
        case .baseball: "Baseball"
        case .bowling: "Bowling ball"
        case .pixel: "8-bit"
        case .gumball: "Gumball machine"
        case .cherry: "Cherry"
        case .orange: "Orange"
        case .macaron: "Macaron"
        case .cakePop: "Cake pop"
        case .earth: "Earth"
        case .sun: "Sun"
        case .dandelion: "Dandelion"
        case .atom: "Atom"
        case .geode: "Geode"
        case .yarn: "Ball of yarn"
        case .arcadeButton: "Big red button"
        case .clock: "Clock"
        case .marble: "Marble"
        case .duck: "Rubber duck"
        case .easterEgg: "Easter egg"
        case .valentine: "Valentine"
        case .fireworks: "Fireworks"
        case .beachBall: "Beach ball"
        case .zen: "Zen stone"
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
        case .disco: Self.rgb(0xB8BEC8)
        case .soap: Self.rgb(0xE9E4F7)
        case .planet: Self.rgb(0xE0B07A)
        case .basketball: Self.rgb(0xE8742A)
        case .donut: Self.rgb(0xD9A066)
        case .waterBalloon: Self.rgb(0x3BA4E8)
        case .eyeball: Self.rgb(0xF4F4F2)
        case .fishbowl: Self.rgb(0xCDEBF7)
        case .moodRing: Self.rgb(0x2E6FD8)
        case .lavaLamp: Self.rgb(0xC2321F)
        case .soccer: Self.rgb(0xF2F2F0)
        case .hockey: Self.rgb(0x1C1C1E)
        case .tennis: Self.rgb(0xCCE03A)
        case .golf: Self.rgb(0xF2F2F2)
        case .baseball: Self.rgb(0xF5F1E6)
        case .bowling: Self.rgb(0x3A1C71)
        case .pixel: Self.rgb(0xFF5A5A)
        case .gumball: Self.rgb(0xCFE8F7)
        case .cherry: Self.rgb(0xC8102E)
        case .orange: Self.rgb(0xF28C1E)
        case .macaron: Self.rgb(0xF7B7CF)
        case .cakePop: Self.rgb(0xF48FB1)
        case .earth: Self.rgb(0x2E7BD8)
        case .sun: Self.rgb(0xFFB020)
        case .dandelion: Self.rgb(0xF2F2EC)
        case .atom: Self.rgb(0x1B2350)
        case .geode: Self.rgb(0x8E8A84)
        case .yarn: Self.rgb(0xD8456B)
        case .arcadeButton: Self.rgb(0xE02020)
        case .clock: Self.rgb(0xF7F5F0)
        case .marble: Self.rgb(0xBFE0F5)
        case .duck: Self.rgb(0xFFD43B)
        case .easterEgg: Self.rgb(0xC9E7FF)
        case .valentine: Self.rgb(0xE8336B)
        case .fireworks: Self.rgb(0x141B3D)
        case .beachBall: Self.rgb(0xF5F5F5)
        case .zen: Self.rgb(0x9A9A94)
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
        case .disco: Self.rgb(0xFFFFFF)
        case .soap: Self.rgb(0xFFFFFF)
        case .planet: Self.rgb(0xFBE3BE)
        case .basketball: Self.rgb(0xFFB27A)
        case .donut: Self.rgb(0xF5D3A3)
        case .waterBalloon: Self.rgb(0xA8DBFA)
        case .eyeball: Self.rgb(0xFFFFFF)
        case .fishbowl: Self.rgb(0xFFFFFF)
        case .moodRing: Self.rgb(0x9CC2FF)
        case .lavaLamp: Self.rgb(0xFF8A4C)
        case .soccer: Self.rgb(0xFFFFFF)
        case .hockey: Self.rgb(0x55555A)
        case .tennis: Self.rgb(0xF4FF9E)
        case .golf: Self.rgb(0xFFFFFF)
        case .baseball: Self.rgb(0xFFFFFF)
        case .bowling: Self.rgb(0x7A4FC9)
        case .pixel: Self.rgb(0xFF9A9A)
        case .gumball: Self.rgb(0xFFFFFF)
        case .cherry: Self.rgb(0xFF7A8A)
        case .orange: Self.rgb(0xFFC27A)
        case .macaron: Self.rgb(0xFFE3EE)
        case .cakePop: Self.rgb(0xFFD3E2)
        case .earth: Self.rgb(0x8CC4FF)
        case .sun: Self.rgb(0xFFF0A0)
        case .dandelion: Self.rgb(0xFFFFFF)
        case .atom: Self.rgb(0x3E4A9A)
        case .geode: Self.rgb(0xC9C4BC)
        case .yarn: Self.rgb(0xFF9AB4)
        case .arcadeButton: Self.rgb(0xFF7A7A)
        case .clock: Self.rgb(0xFFFFFF)
        case .marble: Self.rgb(0xFFFFFF)
        case .duck: Self.rgb(0xFFF3A8)
        case .easterEgg: Self.rgb(0xF4FAFF)
        case .valentine: Self.rgb(0xFF9AB8)
        case .fireworks: Self.rgb(0x3A4580)
        case .beachBall: Self.rgb(0xFFFFFF)
        case .zen: Self.rgb(0xD0D0CA)
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
        case .disco: Self.rgb(0x4A505C)
        case .soap: Self.rgb(0xA9B4D6)
        case .planet: Self.rgb(0x8A5A2B)
        case .basketball: Self.rgb(0x8A3A0E)
        case .donut: Self.rgb(0x8A5A2A)
        case .waterBalloon: Self.rgb(0x0E5A9A)
        case .eyeball: Self.rgb(0xB9B9B4)
        case .fishbowl: Self.rgb(0x6FA9C8)
        case .moodRing: Self.rgb(0x0E2F6B)
        case .lavaLamp: Self.rgb(0x4A0F08)
        case .soccer: Self.rgb(0x9C9C98)
        case .hockey: Self.rgb(0x050506)
        case .tennis: Self.rgb(0x6E7E0C)
        case .golf: Self.rgb(0xA4A4A4)
        case .baseball: Self.rgb(0xA8A291)
        case .bowling: Self.rgb(0x140630)
        case .pixel: Self.rgb(0x8A1A1A)
        case .gumball: Self.rgb(0x7FB0CF)
        case .cherry: Self.rgb(0x5C0412)
        case .orange: Self.rgb(0x8A4508)
        case .macaron: Self.rgb(0xB86E8E)
        case .cakePop: Self.rgb(0xA8476B)
        case .earth: Self.rgb(0x0E3570)
        case .sun: Self.rgb(0xD8540E)
        case .dandelion: Self.rgb(0xA8AE9A)
        case .atom: Self.rgb(0x070A1F)
        case .geode: Self.rgb(0x3E3B37)
        case .yarn: Self.rgb(0x7A1A35)
        case .arcadeButton: Self.rgb(0x7A0A0A)
        case .clock: Self.rgb(0xA8A49A)
        case .marble: Self.rgb(0x5E9CC8)
        case .duck: Self.rgb(0xC89A0A)
        case .easterEgg: Self.rgb(0x7EAFD8)
        case .valentine: Self.rgb(0x8A0E36)
        case .fireworks: Self.rgb(0x05081A)
        case .beachBall: Self.rgb(0xA0A0A0)
        case .zen: Self.rgb(0x55554F)
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
        case .soap: Self.rgb(0x8B7FD6)
        case .eyeball: Self.rgb(0x2E7DD8)
        case .fishbowl: Self.rgb(0x1E9BD8)
        case .disco: Self.rgb(0x8A6FE0)
        case .soccer: Self.rgb(0x1E8E3E)
        case .hockey: Self.rgb(0x2B7BB9)
        case .tennis: Self.rgb(0x6E8A0A)
        case .golf: Self.rgb(0x2E8B57)
        case .baseball: Self.rgb(0xC62828)
        case .bowling: Self.rgb(0x7A4FC9)
        case .pixel: Self.rgb(0xFF5A5A)
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
        case .disco: Self.rgb(0x5B3FB8)
        case .soap: Self.rgb(0x5B4FA8)
        case .planet: Self.rgb(0x8A4E1A)
        case .basketball: Self.rgb(0xA8480F)
        case .donut: Self.rgb(0xB0326A)
        case .waterBalloon: Self.rgb(0x0B5E95)
        case .eyeball: Self.rgb(0x1F5FA8)
        case .fishbowl: Self.rgb(0x0B6E99)
        case .moodRing: Self.rgb(0x1E4FA8)
        case .lavaLamp: Self.rgb(0xA0280F)
        case .soccer: Self.rgb(0x15703A)
        case .hockey: Self.rgb(0x1D5C8F)
        case .tennis: Self.rgb(0x556B05)
        case .golf: Self.rgb(0x1F6B40)
        case .baseball: Self.rgb(0xA11F1F)
        case .bowling: Self.rgb(0x5B33B0)
        case .pixel: Self.rgb(0xB02222)
        case .gumball: Self.rgb(0x1F6E9C)
        case .cherry: Self.rgb(0xA30D25)
        case .orange: Self.rgb(0xA4500F)
        case .macaron: Self.rgb(0xA8466F)
        case .cakePop: Self.rgb(0xA8336A)
        case .earth: Self.rgb(0x1E5FA8)
        case .sun: Self.rgb(0xA85A0A)
        case .dandelion: Self.rgb(0x5E7A3A)
        case .atom: Self.rgb(0x3646B0)
        case .geode: Self.rgb(0x6D3FB0)
        case .yarn: Self.rgb(0xA82D50)
        case .arcadeButton: Self.rgb(0xB01818)
        case .clock: Self.rgb(0x5A564E)
        case .marble: Self.rgb(0x1F6E9C)
        case .duck: Self.rgb(0x9A7205)
        case .easterEgg: Self.rgb(0x3E6FA8)
        case .valentine: Self.rgb(0xB01E52)
        case .fireworks: Self.rgb(0x3646B0)
        case .beachBall: Self.rgb(0xC0392B)
        case .zen: Self.rgb(0x55554F)
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

/// The theme gallery's sections.
enum ThemeGroup: String, CaseIterable, Sendable {
    case classic, favorites, sports, food, nature, objects, seasons
    var title: String {
        switch self {
        case .classic: "Classic"
        case .favorites: "Pro favorites"
        case .sports: "Sports and games"
        case .food: "Treats"
        case .nature: "Nature and space"
        case .objects: "Fun objects"
        case .seasons: "Seasons and holidays"
        }
    }
}
