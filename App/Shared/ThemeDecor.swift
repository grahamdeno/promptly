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
                // Soft craters, darker on their lower right with a lit rim on the upper left, carried slowly round as
                // the moon turns (once every 40 seconds), narrowing toward the edge.
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { tl in
                    let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                    ZStack {
                        ForEach(0..<(Self.craters.count * 2), id: \.self) { i in
                            ThemeMarks.crater(i, t: t, w: w, h: h, dark: palette.dark)
                        }
                    }
                }
            case .snowball:
                // Snow drifting down inside, swaying and turning as it falls.
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { tl in
                    let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                    ZStack {
                        ForEach(0..<14, id: \.self) { i in
                            ThemeMarks.snowflake(i, t: t, w: w, h: h)
                        }
                    }
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
                // Mirror tiles turning: rows slide sideways, faster across the middle where the ball faces you,
                // and the bright tiles travel with them (one turn every 10 seconds; still with Reduce Motion).
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { tl in
                    let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                    Canvas { ctx, size in
                        let n = 14
                        let tile = size.width / CGFloat(n)
                        let turn = CGFloat((t / 10).truncatingRemainder(dividingBy: 1))
                        for row in 0..<n {
                            var rng = SeededRandom(seed: UInt64(11 + row))
                            let bright = (0..<n).map { _ in rng.next() }
                            for col in 0..<(n + 1) {
                                let base = (CGFloat(col) / CGFloat(n) + turn).truncatingRemainder(dividingBy: 1)
                                // Squeeze toward the edges, like tiles curving around a sphere.
                                let u = base * 2 - 1
                                let x = (CGFloat(asin(Double(u))) / .pi + 0.5) * size.width
                                let wTile = max(1, tile * CGFloat(cos(Double(u) * .pi / 2)) - 1.5)
                                let v = bright[col % n]
                                let r = CGRect(x: x - wTile / 2, y: CGFloat(row) * tile + 1, width: wTile, height: tile - 2)
                                ctx.fill(Path(r), with: .color(v > 0.85 ? .white.opacity(0.95) : (v < 0.25 ? .black.opacity(0.25) : .white.opacity(0.12))))
                            }
                        }
                    }
                }
            case .soap:
                // A thin rainbow film that swirls and shimmers while it rests.
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { tl in
                    let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                    Ellipse()
                        .fill(AngularGradient(colors: [GumPalette.rgb(0xFFB3D9), GumPalette.rgb(0xB8E0FF), GumPalette.rgb(0xC8F5D8),
                                                       GumPalette.rgb(0xFFF1A8), GumPalette.rgb(0xD7B8FF), GumPalette.rgb(0xFFB3D9)],
                                              center: UnitPoint(x: 0.5 + 0.08 * sin(t / 3), y: 0.45 + 0.08 * cos(t / 4)),
                                              angle: .degrees(t * 18)))
                        .opacity(0.4 + 0.1 * sin(t / 1.7))
                        .blur(radius: max(4, w * 0.03))
                }
                Ellipse().stroke(GumPalette.rgb(0xB9AEE6).opacity(0.8), lineWidth: max(1.5, w * 0.006))
            case .planet:
                // Cloud bands drifting sideways as the planet turns, each at its own speed.
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { tl in
                    let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                    VStack(spacing: h * 0.06) {
                        ForEach(0..<6, id: \.self) { i in
                            let speed = 0.03 + 0.012 * Double(i % 3)
                            let shift = CGFloat((t * speed).truncatingRemainder(dividingBy: 1))
                            HStack(spacing: w * 0.08) {
                                ForEach(0..<4, id: \.self) { k in
                                    Capsule().fill((i % 2 == 0 ? palette.dark : palette.light).opacity(k % 2 == 0 ? 0.4 : 0.25))
                                        .frame(width: w * 0.42, height: h * 0.07)
                                }
                            }
                            .offset(x: -w * shift * 2)
                            .frame(width: w * 1.1, alignment: .leading)
                        }
                    }
                    .rotationEffect(.degrees(-12))
                    .blur(radius: max(1, w * 0.008))
                }
            case .basketball:
                // Seams, and the ball rolls to a new random angle now and then.
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { tl in
                    ZStack {
                        Rectangle().fill(Color.black.opacity(0.75)).frame(width: max(2, w * 0.012), height: h * 1.2)
                        Rectangle().fill(Color.black.opacity(0.75)).frame(width: w * 1.2, height: max(2, w * 0.012))
                        Ellipse().stroke(Color.black.opacity(0.75), lineWidth: max(2, w * 0.012)).frame(width: w * 0.55, height: h * 1.1).offset(x: -w * 0.45)
                        Ellipse().stroke(Color.black.opacity(0.75), lineWidth: max(2, w * 0.012)).frame(width: w * 0.55, height: h * 1.1).offset(x: w * 0.45)
                    }
                    .frame(width: w, height: h)
                    .rotationEffect(.degrees(Self.tumble(reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate, seed: 1)))
                }
            case .donut:
                // Pink glaze with sprinkles, and the hole.
                ZStack {
                    Ellipse().fill(GumPalette.rgb(0xF48FB1)).frame(width: w * 0.86, height: h * 0.62).offset(y: -h * 0.12)
                    // Sprinkles that shimmer, each catching the light in turn.
                    TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { tl in
                        let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                        ZStack {
                            ForEach(0..<18, id: \.self) { i in
                                Self.glazeSprinkle(i, t: t, w: w, h: h)
                            }
                        }
                    }
                    Ellipse().fill(palette.dark.opacity(0.85)).frame(width: w * 0.2, height: h * 0.12).offset(y: -h * 0.14)
                }
            case .waterBalloon:
                Ellipse().fill(.white.opacity(0.25)).frame(width: w * 0.5, height: h * 0.7).offset(x: -w * 0.15, y: -h * 0.05).blur(radius: w * 0.05)
            case .eyeball:
                // The eye looks around slowly: it glances to a new spot, holds, then glances again.
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { ctx in
                    let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
                    let gaze = Self.gaze(t)
                    ZStack {
                        Ellipse().stroke(GumPalette.rgb(0xE57373).opacity(0.35), lineWidth: max(1, w * 0.004)).frame(width: w * 0.9, height: h * 0.9)
                            .position(x: w / 2, y: h / 2)
                        ZStack {
                            Circle().fill(RadialGradient(colors: [GumPalette.rgb(0x6EC6FF), GumPalette.rgb(0x1F5FA8)], center: .center, startRadius: 0, endRadius: w * 0.14))
                                .frame(width: w * 0.28, height: w * 0.28)
                            Circle().fill(Color.black).frame(width: w * 0.12, height: w * 0.12)
                            Circle().fill(.white.opacity(0.9)).frame(width: w * 0.04, height: w * 0.04).offset(x: -w * 0.04, y: -w * 0.04)
                        }
                        .position(x: w * gaze.x, y: h * gaze.y)
                    }
                }
            case .fishbowl:
                // Water. Food sprinkles in on one side, the fish swims over and gobbles it, then the other side.
                Rectangle().fill(GumPalette.rgb(0x7CC4E8).opacity(0.45)).frame(width: w, height: h * 0.72).position(x: w / 2, y: h * 0.64)
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { ctx in
                    let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
                    let f = Self.fish(t)
                    ZStack {
                        ForEach(0..<6, id: \.self) { i in
                            let flake = Self.flake(i, t: t)
                            if flake.visible {
                                RoundedRectangle(cornerRadius: 1).fill([GumPalette.rgb(0xE0802E), GumPalette.rgb(0xC9572A), GumPalette.rgb(0xE8B04A)][i % 3])
                                    .frame(width: max(3, w * 0.022), height: max(2, w * 0.014))
                                    .rotationEffect(.degrees(flake.spin))
                                    .position(x: w * flake.x, y: h * flake.y)
                            }
                        }
                        Text("🐠").font(.system(size: max(14, w * 0.14)))
                            .scaleEffect(x: f.facingRight ? -1 : 1, y: 1)
                            .scaleEffect(f.gulp)
                            .position(x: w * f.x, y: h * f.y)
                    }
                }
            case .moodRing:
                // Blue when it's far off, green as it nears, red when it's time.
                let c: Color = level < 0.5 ? GumPalette.rgb(0x2E6FD8) : (level < 0.85 ? GumPalette.rgb(0x2EA86B) : GumPalette.rgb(0xD8342E))
                Ellipse().fill(c.opacity(0.75)).blendMode(.color)
                Ellipse().fill(RadialGradient(colors: [.white.opacity(0.35), .clear], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: w * 0.5))
            case .soccer:
                // Black pentagon patches, smaller toward the edge, and the ball rolls to a new random angle now and then.
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { tl in
                    ZStack {
                        ForEach(0..<Self.patches.count, id: \.self) { i in
                            let p = Self.patches[i]
                            Pentagon().fill(Color.black.opacity(0.85))
                                .frame(width: w * p.2, height: w * p.2)
                                .rotationEffect(.degrees(p.3))
                                .position(x: w * p.0, y: h * p.1)
                        }
                    }
                    .frame(width: w, height: h)
                    .rotationEffect(.degrees(Self.tumble(reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate, seed: 2)))
                }
            case .hockey:
                // Grippy knurled edge and a faint ring.
                Ellipse().strokeBorder(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: max(3, w * 0.03), dash: [max(2, w * 0.008), max(2, w * 0.008)]))
                Ellipse().stroke(Color.white.opacity(0.12), lineWidth: max(1, w * 0.006)).frame(width: w * 0.62, height: h * 0.62)
            case .tennis:
                // Fuzz and the curved white seams.
                Canvas { ctx, size in
                    var rng = SeededRandom(seed: 5)
                    for _ in 0..<Int(size.width * size.height / 30) {
                        let x = rng.next() * size.width, y = rng.next() * size.height
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)), with: .color(.white.opacity(0.18)))
                    }
                }
                Ellipse().stroke(Color.white.opacity(0.95), lineWidth: max(2, w * 0.022)).frame(width: w * 0.7, height: h * 1.05).offset(x: -w * 0.42)
                Ellipse().stroke(Color.white.opacity(0.95), lineWidth: max(2, w * 0.022)).frame(width: w * 0.7, height: h * 1.05).offset(x: w * 0.42)
            case .golf:
                // Dimples.
                Canvas { ctx, size in
                    let step = max(6, size.width / 18)
                    var row = 0
                    var y: CGFloat = 0
                    while y < size.height {
                        var x: CGFloat = row % 2 == 0 ? 0 : step / 2
                        while x < size.width {
                            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: step * 0.55, height: step * 0.55)), with: .color(.black.opacity(0.08)))
                            ctx.fill(Path(ellipseIn: CGRect(x: x + step * 0.08, y: y + step * 0.08, width: step * 0.3, height: step * 0.3)), with: .color(.white.opacity(0.5)))
                            x += step
                        }
                        y += step * 0.86
                        row += 1
                    }
                }
            case .baseball:
                // Two seams with red stitches.
                ForEach([-1.0, 1.0], id: \.self) { side in
                    Ellipse().stroke(GumPalette.rgb(0xC62828).opacity(0.5), lineWidth: max(1, w * 0.006))
                        .frame(width: w * 0.7, height: h * 1.05).offset(x: side * w * 0.42)
                    Ellipse().stroke(GumPalette.rgb(0xC62828), style: StrokeStyle(lineWidth: max(2, w * 0.02), dash: [max(2, w * 0.012), max(3, w * 0.02)]))
                        .frame(width: w * 0.66, height: h * 1.0).offset(x: side * w * 0.42)
                }
            case .bowling:
                // A swirl and three finger holes.
                Ellipse().fill(AngularGradient(colors: [palette.light.opacity(0.6), .clear, palette.light.opacity(0.4), .clear, palette.light.opacity(0.6)], center: UnitPoint(x: 0.4, y: 0.6)))
                    .blur(radius: max(4, w * 0.04))
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Color.black.opacity(0.85))
                        .overlay(Circle().stroke(palette.light.opacity(0.4), lineWidth: 1))
                        .frame(width: w * (i == 2 ? 0.09 : 0.075), height: w * (i == 2 ? 0.09 : 0.075))
                        .position(x: w * [0.44, 0.58, 0.5][i], y: h * [0.24, 0.24, 0.38][i])
                }
            case .pixel:
                // Blocky pixels with a stepped highlight.
                Canvas { ctx, size in
                    let n = 16
                    let px = size.width / CGFloat(n)
                    for row in 0..<n { for col in 0..<n {
                        let cx = (CGFloat(col) + 0.5) / CGFloat(n) - 0.38, cy = (CGFloat(row) + 0.5) / CGFloat(n) - 0.3
                        let d = (cx * cx + cy * cy).squareRoot()
                        let shade: Color = d < 0.12 ? .white.opacity(0.55) : (d < 0.3 ? .white.opacity(0.18) : (d > 0.75 ? .black.opacity(0.3) : .clear))
                        ctx.fill(Path(CGRect(x: CGFloat(col) * px, y: CGFloat(row) * px, width: px + 0.5, height: px + 0.5)), with: .color(shade))
                    } }
                }
            case .gumball:
                // Little gumballs filling the glass. From about ten minutes out they jostle silently,
                // more and more as the meeting nears and on past the start.
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || level < 0.83)) { tl in
                    // level is the share of the last hour gone, so 0.83 is ten minutes out.
                    let t = reduceMotion || level < 0.83 ? 0 : tl.date.timeIntervalSinceReferenceDate
                    let shake = level < 0.83 ? 0 : 0.3 + 0.7 * min(1, (level - 0.83) / 0.17)
                    Canvas { ctx, size in
                        var rng = SeededRandom(seed: 3)
                        let r = size.width * 0.05
                        let colors: [Color] = [GumPalette.rgb(0xFF5A5A), GumPalette.rgb(0xFFD43B), GumPalette.rgb(0x3DA5FF), GumPalette.rgb(0x3DDC97), GumPalette.rgb(0xFF7FB0), .white]
                        var y = size.height * 0.98
                        var k = 0.0
                        while y > size.height * 0.32 {
                            var x = rng.next() * r
                            while x < size.width {
                                // Looser toward the top, where the balls have room to move.
                                let free = 0.4 + 0.6 * (1 - y / size.height)
                                let dx = r * 0.35 * shake * free * sin(t * (7 + k.truncatingRemainder(dividingBy: 5)) + k)
                                let dy = r * 0.3 * shake * free * abs(sin(t * (5.5 + k.truncatingRemainder(dividingBy: 3)) + k * 1.7))
                                ctx.fill(Path(ellipseIn: CGRect(x: x + dx, y: y - r * 2 - dy, width: r * 2, height: r * 2)), with: .color(colors[Int(rng.next() * 6) % 6]))
                                x += r * 2.05
                                k += 1
                            }
                            y -= r * 1.8
                        }
                    }
                }
            case .orange:
                Canvas { ctx, size in
                    var rng = SeededRandom(seed: 8)
                    for _ in 0..<Int(size.width * size.height / 90) {
                        ctx.fill(Path(ellipseIn: CGRect(x: rng.next() * size.width, y: rng.next() * size.height, width: 2, height: 2)), with: .color(.black.opacity(0.08)))
                    }
                }
            case .macaron:
                // The cream filling and the frilly foot.
                Capsule().fill(GumPalette.rgb(0xFFF6E8)).frame(width: w * 1.05, height: h * 0.07).position(x: w / 2, y: h * 0.5)
                HStack(spacing: 0) { ForEach(0..<24, id: \.self) { _ in Circle().fill(palette.dark.opacity(0.25)).frame(width: w / 24, height: w / 24) } }
                    .frame(width: w).position(x: w / 2, y: h * 0.57)
            case .cakePop:
                // Sprinkles that glisten, each catching the light in turn.
                TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { tl in
                    let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                    Canvas { ctx, size in
                        var rng = SeededRandom(seed: 12)
                        let colors: [Color] = [.white, GumPalette.rgb(0x3DA5FF), GumPalette.rgb(0xFFD43B), GumPalette.rgb(0x3DDC97), GumPalette.rgb(0x9B5CFF)]
                        for k in 0..<60 {
                            let angle = rng.next() * 3.14, px = rng.next() * size.width, py = rng.next() * size.height * 0.7
                            let move = CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: px, y: py))
                            let p = Path(roundedRect: CGRect(x: 0, y: 0, width: size.width * 0.035, height: size.width * 0.012), cornerRadius: 2).applying(move)
                            ctx.fill(p, with: .color(colors[Int(rng.next() * 5) % 5]))
                            let glint = max(0, sin(t * 1.8 + Double(k) * 2.39))
                            if glint > 0.75 {
                                ctx.fill(p, with: .color(.white.opacity((glint - 0.75) * 3.2)))
                                let g = size.width * 0.03 * (glint - 0.75) * 4
                                ctx.fill(Path(ellipseIn: CGRect(x: px - g / 2, y: py - g / 2, width: g, height: g)), with: .color(.white.opacity(0.7 * (glint - 0.75) * 4)))
                            }
                        }
                    }
                }
            case .earth:
                // Continents drifting with the turn, and clouds.
                TimelineView(.animation(minimumInterval: 1.0 / 15, paused: reduceMotion)) { ctx in
                    let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
                    let shift = CGFloat((t / 16).truncatingRemainder(dividingBy: 1))
                    ZStack {
                        ForEach(0..<6, id: \.self) { i in
                            let x = (CGFloat(i) * 0.37 + shift).truncatingRemainder(dividingBy: 1.4) - 0.2
                            Ellipse().fill(GumPalette.rgb(0x3DAA5C)).frame(width: w * 0.32, height: h * 0.2)
                                .rotationEffect(.degrees(Double(i) * 33)).position(x: w * x, y: h * (0.25 + 0.12 * CGFloat(i % 4)))
                        }
                        ForEach(0..<4, id: \.self) { i in
                            Capsule().fill(.white.opacity(0.7)).frame(width: w * 0.3, height: h * 0.04)
                                .position(x: w * ((CGFloat(i) * 0.31 + shift * 1.6).truncatingRemainder(dividingBy: 1.3) - 0.15), y: h * (0.2 + 0.17 * CGFloat(i)))
                        }
                    }
                    .blur(radius: max(1, w * 0.006))
                }
            case .sun:
                // Hot spots carried round as the sun turns, flaring as they go.
                TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { ctx in
                    let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
                    let turn = (t / 14).truncatingRemainder(dividingBy: 1)
                    ZStack {
                        ForEach(0..<8, id: \.self) { i in
                            let d = Double(i)
                            // Each spot travels left to right across the face and wraps round the back.
                            let u = (d / 8 + turn).truncatingRemainder(dividingBy: 1)
                            let x = 0.5 - 0.5 * cos(u * 2 * .pi)
                            let facing: Double = sin(u * 2 * .pi)
                            let glow: Double = facing > 0 ? (0.3 + 0.2 * sin(t * 0.8 + d)) * facing : 0
                            Circle().fill(GumPalette.rgb(0xFF7A1A).opacity(glow))
                                .frame(width: w * 0.22 * CGFloat(0.5 + 0.5 * facing), height: w * 0.22)
                                .position(x: w * CGFloat(x), y: h * (0.25 + 0.09 * CGFloat(i % 5)))
                        }
                    }
                    .blur(radius: max(4, w * 0.04))
                }
            case .dandelion:
                // Seeds radiating from the middle, each swaying slowly on its stalk.
                TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { tl in
                    let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                    Canvas { ctx, size in
                        let c = CGPoint(x: size.width / 2, y: size.height * 0.55)
                        for k in 0..<72 {
                            let sway = 0.06 * sin(t * 0.9 + Double(k) * 0.45) + 0.03 * sin(t * 0.37 + Double(k))
                            let a = Double(k) / 72 * 2 * .pi + sway
                            let len = 0.44 + 0.04 * sin(Double(k) * 2.7)
                            let end = CGPoint(x: c.x + cos(a) * size.width * len, y: c.y + sin(a) * size.height * len)
                            var line = Path(); line.move(to: c); line.addLine(to: end)
                            ctx.stroke(line, with: .color(GumPalette.rgb(0xB8BCA8).opacity(0.6)), lineWidth: 0.8)
                            // A little fan of fluff at the tip.
                            for f in -2...2 {
                                let fa = a + Double(f) * 0.28
                                var fluff = Path(); fluff.move(to: end)
                                fluff.addLine(to: CGPoint(x: end.x + cos(fa) * size.width * 0.035, y: end.y + sin(fa) * size.width * 0.035))
                                ctx.stroke(fluff, with: .color(.white.opacity(0.85)), lineWidth: 0.7)
                            }
                            ctx.fill(Path(ellipseIn: CGRect(x: end.x - 2, y: end.y - 2, width: 4, height: 4)), with: .color(.white))
                        }
                    }
                }
            case .atom:
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { ctx in
                    let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
                    ZStack {
                        Circle().fill(GumPalette.rgb(0x8AB4FF)).frame(width: w * 0.12, height: w * 0.12).blur(radius: w * 0.02)
                        ForEach(0..<3, id: \.self) { i in
                            let rot = Double(i) * 60
                            Ellipse().stroke(GumPalette.rgb(0x8AB4FF).opacity(0.6), lineWidth: max(1.5, w * 0.008))
                                .frame(width: w * 0.8, height: h * 0.28).rotationEffect(.degrees(rot))
                            let a = t * (1.2 + Double(i) * 0.3) + Double(i)
                            Circle().fill(Color.white).frame(width: w * 0.035, height: w * 0.035)
                                .offset(x: cos(a) * w * 0.4, y: sin(a) * h * 0.14).rotationEffect(.degrees(rot))
                        }
                    }
                    .position(x: w / 2, y: h * 0.42)
                }
            case .geode:
                // A crack showing crystal.
                Ellipse().fill(AngularGradient(colors: [GumPalette.rgb(0x9B5CFF), GumPalette.rgb(0xD7B8FF), GumPalette.rgb(0x6D3FD6), GumPalette.rgb(0xE9D8FF), GumPalette.rgb(0x9B5CFF)], center: .center))
                    .frame(width: w * 0.45, height: h * 0.3).position(x: w * 0.55, y: h * 0.35)
                Ellipse().stroke(GumPalette.rgb(0x2E2B28), lineWidth: max(2, w * 0.012)).frame(width: w * 0.47, height: h * 0.32).position(x: w * 0.55, y: h * 0.35)
            case .yarn:
                ForEach(0..<7, id: \.self) { i in
                    Ellipse().stroke(palette.dark.opacity(0.35), lineWidth: max(1.5, w * 0.012))
                        .frame(width: w * 0.95, height: h * 0.35).rotationEffect(.degrees(Double(i) * 26))
                }
            case .arcadeButton:
                Ellipse().stroke(palette.dark.opacity(0.6), lineWidth: max(4, w * 0.04)).padding(w * 0.05)
            case .clock:
                // Tick marks and hands; the minute hand sweeps toward twelve as the meeting nears.
                ZStack {
                    ForEach(0..<12, id: \.self) { i in
                        Capsule().fill(Color.black.opacity(0.7)).frame(width: max(2, w * 0.01), height: w * 0.05)
                            .offset(y: -h * 0.4).rotationEffect(.degrees(Double(i) * 30))
                    }
                    Capsule().fill(Color.black).frame(width: max(3, w * 0.018), height: h * 0.22).offset(y: -h * 0.11).rotationEffect(.degrees(300))
                    Capsule().fill(GumPalette.rgb(0xC62828)).frame(width: max(2, w * 0.01), height: h * 0.34).offset(y: -h * 0.17).rotationEffect(.degrees(360 * (1 - level)))
                    Circle().fill(Color.black).frame(width: w * 0.04, height: w * 0.04)
                }
                .position(x: w / 2, y: h / 2)
            case .marble:
                Ellipse().fill(AngularGradient(colors: [GumPalette.rgb(0xFF5A5A), .clear, GumPalette.rgb(0xFFD43B), .clear, GumPalette.rgb(0x3DA5FF), .clear], center: .center))
                    .frame(width: w * 0.5, height: h * 0.5).rotationEffect(.degrees(25)).blur(radius: max(2, w * 0.015)).opacity(0.85)
            case .duck:
                Ellipse().fill(GumPalette.rgb(0xFF8A1E)).frame(width: w * 0.22, height: h * 0.1).position(x: w * 0.82, y: h * 0.42)
                Circle().fill(Color.black).frame(width: w * 0.05, height: w * 0.05).position(x: w * 0.66, y: h * 0.3)
                Ellipse().stroke(palette.dark.opacity(0.4), lineWidth: max(2, w * 0.012)).frame(width: w * 0.45, height: h * 0.3).position(x: w * 0.38, y: h * 0.62)
            case .easterEgg:
                // A dyed egg: a pastel zigzag band, polka dots and a wavy stripe, with a crack that shows when it rocks.
                Canvas { ctx, size in
                    let W = size.width, H = size.height
                    // Wavy stripe near the top.
                    var wave = Path()
                    wave.move(to: CGPoint(x: 0, y: H * 0.27))
                    for k in 0...24 {
                        let x = W * CGFloat(k) / 24
                        wave.addLine(to: CGPoint(x: x, y: H * 0.27 + H * 0.025 * CGFloat(sin(Double(k) * 1.2))))
                    }
                    ctx.stroke(wave, with: .color(GumPalette.rgb(0xD7B8FF)), lineWidth: H * 0.05)
                    // Zigzag band across the middle.
                    var zig = Path()
                    zig.move(to: CGPoint(x: 0, y: H * 0.5))
                    for k in 0...12 {
                        zig.addLine(to: CGPoint(x: W * CGFloat(k) / 12, y: H * (k % 2 == 0 ? 0.46 : 0.56)))
                    }
                    ctx.stroke(zig, with: .color(GumPalette.rgb(0xFFB3D9)), style: StrokeStyle(lineWidth: H * 0.06, lineJoin: .round))
                    // Polka dots below.
                    for row in 0..<2 {
                        for col in 0..<6 {
                            let x = W * (0.12 + 0.16 * CGFloat(col) + (row == 1 ? 0.08 : 0))
                            let y = H * (0.68 + 0.1 * CGFloat(row))
                            ctx.fill(Path(ellipseIn: CGRect(x: x - W * 0.03, y: y - W * 0.03, width: W * 0.06, height: W * 0.06)),
                                     with: .color([GumPalette.rgb(0xFFF1A8), GumPalette.rgb(0xB5F2D6)][(row + col) % 2]))
                        }
                    }
                }
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { tl in
                    let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                    Path { p in
                        p.move(to: CGPoint(x: w * 0.42, y: h * 0.16))
                        p.addLine(to: CGPoint(x: w * 0.47, y: h * 0.21))
                        p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.15))
                        p.addLine(to: CGPoint(x: w * 0.55, y: h * 0.22))
                        p.addLine(to: CGPoint(x: w * 0.59, y: h * 0.17))
                    }
                    .stroke(Color.black.opacity(0.55 * EggRock.crack(t)), style: StrokeStyle(lineWidth: max(1.5, w * 0.006), lineJoin: .round))
                }
            case .valentine:
                // A heart that gives a double beat every few seconds.
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { tl in
                    let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                    Image(systemName: "heart.fill").font(.system(size: w * 0.3)).foregroundStyle(.white.opacity(0.35 + 0.2 * HeartBeat.beat(t)))
                        .scaleEffect(1 + 0.14 * HeartBeat.beat(t))
                        .position(x: w * 0.5, y: h * 0.38)
                }
            case .fireworks:
                TimelineView(.animation(minimumInterval: 1.0 / 10, paused: reduceMotion)) { ctx in
                    let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
                    Canvas { c, size in
                        var rng = SeededRandom(seed: 4)
                        for k in 0..<40 {
                            let x = rng.next() * size.width, y = rng.next() * size.height
                            let a = 0.4 + 0.6 * abs(sin(t * 2 + Double(k)))
                            c.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 3, height: 3)), with: .color([Color.yellow, .pink, .cyan, .white][k % 4].opacity(a)))
                        }
                    }
                }
            case .beachBall:
                Ellipse().fill(AngularGradient(stops: [
                    .init(color: GumPalette.rgb(0xE53935), location: 0), .init(color: GumPalette.rgb(0xE53935), location: 0.166),
                    .init(color: .white, location: 0.167), .init(color: .white, location: 0.333),
                    .init(color: GumPalette.rgb(0x1E88E5), location: 0.334), .init(color: GumPalette.rgb(0x1E88E5), location: 0.5),
                    .init(color: .white, location: 0.501), .init(color: .white, location: 0.666),
                    .init(color: GumPalette.rgb(0xFDD835), location: 0.667), .init(color: GumPalette.rgb(0xFDD835), location: 0.833),
                    .init(color: .white, location: 0.834), .init(color: .white, location: 1)], center: UnitPoint(x: 0.5, y: 0.35)))
                    .opacity(0.9)
            case .zen:
                // Raked sand: rings around a small stone, and every so often a drop lands and a ripple spreads out.
                Canvas { ctx, size in
                    var rng = SeededRandom(seed: 9)
                    for _ in 0..<Int(size.width * size.height / 140) {
                        ctx.fill(Path(ellipseIn: CGRect(x: rng.next() * size.width, y: rng.next() * size.height, width: 1.5, height: 1.5)), with: .color(.white.opacity(0.22)))
                    }
                    let c = CGPoint(x: size.width * 0.6, y: size.height * 0.58)
                    for k in 1...6 {
                        let r = size.width * 0.07 * CGFloat(k)
                        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.6, width: r * 2, height: r * 1.2)),
                                   with: .color(.white.opacity(0.18)), lineWidth: max(1, size.width * 0.006))
                    }
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - size.width * 0.06, y: c.y - size.width * 0.04, width: size.width * 0.12, height: size.width * 0.08)),
                             with: .color(palette.dark.opacity(0.8)))
                }
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { tl in
                    let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                    let k = t.truncatingRemainder(dividingBy: 9)
                    ZStack {
                        ForEach(0..<3, id: \.self) { i in
                            let p = (k - Double(i) * 0.5) / 4
                            if p > 0 && p < 1 {
                                Ellipse().stroke(Color.white.opacity(0.5 * (1 - p)), lineWidth: max(1, w * 0.006))
                                    .frame(width: w * 0.7 * CGFloat(p), height: w * 0.42 * CGFloat(p))
                                    .position(x: w * 0.6, y: h * 0.58)
                            }
                        }
                    }
                }
            case .lavaLamp:
                // Gooey wax: blobs that stretch as they rise, merge and split, over a warm glow from the base
                // and a pool of wax sitting at the bottom.
                Ellipse().fill(RadialGradient(colors: [GumPalette.rgb(0xFFB347).opacity(0.55), .clear],
                                              center: UnitPoint(x: 0.5, y: 1.0), startRadius: 0, endRadius: h * 0.75))
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { ctx in
                    let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
                    ZStack {
                        Self.lava(t: t, w: w, h: h, color: GumPalette.rgb(0xFF9F1C), grow: 1)
                        Self.lava(t: t, w: w, h: h, color: GumPalette.rgb(0xFFD166), grow: 0.55)
                            .offset(x: -w * 0.012, y: -h * 0.012)
                    }
                }
            default:
                EmptyView()
            }
        }
        .frame(width: w, height: h)
        .modifier(RestSpin(on: [.tennis, .golf, .baseball, .bowling, .pixel, .beachBall].contains(palette), paused: reduceMotion,
                           seed: Double(GumPalette.allCases.firstIndex(of: palette) ?? 0)))
        .clipShape(Ellipse())
        .allowsHitTesting(false)
    }

    /// (x, y, size) as fractions of the ball.
    static let craters: [(CGFloat, CGFloat, CGFloat)] = [
        (0.30, 0.30, 0.12), (0.62, 0.22, 0.08), (0.70, 0.45, 0.14), (0.42, 0.52, 0.09),
        (0.22, 0.58, 0.07), (0.55, 0.70, 0.11), (0.80, 0.68, 0.06), (0.35, 0.80, 0.08), (0.50, 0.36, 0.05),
    ]
    /// (x, y, size, angle) for the soccer ball's patches.
    /// Where the eye is looking (share of the ball): a new spot every 3.2 seconds, eased over 0.7 seconds.
    static func gaze(_ t: TimeInterval) -> CGPoint {
        let spots: [CGPoint] = [CGPoint(x: 0.55, y: 0.3), CGPoint(x: 0.38, y: 0.36), CGPoint(x: 0.62, y: 0.42),
                                CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.4, y: 0.28), CGPoint(x: 0.66, y: 0.32), CGPoint(x: 0.47, y: 0.44)]
        let seg = t / 3.2
        let i = Int(seg.rounded(.down))
        let k = min(1, (seg - Double(i)) * 3.2 / 0.7)
        let e = CGFloat((1 - cos(k * .pi)) / 2)
        let a = spots[((i - 1) % spots.count + spots.count) % spots.count], b = spots[(i % spots.count + spots.count) % spots.count]
        return CGPoint(x: a.x + (b.x - a.x) * e, y: a.y + (b.y - a.y) * e)
    }

    /// Feeding runs in 7-second turns, alternating left and right.
    private static func feedSide(_ turn: Int) -> CGFloat { turn % 2 == 0 ? 0.3 : 0.7 }

    /// The fish swims to the side being fed (about 2 seconds), then nibbles in place.
    static func fish(_ t: TimeInterval) -> (x: CGFloat, y: CGFloat, facingRight: Bool, gulp: CGFloat) {
        let turn = Int((t / 7).rounded(.down)), k = t - Double(turn) * 7
        let from = feedSide(turn - 1), to = feedSide(turn)
        let m = min(1, k / 2.2)
        let e = CGFloat((1 - cos(m * .pi)) / 2)
        let x = from + (to - from) * e + (m >= 1 ? 0.03 * CGFloat(sin(k * 2.4)) : 0)
        let facingRight = m < 1 ? to > from : cos(k * 2.4) > 0
        // A little gulp each time a flake reaches the fish.
        let gulpPhase = k > 2.2 ? (k - 2.2).truncatingRemainder(dividingBy: 0.75) : 1
        let gulp: CGFloat = gulpPhase < 0.15 ? 1.12 : 1
        return (x, 0.5 + 0.025 * CGFloat(sin(t * 1.3)), facingRight, gulp)
    }

    /// Flakes drift down from the surface on the fed side; each is eaten when it reaches the fish.
    static func flake(_ i: Int, t: TimeInterval) -> (visible: Bool, x: CGFloat, y: CGFloat, spin: Double) {
        let turn = Int((t / 7).rounded(.down)), k = t - Double(turn) * 7
        let start = 0.2 + Double(i) * 0.35, eatenAt = 2.4 + Double(i) * 0.75
        guard k >= start, k < eatenAt else { return (false, 0, 0, 0) }
        let p = CGFloat((k - start) / (eatenAt - start))
        let side = feedSide(turn)
        let spread = CGFloat((Double(i) * 0.37).truncatingRemainder(dividingBy: 1) - 0.5) * 0.14
        return (true, side + spread * (1 - p * 0.7) + 0.015 * CGFloat(sin(k * 3 + Double(i))), 0.3 + 0.2 * p, k * 90 + Double(i) * 50)
    }

    /// One layer of lava: blurred blobs cut at half opacity so neighbours fuse like wax.
    static func lava(t: TimeInterval, w: CGFloat, h: CGFloat, color: Color, grow: CGFloat) -> some View {
        Canvas { c, size in
            c.addFilter(.alphaThreshold(min: 0.5, color: color))
            c.addFilter(.blur(radius: max(4, size.width * 0.045)))
            c.drawLayer { l in
                // The pool at the bottom, gently heaving.
                let pool = CGRect(x: -size.width * 0.1, y: size.height * (0.8 - 0.02 * sin(t * 0.7)),
                                  width: size.width * 1.2, height: size.height * 0.4)
                l.fill(Path(ellipseIn: pool.insetBy(dx: size.width * 0.1 * (1 - grow), dy: size.height * 0.08 * (1 - grow))), with: .color(.black))
                for i in 0..<5 {
                    let d = Double(i)
                    let period = 9 + d * 2.3
                    let phase = (t / period + d * 0.27).truncatingRemainder(dividingBy: 1)
                    // Rise slowly from the pool, linger near the top, sink back.
                    let rise = (1 - cos(phase * 2 * .pi)) / 2
                    let speed = abs(sin(phase * 2 * .pi))
                    let r = size.width * CGFloat(0.09 + 0.025 * Double(i % 3)) * grow
                    let x = size.width * CGFloat(0.26 + 0.12 * d + 0.04 * sin(t / 3 + d))
                    let y = size.height * CGFloat(0.88 - 0.68 * rise)
                    let stretch = CGFloat(1 + 0.45 * speed)
                    l.fill(Path(ellipseIn: CGRect(x: x - r / stretch, y: y - r * stretch, width: 2 * r / stretch, height: 2 * r * stretch)),
                           with: .color(.black))
                }
            }
        }
        .frame(width: w, height: h)
    }

    /// A resting ball nudged to a new random angle every 4 seconds, easing there over 1.4 seconds.
    static func tumble(_ t: TimeInterval, seed: Int) -> Double {
        func target(_ i: Int) -> Double {
            var x = UInt64(bitPattern: Int64(i &* 2654435761 &+ seed &* 40503))
            x ^= x >> 13; x = x &* 0x5bd1e995; x ^= x >> 15
            return Double(x % 360) - 180
        }
        let seg = t / 4
        let i = Int(seg.rounded(.down))
        let k = min(1, (seg - Double(i)) * 4 / 1.4)
        let e = (1 - cos(k * .pi)) / 2
        let a = target(i - 1), b = target(i)
        var d = (b - a).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 } else if d < -180 { d += 360 }
        return a + d * e
    }

    private static let sprinkleColors: [Color] = [GumPalette.rgb(0xFFFFFF), GumPalette.rgb(0x3DA5FF), GumPalette.rgb(0xFFD43B), GumPalette.rgb(0x3DDC97)]

    /// One glaze sprinkle on the donut, catching the light in turn.
    static func glazeSprinkle(_ i: Int, t: Double, w: CGFloat, h: CGFloat) -> some View {
        let a: Double = Double(i) * 0.9
        let glint: Double = max(0, sin(t * 2.2 + Double(i) * 1.7))
        let x: CGFloat = CGFloat(cos(a)) * w * 0.3
        let y: CGFloat = CGFloat(sin(a)) * h * 0.18 - h * 0.12
        return Capsule().fill(sprinkleColors[i % 4])
            .overlay(Capsule().fill(Color.white.opacity(glint * 0.8)))
            .frame(width: max(4, w * 0.035), height: max(1.5, w * 0.012))
            .scaleEffect(1 + 0.15 * glint)
            .rotationEffect(.radians(a * 2))
            .offset(x: x, y: y)
    }

    private static let soapColors: [Color] = [GumPalette.rgb(0xFFB3D9), GumPalette.rgb(0xB8E0FF), GumPalette.rgb(0xD7B8FF), GumPalette.rgb(0xFFB3D9)]

    /// One tiny bubble drifting up off the soap bubble, wobbling and fading.
    static func soapBubble(_ i: Int, t: Double, w: CGFloat, hidden: Bool) -> some View {
        let d: Double = Double(i)
        let period: Double = 4.5 + d.truncatingRemainder(dividingBy: 3) * 1.3
        let phase: Double = ((t + d * 0.83) / period).truncatingRemainder(dividingBy: 1)
        let size: CGFloat = w * (0.025 + 0.012 * CGFloat(i % 4))
        let lane: CGFloat = CGFloat((d * 0.37).truncatingRemainder(dividingBy: 1))
        let wobble: CGFloat = CGFloat(sin(t * 2 + d))
        let x: CGFloat = w * (0.25 + 0.5 * lane) + w * 0.04 * wobble
        let y: CGFloat = w * 0.12 - w * 0.75 * CGFloat(phase)
        let fade: Double = hidden ? 0 : (phase < 0.1 ? phase * 10 : 1 - phase)
        let line: CGFloat = max(1, size * 0.12)
        let dot: CGFloat = size * 0.25
        let nudge: CGFloat = -size * 0.2
        let rim = AngularGradient(colors: soapColors, center: .center)
        let glint = Circle().fill(Color.white.opacity(0.9)).frame(width: dot, height: dot).offset(x: nudge, y: nudge)
        return Circle()
            .stroke(rim, lineWidth: line)
            .background(Circle().fill(Color.white.opacity(0.35)))
            .overlay(glint)
            .frame(width: size, height: size)
            .position(x: x, y: y)
            .opacity(fade)
    }

    private static let fallColors: [Color] = [GumPalette.rgb(0xFFFFFF), GumPalette.rgb(0x3DA5FF), GumPalette.rgb(0xFFD43B), GumPalette.rgb(0x3DDC97), GumPalette.rgb(0xF48FB1)]

    /// One sprinkle tumbling down onto the donut from above.
    static func fallingSprinkle(_ i: Int, t: Double, w: CGFloat, hidden: Bool) -> some View {
        let d: Double = Double(i)
        let period: Double = 2.2 + (d * 0.37).truncatingRemainder(dividingBy: 1) * 1.2
        let phase: Double = ((t + d * 0.41) / period).truncatingRemainder(dividingBy: 1)
        let x: CGFloat = w * (0.22 + 0.56 * CGFloat((d * 0.61).truncatingRemainder(dividingBy: 1)))
        let y: CGFloat = -w * 0.55 + w * 0.7 * CGFloat(phase)
        let fade: Double = hidden ? 0 : (phase > 0.85 ? (1 - phase) / 0.15 : 1)
        return Capsule().fill(fallColors[i % 5])
            .frame(width: max(4, w * 0.035), height: max(1.5, w * 0.012))
            .rotationEffect(.degrees(phase * 540 + d * 40))
            .position(x: x, y: y)
            .opacity(fade)
    }

    /// One snowflake falling inside the snowball, swaying as it goes and starting again at the top.
    static func snowflake(_ i: Int, t: Double, w: CGFloat, h: CGFloat) -> some View {
        let d: Double = Double(i)
        let period: Double = 7 + (d * 0.53).truncatingRemainder(dividingBy: 1) * 5
        let phase: Double = ((t + d * 1.7) / period).truncatingRemainder(dividingBy: 1)
        let lane: CGFloat = CGFloat((d * 0.618).truncatingRemainder(dividingBy: 1))
        let sway: CGFloat = 0.04 * CGFloat(sin(t * 0.9 + d * 2))
        let size: CGFloat = max(7, w * (0.03 + 0.02 * CGFloat(i % 3)))
        let x: CGFloat = w * (0.12 + 0.76 * lane + sway)
        let y: CGFloat = h * CGFloat(-0.05 + 1.1 * phase)
        return Image(systemName: "snowflake")
            .font(.system(size: size))
            .foregroundStyle(Color.white.opacity(0.9))
            .rotationEffect(.degrees(t * 30 + d * 40))
            .position(x: x, y: y)
    }

    /// One crater on the turning moon. The second half of the list is the far side (the same craters flipped).
    static func crater(_ i: Int, t: Double, w: CGFloat, h: CGFloat, dark: Color) -> some View {
        let n: Int = craters.count
        let c = craters[i % n]
        let back: Bool = i >= n
        let lat: Double = Double(2 * (back ? 1 - c.1 : c.1) - 1)
        let row: Double = max(0.05, (1 - lat * lat).squareRoot())
        let lon0: Double = asin(min(1, max(-1, Double(2 * c.0 - 1) / row))) + (back ? .pi : 0)
        let lon: Double = lon0 + t * 2 * .pi / 40
        let facing: Double = cos(lon)
        let x: CGFloat = w * CGFloat(0.5 + 0.5 * sin(lon) * row)
        let y: CGFloat = h * CGFloat((lat + 1) / 2)
        let size: CGFloat = w * c.2
        let squash: CGFloat = CGFloat(max(0.05, facing))
        return ZStack {
            Ellipse().fill(dark.opacity(0.22))
            Ellipse().stroke(Color.white.opacity(0.35), lineWidth: max(1, size * 0.08))
                .offset(x: -size * 0.06, y: -size * 0.06)
        }
        .frame(width: size * squash, height: size * 0.8)
        .blur(radius: max(1, w * 0.004))
        .opacity(facing > 0 ? min(1, facing * 3) : 0)
        .position(x: x, y: y)
    }

    static let patches: [(CGFloat, CGFloat, CGFloat, Double)] = [
        (0.5, 0.38, 0.2, 0), (0.22, 0.3, 0.13, 20), (0.78, 0.3, 0.13, -20), (0.3, 0.68, 0.14, 40),
        (0.7, 0.68, 0.14, -40), (0.5, 0.92, 0.1, 0), (0.08, 0.55, 0.08, 10), (0.92, 0.55, 0.08, -10),
    ]
    static let flakes: [(CGFloat, CGFloat, CGFloat)] = [
        (0.38, 0.22, 0.06), (0.65, 0.32, 0.045), (0.48, 0.45, 0.035), (0.25, 0.48, 0.04), (0.72, 0.58, 0.05),
    ]
}

/// Sparkly dots for glitter.
/// A slow spin at rest that drifts one way, eases off and turns back the other way, never quite repeating.
struct RestSpin: ViewModifier {
    let on: Bool
    let paused: Bool
    let seed: Double

    func body(content: Content) -> some View {
        if on {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused)) { tl in
                let t = paused ? 0 : tl.date.timeIntervalSinceReferenceDate
                content.rotationEffect(.degrees(150 * sin(t / 11 + seed) + 90 * sin(t / 6.3 + seed * 2.1)))
            }
        } else {
            content
        }
    }
}

/// A double heartbeat (lub-dub) every 4.5 seconds; 0 at rest, up to 1 on the beat.
enum HeartBeat {
    static func beat(_ t: Double) -> Double {
        let k = t.truncatingRemainder(dividingBy: 4.5)
        func bump(_ at: Double, _ size: Double) -> Double {
            let x = (k - at) / 0.18
            return x > 0 && x < 1 ? size * sin(x * .pi) : 0
        }
        return bump(0, 1) + bump(0.28, 0.7)
    }
}

/// The Easter egg rocks side to side every 8 seconds, as if something inside is about to hatch.
enum EggRock {
    /// Rotation in degrees.
    static func angle(_ t: Double) -> Double {
        let k = t.truncatingRemainder(dividingBy: 8)
        guard k < 1.6 else { return 0 }
        return 7 * exp(-k * 1.6) * sin(k * 2 * .pi * 2)
    }

    /// How visible the crack is: it shows as the egg rocks, then fades.
    static func crack(_ t: Double) -> Double {
        let k = t.truncatingRemainder(dividingBy: 8)
        return k < 0.3 ? k / 0.3 : max(0, 1 - (k - 0.3) / 2.5)
    }
}

/// An egg outline: narrow at the top, full and heavy at the bottom (the water balloon and the Easter egg).
struct EggShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX, cy = rect.midY, rx = rect.width / 2, ry = rect.height / 2
        let steps = 96
        for n in 0...steps {
            let t = Double(n) / Double(steps) * 2 * .pi
            // sin(t) is -1 at the top and 1 at the bottom: pinch the top, fill out the bottom.
            let m = (1 + 0.16 * sin(t)) / 1.06
            let pt = CGPoint(x: cx + rx * CGFloat(cos(t) * m), y: cy + ry * CGFloat(sin(t)))
            if n == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

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
            case .cherry, .orange:
                ZStack {
                    Capsule().fill(GumPalette.rgb(0x5A3A1E)).frame(width: max(2, w * 0.018), height: w * 0.14).rotationEffect(.degrees(15)).offset(y: -w * 0.05)
                    Ellipse().fill(GumPalette.rgb(0x3DAA5C)).frame(width: w * 0.12, height: w * 0.05).rotationEffect(.degrees(-25)).offset(x: w * 0.06, y: -w * 0.08)
                }
                .position(x: w / 2, y: w * 0.01)
            case .clock:
                HStack(spacing: w * 0.25) {
                    Circle().fill(GumPalette.rgb(0xB8B4AA)).frame(width: w * 0.13, height: w * 0.13)
                    Circle().fill(GumPalette.rgb(0xB8B4AA)).frame(width: w * 0.13, height: w * 0.13)
                }
                .position(x: w / 2, y: w * 0.02)
            case .yarn:
                Circle().trim(from: 0.55, to: 0.95).stroke(palette.base, style: StrokeStyle(lineWidth: max(2, w * 0.012), lineCap: .round))
                    .frame(width: w * 0.3, height: w * 0.3).position(x: w * 0.72, y: w * 0.0)
            case .planet:
                // The ring, tilted across the ball.
                // The ring wobbles: its tilt and openness sway slowly.
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { tl in
                    let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                    Ellipse()
                        .stroke(LinearGradient(colors: [GumPalette.rgb(0xF5DEB3), GumPalette.rgb(0xC8A06A), GumPalette.rgb(0xF5DEB3)], startPoint: .leading, endPoint: .trailing),
                                lineWidth: max(4, w * 0.035))
                        .frame(width: w * 1.45, height: w * (0.28 + 0.06 * CGFloat(sin(t * 0.9))))
                        .rotationEffect(.degrees(-12 + 5 * sin(t * 0.7)))
                        .position(x: w / 2, y: (h ?? w) / 2)
                }
            case .soap:
                // Tiny bubbles drifting up off the top, wobbling as they rise and fading away.
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { tl in
                    let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                    ZStack {
                        ForEach(0..<9, id: \.self) { i in
                            ThemeMarks.soapBubble(i, t: t, w: w, hidden: reduceMotion)
                        }
                    }
                }
            case .donut:
                // Sprinkles raining down onto the donut from above, tumbling as they fall.
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { tl in
                    let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                    ZStack {
                        ForEach(0..<12, id: \.self) { i in
                            ThemeMarks.fallingSprinkle(i, t: t, w: w, hidden: reduceMotion)
                        }
                    }
                }
            case .dandelion:
                // A ragged, fluffy rim: wisps poking out past the edge, swaying with the seeds.
                TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { tl in
                    let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                    let hh = h ?? w
                    Canvas { ctx, size in
                        let c = CGPoint(x: size.width / 2, y: size.height / 2)
                        for k in 0..<90 {
                            let a = Double(k) / 90 * 2 * .pi + 0.05 * sin(t * 0.9 + Double(k) * 0.4)
                            let rx = size.width / 2, ry = size.height / 2
                            let inner = CGPoint(x: c.x + cos(a) * rx * 0.94, y: c.y + sin(a) * ry * 0.94)
                            let out = 1.0 + 0.05 + 0.06 * abs(sin(Double(k) * 1.7))
                            let tip = CGPoint(x: c.x + cos(a) * rx * out, y: c.y + sin(a) * ry * out)
                            var p = Path(); p.move(to: inner); p.addLine(to: tip)
                            ctx.stroke(p, with: .color(.white.opacity(0.75)), lineWidth: 0.8)
                            ctx.fill(Path(ellipseIn: CGRect(x: tip.x - 1.5, y: tip.y - 1.5, width: 3, height: 3)), with: .color(.white.opacity(0.9)))
                        }
                    }
                    .frame(width: w, height: hh)
                }
            case .valentine:
                // Little hearts slip out on each beat and float slowly up and away.
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { tl in
                    let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                    ZStack {
                        ForEach(0..<6, id: \.self) { i in
                            ThemeTopper.floatingHeart(i, t: t, w: w, hidden: reduceMotion)
                        }
                    }
                }
            case .waterBalloon:
                // The neck pinching up from the top, the tied knot, and the rolled lip poking out of it.
                Path { p in
                    p.move(to: CGPoint(x: w * 0.455, y: w * 0.012))
                    p.addQuadCurve(to: CGPoint(x: w * 0.482, y: -w * 0.05), control: CGPoint(x: w * 0.478, y: -w * 0.012))
                    p.addLine(to: CGPoint(x: w * 0.518, y: -w * 0.05))
                    p.addQuadCurve(to: CGPoint(x: w * 0.545, y: w * 0.012), control: CGPoint(x: w * 0.522, y: -w * 0.012))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [palette.light, palette.base, palette.dark], startPoint: .leading, endPoint: .trailing))
                Ellipse().fill(RadialGradient(colors: [palette.light, palette.dark], center: UnitPoint(x: 0.35, y: 0.35), startRadius: 0, endRadius: w * 0.04))
                    .frame(width: w * 0.07, height: w * 0.05).position(x: w / 2, y: -w * 0.062)
                Capsule().fill(palette.base)
                    .frame(width: w * 0.05, height: w * 0.022).rotationEffect(.degrees(-25)).position(x: w * 0.528, y: -w * 0.09)
                Capsule().stroke(palette.dark.opacity(0.6), lineWidth: max(1, w * 0.004))
                    .frame(width: w * 0.05, height: w * 0.022).rotationEffect(.degrees(-25)).position(x: w * 0.528, y: -w * 0.09)
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
        case .soccer:
            if i == 0 { Text("⚽").font(.system(size: emoji)) }
            else if i % 3 == 0 { Pentagon().fill(Color.black.opacity(0.85)).frame(width: small * 0.7, height: small * 0.7) }
            else { Capsule().fill(i % 2 == 0 ? GumPalette.rgb(0x2EA84F) : GumPalette.rgb(0x1E7A38)).frame(width: 3, height: small * 0.8) }
        case .hockey:
            if i == 0 { Text("🏒").font(.system(size: emoji)) }
            else if i == 4 { Ellipse().fill(GumPalette.rgb(0x1C1C1E)).frame(width: side * 0.6, height: side * 0.25) }
            else { Circle().fill(Color.white).overlay(Circle().stroke(GumPalette.rgb(0xA9D3F0), lineWidth: 1)).frame(width: small * 0.5, height: small * 0.5) }
        case .tennis:
            if i == 0 { Text("🎾").font(.system(size: emoji)) }
            else { Circle().fill(GumPalette.rgb(0xCCE03A)).frame(width: small * 0.5, height: small * 0.5).blur(radius: 1) }
        case .golf:
            if i == 0 { Text("⛳").font(.system(size: emoji)) }
            else if i % 2 == 0 { Circle().fill(Color.white).overlay(Circle().stroke(Color.gray.opacity(0.4), lineWidth: 1)).frame(width: small * 0.5, height: small * 0.5) }
            else { Capsule().fill(GumPalette.rgb(0x2EA84F)).frame(width: 3, height: small * 0.7) }
        case .baseball:
            if i == 0 { Text("⚾").font(.system(size: emoji)) }
            else { Capsule().fill(GumPalette.rgb(0xC62828)).frame(width: small * 0.6, height: 3).rotationEffect(.degrees(Double(i) * 37)) }
        case .bowling:
            if i == 0 { Text("🎳").font(.system(size: emoji)) }
            else { Capsule().fill(Color.white).overlay(Capsule().fill(GumPalette.rgb(0xC62828)).frame(height: 2)).frame(width: small * 0.35, height: small).shadow(radius: 1) }
        case .pixel:
            if i == 0 { Text("👾").font(.system(size: emoji)) }
            else { Rectangle().fill([GumPalette.rgb(0xFF5A5A), GumPalette.rgb(0xFFD43B), GumPalette.rgb(0x3DA5FF), GumPalette.rgb(0x3DDC97)][i % 4]).frame(width: small * 0.5, height: small * 0.5) }
        case .gumball, .cherry, .orange, .macaron, .cakePop, .earth, .sun, .dandelion, .atom, .geode,
             .yarn, .arcadeButton, .clock, .marble, .duck, .easterEgg, .valentine, .fireworks, .beachBall, .zen:
            let look = simpleDebris(palette)
            if i == 0, let e = look.emoji { Text(e).font(.system(size: emoji)) }
            else if look.round { Circle().fill(look.colors[i % look.colors.count]).frame(width: small * 0.6, height: small * 0.6) }
            else { FourPointStar().fill(look.colors[i % look.colors.count]).frame(width: small * 0.8, height: small * 0.8) }
        case .lavaLamp:
            Ellipse().fill(i % 2 == 0 ? GumPalette.rgb(0xFFC23A) : GumPalette.rgb(0xFF7A3D)).frame(width: side * 0.7, height: side * 0.8).blur(radius: 3)
        default:
            EmptyView()
        }
    }

    /// Emoji and piece colors for the simpler themes.
    static func simpleDebris(_ p: GumPalette) -> (emoji: String?, colors: [Color], round: Bool) {
        let c = GumPalette.rgb
        switch p {
        case .gumball: return ("🍬", [c(0xFF5A5A), c(0xFFD43B), c(0x3DA5FF), c(0x3DDC97), c(0xFF7FB0)], true)
        case .cherry: return ("🍒", [c(0xC8102E), c(0x8A0A1E)], true)
        case .orange: return ("🍊", [c(0xF28C1E), c(0xFFC27A)], true)
        case .macaron: return (nil, [c(0xF7B7CF), c(0xFFF6E8), c(0xB5F2D6)], true)
        case .cakePop: return ("🧁", [c(0xF48FB1), c(0x3DA5FF), c(0xFFD43B), .white], false)
        case .earth: return ("🌍", [c(0xFFE08A), .white, c(0x8CC4FF)], false)
        case .sun: return ("☀️", [c(0xFFB020), c(0xFFF0A0), c(0xFF7A1A)], false)
        case .dandelion: return (nil, [.white, c(0xE8EADF)], true)
        case .atom: return ("⚛️", [c(0x8AB4FF), .white], false)
        case .geode: return ("💎", [c(0x9B5CFF), c(0xD7B8FF), c(0x8E8A84)], false)
        case .yarn: return ("🧶", [c(0xD8456B), c(0xFF9AB4)], true)
        case .arcadeButton: return ("🔴", [c(0xE02020), c(0xFFD43B)], false)
        case .clock: return ("⏰", [c(0xC62828), .black], false)
        case .marble: return (nil, [c(0xBFE0F5), c(0xFF5A5A), c(0xFFD43B), c(0x3DA5FF)], true)
        case .duck: return ("🦆", [c(0x5BB5E0), .white], true)
        case .easterEgg: return ("🐣", [c(0xFFB3D9), c(0xFFF1A8), c(0xB5F2D6), c(0xD7B8FF)], false)
        case .valentine: return ("💕", [c(0xE8336B), c(0xFF9AB8), .white], false)
        case .fireworks: return ("🎆", [c(0xFFD43B), c(0xFF5AA0), c(0x5AE0FF), .white], false)
        case .beachBall: return ("🏖️", [c(0xE53935), c(0x1E88E5), c(0xFDD835), c(0xE8D4A8)], true)
        case .zen: return (nil, [c(0xD0D0CA), c(0x9A9A94)], true)
        default: return (nil, [.white], true)
        }
    }

    static func handles(_ palette: GumPalette) -> Bool {
        palette != .bubblegum && palette != .coral && palette != .unicorn && palette != .fortune
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

/// A regular pentagon, point up, for the soccer ball.
struct Pentagon: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        for k in 0..<5 {
            let a = -Double.pi / 2 + Double(k) * 2 * .pi / 5
            let pt = CGPoint(x: r.midX + cos(a) * r.width / 2, y: r.midY + sin(a) * r.height / 2)
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

extension ThemeTopper {
    /// One small heart leaving the Valentine ball and floating slowly up and away, fading as it goes.
    static func floatingHeart(_ i: Int, t: Double, w: CGFloat, hidden: Bool) -> some View {
        let d: Double = Double(i)
        let period: Double = 9
        // Each heart starts on a beat (beats are every 4.5 s), staggered across two cycles of three.
        let phase: Double = ((t - d * 1.5) / period).truncatingRemainder(dividingBy: 1)
        let p: Double = phase < 0 ? phase + 1 : phase
        let lane: CGFloat = CGFloat((d * 0.37).truncatingRemainder(dividingBy: 1)) - 0.5
        let x: CGFloat = w * (0.5 + 0.35 * lane) + w * 0.05 * CGFloat(sin(t * 0.8 + d))
        let y: CGFloat = w * 0.2 - w * 1.6 * CGFloat(p)
        let size: CGFloat = max(10, w * (0.05 + 0.015 * CGFloat(i % 3)))
        let fade: Double = hidden ? 0 : (p < 0.08 ? p / 0.08 : (1 - p) * 0.9)
        return Image(systemName: "heart.fill")
            .font(.system(size: size))
            .foregroundStyle(GumPalette.rgb(0xFF9AB8))
            .rotationEffect(.degrees(12 * sin(t + d)))
            .position(x: x, y: y)
            .opacity(fade)
    }
}
