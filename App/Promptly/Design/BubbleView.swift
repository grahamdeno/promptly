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
    var style: BallStyle
    var popCount: Int
    var hint: String? = nil
    var accessibilityTitle: String = "Pop the bubble"
    var minSize: CGFloat = 150
    var maxSize: CGFloat = 710
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Inflates in breaths: 36 puffs from empty to full.
    private var puff: Double {
        style == .bubble ? (min(1, max(0, progress)) * 36).rounded(.down) / 36 : 0.4
    }

    private var width: CGFloat {
        style == .bubble ? minSize + CGFloat(puff) * (maxSize - minSize) : steadySize
    }

    private var height: CGFloat { width * (1 + 0.1 * CGFloat(puff)) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                TimelineView(.animation(paused: reduceMotion || style == .steady || progress < 0.7)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let m = idleMotion(t)
                    bubbleButton
                        .scaleEffect(x: m.sx * popScale.width * regrowScale, y: m.sy * popScale.height * regrowScale,
                                     anchor: .bottom)
                        .offset(x: m.dx, y: m.dy)
                        .opacity(opacity)
                }
                if showPieces { pieces }
                if showLump { lump }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            .offset(y: height * 0.42)
        }
        .animation(.timingCurve(0.2, 0.7, 0.3, 1, duration: 0.9), value: puff)
        .onChange(of: popCount) { _, _ in
            if !popping { burst(then: nil) }
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
                .overlay(alignment: .top) {
                    if let hint, !popping {
                        Text(hint)
                            .font(.system(size: width < 260 ? 13 : 16, weight: .semibold))
                            .tracking(0.2)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 1)
                            .padding(.top, height * (width < 260 ? 0.2 : 0.15))
                            .phaseAnimator([0.92, 0.55]) { view, value in view.opacity(value) } animation: { _ in .easeInOut(duration: 1.2) }
                    }
                }
                .contentShape(Ellipse())
        }
        .buttonStyle(.plain)
        .disabled(onPop == nil)
        .accessibilityLabel(accessibilityTitle)
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

    /// The scraps fly up and outward, tumbling, then fall away and fade.
    private var pieces: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<Self.scraps.count, id: \.self) { i in
                let scrap = Self.scraps[i]
                let side = width * scrap.size
                let fallScale: CGFloat = 1.25
                GumScrap(seed: scrap.seed, strand: scrap.strand)
                    .frame(width: scrap.strand ? side * 1.9 : side, height: scrap.strand ? side * 0.42 : side * 0.82)
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
            // A last stretch at the weak spot.
            withAnimation(.easeOut(duration: 0.08)) { popScale = CGSize(width: 1.03, height: 1.045) }
            try? await Task.sleep(for: .milliseconds(80))
            // It tears: the bubble becomes scraps that fly up and out...
            piecesUp = false
            piecesDown = false
            showPieces = true
            opacity = 0
            popScale = CGSize(width: 1, height: 1)
            withAnimation(.timingCurve(0.15, 0.7, 0.35, 1, duration: 0.5)) { piecesUp = true }
            showLump = true
            lumpScale = 0.4
            withAnimation(.easeOut(duration: 0.25)) { lumpScale = 1 }
            try? await Task.sleep(for: .milliseconds(300))
            action?()
            try? await Task.sleep(for: .milliseconds(200))
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

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let fill = 0.98 - thinness * 0.16
            ZStack {
                Ellipse()
                    .fill(RadialGradient(colors: [GumColors.light.opacity(fill), GumColors.coral.opacity(fill),
                                                  GumColors.dark.opacity(min(1, fill + 0.04))],
                                         center: UnitPoint(x: 0.38, y: 0.26), startRadius: 0, endRadius: max(w, h) * 0.75))
                Ellipse()
                    .stroke(.white.opacity(0.10 + thinness * 0.2), lineWidth: max(2, w * 0.02))
                    .blur(radius: w * 0.02)
                    .padding(w * 0.03)
                Ellipse()
                    .fill(.white.opacity(0.42 + thinness * 0.25))
                    .frame(width: w * (0.26 + 0.1 * thinness), height: h * (0.14 + 0.06 * thinness))
                    .rotationEffect(.degrees(-24))
                    .blur(radius: w * 0.008)
                    .position(x: w * 0.32, y: h * 0.2)
                Circle()
                    .fill(.white.opacity(0.7))
                    .frame(width: w * 0.07, height: w * 0.05)
                    .position(x: w * 0.58, y: h * 0.1)
            }
            .shadow(color: GumColors.coral.opacity(0.25), radius: 30, y: -12)
        }
    }
}
