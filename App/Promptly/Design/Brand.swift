import SwiftUI

enum Brand {
    static var coral: Color { GumColors.coral }
    static var coralLight: Color { GumColors.light }
    static var coralDark: Color { GumColors.dark }
    static let ink = Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x14 / 255)
    /// 5.3:1 on white.
    static let secondary = Color(red: 0x6B / 255, green: 0x6B / 255, blue: 0x6B / 255)
    static let hairline = Color(red: 0xEF / 255, green: 0xEF / 255, blue: 0xEF / 255)

    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func color(hex: String) -> Color {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return .gray }
        return Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
                     blue: Double(v & 0xFF) / 255)
    }
}

/// The lowercase wordmark with its coral dot.
struct Wordmark: View {
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 2) {
            Text("pop in")
                .font(Brand.display(22))
                .tracking(-0.4)
                .foregroundStyle(Brand.ink)
            Circle().fill(Brand.coral).frame(width: 7, height: 7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pop In")
    }
}

/// Black pill, the main action.
struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 50
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Brand.ink))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Quiet pill, the second action.
struct SecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = 50
    var fill = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Brand.ink)
            .padding(.horizontal, 22)
            .frame(height: height)
            .frame(maxWidth: fill ? .infinity : nil)
            .background(Capsule().fill(Brand.ink.opacity(0.07)))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
