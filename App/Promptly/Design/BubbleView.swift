import SwiftUI

/// The gum bubble, and the screen's main button: tap it to pop it.
///
/// `.bubble` style inflates in small puffs as the meeting nears (each easing out, no bounce), stretches upward and
/// thins as it grows, swells slowly near the start and trembles at the start. Tapping pops it like real gum: the film
/// tears open near the top, splits into a few ragged sheets that snap back down toward the bottom edge and crumple
/// into a small lump, and a new bubble inflates out of the lump. `.steady` keeps one size but still pops.
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
    @State private var showSheets = false
    @State private var sheetsOpen = false
    @State private var sheetsCollapse = false
    @State private var showLump = false
    @State private var lumpScale: CGFloat = 0.6
    @State private var specksOut = false
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
                if showSheets { sheets }
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

    /// Slow swelling near the start; a fine tremble at the start. No bounce.
    private func idleMotion(_ t: TimeInterval) -> (sx: CGFloat, sy: CGFloat, dx: CGFloat, dy: CGFloat) {
        guard style == .bubble, !reduceMotion, !popping else { return (1, 1, 0, 0) }
        if progress >= 1 {
            return (1.02, 1.03, CGFloat(0.7 * sin(t * 45)), CGFloat(0.5 * sin(t * 53 + 1)))
        }
        if progress > 0.7 {
            let s = (1 - cos(t * 2 * .pi / 2.8)) / 2
            return (CGFloat(1 + 0.012 * s), CGFloat(1 + 0.022 * s), 0, 0)
        }
        return (1, 1, 0, 0)
    }

    // MARK: Pop

    /// Where the film gives way: near the top of the bubble, a little off center.
    private let tear = UnitPoint(x: 0.54, y: 0.1)

    /// Sector edges around the tear, in degrees, deliberately uneven so the sheets differ in size.
    private static let sheetEdges: [Double] = [-118, -72, -31, 18, 62, 101, 158, 214]

    /// The torn sheets: slices of the bubble that open slightly, then snap back down and crumple.
    private var sheets: some View {
        let edges = Self.sheetEdges
        return ZStack(alignment: .bottom) {
            ForEach(0..<edges.count, id: \.self) { i in
                let a0 = edges[i]
                let a1 = i + 1 < edges.count ? edges[i + 1] : edges[0] + 360
                let mid = (a0 + a1) / 2 * .pi / 180
                let open = CGSize(width: cos(mid) * 14, height: sin(mid) * 10)
                let spin = (i % 2 == 0 ? -1.0 : 1.0) * (12 + Double(i % 3) * 7)
                GumBubbleShape(thinness: puff)
                    .frame(width: width, height: height)
                    .clipShape(TornWedge(tear: tear, from: a0, to: a1, seed: i))
                    .offset(sheetsOpen ? open : .zero)
                    .rotationEffect(.degrees(sheetsCollapse ? spin : 0), anchor: .bottom)
                    .scaleEffect(x: sheetsCollapse ? 0.38 : 1, y: sheetsCollapse ? 0.08 : 1, anchor: .bottom)
                    .opacity(sheetsCollapse ? 0.85 : 1)
            }
            specks
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A few tiny bits that come off the tear. Most of the gum stays connected.
    private var specks: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<4, id: \.self) { i in
                let dx = [-26.0, -9, 12, 30][i]
                let dy = [-18.0, -30, -26, -12][i]
                Capsule()
                    .fill(GumColors.coral.opacity(0.85))
                    .frame(width: CGFloat(5 + i % 2 * 3), height: CGFloat(3 + i % 2))
                    .rotationEffect(.degrees(Double(i) * 40))
                    .offset(x: specksOut ? dx : 0, y: specksOut ? dy + (sheetsCollapse ? 70 : 0) : 0)
                    .opacity(sheetsCollapse ? 0 : 1)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .offset(x: width * tear.x, y: height * tear.y)
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
            withAnimation(.easeOut(duration: 0.07)) { popScale = CGSize(width: 1.03, height: 1.045) }
            try? await Task.sleep(for: .milliseconds(70))
            // Tear: swap the whole bubble for its sheets, which part slightly at the tear.
            sheetsOpen = false
            sheetsCollapse = false
            specksOut = false
            showSheets = true
            opacity = 0
            popScale = CGSize(width: 1, height: 1)
            withAnimation(.easeOut(duration: 0.07)) { sheetsOpen = true }
            withAnimation(.easeOut(duration: 0.25)) { specksOut = true }
            try? await Task.sleep(for: .milliseconds(70))
            // Snap back: the sheets whip down toward the bottom edge and crumple.
            withAnimation(.easeIn(duration: 0.24)) { sheetsCollapse = true }
            try? await Task.sleep(for: .milliseconds(150))
            action?()
            showLump = true
            lumpScale = 0.4
            withAnimation(.easeOut(duration: 0.18)) { lumpScale = 1 }
            try? await Task.sleep(for: .milliseconds(140))
            showSheets = false
            try? await Task.sleep(for: .milliseconds(260))
            // A new bubble inflates out of the lump, easing out with no overshoot.
            regrowScale = 0.05
            opacity = 1
            withAnimation(.timingCurve(0.2, 0.7, 0.3, 1, duration: 1.1)) { regrowScale = 1 }
            withAnimation(.easeOut(duration: 0.35)) { lumpScale = 0.2 }
            try? await Task.sleep(for: .milliseconds(350))
            showLump = false
            try? await Task.sleep(for: .milliseconds(750))
            popping = false
        }
    }
}

/// One torn sheet: a wedge of the bubble from the tear point outward, with ragged, wrinkled edges.
struct TornWedge: Shape {
    var tear: UnitPoint
    var from: Double
    var to: Double
    var seed: Int

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.minX + tear.x * rect.width, y: rect.minY + tear.y * rect.height)
        let reach = max(rect.width, rect.height) * 1.6
        func edge(_ degrees: Double, _ s: Int) -> [CGPoint] {
            let a = degrees * .pi / 180
            return (1...10).map { i in
                let t = Double(i) / 10
                let jag = sin(Double(s * 37 + i * 101)) * 0.035 * reach * (0.4 + t)
                return CGPoint(x: c.x + cos(a) * reach * t - sin(a) * jag,
                               y: c.y + sin(a) * reach * t + cos(a) * jag)
            }
        }
        var p = Path()
        p.move(to: c)
        for pt in edge(from, seed) { p.addLine(to: pt) }
        let steps = 12
        for k in 1...steps {
            let a = (from + (to - from) * Double(k) / Double(steps)) * .pi / 180
            p.addLine(to: CGPoint(x: c.x + cos(a) * reach, y: c.y + sin(a) * reach))
        }
        for pt in edge(to, seed + 1).reversed() { p.addLine(to: pt) }
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
