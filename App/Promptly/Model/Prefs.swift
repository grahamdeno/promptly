import Foundation

enum AlarmSoundChoice: String, CaseIterable, Sendable {
    /// The airy gum pop (#5) repeating in a rhythm that speeds up (Sounds/bubble_blow_alarm.wav). Shown as "Gum pops".
    case bubbleBlow
    /// Apple's standard alarm sound. AlarmKit can't pick a named system tone such as Mercury.
    case appleDefault
    /// "Popcorn": the owner's own recorded pops, cleaned up, evened out and made louder
    /// (Sounds/recorded_pops_alarm.wav; the raw value and file name stay "recorded" so saved choices keep working). Pro.
    case recorded
    /// Bright rising chimes for Unicorn mode (Sounds/unicorn_chimes_alarm.wav). Pro.
    case chimes
    /// "Oracle": a humming singing bowl, struck and swelling, made for Fortune (Sounds/oracle_alarm.wav). Pro.
    case oracle

    var isPro: Bool { self == .recorded || self == .chimes || self == .oracle }

    var label: String {
        switch self {
        case .bubbleBlow: "Gum pops"
        case .recorded: "Popcorn"
        case .chimes: "Chimes"
        case .oracle: "Oracle"
        case .appleDefault: "Apple"
        }
    }

    /// The bundled file for this sound; Apple's default has none, so Pop In's own ring uses Gum pops for it.
    var fileName: String {
        switch self {
        case .recorded: "recorded_pops_alarm.wav"
        case .chimes: "unicorn_chimes_alarm.wav"
        case .oracle: "oracle_alarm.wav"
        default: "bubble_blow_alarm.wav"
        }
    }
}

/// The sound when a bubble pops. Unicorn mode defaults to Sparkle, other colors to Pop, until the owner picks one.
enum PopChoice: String, CaseIterable, Sendable {
    /// One real gum pop, taken from the owner's recording (Sounds/pop.wav).
    case pop
    /// A pop with a shower of tiny bells (Sounds/unicorn_pop.wav).
    case sparkle
    /// A quick swell into a bright ting with a sparkly tail (Sounds/fortune_pop.wav). Fortune's default.
    case star
    case off

    var label: String {
        switch self {
        case .pop: "Pop"
        case .sparkle: "Sparkle"
        case .star: "Star"
        case .off: "Off"
        }
    }
}

enum BallStyle: String, CaseIterable, Sendable {
    /// Inflates as the meeting nears and pops when cleared. The owner may roll this back to `.steady`.
    case bubble
    /// A still ball that never grows or pops.
    case steady
}

/// Settings and small state, kept in the shared App Group so the widget (next sprint) can read them.
final class Prefs: @unchecked Sendable {
    static let suite = "group.com.grahamdeno.promptly"
    let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: Prefs.suite) ?? .standard) {
        self.defaults = defaults
    }

    var onboarded: Bool {
        get { defaults.bool(forKey: "onboarded") }
        set { defaults.set(newValue, forKey: "onboarded") }
    }

    /// Minutes before the start that the alarm rings: 1, 2 or 5. Default 1.
    var leadMinutes: Int {
        get { let v = defaults.integer(forKey: "leadMinutes"); return v == 0 ? 1 : v }
        set { defaults.set(newValue, forKey: "leadMinutes") }
    }

    var ballStyle: BallStyle {
        get { BallStyle(rawValue: defaults.string(forKey: "ballStyle") ?? "") ?? .bubble }
        set { defaults.set(newValue.rawValue, forKey: "ballStyle") }
    }

    /// Countdown card on the Lock Screen and in the Dynamic Island for ten minutes before the alarm. Default on.
    var countdownCard: Bool {
        get { defaults.object(forKey: "countdownCard") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "countdownCard") }
    }

    /// Buzz that builds while Promptly is open in the last ten minutes. Default on.
    var buzz: Bool {
        get { defaults.object(forKey: "buzz") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "buzz") }
    }

    /// The gum pop sound when the bubble pops. Default on.
    /// Older on/off switch for the pop sound; only read to work out the default below.
    var popSound: Bool {
        get { defaults.object(forKey: "popSound") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "popSound") }
    }

    /// Fortune theme: show a light meeting fortune on the card in the last ten minutes.
    var fortunes: Bool {
        get { defaults.object(forKey: "fortunes") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "fortunes") }
    }

    /// The pop sound the owner picked, or nil if they never picked one.
    var popChoiceSaved: PopChoice? {
        get { defaults.string(forKey: "popChoice").flatMap(PopChoice.init(rawValue:)) }
        set { defaults.set(newValue?.rawValue, forKey: "popChoice") }
    }

    /// The pop sound in use: the owner's pick, else Sparkle in Unicorn mode and Pop otherwise.
    var popChoice: PopChoice {
        if let saved = popChoiceSaved { return saved }
        if !popSound { return .off }
        switch gumColor {
        case .unicorn: return .sparkle
        case .fortune: return .star
        default: return .pop
        }
    }

    /// One-buzz nudges at 5 and 2 minutes before. Default off.
    var nudges: Bool {
        get { defaults.bool(forKey: "nudges") }
        set { defaults.set(newValue, forKey: "nudges") }
    }

    /// True after the first pop, so the one-time "Tap the bubble" line stops showing.
    var taughtPop: Bool {
        get { defaults.bool(forKey: "taughtPop") }
        set { defaults.set(newValue, forKey: "taughtPop") }
    }

    var gumColor: GumPalette {
        get { GumPalette(rawValue: defaults.string(forKey: GumPalette.key) ?? "") ?? .bubblegum }
        set { defaults.set(newValue.rawValue, forKey: GumPalette.key) }
    }

    var alarmSound: AlarmSoundChoice {
        get { AlarmSoundChoice(rawValue: defaults.string(forKey: "alarmSound") ?? "") ?? .bubbleBlow }
        set { defaults.set(newValue.rawValue, forKey: "alarmSound") }
    }

    /// Calendars that always get a full alarm, even for events without a video link.
    var alarmCalendarIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: "alarmCalendarIDs") ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: "alarmCalendarIDs") }
    }

    /// Calendars that get a gentle notification instead of a full alarm.
    var gentleCalendarIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: "gentleCalendarIDs") ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: "gentleCalendarIDs") }
    }

    /// Keep the screen on while Pop In is open (handy on an iPad left on the desk). Default off.
    var keepAwake: Bool {
        get { defaults.bool(forKey: "keepAwake") }
        set { defaults.set(newValue, forKey: "keepAwake") }
    }

    /// Calendars switched off. Everything else rings, so a newly added calendar is on by default.
    var disabledCalendarIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: "disabledCalendarIDs") ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: "disabledCalendarIDs") }
    }

    /// Meetings joined or cleared: no alarm, and Home moves on to the next one.
    var clearedMeetingIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: "clearedMeetingIDs") ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: "clearedMeetingIDs") }
    }
}

/// Written by the alarm's Join button (OpenMeetingIntent) and read when the app opens.
struct PendingJoin: Codable, Sendable {
    let meetingID: String
    let joinURL: String
    let date: Date

    private static let key = "pendingJoin"

    static func save(meetingID: String, joinURL: String, defaults: UserDefaults = Prefs().defaults) {
        let value = PendingJoin(meetingID: meetingID, joinURL: joinURL, date: .now)
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    /// Returns and removes the pending join if it is less than ten minutes old.
    static func take(now: Date = .now, defaults: UserDefaults = Prefs().defaults) -> PendingJoin? {
        guard let data = defaults.data(forKey: key) else { return nil }
        defaults.removeObject(forKey: key)
        guard let value = try? JSONDecoder().decode(PendingJoin.self, from: data),
              now.timeIntervalSince(value.date) < 600 else { return nil }
        return value
    }
}
