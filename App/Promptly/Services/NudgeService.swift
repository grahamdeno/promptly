import Foundation
import UserNotifications

/// Optional gentle nudges before the alarm: one buzz at 5 and 2 minutes before the start.
/// Off by default. iOS doesn't let them get stronger, and Focus may hold them back.
final class NudgeService {
    private let center = UNUserNotificationCenter.current()
    private let prefix = "nudge-"
    static let offsets: [Int] = [5, 2]

    func requestAccess() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func sync(_ planned: [PlannedAlarm], enabled: Bool, now: Date = .now) async {
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard enabled else { return }
        for alarm in planned {
            for minutes in Self.offsets {
                let date = alarm.meeting.start.addingTimeInterval(TimeInterval(-minutes * 60))
                guard date > now.addingTimeInterval(5) else { continue }
                let content = UNMutableNotificationContent()
                content.title = alarm.meeting.title
                content.body = "Starts in \(minutes) min"
                content.sound = .default
                content.interruptionLevel = .timeSensitive
                content.threadIdentifier = "promptly-nudges"
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
                let request = UNNotificationRequest(identifier: "\(prefix)\(alarm.meeting.id)-\(minutes)", content: content,
                                                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
                try? await center.add(request)
            }
        }
    }
}
