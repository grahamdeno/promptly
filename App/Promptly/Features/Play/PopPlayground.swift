import SwiftUI

/// Pop for fun: every theme's bubble drifting around the screen at different sizes. Tap one and it pops the way
/// that theme does (its own sound and pieces); a new one floats in. A toy, not a game: no timer, nothing to lose.
struct PopPlayground: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bubbles: [PlayBubble] = []
    @State private var bursts: [PlayBurst] = []
    @State private var popped = 0
    private let count = 10

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Color.white.ignoresSafeArea()
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { tl in
                    let now = tl.date
                    ZStack {
                        ForEach(bubbles) { b in
                            let p = b.position(at: now, in: size, still: reduceMotion)
                            PlayBall(palette: b.palette)
                                .frame(width: b.size, height: b.size)
                                .scaleEffect(b.scale(at: now))
                                .position(p)
                                .onTapGesture { pop(b, at: p, in: size) }
                                .accessibilityElement()
                                .accessibilityLabel("\(b.palette.label) bubble")
                                .accessibilityAddTraits(.isButton)
                                .accessibilityAction { pop(b, at: p, in: size) }
                        }
                    }
                }
                ForEach(bursts) { burst in
                    PlayBurstView(burst: burst).allowsHitTesting(false)
                }
                VStack {
                    HStack {
                        Text(popped == 1 ? "1 popped" : "\(popped) popped")
                            .font(.subheadline.weight(.medium).monospacedDigit())
                            .foregroundStyle(Brand.secondary)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .glassEffect(.regular, in: .capsule)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Brand.ink)
                                .frame(width: 44, height: 44)
                        }
                        .glassEffect(.regular, in: .circle)
                        .accessibilityLabel("Done")
                    }
                    .padding(.horizontal, 20)
                    Spacer()
                }
                .padding(.top, 8)
            }
            .onAppear {
                if bubbles.isEmpty { bubbles = (0..<count).map { _ in PlayBubble.random(in: size, entering: false) } }
            }
        }
        .statusBarHidden()
    }

    private func pop(_ b: PlayBubble, at p: CGPoint, in size: CGSize) {
        guard bubbles.contains(where: { $0.id == b.id }) else { return }
        bubbles.removeAll { $0.id == b.id }
        popped += 1
        PopSound.play(file: b.palette.popFile)
        PopHaptics.tap()
        let burst = PlayBurst(palette: b.palette, center: p, size: b.size)
        bursts.append(burst)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1100))
            bursts.removeAll { $0.id == burst.id }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            bubbles.append(PlayBubble.random(in: size, entering: true))
        }
    }
}

/// One drifting bubble. Its path is worked out from when it was born, so nothing is stored between frames.
struct PlayBubble: Identifiable {
    let id = UUID()
    let palette: GumPalette
    let size: CGFloat
    let start: CGPoint
    let velocity: CGVector
    let born: Date
    let phase: Double

    static func random(in area: CGSize, entering: Bool) -> PlayBubble {
        let s = CGFloat.random(in: 64...150)
        let speed = CGFloat.random(in: 18...42)
        let palette = GumPalette.available.randomElement() ?? .bubblegum
        let maxX = max(s + 1, area.width - s / 2)
        let maxY = max(141, area.height - s / 2)
        guard entering else {
            // The first set starts scattered, drifting any way.
            let angle = Double.random(in: 0..<(2 * .pi))
            return PlayBubble(palette: palette, size: s,
                              start: CGPoint(x: CGFloat.random(in: s / 2...maxX), y: CGFloat.random(in: 140...maxY)),
                              velocity: CGVector(dx: CGFloat(cos(angle)) * speed, dy: CGFloat(sin(angle)) * speed),
                              born: .now, phase: Double.random(in: 0..<10))
        }
        // Newcomers float in from any side, heading inward at a slant.
        let slant = CGFloat.random(in: -0.6...0.6)
        let start: CGPoint
        let v: CGVector
        switch Int.random(in: 0..<4) {
        case 0:  // left
            start = CGPoint(x: -s * 0.6, y: CGFloat.random(in: 140...maxY))
            v = CGVector(dx: speed + 12, dy: speed * slant)
        case 1:  // right
            start = CGPoint(x: area.width + s * 0.6, y: CGFloat.random(in: 140...maxY))
            v = CGVector(dx: -speed - 12, dy: speed * slant)
        case 2:  // top
            start = CGPoint(x: CGFloat.random(in: s / 2...maxX), y: -s * 0.6)
            v = CGVector(dx: speed * slant, dy: speed + 12)
        default: // bottom
            start = CGPoint(x: CGFloat.random(in: s / 2...maxX), y: area.height + s * 0.6)
            v = CGVector(dx: speed * slant, dy: -speed - 12)
        }
        return PlayBubble(palette: palette, size: s, start: start, velocity: v, born: .now, phase: Double.random(in: 0..<10))
    }

    /// Drifts in a straight line and bounces off the edges (a folded path), with a gentle bob. A newcomer glides
    /// in from off screen first, and only starts bouncing once it is fully inside.
    func position(at now: Date, in area: CGSize, still: Bool) -> CGPoint {
        let t: CGFloat = still ? 0 : CGFloat(now.timeIntervalSince(born))
        let r = size / 2
        let xLo = r, xHi = area.width - r
        let yLo = 110 + r, yHi = area.height - r
        let rawX = start.x + velocity.dx * t
        let rawY = start.y + velocity.dy * t
        let bob: CGFloat = still ? 0 : CGFloat(sin(Double(t) * 1.3 + phase)) * 4
        if t < entryTime(xLo, xHi, yLo, yHi) {
            return CGPoint(x: rawX, y: rawY + bob)
        }
        return CGPoint(x: Self.fold(rawX, xLo, xHi), y: Self.fold(rawY, yLo, yHi) + bob)
    }

    /// Seconds until the bubble is fully on screen on both axes (0 if it starts inside).
    private func entryTime(_ xLo: CGFloat, _ xHi: CGFloat, _ yLo: CGFloat, _ yHi: CGFloat) -> CGFloat {
        func axis(_ p: CGFloat, _ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
            if p < lo { return v > 0 ? (lo - p) / v : .infinity }
            if p > hi { return v < 0 ? (hi - p) / v : .infinity }
            return 0
        }
        return max(axis(start.x, velocity.dx, xLo, xHi), axis(start.y, velocity.dy, yLo, yHi))
    }

    static func fold(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        guard hi > lo else { return lo }
        let span = hi - lo
        var m = (v - lo).truncatingRemainder(dividingBy: 2 * span)
        if m < 0 { m += 2 * span }
        return lo + (m <= span ? m : 2 * span - m)
    }

    /// Springs into being when it arrives.
    func scale(at now: Date) -> CGFloat {
        let t = now.timeIntervalSince(born)
        guard t < 0.5 else { return 1 }
        let e = 1 - pow(1 - t / 0.5, 3)
        return CGFloat(0.6 + 0.4 * e)
    }
}

/// A theme's bubble, drawn for any palette (not only the chosen one), with its resting motion.
struct PlayBall: View {
    let palette: GumPalette

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                Circle().fill(RadialGradient(colors: [palette.light, palette.base, palette.dark],
                                             center: UnitPoint(x: 0.38, y: 0.26), startRadius: 0, endRadius: w * 0.7))
                ThemeMarks(palette: palette, w: w, h: w)
                if palette == .fortune {
                    FortuneRim(lineWidth: max(2, w * 0.03))
                    FourPointStar().fill(Color.white.opacity(0.9))
                        .frame(width: w * 0.16, height: w * 0.16)
                        .offset(x: w * 0.08, y: -w * 0.14)
                }
                if palette == .unicorn {
                    UnicornSheen(phase: 0.5).clipShape(Circle())
                    Circle().strokeBorder(AngularGradient(colors: GumPalette.rainbow + [GumPalette.rainbow[0]], center: .center),
                                          lineWidth: max(2, w * 0.04))
                }
                Ellipse().fill(Color.white.opacity(0.5))
                    .frame(width: w * 0.3, height: w * 0.17)
                    .rotationEffect(.degrees(-24))
                    .offset(x: -w * 0.18, y: -w * 0.24)
                ThemeTopper(palette: palette, w: w)
            }
            .frame(width: w, height: w)
        }
        .shadow(color: palette.accent.opacity(0.25), radius: 8, y: 4)
    }
}

struct PlayBurst: Identifiable {
    let id = UUID()
    let palette: GumPalette
    let center: CGPoint
    let size: CGFloat
}

/// The pieces a theme's pop throws: its own debris (emoji, sparks, sprinkles) or gum scraps in its colors.
struct PlayBurstView: View {
    let burst: PlayBurst
    @State private var out = false
    private static let n = 10

    var body: some View {
        ZStack {
            Circle().stroke(burst.palette.light, lineWidth: 3)
                .frame(width: burst.size, height: burst.size)
                .scaleEffect(out ? 1.5 : 0.9)
                .opacity(out ? 0 : 0.8)
            ForEach(0..<Self.n, id: \.self) { i in
                piece(i)
                    .rotationEffect(.degrees(out ? Double(i * 47 % 360) : 0))
                    .offset(offset(i))
                    .scaleEffect(out ? 0.7 : 1)
                    .opacity(out ? 0 : 1)
            }
        }
        .position(burst.center)
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { out = true } }
    }

    private func offset(_ i: Int) -> CGSize {
        guard out else { return .zero }
        let a = Double(i) / Double(Self.n) * 2 * .pi + Double(i % 3) * 0.3
        let dist = burst.size * (0.7 + 0.25 * CGFloat(i % 4))
        return CGSize(width: CGFloat(cos(a)) * dist, height: CGFloat(sin(a)) * dist + burst.size * 0.35)
    }

    @ViewBuilder
    private func piece(_ i: Int) -> some View {
        let side = max(22, burst.size * 0.42)
        let p = burst.palette
        if ThemeDebris.handles(p) {
            ThemeDebris.piece(p, index: i, side: side)
        } else if p == .unicorn {
            if i % 4 == 0 {
                Text("🦄").font(.system(size: side * 0.7))
            } else {
                ConfettiPiece(index: i).frame(width: side * 0.45, height: side * 0.45)
            }
        } else if p == .fortune {
            if i % 3 == 0 {
                FourPointStar().fill(GumPalette.violetDeep).frame(width: side * 0.5, height: side * 0.5)
            } else {
                Circle().fill(GumPalette.violet.opacity(0.6)).frame(width: side * 0.6, height: side * 0.6).blur(radius: 4)
            }
        } else {
            Ellipse().fill([p.base, p.light, p.dark][i % 3]).frame(width: side * 0.5, height: side * 0.38)
        }
    }
}
