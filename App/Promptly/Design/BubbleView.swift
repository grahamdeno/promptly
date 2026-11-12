import SwiftUI

/// The gum bubble, and the screen's main button: tap it to pop it.
///
/// `.bubble` style inflates in small puffs as the meeting nears (each easing out, no bounce), stretches upward and
/// thins as it grows, swells slowly near the start and trembles at the start. Tapping pops it like real gum: the film
/// tears into oddly shaped scraps and strands that fly up and outward, tumble and fall away over about a second,
/// leaving a small lump at the bottom edge that the next bubble inflates out of. `.steady` keeps one size but still pops.
/// It also pops when `popCount` changes (for "Not going"). Anchored to the bottom edge, mostly below the screen.
struct BubbleView: View {
    var progress: Double
    /// Seconds since the meeting started (0 before it). Past the start, new bubbles bud off the first one about a
    /// minute apart, then everything swells into one bubble that fills the screen.
    var overdue: TimeInterval = 0
    var style: BallStyle
    var popCount: Int
    /// "Not going": the bubble shrinks away and a fresh one grows back, with no pop.
    var skipCount: Int = 0
    /// Kept for callers; the bubble no longer shows text.
    var hint: String? = nil
    var accessibilityTitle: String = "Pop the bubble"
    var minSize: CGFloat = 150
    var maxSize: CGFloat = 880
    var steadySize: CGFloat = 300
    var onPop: (() -> Void)? = nil

    @State private var popScale = CGSize(width: 1, height: 1)
    @State private var opacity: Double = 1
    @State private var regrowScale: CGFloat = 1
    @State private var showPieces = false
    @State private var piecesUp = false
    @State private var piecesDown = false
    @State private var showLump = false
    @State private var lumpScale: CGFloat = 0.6
    @State private var popping = false
    /// Every few seconds a fingertip presses a small dent into the bubble, inviting a tap. No text on the gum.
    @State private var poked = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.themeStill) private var themeStill

    /// Inflates in breaths: 36 puffs from empty to full.
    private var puff: Double {
        style == .bubble ? (min(1, max(0, progress)) * 36).rounded(.down) / 36 : 0.4
    }

    private var width: CGFloat {
        style == .bubble ? minSize + CGFloat(puff) * (themeMax - minSize) : steadySize
    }
    /// Grenade stays smaller so its fuze, spoon and pin stay in view below the meeting card, even at full size.
    private var themeMax: CGFloat {
        GumPalette.current == .grenade ? max(minSize, maxSize * 0.55) : maxSize
    }

    private var height: CGFloat { width * (1 + 0.1 * CGFloat(puff)) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                TimelineView(.animation(paused: reduceMotion || style == .steady || progress < 0.7)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let m = idleMotion(t)
                    bubbleButton
                        .scaleEffect(x: m.sx * popScale.width * regrowScale * merge, y: m.sy * popScale.height * regrowScale * merge,
                                     anchor: .bottom)
                        .offset(x: m.dx, y: m.dy)
                        .opacity(opacity)
                }
                if style == .bubble && !popping && overdue > 0 { sprouts }
                if showPieces { pieces }
                if showPieces && GumPalette.current == .unicorn && !reduceMotion { sprinkles }
                if showLump { lump }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            .offset(y: height * 0.42)
        }
        .animation(.timingCurve(0.2, 0.7, 0.3, 1, duration: 0.9), value: puff)
        .animation(.timingCurve(0.2, 0.7, 0.3, 1, duration: 1.8), value: overdueStep)
        .onChange(of: popCount) { _, _ in
            if !popping { burst(then: nil) }
        }
        .onChange(of: skipCount) { _, _ in
            guard !popping else { return }
            popping = true
            withAnimation(.easeIn(duration: 0.35)) { regrowScale = 0.05; opacity = reduceMotion ? 0 : 0.6 }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(380))
                opacity = 1
                withAnimation(.timingCurve(0.2, 0.7, 0.3, 1, duration: reduceMotion ? 0.3 : 1.0)) { regrowScale = 1 }
                try? await Task.sleep(for: .milliseconds(600))
                popping = false
            }
        }
        .task(id: onPop != nil) { await pokeLoop() }
    }

    /// The dent: a soft shadowed hollow near the top of the visible gum.
    private var pokeDimple: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let size = max(34, w * 0.11)
            Ellipse()
                .fill(RadialGradient(colors: [Color(red: 0.47, green: 0.08, blue: 0.02).opacity(0.38),
                                              GumColors.dark.opacity(0.12), .clear],
                                     center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: size * 0.6))
                .overlay(Ellipse().stroke(.white.opacity(0.35), lineWidth: 1.5).blur(radius: 1.5).offset(y: -2))
                .frame(width: size, height: size * 0.74)
                .scaleEffect(poked ? 1 : 0.3)
                .opacity(poked && !popping ? 1 : 0)
                .position(x: w * 0.6, y: h * 0.2)
        }
        .allowsHitTesting(false)
    }

    private func pokeLoop() async {
        guard onPop != nil, !reduceMotion else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(4))
            guard !popping, !Task.isCancelled else { continue }
            withAnimation(.easeOut(duration: 0.16)) { poked = true }
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.timingCurve(0.2, 0.7, 0.3, 1, duration: 0.5)) { poked = false }
        }
    }

    // MARK: The bubble

    private var bubbleButton: some View {
        Button {
            guard !popping, onPop != nil else { return }
            burst(then: onPop)
        } label: {
            GumBubbleShape(thinness: puff)
                .frame(width: width, height: height)
                .overlay { if onPop != nil { pokeDimple } }
                .scaleEffect(x: poked ? 1.008 : 1, y: poked ? 0.992 : 1, anchor: .bottom)
                .modifier(ThemeIdle(palette: GumPalette.current, paused: reduceMotion || themeStill || ScreenshotMode.isOn || popping))
                .contentShape(Ellipse())
        }
        .buttonStyle(.plain)
        .disabled(onPop == nil)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityHint("Pops the bubble")
        .accessibilityHidden(onPop == nil)
    }

    /// Slow swelling near the start, a tremble that builds over the last few minutes, strongest at the start.
    /// No bounce.
    private func idleMotion(_ t: TimeInterval) -> (sx: CGFloat, sy: CGFloat, dx: CGFloat, dy: CGFloat) {
        guard style == .bubble, !reduceMotion, !popping else { return (1, 1, 0, 0) }
        if progress >= 1 {
            return (1.02, 1.03, CGFloat(1.2 * sin(t * 45)), CGFloat(0.9 * sin(t * 53 + 1)))
        }
        if progress > 0.7 {
            let s = (1 - cos(t * 2 * .pi / 2.8)) / 2
            // From 90 percent the tremble fades in and grows toward the start.
            let shake = progress > 0.9 ? 0.9 * (progress - 0.9) / 0.1 : 0
            return (CGFloat(1 + 0.012 * s), CGFloat(1 + 0.022 * s),
                    CGFloat(shake * sin(t * 45)), CGFloat(shake * 0.7 * sin(t * 53 + 1)))
        }
        return (1, 1, 0, 0)
    }

    // MARK: Overdue: more bubbles, then one big one

    /// Overdue time in 2-second steps, so growth eases in small puffs like the main bubble.
    private var overdueStep: Double {
        guard style == .bubble, !reduceMotion else { return 0 }
        return (overdue / 2).rounded(.down) * 2
    }

    /// Where each new bubble buds from (share of the main bubble's frame) and how big it gets (share of its width).
    private static let buds: [(x: CGFloat, y: CGFloat, size: CGFloat, startsAt: Double)] = [
        (x: 0.16, y: 0.16, size: 0.42, startsAt: 15),
        (x: 0.86, y: 0.20, size: 0.48, startsAt: 40),
        (x: 0.52, y: -0.06, size: 0.56, startsAt: 70),
    ]

    /// From about two minutes past the start, everything swells into one bubble over the next 50 seconds.
    private var mergeProgress: CGFloat {
        CGFloat(min(1, max(0, (overdueStep - 110) / 50)))
    }

    /// The main bubble's extra scale while merging: big enough to cover the whole screen.
    private var merge: CGFloat { 1 + mergeProgress * 1.7 }

    private var sprouts: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<Self.buds.count, id: \.self) { i in
                let bud = Self.buds[i]
                let grow = CGFloat(min(1, max(0, (overdueStep - bud.startsAt) / 30)))
                let side = width * bud.size * max(0.001, grow) * (1 + mergeProgress * 0.8)
                GumBubbleShape(thinness: 0.6 + 0.3 * Double(grow),
                               tint: nil)
                    .frame(width: side, height: side * 1.05)
                    .position(x: width * bud.x, y: height * bud.y)
                    .opacity(grow > 0 ? Double(1 - mergeProgress) : 0)
            }
        }
        .frame(width: width, height: height)
        .scaleEffect(merge, anchor: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Pop

    /// The scraps a pop leaves: where each starts on the bubble (unit coordinates), its size as a share of the
    /// bubble's width, how far it flies (points: sideways, up), how far it then falls, how much it spins, and whether
    /// it's a stretched strand rather than a scrap.
    private struct Scrap {
        let start: UnitPoint
        let size: CGFloat
        let fly: CGSize
        let fall: CGFloat
        let spin: Double
        let strand: Bool
        let seed: Int
    }

    private static let scraps: [Scrap] = [
        Scrap(start: .init(x: 0.50, y: 0.08), size: 0.22, fly: .init(width: 10, height: -330), fall: 260, spin: 160, strand: false, seed: 1),
        Scrap(start: .init(x: 0.30, y: 0.16), size: 0.26, fly: .init(width: -150, height: -260), fall: 300, spin: -210, strand: false, seed: 2),
        Scrap(start: .init(x: 0.70, y: 0.15), size: 0.24, fly: .init(width: 160, height: -280), fall: 290, spin: 230, strand: false, seed: 3),
        Scrap(start: .init(x: 0.16, y: 0.34), size: 0.20, fly: .init(width: -210, height: -150), fall: 340, spin: -140, strand: false, seed: 4),
        Scrap(start: .init(x: 0.84, y: 0.33), size: 0.21, fly: .init(width: 220, height: -170), fall: 330, spin: 170, strand: false, seed: 5),
        Scrap(start: .init(x: 0.42, y: 0.22), size: 0.16, fly: .init(width: -70, height: -380), fall: 240, spin: 300, strand: true, seed: 6),
        Scrap(start: .init(x: 0.60, y: 0.24), size: 0.15, fly: .init(width: 90, height: -360), fall: 250, spin: -280, strand: true, seed: 7),
        Scrap(start: .init(x: 0.24, y: 0.48), size: 0.17, fly: .init(width: -180, height: -90), fall: 360, spin: 120, strand: true, seed: 8),
        Scrap(start: .init(x: 0.78, y: 0.50), size: 0.14, fly: .init(width: 190, height: -110), fall: 350, spin: -150, strand: false, seed: 9),
        Scrap(start: .init(x: 0.55, y: 0.05), size: 0.07, fly: .init(width: 40, height: -420), fall: 220, spin: 400, strand: false, seed: 10),
        Scrap(start: .init(x: 0.38, y: 0.10), size: 0.06, fly: .init(width: -60, height: -400), fall: 230, spin: -380, strand: false, seed: 11),
        Scrap(start: .init(x: 0.66, y: 0.40), size: 0.08, fly: .init(width: 120, height: -300), fall: 280, spin: 260, strand: true, seed: 12),
    ]

    /// Unicorn mode: which confetti pieces are unicorns.
    private static let unicornSlots: Set<Int> = [0, 4, 9]

    /// Cake sprinkles for Unicorn mode: little rounded rods in the rainbow, flung out with the confetti.
    private struct Sprinkle {
        let start: UnitPoint
        let fly: CGSize
        let fall: CGFloat
        let spin: Double
        let angle: Double
        let color: Int
    }

    private static let sprinkleSet: [Sprinkle] = {
        var rng = SeededRandom(seed: 42)
        return (0..<36).map { i in
            let a = Double(i) / 36 * 2 * .pi + rng.next() * 0.4
            let reach = 140 + rng.next() * 260
            return Sprinkle(start: UnitPoint(x: 0.3 + rng.next() * 0.4, y: 0.08 + rng.next() * 0.35),
                            fly: CGSize(width: cos(a) * reach, height: -abs(sin(a)) * reach - 80),
                            fall: 220 + rng.next() * 180, spin: (rng.next() - 0.5) * 720,
                            angle: rng.next() * 180, color: i % 5)
        }
    }()

    private var sprinkles: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<Self.sprinkleSet.count, id: \.self) { i in
                let sp = Self.sprinkleSet[i]
                Capsule()
                    .fill(GumPalette.rainbow.at(sp.color) ?? .pink)
                    .frame(width: 14, height: 4.5)
                    .rotationEffect(.degrees(sp.angle + (piecesDown ? sp.spin : (piecesUp ? sp.spin * 0.4 : 0))))
                    .position(x: width * sp.start.x, y: height * sp.start.y)
                    .offset(x: piecesDown ? sp.fly.width * 1.2 : (piecesUp ? sp.fly.width : 0),
                            y: piecesDown ? sp.fly.height + sp.fall : (piecesUp ? sp.fly.height : 0))
                    .opacity(piecesDown ? 0 : 1)
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The scraps fly up and outward, tumbling, then fall away and fade.
    private var pieces: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<Self.scraps.count, id: \.self) { i in
                let scrap = Self.scraps[i]
                let side = width * scrap.size
                let fallScale: CGFloat = 1.25
                Group {
                    if ThemeDebris.handles(GumPalette.current) {
                        ThemeDebris.piece(GumPalette.current, index: i, side: side)
                    } else if GumPalette.current == .fortune {
                        // Fortune: puffs of violet mist and little star sparks.
                        if i % 3 == 0 {
                            FourPointStar().fill(i % 2 == 0 ? GumPalette.violetDeep : GumPalette.rgb(0xF5B82E))
                                .frame(width: max(26, side * 0.55), height: max(26, side * 0.55))
                                .shadow(color: GumPalette.violet.opacity(0.6), radius: 6)
                        } else {
                            Circle().fill(GumPalette.violet.opacity(0.65))
                                .frame(width: side * 1.3, height: side * 1.3)
                                .blur(radius: side * 0.22)
                        }
                    } else if GumPalette.current == .unicorn {
                        if Self.unicornSlots.contains(i) {
                            Text("🦄").font(.system(size: max(26, side * 0.5)))
                        } else {
                            ConfettiPiece(index: i).frame(width: max(18, side * 0.45), height: max(18, side * 0.45))
                        }
                    } else {
                        GumScrap(seed: scrap.seed, strand: scrap.strand)
                            .frame(width: scrap.strand ? side * 1.9 : side, height: scrap.strand ? side * 0.42 : side * 0.82)
                    }
                }
                    .rotationEffect(.degrees(piecesDown ? scrap.spin : (piecesUp ? scrap.spin * 0.45 : 0)))
                    .scaleEffect(piecesDown ? 0.55 : (piecesUp ? 0.9 : 1))
                    .position(x: width * scrap.start.x, y: height * scrap.start.y)
                    .offset(x: piecesDown ? scrap.fly.width * fallScale : (piecesUp ? scrap.fly.width : 0),
                            y: piecesDown ? scrap.fly.height + scrap.fall : (piecesUp ? scrap.fly.height : 0))
                    .opacity(piecesDown ? 0 : 1)
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The crumpled gum left at the bottom edge, out of which the next bubble inflates.
    private var lump: some View {
        ZStack {
            Ellipse().fill(GumColors.dark.opacity(0.9)).frame(width: 64, height: 30).offset(x: -10, y: 2)
            Ellipse().fill(GumColors.coral).frame(width: 58, height: 28).offset(x: 9, y: -2)
            Ellipse().fill(GumColors.light.opacity(0.9)).frame(width: 30, height: 12).offset(x: -4, y: -8)
            Ellipse().stroke(GumColors.dark.opacity(0.5), lineWidth: 1.5).frame(width: 26, height: 10).offset(x: 14, y: 2)
        }
        .scaleEffect(lumpScale, anchor: .bottom)
        .offset(y: -height * 0.42 + 10)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func burst(then action: (() -> Void)?) {
        popping = true
        PopHaptics.pop()
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) { opacity = 0 }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(200))
                action?()
                withAnimation(.easeIn(duration: 0.4)) { opacity = 1 }
                popping = false
            }
            return
        }
        Task { @MainActor in
            // It tears on the touch, in the same frame as the sound and the tap haptic (a stretch before it read as
            // a hesitation): the bubble becomes scraps that fly up and out...
            piecesUp = false
            piecesDown = false
            showPieces = true
            opacity = 0
            popScale = CGSize(width: 1, height: 1)
            withAnimation(.timingCurve(0.15, 0.7, 0.35, 1, duration: 0.5)) { piecesUp = true }
            showLump = true
            lumpScale = 0.4
            withAnimation(.easeOut(duration: 0.25)) { lumpScale = 1 }
            // The meeting clears while the pieces are still flying, so the card changes with the pop, not after it.
            try? await Task.sleep(for: .milliseconds(60))
            action?()
            try? await Task.sleep(for: .milliseconds(440))
            // ...then tumble down and fade, like gravity took over.
            withAnimation(.timingCurve(0.5, 0, 0.85, 0.6, duration: 0.65)) { piecesDown = true }
            try? await Task.sleep(for: .milliseconds(450))
            // A new bubble inflates out of the lump, easing out with no overshoot.
            regrowScale = 0.05
            opacity = 1
            withAnimation(.timingCurve(0.2, 0.7, 0.3, 1, duration: 1.1)) { regrowScale = 1 }
            withAnimation(.easeOut(duration: 0.35)) { lumpScale = 0.2 }
            try? await Task.sleep(for: .milliseconds(250))
            showPieces = false
            try? await Task.sleep(for: .milliseconds(150))
            showLump = false
            try? await Task.sleep(for: .milliseconds(700))
            popping = false
        }
    }
}

/// One scrap of torn gum: an irregular blob with ragged edges, or a stretched strand pinched in the middle.
struct GumScrap: View {
    var seed: Int
    var strand: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                ScrapShape(seed: seed, strand: strand)
                    .fill(LinearGradient(colors: [GumColors.light, GumColors.coral, GumColors.dark],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                ScrapShape(seed: seed, strand: strand)
                    .stroke(GumColors.dark.opacity(0.45), lineWidth: 1)
                Ellipse()
                    .fill(.white.opacity(0.45))
                    .frame(width: w * 0.32, height: h * 0.18)
                    .position(x: w * 0.38, y: h * 0.32)
                    .blur(radius: 1)
            }
        }
    }
}

/// An uneven closed outline: a lumpy blob with a few torn notches, or a thin strand with frayed ends.
struct ScrapShape: Shape {
    var seed: Int
    var strand: Bool

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let n = 14
        var pts: [CGPoint] = []
        for k in 0..<n {
            let a = Double(k) / Double(n) * 2 * .pi
            // Smooth lumps plus a couple of sharp torn notches.
            var r = 0.72 + 0.18 * sin(a * 2 + Double(seed)) + 0.12 * sin(a * 3 + Double(seed * 7))
            if (k + seed) % 5 == 0 { r *= 0.62 }
            if (k + seed * 3) % 7 == 0 { r *= 1.18 }
            if strand {
                // Pinched in the middle, frayed at the ends.
                let pinch = 0.55 + 0.45 * abs(cos(a))
                r *= pinch
            }
            pts.append(CGPoint(x: c.x + cos(a) * rect.width / 2 * r, y: c.y + sin(a) * rect.height / 2 * r))
        }
        var p = Path()
        let mid = { (a: CGPoint, b: CGPoint) in CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        p.move(to: mid(pts[n - 1], pts[0]))
        for k in 0..<n {
            let next = pts[(k + 1) % n]
            // Notched points get a sharp corner; the rest are rounded.
            if (k + seed) % 5 == 0 {
                p.addLine(to: pts[k])
                p.addLine(to: mid(pts[k], next))
            } else {
                p.addQuadCurve(to: mid(pts[k], next), control: pts[k])
            }
        }
        p.closeSubpath()
        return p
    }
}

/// Gum: slightly uneven, glossy, and more see-through the more it's stretched.
struct GumBubbleShape: View {
    /// 0 when small and thick, 1 when fully stretched.
    var thinness: Double
    /// Overrides the gum's main color.
    var tint: Color? = nil
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.themeStill) private var themeStill
    private var reduceMotion: Bool { systemReduceMotion || themeStill }
    @Environment(\.fortuneText) private var fortuneText

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let streak = min(26, max(5, w * 0.03))
            ZStack {
            // The glow under the ball, on a plain shape so it isn't redrawn with every animation frame.
            Group {
                if GumPalette.current == .waterBalloon || GumPalette.current == .easterEgg {
                    EggShape().fill(GumColors.dark)
                } else {
                    Ellipse().fill(GumColors.dark)
                }
            }
            .shadow(color: GumColors.accent.opacity(GumPalette.current == .fortune ? 0.45 : 0.3),
                    radius: GumPalette.current == .fortune ? 40 : 30, y: -12)
            ZStack {
                // Solid, saturated gum with a soft lit side (Unicorn uses the same pink gum).
                Ellipse()
                    .fill(RadialGradient(colors: [GumColors.light, tint ?? GumColors.coral, GumColors.dark],
                                         center: UnitPoint(x: 0.36, y: 0.24), startRadius: 0, endRadius: max(w, h) * 0.78))
                if GumPalette.current == .unicorn {
                    // Unicorn: a holographic rainbow band slides slowly across the gum.
                    TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { ctx in
                        let t = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 9) / 9
                        UnicornSheen(phase: reduceMotion || ScreenshotMode.isOn ? 0.5 : t)
                    }
                    .clipShape(Ellipse())
                }
                ThemeMarks(palette: GumPalette.current, w: w, h: h, level: thinness)
                if GumPalette.current == .fortune {
                    // Fortune: a soft star of light drifts slowly inside the black glass. When there is a fortune,
                    // the words surface out of the violet mist now and then, rest a while, and sink back.
                    TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion || ScreenshotMode.isOn)) { ctx in
                        let t = reduceMotion || ScreenshotMode.isOn ? 0 : ctx.date.timeIntervalSinceReferenceDate
                        let words = fortuneText.map { _ in FortuneSurface.amount(t, still: reduceMotion || ScreenshotMode.isOn) } ?? 0
                        let side = max(10, w * 0.07)
                        ZStack {
                            Circle().fill(GumPalette.violet.opacity(0.45)).frame(width: side * 2.6, height: side * 2.6).blur(radius: side * 0.7)
                            FourPointStar().fill(Color.white.opacity(0.92)).frame(width: side, height: side)
                                .rotationEffect(.degrees(sin(t / 3) * 12))
                        }
                        .opacity(1 - words)
                        .position(x: w * (0.5 + 0.16 * sin(t / 7)), y: h * (0.26 + 0.05 * sin(t / 5)))
                        if let fortuneText {
                            FortuneWords(text: fortuneText, w: w, amount: words)
                                .position(x: w * 0.5, y: h * 0.3)
                        }
                    }
                    .clipShape(Ellipse())
                }
                // Depth: the edge falls into shadow, strongest at the lower right.
                Ellipse()
                    .stroke(GumColors.dark.opacity(0.55), lineWidth: max(6, w * 0.05))
                    .blur(radius: max(6, w * 0.03))
                    .mask(Ellipse())
                // Gloss: a crisp curved streak along the upper left, the way light wraps a stretched bubble.
                Ellipse()
                    .trim(from: 0.56, to: 0.71)
                    .stroke(.white.opacity(GumPalette.current == .fortune ? 0.55 : 0.9), style: StrokeStyle(lineWidth: streak, lineCap: .round))
                    .padding(w * 0.075)
                    .blur(radius: 1.2)
                // A small bright window reflection beside it.
                Ellipse()
                    .fill(.white.opacity(0.8))
                    .frame(width: w * 0.1, height: h * 0.055)
                    .rotationEffect(.degrees(-32))
                    .blur(radius: 1)
                    .position(x: w * 0.31, y: h * 0.25)
                // A small glint, stretched along the curve like the other highlights.
                Ellipse()
                    .fill(.white.opacity(0.85))
                    .frame(width: max(10, w * 0.055), height: max(4, w * 0.02))
                    .rotationEffect(.degrees(24))
                    .blur(radius: 1.2)
                    .position(x: w * 0.6, y: h * 0.1)
                // A thin rim of light on the far edge.
                Ellipse()
                    .trim(from: 0.84, to: 0.97)
                    .stroke(.white.opacity(0.35 + thinness * 0.15), style: StrokeStyle(lineWidth: max(2, w * 0.006), lineCap: .round))
                    .padding(w * 0.012)
                if GumPalette.current == .unicorn {
                    // The rainbow rim turns once every 6 seconds (still with Reduce Motion and in screenshots).
                    TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion || ScreenshotMode.isOn)) { ctx in
                        let spin = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) / 6 * 360
                        UnicornRim(lineWidth: max(2.5, w * 0.008),
                                   angle: reduceMotion || ScreenshotMode.isOn ? -60 : -60 + spin)
                    }
                }
                if GumPalette.current == .fortune {
                    // A violet glow at the edge that slowly circles the ball (once every 8 seconds).
                    TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion || ScreenshotMode.isOn)) { ctx in
                        let spin = reduceMotion || ScreenshotMode.isOn ? 0 : ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 8) / 8 * 360
                        ZStack {
                            FortuneRim(lineWidth: max(10, w * 0.03), angle: spin).blur(radius: max(6, w * 0.02)).opacity(0.8)
                            FortuneRim(lineWidth: max(3, w * 0.009), angle: spin)
                        }
                        .mask(Ellipse())
                    }
                }
            }
            .modifier(EggMask(on: GumPalette.current == .waterBalloon || GumPalette.current == .easterEgg))
                ThemeTopper(palette: GumPalette.current, w: w, h: h)
            }
        }
    }
}

/// Unicorn confetti: stars, hearts, sparkles and dots in the rainbow.
struct ConfettiPiece: View {
    var index: Int
    private static let symbols = ["star.fill", "heart.fill", "sparkle", "circle.fill"]

    var body: some View {
        Image(systemName: Self.symbols.at(index % 4) ?? "star.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(GumPalette.rainbow.at(index % 5) ?? .pink)
            .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
    }
}

extension Array {
    /// Safe lookup: nil when out of range.
    func at(_ i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}


/// Resting motion for themes that move as a whole: the water balloon gets poked every so often and
/// jiggles to a stop, and the mood ring breathes in a box pattern (in 4, hold 4, out 4, hold 4).
struct ThemeIdle: ViewModifier {
    let palette: GumPalette
    let paused: Bool

    func body(content: Content) -> some View {
        switch palette {
        case .waterBalloon, .moodRing, .easterEgg, .valentine:
            TimelineView(.animation(minimumInterval: 1.0 / 20, paused: paused)) { ctx in
                let t = paused ? 0 : ctx.date.timeIntervalSinceReferenceDate
                let s = Self.scale(palette, t: t)
                content.scaleEffect(x: s.width, y: s.height, anchor: .bottom)
                    .rotationEffect(.degrees(palette == .easterEgg ? EggRock.angle(t) : 0), anchor: .bottom)
            }
        default:
            content
        }
    }

    static func scale(_ palette: GumPalette, t: TimeInterval) -> CGSize {
        switch palette {
        case .waterBalloon:
            // A poke every 7 seconds, then a damped wobble that settles in about 3 seconds.
            let k = t.truncatingRemainder(dividingBy: 7)
            // Hanging from its neck, the water pulls it slightly long.
            guard k < 3.2 else { return CGSize(width: 0.9, height: 1.06) }
            let wob = exp(-k * 1.5) * sin(k * 2 * .pi * 2.2)
            return CGSize(width: 0.9 * (1 + 0.06 * wob), height: 1.06 * (1 - 0.06 * wob))
        case .moodRing:
            let k = t.truncatingRemainder(dividingBy: 16)
            let ease: (Double) -> Double = { x in (1 - cos(x * .pi)) / 2 }
            let b: Double = k < 4 ? ease(k / 4) : (k < 8 ? 1 : (k < 12 ? 1 - ease((k - 8) / 4) : 0))
            let s = 1 + 0.04 * b
            return CGSize(width: s, height: s)
        case .easterEgg:
            return CGSize(width: 0.88, height: 1.08)
        case .valentine:
            let s = 1 + 0.025 * HeartBeat.beat(t)
            return CGSize(width: s, height: s)
        default:
            return CGSize(width: 1, height: 1)
        }
    }
}


/// Cuts the water balloon's gum to the egg outline and shades its edge.
struct EggMask: ViewModifier {
    let on: Bool

    func body(content: Content) -> some View {
        if on {
            GeometryReader { geo in
                let w = geo.size.width
                content
                    .overlay(EggShape().stroke(GumColors.dark.opacity(0.5), lineWidth: max(6, w * 0.05))
                        .blur(radius: max(6, w * 0.03)))
                    .mask(EggShape())
            }
        } else {
            content
        }
    }
}


extension EnvironmentValues {
    /// The fortune to show inside the Fortune ball, when there is one.
    @Entry var fortuneText: String? = nil
}

/// When the fortune words show inside the ball: they surface over 1.5 seconds, stay 9 seconds, sink back over
/// 1.5 seconds, and the star returns for 4 seconds before the next time. Held fully up with Reduce Motion.
enum FortuneSurface {
    static func amount(_ t: Double, still: Bool) -> Double {
        if still { return 1 }
        let k = t.truncatingRemainder(dividingBy: 16)
        if k < 1.5 { return k / 1.5 }
        if k < 10.5 { return 1 }
        if k < 12 { return 1 - (k - 10.5) / 1.5 }
        return 0
    }
}

/// The fortune's words, soft violet-white, floating up out of the mist inside the black ball.
struct FortuneWords: View {
    let text: String
    let w: CGFloat
    let amount: Double

    var body: some View {
        let size: CGFloat = max(13, w * 0.05)
        let blur: CGFloat = CGFloat(1 - amount) * size * 0.5
        ZStack {
            Circle().fill(GumPalette.violet.opacity(0.35 * amount))
                .frame(width: w * 0.62, height: w * 0.62)
                .blur(radius: w * 0.08)
            Text(text)
                .font(.system(size: size, weight: .semibold, design: .serif).italic())
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.95))
                .shadow(color: GumPalette.violet.opacity(0.9), radius: size * 0.4)
                .lineLimit(4)
                .minimumScaleFactor(0.6)
                .frame(width: w * 0.46)
                .blur(radius: blur)
                .opacity(amount)
                .offset(y: CGFloat(1 - amount) * size * 0.8)
        }
        .accessibilityHidden(true)
    }
}
