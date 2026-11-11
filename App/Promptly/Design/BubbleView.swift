import SwiftUI

/// The gum bubble, and the screen's main button: tap it to pop it.
///
/// `.bubble` style inflates in small puffs as the meeting nears (each easing out, no bounce), stretches upward and
/// thins as it grows, swells slowly near the start and trembles at the start. Tapping bursts it into gum shreds that
/// fall away, then a new bubble inflates smoothly from nothing. `.steady` keeps one size but still pops.
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
    @State private var shredsOut = false
    @State private var shredsFall = false
    @State private var showShreds = false
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
            ZStack {
                TimelineView(.animation(paused: reduceMotion || style == .steady || progress < 0.7)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let m = idleMotion(t)
                    bubbleButton
                        .scaleEffect(x: m.sx * popScale.width * regrowScale, y: m.sy * popScale.height * regrowScale,
                                     anchor: .bottom)
                        .offset(x: m.dx, y: m.dy)
                        .opacity(opacity)
                }
                if showShreds { shreds }
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

    private var shreds: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) / 12 * 2 * .pi - .pi / 2 + (i % 2 == 0 ? -0.12 : 0.18)
                let r = 70 + Double(i % 4) * 34
                let out = CGSize(width: cos(angle) * r, height: sin(angle) * r * 0.8)
                Ellipse()
                    .fill(Brand.coral.opacity(0.9))
                    .frame(width: CGFloat(18 + (i % 3) * 12), height: CGFloat(10 + (i % 4) * 5))
                    .rotationEffect(.degrees(shredsFall ? Double((i % 2 == 0 ? -1 : 1) * (60 + i * 14)) : 0))
                    .offset(x: shredsOut ? out.width * (shredsFall ? 1.1 : 1) : 0,
                            y: shredsOut ? out.height + (shredsFall ? 140 : 0) : 0)
                    .opacity(shredsFall ? 0 : 1)
            }
        }
        .offset(y: -height * 0.26)
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
            // A last stretch, then it's gone.
            withAnimation(.easeOut(duration: 0.08)) { popScale = CGSize(width: 1.035, height: 1.05) }
            try? await Task.sleep(for: .milliseconds(80))
            shredsOut = false
            shredsFall = false
            showShreds = true
            withAnimation(.easeIn(duration: 0.16)) { popScale = CGSize(width: 0.92, height: 0.86); opacity = 0 }
            withAnimation(.timingCurve(0.25, 0.6, 0.4, 1, duration: 0.3)) { shredsOut = true }
            try? await Task.sleep(for: .milliseconds(180))
            action?()
            withAnimation(.easeIn(duration: 0.45)) { shredsFall = true }
            try? await Task.sleep(for: .milliseconds(450))
            showShreds = false
            // A new bubble inflates from nothing, easing out with no overshoot.
            popScale = CGSize(width: 1, height: 1)
            regrowScale = 0.05
            opacity = 1
            withAnimation(.timingCurve(0.2, 0.7, 0.3, 1, duration: 1.1)) { regrowScale = 1 }
            try? await Task.sleep(for: .milliseconds(1100))
            popping = false
        }
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
