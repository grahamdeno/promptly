import CryptoKit
import Foundation

struct PlannedAlarm: Hashable, Sendable {
    let id: UUID
    let meeting: Meeting
    let fireDate: Date
}

/// Decides which alarms should exist. Pure: the AlarmService makes the system match this list.
enum AlarmPlanner {
    /// AlarmKit has no published cap, so stay modest: the next day or two of meetings.
    static let defaultLimit = 24

    static func plan(meetings: [Meeting], leadMinutes: Int, now: Date, cleared: Set<String>,
                     limit: Int = defaultLimit) -> [PlannedAlarm] {
        let lead = TimeInterval(max(0, leadMinutes) * 60)
        return meetings
            .filter { !cleared.contains($0.id) }
            .map { PlannedAlarm(id: stableID(for: $0, leadMinutes: leadMinutes), meeting: $0,
                                fireDate: $0.start.addingTimeInterval(-lead)) }
            .filter { $0.fireDate > now }
            .sorted { $0.fireDate < $1.fireDate }
            .prefix(limit)
            .map { $0 }
    }

    /// Same meeting, title, link and lead time gives the same ID, so re-syncing never duplicates an alarm,
    /// and any change (moved, renamed, new link, new lead time) gives a new ID that replaces the old alarm.
    static func stableID(for meeting: Meeting, leadMinutes: Int) -> UUID {
        let key = [meeting.id, meeting.title, String(leadMinutes),
                   String(Int(meeting.start.timeIntervalSince1970)), meeting.joinURL?.absoluteString ?? ""]
            .joined(separator: "|")
        var b = Array(SHA256.hash(data: Data(key.utf8)).prefix(16))
        b[6] = (b[6] & 0x0F) | 0x50 // version 5 style
        b[8] = (b[8] & 0x3F) | 0x80 // RFC 4122 variant
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }
}
