import CryptoKit
import Foundation

struct PlannedAlarm: Hashable, Sendable {
    let id: UUID
    let meeting: Meeting
    /// When the alarm rings.
    let fireDate: Date
    /// Length of the Lock Screen countdown card before it rings; nil for a plain alarm.
    let countdownSeconds: TimeInterval?

    /// When AlarmKit should start: the countdown's start when there is one, else the ring time.
    /// Assumption to confirm on device: a fixed schedule with a pre-alert countdown starts counting at the scheduled
    /// date and rings when the countdown ends. If the phone shows otherwise, flip `AlarmPlanner.countdownStartsAtSchedule`.
    var scheduleDate: Date {
        guard let countdownSeconds, AlarmPlanner.countdownStartsAtSchedule else { return fireDate }
        return fireDate.addingTimeInterval(-countdownSeconds)
    }
}

/// Decides which alarms should exist. Pure: the AlarmService makes the system match this list.
enum AlarmPlanner {
    /// AlarmKit has no published cap, so stay modest: the next day or two of meetings.
    static let defaultLimit = 24
    /// The Lock Screen countdown card shows for this long before the alarm rings.
    static let countdownWindow: TimeInterval = 10 * 60
    static let countdownStartsAtSchedule = true

    static func plan(meetings: [Meeting], leadMinutes: Int, now: Date, cleared: Set<String>,
                     countdown: Bool = false, limit: Int = defaultLimit) -> [PlannedAlarm] {
        let lead = TimeInterval(max(0, leadMinutes) * 60)
        return meetings
            .filter { !cleared.contains($0.id) }
            .map { meeting -> PlannedAlarm in
                let fire = meeting.start.addingTimeInterval(-lead)
                // Only add a countdown when the whole window is still ahead; otherwise ring plainly.
                let hasRoom = fire.timeIntervalSince(now) >= countdownWindow + 60
                let seconds: TimeInterval? = (countdown && hasRoom) ? countdownWindow : nil
                return PlannedAlarm(id: stableID(for: meeting, leadMinutes: leadMinutes, countdown: seconds != nil),
                                    meeting: meeting, fireDate: fire, countdownSeconds: seconds)
            }
            .filter { $0.fireDate > now }
            .sorted { $0.fireDate < $1.fireDate }
            .prefix(limit)
            .map { $0 }
    }

    /// Same meeting, title, link, lead time and countdown gives the same ID, so re-syncing never duplicates an alarm,
    /// and any change gives a new ID that replaces the old alarm.
    static func stableID(for meeting: Meeting, leadMinutes: Int, countdown: Bool = false) -> UUID {
        let key = [meeting.id, meeting.title, String(leadMinutes),
                   String(Int(meeting.start.timeIntervalSince1970)), meeting.joinURL?.absoluteString ?? "",
                   countdown ? "cd" : ""]
            .joined(separator: "|")
        var b = Array(SHA256.hash(data: Data(key.utf8)).prefix(16))
        b[6] = (b[6] & 0x0F) | 0x50 // version 5 style
        b[8] = (b[8] & 0x3F) | 0x80 // RFC 4122 variant
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }
}

/// How the in-app buzz builds as a meeting nears. Pure, unit tested.
enum HapticCurve {
    /// Buzzing starts this long before the start.
    static let window: TimeInterval = 10 * 60

    /// Strength 0...1 and seconds until the next tap, or nil when it shouldn't buzz.
    static func at(remaining: TimeInterval) -> (intensity: Double, interval: TimeInterval)? {
        if remaining > window || remaining < -60 { return nil }
        if remaining <= 0 { return (1, 0.5) }
        let t = 1 - remaining / window          // 0 at ten minutes, 1 at the start
        let intensity = 0.15 + 0.85 * pow(t, 1.5)
        let interval = 6 - 5.4 * t              // every 6 s at first, every 0.6 s at the start
        return (min(1, intensity), max(0.6, interval))
    }
}
