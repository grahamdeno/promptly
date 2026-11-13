import SwiftUI

/// The Pop In Pro sheet: what it adds, one price, buy or restore. No timers, no tricks.
struct ProView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 32

    private let features: [(String, String)] = [
        ("sparkles", "Unicorn mode: a rainbow bubble that bursts into confetti"),
        ("moon.stars", "Fortune: black glass, a violet glow and a meeting fortune"),
        ("moon.circle", "Moon and Grenade themes, each with its own pop"),
        ("square.grid.3x3", "Every theme, plus each new one through the year"),
        ("bell.and.waves.left.and.right", "More alarm sounds: Popcorn, Chimes, Oracle and Sonar"),
        ("calendar.badge.clock", "Per-calendar alerts: Alarm, Smart or Gentle"),
        ("clock", "Ring up to 10 minutes early"),
        ("ipad.landscape", "Desk mode: keep the screen on while Pop In is open"),
    ]

    var body: some View {
        let store = model.store
        ZStack {
            Color.white.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(Brand.ink)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Close")
                    }
                    GumBall()
                        .frame(width: 96, height: 96)
                        .frame(maxWidth: .infinity)
                    Text(store.isPro ? "You have Pop In Pro" : "Pop In Pro")
                        .font(.system(size: titleSize, weight: .semibold))
                        .tracking(-0.8)
                        .foregroundStyle(Brand.ink)
                    Text(store.betaAccess && !store.purchased
                         ? "Unlocked for TestFlight testing. In the App Store version this is a one-time \(store.price) purchase."
                         : store.isPro ? "Thanks for supporting Pop In. Everything below is unlocked."
                                       : "One purchase, yours for good. The free app keeps every alarm, the bubble and the widgets.")
                        .font(.callout)
                        .foregroundStyle(Brand.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(features, id: \.1) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Image(systemName: item.0).foregroundStyle(Brand.coralDark).frame(width: 24)
                                Text(item.1).font(.body).foregroundStyle(Brand.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .glassCard()
                    if let message = store.message {
                        Text(message).font(.subheadline).foregroundStyle(Brand.ink)
                    }
                    if !store.purchased {
                        Button(store.purchasing ? "One moment…"
                               : store.betaAccess ? "Test the purchase (free in TestFlight)" : "Unlock for \(store.price)") {
                            Task { await store.buy() }
                        }
                        .buttonStyle(PrimaryButtonStyle(height: 56))
                        .disabled(store.purchasing)
                        Button("Restore purchase") { Task { await store.restore() } }
                            .buttonStyle(SecondaryButtonStyle(height: 44, fill: true))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .task { await store.load() }
    }
}
