import SwiftUI

/// The bubble's colors, shared by the app and the widget extension.
enum GumColors {
    static let coral = Color(red: 0xE8 / 255, green: 0x55 / 255, blue: 0x3A / 255)
    static let light = Color(red: 0xFF / 255, green: 0xB8 / 255, blue: 0xA0 / 255)
    static let dark = Color(red: 0xC8 / 255, green: 0x36 / 255, blue: 0x1C / 255)
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
