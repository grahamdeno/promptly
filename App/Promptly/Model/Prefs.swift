import Foundation

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
