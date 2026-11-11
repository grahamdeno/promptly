import SwiftUI

/// The coral ball. In `.bubble` style it inflates as the meeting nears, strains near the start, and pops
/// (then springs back small) whenever `popCount` changes. In `.steady` style it stays still.
/// Anchored to the bottom edge, mostly below the screen.
struct BubbleView: View {
    var progress: Double
    var style: BallStyle
    var popCount: Int
    var minSize: CGFloat = 150
    var maxSize: CGFloat = 690
    var steadySize: CGFloat = 300

    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 1
    @State private var burst = false
    @State private var showFragments = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var size: CGFloat {
        style == .bubble ? minSize + CGFloat(min(1, max(0, progress))) * (maxSize - minSize) : steadySize
    }

    /// Strain starts at 72 percent and gets stronger toward the start.
    private var strain: Double {
        guard style == .bubble, !reduceMotion, progress > 0.72 else { return 0 }
        return 0.025 * min(1, (progress - 0.72) / 0.28)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TimelineView(.animation(paused: strain == 0)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let speed = progress >= 1 ? 14.0 : 7.0
                    let wobble = strain * sin(t * speed)
                    BallShape()
                        .frame(width: size, height: size)
                        .scaleEffect(x: scale * (1 + wobble), y: scale * (1 - wobble), anchor: .init(x: 0.5, y: 0.7))
                        .opacity(opacity)
                }
                if showFragments {
                    ForEach(0..<10, id: \.self) { i in
                        let angle = Double(i) / 10 * 2 * .pi - .pi / 2
                        let distance = 120 + Double(i % 3) * 40
                        let dot = CGFloat(14 + (i % 4) * 6)
                        Circle()
                            .fill(Brand.coral)
                            .frame(width: dot, height: dot)
                            .offset(x: burst ? cos(angle) * distance : 0, y: burst ? sin(angle) * distance : 0)
                            .scaleEffect(burst ? 0.3 : 1)
                            .opacity(burst ? 0 : 1)
                            .offset(y: -size * 0.2)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            .offset(y: size * 0.42)
        }
        .animation(.linear(duration: 1), value: size)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: popCount) { _, _ in pop() }
    }

    private func pop() {
        guard style == .bubble else { return }
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.3)) { opacity = 0.4 }
            withAnimation(.easeInOut(duration: 0.3).delay(0.3)) { opacity = 1 }
            return
        }
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.13)) { scale = 1.12 }
            try? await Task.sleep(for: .milliseconds(130))
            showFragments = true
            burst = false
            withAnimation(.easeIn(duration: 0.25)) { scale = 0.2; opacity = 0 }
            withAnimation(.easeOut(duration: 0.5)) { burst = true }
            try? await Task.sleep(for: .milliseconds(450))
            showFragments = false
            scale = 0
            opacity = 1
            withAnimation(.spring(response: 0.5, dampingFraction: 0.45)) { scale = 1 }
        }
    }
}

/// A glossy ball: coral radial gradient with a soft highlight.
struct BallShape: View {
    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Brand.coralLight, Brand.coral, Brand.coralDark],
                                         center: UnitPoint(x: 0.36, y: 0.28),
                                         startRadius: 0, endRadius: s * 0.78))
                Ellipse()
                    .fill(.white.opacity(0.5))
                    .frame(width: s * 0.3, height: s * 0.18)
                    .rotationEffect(.degrees(-24))
                    .blur(radius: s * 0.012)
                    .position(x: s * 0.33, y: s * 0.21)
                Circle()
                    .fill(.white.opacity(0.65))
                    .frame(width: s * 0.07, height: s * 0.055)
                    .position(x: s * 0.56, y: s * 0.12)
            }
            .shadow(color: Brand.coral.opacity(0.28), radius: 30, y: -12)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
