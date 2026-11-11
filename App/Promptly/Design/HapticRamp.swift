import AVFoundation
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
        PopSound.play()
    }
}

/// Pop In's own alarm while it's open (Apple's is held back then): the gum pops alarm on a loop, at full alarm
/// volume, until the bubble is popped or "Not going" is tapped.
@MainActor
enum AlarmLoop {
    private static var player: AVAudioPlayer?

    static func start() {
        guard player?.isPlaying != true,
              let url = Bundle.main.url(forResource: "bubble_blow_alarm", withExtension: "wav"),
              let p = try? AVAudioPlayer(contentsOf: url) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        p.numberOfLoops = -1
        p.volume = 1
        p.play()
        player = p
    }

    static func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

/// The airy gum pop (Sounds/pop.wav, made for Pop In). Ambient: stays quiet when the silent switch is on and
/// mixes with whatever else is playing. Off when the owner turns off "Pop sound".
@MainActor
enum PopSound {
    private static var player: AVAudioPlayer? = {
        guard let url = Bundle.main.url(forResource: "pop", withExtension: "wav") else { return nil }
        let p = try? AVAudioPlayer(contentsOf: url)
        p?.prepareToPlay()
        return p
    }()

    static func play() {
        guard Prefs().popSound else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.currentTime = 0
        player?.play()
    }
}
