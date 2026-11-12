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
    @MainActor private static let impact = UIImpactFeedbackGenerator(style: .rigid)
    @MainActor private static let notice = UINotificationFeedbackGenerator()

    /// Warms up the haptics and the sound so the first pop lands instantly.
    @MainActor static func prepare() {
        impact.prepare()
        notice.prepare()
        PopSound.prepare()
    }

    @MainActor static func pop() {
        PopSound.play()
        impact.impactOccurred(intensity: 1)
        notice.notificationOccurred(.success)
        impact.prepare()
        notice.prepare()
    }
}

/// Pop In's own alarm while it's open (Apple's is held back then): the gum pops alarm on a loop, at full alarm
/// volume, until the bubble is popped or "Not going" is tapped.
@MainActor
enum AlarmLoop {
    private static var player: AVAudioPlayer?

    /// Volume while Pop In rings itself: quiet at first, rising over the last two minutes to full at the start time.
    nonisolated static func volume(now: Date, start: Date) -> Float {
        let remaining = start.timeIntervalSince(now)
        if remaining <= 0 { return 1 }
        if remaining >= 120 { return quiet }
        return quiet + (1 - quiet) * Float(1 - remaining / 120)
    }
    nonisolated static let quiet: Float = 0.25
    private static var ramp: Task<Void, Never>?

    static func start(meetingStart: Date? = nil) {
        let file = Prefs().alarmSound.fileName
        guard player?.isPlaying != true,
              let url = Bundle.main.url(forResource: (file as NSString).deletingPathExtension, withExtension: "wav"),
              let p = try? AVAudioPlayer(contentsOf: url) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        p.numberOfLoops = -1
        p.volume = meetingStart.map { volume(now: .now, start: $0) } ?? 1
        p.play()
        player = p
        ramp?.cancel()
        if let meetingStart {
            ramp = Task { @MainActor in
                while !Task.isCancelled, player === p {
                    try? await Task.sleep(for: .milliseconds(500))
                    let v = volume(now: .now, start: meetingStart)
                    p.setVolume(v, fadeDuration: 0.5)
                    if v >= 1 { break }
                }
            }
        }
    }

    /// A short sample when a sound is picked in settings, so each choice can be heard right away.
    /// Uses the playback category so it's audible with the silent switch on, like the alarm itself.
    static func preview(_ choice: AlarmSoundChoice, seconds: Double = 4) {
        stop()
        guard let url = Bundle.main.url(forResource: (choice.fileName as NSString).deletingPathExtension, withExtension: "wav"),
              let p = try? AVAudioPlayer(contentsOf: url) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        p.volume = 1
        p.play()
        player = p
        previewEnd?.cancel()
        previewEnd = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            if !Task.isCancelled, player === p { stop() }
        }
    }

    private static var previewEnd: Task<Void, Never>?

    static var isPlaying: Bool { player?.isPlaying == true }

    static func stop() {
        ramp?.cancel()
        ramp = nil
        previewEnd?.cancel()
        previewEnd = nil
        let wasPlaying = player != nil
        player?.stop()
        player = nil
        // Off the main thread: deactivating the session can take a moment, and this runs during the pop.
        if wasPlaying {
            DispatchQueue.global(qos: .userInitiated).async {
                try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            }
        }
    }
}

/// The airy gum pop (Sounds/pop.wav, made for Pop In). Ambient: stays quiet when the silent switch is on and
/// mixes with whatever else is playing. Off when the owner turns off "Pop sound".
@MainActor
enum PopSound {
    /// Every pop sound, loaded once.
    private static var players: [PopChoice: AVAudioPlayer] = {
        var all: [PopChoice: AVAudioPlayer] = [:]
        for choice in PopChoice.allCases where choice != .themeSound {
            if let name = choice.fileName, let p = load(name) { all[choice] = p }
        }
        return all
    }()
    /// The theme sounds, by file name, loaded when first used.
    private static var byFile: [String: AVAudioPlayer] = [:]
    private static func player(for choice: PopChoice) -> AVAudioPlayer? {
        guard choice == .themeSound else { return players[choice] }
        let name = GumPalette.current.popFile
        if let p = byFile[name] { return p }
        let p = load(name)
        byFile[name] = p
        return p
    }

    private static func load(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        let p = try? AVAudioPlayer(contentsOf: url)
        p?.prepareToPlay()
        return p
    }

    /// Loads both sounds ahead of time (at launch), so a tap never waits on reading a file.
    static func prepare() {
        _ = players
        _ = player(for: .themeSound)
    }

    /// Pop or Sparkle, as chosen in settings (Unicorn mode defaults to Sparkle). Never activates the audio session
    /// by hand: that call can stall the main thread for a moment, which showed as a hitch at the pop.
    static func play() {
        let choice = Prefs().popChoice
        guard choice != .off else { return }
        let session = AVAudioSession.sharedInstance()
        if session.category != .ambient, !AlarmLoop.isPlaying {
            try? session.setCategory(.ambient, options: [.mixWithOthers])
        }
        let player = player(for: choice) ?? players[.pop]
        player?.currentTime = 0
        player?.play()
    }
}
