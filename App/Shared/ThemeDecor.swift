import SwiftUI

/// What makes each Pro theme more than a color: marks on the ball (craters, ribs, a glitter band), things on top of
/// it (a grenade's fuze and pin, an ornament's cap, a pumpkin's stem), and what it pops into. Used by the bubble, the
/// buds, the small ball on the Lock Screen and in widgets.

/// Marks drawn on the ball, clipped to it. `w`, `h` are the ball's size.
struct ThemeMarks: View {
    let palette: GumPalette
    let w: CGFloat
    let h: CGFloat
    /// How close the meeting is, 0 to 1 (the bubble's thinness); Mood ring turns from blue to green to red with it.
    var level: Double = 0.5
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch palette {
            case .moon:
                // Soft craters, darker on their lower right, with a lit rim on the upper left.
                ForEach(0..<Self.craters.count, id: \.self) { i in
                    let c = Self.craters[i]
                    ZStack {
                        Ellipse().fill(palette.dark.opacity(0.22))
                        Ellipse().stroke(Color.white.opacity(0.35), lineWidth: max(1, w * c.2 * 0.08))
                            .offset(x: -w * c.2 * 0.06, y: -w * c.2 * 0.06)
                    }
                    .frame(width: w * c.2, height: w * c.2 * 0.8)
                    .blur(radius: max(1, w * 0.004))
                    .position(x: w * c.0, y: h * c.1)
                }
            case .snowball:
                // A frosty sparkle of flakes on the surface.
                ForEach(0..<Self.flakes.count, id: \.self) { i in
                    let f = Self.flakes[i]
                    Image(systemName: "snowflake")
                        .font(.system(size: max(8, w * f.2)))
                        .foregroundStyle(.white.opacity(0.9))
                        .position(x: w * f.0, y: h * f.1)
                }
            case .ornament:
                // A band of gold glitter across the ball.
                Rectangle()
                    .fill(LinearGradient(colors: [GumPalette.rgb(0xB8860B), GumPalette.rgb(0xFFE08A), GumPalette.rgb(0xD4A017)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(GlitterDots().opacity(0.8))
                    .frame(width: w, height: max(6, h * 0.075))
                    .position(x: w / 2, y: h * 0.3)
            case .pumpkin:
                // Ribs running from the stem down.
                ForEach(-2...2, id: \.self) { k in
                    Ellipse()
                        .stroke(palette.dark.opacity(0.28), lineWidth: max(2, w * 0.02))
                        .frame(width: w * (0.18 + 0.2 * CGFloat(abs(k))), height: h * 1.02)
                        .blur(radius: max(1, w * 0.01))
                        .position(x: w / 2, y: h / 2)
                }
            case .grenade:
                // The seam where the body halves meet.
                Ellipse()
                    .stroke(palette.dark.opacity(0.35), lineWidth: max(1.5, w * 0.008))
                    .frame(width: w * 0.98, height: h * 0.16)
                    .position(x: w / 2, y: h * 0.22)
            case .disco:
                // Mirror tiles, some catching the light.
                Canvas { ctx, size in
                    let n = 14
                    let tile = size.width / CGFloat(n)
                    var rng = SeededRandom(seed: 11)
                    for row in 0..<n { for col in 0..<n {
                        let r = CGRect(x: CGFloat(col) * tile + 1, y: CGFloat(row) * tile + 1, width: tile - 2, height: tile - 2)
                        let v = rng.next()
                        ctx.fill(Path(r), with: .color(v > 0.85 ? .white.opacity(0.9) : (v < 0.25 ? .black.opacity(0.25) : .white.opacity(0.12))))
                    } }
                }
            case .soap:
                // A thin, swirling rainbow film.
                Ellipse()
                    .fill(AngularGradient(colors: [GumPalette.rgb(0xFFB3D9), GumPalette.rgb(0xB8E0FF), GumPalette.rgb(0xC8F5D8),
                                                   GumPalette.rgb(0xFFF1A8), GumPalette.rgb(0xD7B8FF), GumPalette.rgb(0xFFB3D9)], center: .center))
                    .opacity(0.45)
                    .blur(radius: max(4, w * 0.03))
                Ellipse().stroke(GumPalette.rgb(0xB9AEE6).opacity(0.8), lineWidth: max(1.5, w * 0.006))
            case .planet:
                // Cloud bands.
                VStack(spacing: h * 0.06) {
                    ForEach(0..<6, id: \.self) { i in
                        Capsule().fill((i % 2 == 0 ? palette.dark : palette.light).opacity(0.35))
                            .frame(width: w * 1.1, height: h * 0.07)
                    }
                }
                .rotationEffect(.degrees(-12))
                .blur(radius: max(1, w * 0.008))
            case .basketball:
                // Seams.
                ZStack {
                    Rectangle().fill(Color.black.opacity(0.75)).frame(width: max(2, w * 0.012), height: h)
                    Rectangle().fill(Color.black.opacity(0.75)).frame(width: w, height: max(2, w * 0.012))
                    Ellipse().stroke(Color.black.opacity(0.75), lineWidth: max(2, w * 0.012)).frame(width: w * 0.55, height: h * 1.1).offset(x: -w * 0.45)
                    Ellipse().stroke(Color.black.opacity(0.75), lineWidth: max(2, w * 0.012)).frame(width: w * 0.55, height: h * 1.1).offset(x: w * 0.45)
                }
            case .donut:
                // Pink glaze with sprinkles, and the hole.
                ZStack {
                    Ellipse().fill(GumPalette.rgb(0xF48FB1)).frame(width: w * 0.86, height: h * 0.62).offset(y: -h * 0.12)
                    ForEach(0..<18, id: \.self) { i in
                        let a = Double(i) * 0.9
                        Capsule().fill([GumPalette.rgb(0xFFFFFF), GumPalette.rgb(0x3DA5FF), GumPalette.rgb(0xFFD43B), GumPalette.rgb(0x3DDC97)][i % 4])
                            .frame(width: max(4, w * 0.035), height: max(1.5, w * 0.012))
                            .rotationEffect(.radians(a * 2))
                            .offset(x: cos(a) * w * 0.3, y: sin(a) * h * 0.18 - h * 0.12)
                    }
                    Ellipse().fill(palette.dark.opacity(0.85)).frame(width: w * 0.2, height: h * 0.12).offset(y: -h * 0.14)
                }
            case .waterBalloon:
                Ellipse().fill(.white.opacity(0.25)).frame(width: w * 0.5, height: h * 0.7).offset(x: -w * 0.15, y: -h * 0.05).blur(radius: w * 0.05)
            case .eyeball:
                // The iris looks up and to the side.
                ZStack {
                    Ellipse().stroke(GumPalette.rgb(0xE57373).opacity(0.35), lineWidth: max(1, w * 0.004)).frame(width: w * 0.9, height: h * 0.9)
                    Circle().fill(RadialGradient(colors: [GumPalette.rgb(0x6EC6FF), GumPalette.rgb(0x1F5FA8)], center: .center, startRadius: 0, endRadius: w * 0.14))
                        .frame(width: w * 0.28, height: w * 0.28)
                    Circle().fill(Color.black).frame(width: w * 0.12, height: w * 0.12)
                    Circle().fill(.white.opacity(0.9)).frame(width: w * 0.04, height: w * 0.04).offset(x: -w * 0.04, y: -w * 0.04)
                }
                .position(x: w * 0.55, y: h * 0.3)
            case .fishbowl:
                // Water, and a goldfish swimming slowly back and forth.
                Rectangle().fill(GumPalette.rgb(0x7CC4E8).opacity(0.45)).frame(width: w, height: h * 0.72).position(x: w / 2, y: h * 0.64)
                TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { ctx in
                    let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
                    Text("🐠").font(.system(size: max(14, w * 0.14)))
                        .scaleEffect(x: cos(t / 3) >= 0 ? -1 : 1, y: 1)
                        .position(x: w * (0.5 + 0.22 * sin(t / 3)), y: h * (0.42 + 0.03 * sin(t)))
                }
            case .moodRing:
                // Blue when it's far off, green as it nears, red when it's time.
                let c: Color = level < 0.5 ? GumPalette.rgb(0x2E6FD8) : (level < 0.85 ? GumPalette.rgb(0x2EA86B) : GumPalette.rgb(0xD8342E))
                Ellipse().fill(c.opacity(0.75)).blendMode(.color)
                Ellipse().fill(RadialGradient(colors: [.white.opacity(0.35), .clear], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: w * 0.5))
            case .lavaLamp:
                // Warm blobs rising and sinking.
                TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { ctx in
                    let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
                    ZStack {
                        ForEach(0..<4, id: \.self) { i in
                            let d = Double(i)
                            Ellipse().fill(GumPalette.rgb(0xFFC23A))
                                .frame(width: w * (0.18 + 0.06 * d), height: w * (0.22 + 0.05 * d))
                                .position(x: w * (0.3 + 0.14 * d), y: h * (0.55 + 0.3 * sin(t / (6 + d) + d)))
                        }
                    }
                    .blur(radius: max(3, w * 0.02))
                }
            default:
                EmptyView()
            }
        }
        .frame(width: w, height: h)
        .clipShape(Ellipse())
        .allowsHitTesting(false)
    }

    /// (x, y, size) as fractions of the ball.
    static let craters: [(CGFloat, CGFloat, CGFloat)] = [
        (0.30, 0.30, 0.12), (0.62, 0.22, 0.08), (0.70, 0.45, 0.14), (0.42, 0.52, 0.09),
        (0.22, 0.58, 0.07), (0.55, 0.70, 0.11), (0.80, 0.68, 0.06), (0.35, 0.80, 0.08), (0.50, 0.36, 0.05),
    ]
    static let flakes: [(CGFloat, CGFloat, CGFloat)] = [
        (0.38, 0.22, 0.06), (0.65, 0.32, 0.045), (0.48, 0.45, 0.035), (0.25, 0.48, 0.04), (0.72, 0.58, 0.05),
    ]
}

/// Sparkly dots for glitter.
struct GlitterDots: View {
    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: 7)
            for _ in 0..<Int(size.width * size.height / 40) {
                let x = rng.next() * size.width, y = rng.next() * size.height, r = 0.6 + rng.next() * 1.4
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(0.4 + rng.next() * 0.6)))
            }
        }
    }
}

/// Things that sit on top of the ball, outside it. Drawn in the ball's frame (top at y = 0).
struct ThemeTopper: View {
    let palette: GumPalette
    let w: CGFloat
    var h: CGFloat? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch palette {
            case .grenade:
                // The fuze, the spoon down the side, and the pin's ring: "pull the pin".
                ZStack {
                    RoundedRectangle(cornerRadius: w * 0.02)
                        .fill(LinearGradient(colors: [GumPalette.rgb(0x6E6E72), GumPalette.rgb(0x3A3A3E)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: w * 0.17, height: w * 0.085)
                    Capsule()
                        .fill(LinearGradient(colors: [GumPalette.rgb(0x8A8D8B), GumPalette.rgb(0x5C5F5D)], startPoint: .top, endPoint: .bottom))
                        .frame(width: w * 0.27, height: w * 0.035)
                        .rotationEffect(.degrees(32))
                        .offset(x: w * 0.13, y: w * 0.06)
                    // The pin's ring sways a little, inviting a pull.
                    TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { ctx in
                        let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
                        Circle()
                            .stroke(GumPalette.rgb(0xC9A33A), lineWidth: max(2, w * 0.014))
                            .frame(width: w * 0.12, height: w * 0.12)
                            .rotationEffect(.degrees(sin(t * 1.6) * 10), anchor: .trailing)
                    }
                    .frame(width: w * 0.12, height: w * 0.12)
                    .offset(x: -w * 0.15, y: -w * 0.03)
                    Capsule().fill(GumPalette.rgb(0xC9A33A))
                        .frame(width: w * 0.08, height: max(2, w * 0.012))
                        .offset(x: -w * 0.07, y: -w * 0.005)
                }
                .position(x: w / 2, y: w * 0.01)
            case .ornament:
                ZStack {
                    Circle()
                        .trim(from: 0.5, to: 1)
                        .stroke(Color.gray, lineWidth: max(1.5, w * 0.01))
                        .frame(width: w * 0.08, height: w * 0.08)
                        .offset(y: -w * 0.05)
                    RoundedRectangle(cornerRadius: w * 0.012)
                        .fill(LinearGradient(colors: [GumPalette.rgb(0xF2C94C), GumPalette.rgb(0xB8860B)], startPoint: .leading, endPoint: .trailing))
                        .overlay(HStack(spacing: w * 0.012) {
                            ForEach(0..<7, id: \.self) { _ in Rectangle().fill(Color.black.opacity(0.15)).frame(width: max(1, w * 0.004)) }
                        })
                        .frame(width: w * 0.16, height: w * 0.07)
                }
                .position(x: w / 2, y: w * 0.005)
            case .pumpkin:
                ZStack {
                    RoundedRectangle(cornerRadius: w * 0.012)
                        .fill(LinearGradient(colors: [GumPalette.rgb(0x7A5230), GumPalette.rgb(0x4E3220)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: w * 0.05, height: w * 0.12)
                        .rotationEffect(.degrees(12))
                        .offset(y: -w * 0.03)
                    Circle()
                        .trim(from: 0.55, to: 0.95)
                        .stroke(GumPalette.rgb(0x4F8A3A), style: StrokeStyle(lineWidth: max(1.5, w * 0.01), lineCap: .round))
                        .frame(width: w * 0.12, height: w * 0.12)
                        .offset(x: w * 0.07, y: -w * 0.05)
                }
                .position(x: w / 2, y: w * 0.01)
            case .planet:
                // The ring, tilted across the ball.
                Ellipse()
                    .stroke(LinearGradient(colors: [GumPalette.rgb(0xF5DEB3), GumPalette.rgb(0xC8A06A), GumPalette.rgb(0xF5DEB3)], startPoint: .leading, endPoint: .trailing),
                            lineWidth: max(4, w * 0.035))
                    .frame(width: w * 1.45, height: w * 0.28)
                    .rotationEffect(.degrees(-12))
                    .position(x: w / 2, y: (h ?? w) / 2)
            case .waterBalloon:
                // The tied knot.
                Ellipse().fill(palette.dark).frame(width: w * 0.06, height: w * 0.05).position(x: w / 2, y: -w * 0.005)
            case .fishbowl:
                // The bowl's lip.
                Capsule().stroke(GumPalette.rgb(0x9FD3EE), lineWidth: max(2, w * 0.012))
                    .frame(width: w * 0.42, height: w * 0.05).position(x: w / 2, y: w * 0.02)
            default:
                EmptyView()
            }
        }
        .frame(width: w, height: h ?? w)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// What a theme pops into, piece by piece; nil means the default gum scraps (or Unicorn's and Fortune's own).
enum ThemeDebris {
    @ViewBuilder
    static func piece(_ palette: GumPalette, index i: Int, side: CGFloat) -> some View {
        let emoji = max(26, side * 0.5)
        let small = max(14, side * 0.32)
        switch palette {
        case .moon:
            if i == 0 || i == 6 { Text("👽").font(.system(size: emoji)) }
            else if i == 3 { Text("🛸").font(.system(size: emoji * 1.1)) }
            else if i % 3 == 0 { FourPointStar().fill(GumPalette.rgb(0x6366F1)).frame(width: small, height: small) }
            else { Circle().fill(GumPalette.rgb(0x9CA3AF).opacity(0.7)).frame(width: small * 0.7, height: small * 0.7).blur(radius: 1.5) }
        case .grenade:
            if i == 0 {
                Circle().stroke(GumPalette.rgb(0xC9A33A), lineWidth: 5).frame(width: max(30, side * 0.5), height: max(30, side * 0.5))
            } else if i == 1 {
                Capsule().fill(GumPalette.rgb(0x7A7D7B)).frame(width: max(40, side * 0.8), height: max(10, side * 0.14))
            } else if i % 2 == 0 {
                Circle().fill(GumPalette.rgb(0xB8B8B0).opacity(0.6)).frame(width: side * 1.2, height: side * 1.2).blur(radius: side * 0.25)
            } else {
                Capsule().fill([GumPalette.rgb(0x6B7A35), GumPalette.rgb(0xC9A33A), GumPalette.rgb(0xA89F68)][i % 3])
                    .frame(width: small, height: small * 0.35)
            }
        case .snowball:
            if i % 4 == 0 { Text("❄️").font(.system(size: emoji * 0.8)) }
            else { Circle().fill(Color.white).overlay(Circle().stroke(GumPalette.rgb(0xA5CFEA), lineWidth: 1)).frame(width: small, height: small).blur(radius: 0.8) }
        case .ornament:
            if i == 0 { Text("⭐").font(.system(size: emoji)) }
            else if i == 5 { Text("🎄").font(.system(size: emoji)) }
            else if i % 2 == 0 { FourPointStar().fill(GumPalette.rgb(0xE8B923)).frame(width: small, height: small) }
            else { Capsule().fill(GumPalette.rgb(0xD4A017)).frame(width: small * 1.6, height: 3) }
        case .pumpkin:
            if i == 0 || i == 4 || i == 8 { Text("🍂").font(.system(size: emoji)) }
            else if i == 6 { Text("☕").font(.system(size: emoji)) }
            else { Ellipse().fill([GumPalette.rgb(0x96522A), GumPalette.rgb(0xC4783C), GumPalette.rgb(0x6E3C1E)][i % 3]).frame(width: small * 0.5, height: small * 0.35) }
        case .disco:
            if i == 0 { Text("🪩").font(.system(size: emoji)) }
            else { Rectangle().fill(i % 3 == 0 ? GumPalette.rgb(0xFFD66B) : (i % 3 == 1 ? Color.white : GumPalette.rgb(0xB8BEC8)))
                    .overlay(Rectangle().stroke(GumPalette.rgb(0x8A8F99), lineWidth: 0.5)).frame(width: small * 0.6, height: small * 0.6) }
        case .soap:
            Circle().stroke(GumPalette.rgb(0xA99EE0), lineWidth: 1.5).background(Circle().fill(.white.opacity(0.3)))
                .frame(width: small * (i % 2 == 0 ? 1.2 : 0.7), height: small * (i % 2 == 0 ? 1.2 : 0.7))
        case .planet:
            if i == 0 { Ellipse().stroke(GumPalette.rgb(0xC8A06A), lineWidth: 5).frame(width: side * 1.2, height: side * 0.3) }
            else if i % 3 == 0 { Circle().fill(GumPalette.rgb(0x9CA3AF)).frame(width: small, height: small) }
            else { FourPointStar().fill(GumPalette.rgb(0xE0B07A)).frame(width: small * 0.8, height: small * 0.8) }
        case .basketball:
            if i == 0 { Text("🏀").font(.system(size: emoji)) }
            else { Capsule().fill(i % 2 == 0 ? GumPalette.rgb(0xE8742A) : Color.black.opacity(0.8)).frame(width: small, height: small * 0.3) }
        case .donut:
            if i == 0 { Text("🍩").font(.system(size: emoji)) }
            else { Capsule().fill([GumPalette.rgb(0xF48FB1), GumPalette.rgb(0x3DA5FF), GumPalette.rgb(0xFFD43B), GumPalette.rgb(0x3DDC97), Color.white][i % 5])
                    .frame(width: small * 0.9, height: small * 0.28) }
        case .waterBalloon:
            if i == 0 { Text("💦").font(.system(size: emoji)) }
            else { Circle().fill(GumPalette.rgb(0x3BA4E8).opacity(0.75)).frame(width: small * 0.7, height: small * 0.7) }
        case .eyeball:
            if i == 0 { Text("👁️").font(.system(size: emoji)) }
            else if i % 2 == 0 { Capsule().fill(Color.black.opacity(0.8)).frame(width: small * 0.9, height: 2.5) }
            else { Capsule().fill([GumPalette.rgb(0x6EC6FF), GumPalette.rgb(0xFF8A3D), GumPalette.rgb(0x3DDC97)][i % 3]).frame(width: small, height: small * 0.35) }
        case .fishbowl:
            if i == 0 { Text("🐠").font(.system(size: emoji)) }
            else { Circle().stroke(GumPalette.rgb(0x5BB5E0), lineWidth: 1.5).frame(width: small * (i % 2 == 0 ? 1.0 : 0.6), height: small * (i % 2 == 0 ? 1.0 : 0.6)) }
        case .moodRing:
            FourPointStar().fill([GumPalette.rgb(0x2E6FD8), GumPalette.rgb(0x2EA86B), GumPalette.rgb(0xD8342E), GumPalette.rgb(0x9B5CFF)][i % 4])
                .frame(width: small, height: small)
        case .lavaLamp:
            Ellipse().fill(i % 2 == 0 ? GumPalette.rgb(0xFFC23A) : GumPalette.rgb(0xFF7A3D)).frame(width: side * 0.7, height: side * 0.8).blur(radius: 3)
        default:
            EmptyView()
        }
    }

    static func handles(_ palette: GumPalette) -> Bool {
        [.moon, .grenade, .snowball, .ornament, .pumpkin].contains(palette) || GumPalette.novelty.contains(palette)
    }
}

/// A tiny repeatable random source, so the sprinkles land the same way every pop.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    /// 0..<1
    mutating func next() -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return Double(state % 1_000_000) / 1_000_000
    }
}
