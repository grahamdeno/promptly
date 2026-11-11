import Foundation
import WidgetKit

/// The upcoming meetings, written by the app into the shared App Group for the Home Screen widget.
/// The widget never reads the calendar itself.
struct WidgetSnapshot: Codable, Sendable {
    struct Item: Codable, Hashable, Sendable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let service: String
        let hasLink: Bool
    }

    var items: [Item]

    static let suite = "group.com.grahamdeno.promptly"
    private static let key = "widgetSnapshot"

    static func load(defaults: UserDefaults? = UserDefaults(suiteName: suite)) -> WidgetSnapshot {
        guard let data = defaults?.data(forKey: key),
              let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return WidgetSnapshot(items: []) }
        return snap
    }

    func save(defaults: UserDefaults? = UserDefaults(suiteName: WidgetSnapshot.suite)) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults?.set(data, forKey: Self.key)
        WidgetCenter.shared.reloadTimelines(ofKind: NextMeetingKind.kind)
    }

    /// Meetings that haven't ended by `date`.
    func upcoming(at date: Date) -> [Item] {
        items.filter { $0.end > date }.sorted { $0.start < $1.start }
    }
}

enum NextMeetingKind {
    static let kind = "PromptlyNextMeeting"
}

/// When the widget redraws. Pure, unit tested.
enum WidgetTimeline {
    /// Every 5 minutes until the last hour, then every minute so the bubble grows in steps, then at the start and end.
    static func entryDates(now: Date, start: Date?, end: Date?, maxEntries: Int = 90) -> [Date] {
        guard let start, let end, end > now else { return [now] }
        var dates: [Date] = [now]
        let hourBefore = start.addingTimeInterval(-3600)
        var t = now
        while t < start, dates.count < maxEntries {
            let step: TimeInterval = t < hourBefore ? 300 : 60
            t = t.addingTimeInterval(step)
            if t < start { dates.append(t) }
        }
        dates.append(start)
        dates.append(end)
        return Array(Set(dates.filter { $0 >= now })).sorted()
    }

    /// The bubble's growth over the last hour, 0 to 1 (same curve as the app).
    static func progress(now: Date, start: Date) -> Double {
        let remaining = start.timeIntervalSince(now)
        guard remaining > 0 else { return 1 }
        return min(1, max(0, 1 - remaining / 3600))
    }

    /// Opens Promptly and pops this meeting's bubble there.
    static func popURL(meetingID: String) -> URL? {
        var c = URLComponents()
        c.scheme = "promptly"
        c.host = "pop"
        c.queryItems = [URLQueryItem(name: "id", value: meetingID)]
        return c.url
    }
}
