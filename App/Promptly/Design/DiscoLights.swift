import SwiftUI

/// Disco theme: little flecks of colored light thrown across the whole screen by the turning mirror ball.
/// They sweep slowly in the direction the ball turns and twinkle as tiles catch and lose the light.
/// Shows nothing for other themes, with Reduce Motion, or in screenshots.
struct DiscoLights: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.themeStill) private var themeStill

    private static let colors: [Color] = [
        .white, GumPalette.rgb(0xFF7FD1), GumPalette.rgb(0x7FE3FF), GumPalette.rgb(0xFFD66B), GumPalette.rgb(0xB79BFF),
    ]

    var body: some View {
        if GumPalette.current == .disco && !reduceMotion && !themeStill && !ScreenshotMode.isOn {
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    Self.draw(ctx: &ctx, size: size, t: t)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private static func draw(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        var rng = SeededRandom(seed: 21)
        // One full sweep across the screen per ball turn (the ball turns once every 10 seconds), drifting a little faster near the middle rows.
        let sweep = t / 14
        ctx.addFilter(.blur(radius: 1.5))
        for k in 0..<34 {
            let lane = rng.next()
            let row = rng.next()
            let speed = 0.75 + 0.5 * rng.next()
            let w = 10 + 18 * rng.next()
            let color = colors[Int(rng.next() * 5) % 5]
            let spin = rng.next() * 40 - 20
            let u = (lane + sweep * speed).truncatingRemainder(dividingBy: 1)
            let x = CGFloat(u) * (size.width + 80) - 40
            let y = CGFloat(row) * size.height + CGFloat(sin(t * 0.5 + Double(k))) * 6
            // Each fleck brightens and fades as its tile turns into and out of the light.
            let twinkle = max(0, sin(t * (1.4 + rng.next()) + Double(k) * 2.1))
            let alpha = 0.18 + 0.32 * twinkle
            let rect = CGRect(x: -w / 2, y: -w * 0.35, width: w, height: w * 0.7)
            var fleck = ctx
            fleck.translateBy(x: x, y: y)
            fleck.rotate(by: .degrees(spin))
            fleck.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(color.opacity(alpha)))
            if twinkle > 0.9 {
                // The brightest flecks flash a tiny star.
                let s = w * 0.9
                var star = Path()
                star.move(to: CGPoint(x: 0, y: -s)); star.addLine(to: CGPoint(x: 0, y: s))
                star.move(to: CGPoint(x: -s, y: 0)); star.addLine(to: CGPoint(x: s, y: 0))
                fleck.stroke(star, with: .color(color.opacity((twinkle - 0.9) * 6)), lineWidth: 1.2)
            }
        }
    }
}
