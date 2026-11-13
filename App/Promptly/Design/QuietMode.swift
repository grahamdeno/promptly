import SwiftUI
import UIKit

/// Keeps the phone cool while Pop In sits open.
/// - Quiet mode: after two minutes untouched, with the meeting more than fifteen minutes off, the decoration holds
///   still. (The screen used to dim too; the owner disliked coming back to a dim app, so brightness is never touched.) A touch, or the meeting coming within fifteen minutes, wakes it.
/// - Warm phone or Low Power Mode: the decoration holds still until the phone cools or Low Power Mode is off.
@MainActor @Observable
final class PowerWatch {
    static let shared = PowerWatch()

    /// True when iOS reports the phone as warm (serious or critical) or Low Power Mode is on.
    private(set) var strained = false

    private init() {
        update()
        let center = NotificationCenter.default
        center.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in PowerWatch.shared.update() }
        }
        center.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { _ in
            Task { @MainActor in PowerWatch.shared.update() }
        }
    }

    private func update() {
        let info = ProcessInfo.processInfo
        strained = info.thermalState == .serious || info.thermalState == .critical || info.isLowPowerModeEnabled
    }
}

enum QuietMode {
    static let after: TimeInterval = 2 * 60
    static let wakeBefore: TimeInterval = 15 * 60

    /// Pure rule, unit tested: quiet once untouched long enough, unless a meeting is close or happening.
    static func isQuiet(now: Date, lastTouch: Date, nextStart: Date?) -> Bool {
        guard now.timeIntervalSince(lastTouch) >= after else { return false }
        if let nextStart, nextStart.timeIntervalSince(now) <= wakeBefore { return false }
        return true
    }
}

/// Dims the screen a little while quiet, and puts the brightness back when quiet ends or the screen goes away.
struct QuietBrightness: ViewModifier {
    let quiet: Bool
    @State private var saved: CGFloat?
    @Environment(\.scenePhase) private var phase

    func body(content: Content) -> some View {
        content
            .onChange(of: quiet) { _, now in now ? dim() : restore() }
            .onChange(of: phase) { _, p in if p != .active { restore() } }
            .onDisappear { restore() }
    }

    private var screen: UIScreen? {
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen }.first
    }

    private func dim() {
        guard saved == nil, let screen, !ScreenshotMode.isOn else { return }
        saved = screen.brightness
        screen.brightness = max(0.1, screen.brightness * 0.6)
    }

    private func restore() {
        guard let saved, let screen else { return }
        screen.brightness = saved
        self.saved = nil
    }
}
