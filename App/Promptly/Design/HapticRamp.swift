import SwiftUI
import UIKit

/// While this screen is open, buzzes lightly from ten minutes out and gets stronger and closer together until the start.
/// Apps can't vibrate on their own when the phone is locked, so this only runs on screen.
struct HapticRamp: ViewModifier {
    let start: Date?
    let enabled: Bool

    func body(content: Content) -> some View {
        content.task(id: "\(start?.timeIntervalSince1970 ?? 0)-\(enabled)") { await run() }
    }

    @MainActor
    private func run() async {
        guard enabled, let start else { return }
        let soft = UIImpactFeedbackGenerator(style: .soft)
        let rigid = UIImpactFeedbackGenerator(style: .rigid)
        soft.prepare()
        rigid.prepare()
        while !Task.isCancelled {
            let remaining = start.timeIntervalSinceNow
            if remaining < -60 { return }
            guard let step = HapticCurve.at(remaining: remaining) else {
                try? await Task.sleep(for: .seconds(min(30, max(1, remaining - HapticCurve.window))))
                continue
            }
            (step.intensity < 0.55 ? soft : rigid).impactOccurred(intensity: step.intensity)
            try? await Task.sleep(for: .seconds(step.interval))
        }
    }
}

extension View {
    func hapticRamp(until start: Date?, enabled: Bool) -> some View {
        modifier(HapticRamp(start: start, enabled: enabled))
    }
}

enum PopHaptics {
    @MainActor static func pop() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
