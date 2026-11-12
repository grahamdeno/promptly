import Foundation

/// App Store screenshots. The Screenshots UI test launches Pop In with `-screenshots -scene <name>`; Pop In then shows
/// made-up meetings instead of the calendar, schedules no alarms and unlocks every Pro feature. Never used otherwise.
enum ScreenshotScene: String {
    case home, now, late, unicorn, settings, pop, pro
    /// For the UX audit: first run, nothing coming up, the next meeting tomorrow, and a long list of calendars.
    case welcome, empty, far, manycals
}

enum ScreenshotMode {
    static let scene: ScreenshotScene? = {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-screenshots") else { return nil }
        if let i = args.firstIndex(of: "-scene"), i + 1 < args.count {
            return ScreenshotScene(rawValue: args[i + 1]) ?? .home
        }
        return .home
    }()

    static var isOn: Bool { scene != nil }
    static let args = ProcessInfo.processInfo.arguments
    /// `-free`: show the free version (Pro choices locked), for the audit.
    static var free: Bool { args.contains("-free") }

    /// Demo meetings, timed relative to launch so the countdown and the bubble look right.
    static func meetings(now: Date = .now) -> [Meeting] {
        let firstStart: Date
        switch scene {
        case .now: firstStart = now.addingTimeInterval(2 * 60)
        case .far: firstStart = Calendar.current.date(bySettingHour: 16, minute: 35, second: 0,
                                                      of: now.addingTimeInterval(24 * 3600)) ?? now.addingTimeInterval(20 * 3600)
        case .late: firstStart = now.addingTimeInterval(120 - 50)   // 50 s after a 2-minute-early ring
        default: firstStart = now.addingTimeInterval(7 * 60 + 20)
        }
        func meeting(_ id: String, _ title: String, _ start: Date, minutes: Double, calendar: String, link: String?) -> Meeting {
            Meeting(id: "shot-\(id)", eventID: "shot-\(id)", title: title, start: start,
                    end: start.addingTimeInterval(minutes * 60), calendarID: calendar, joinURL: link.flatMap(URL.init(string:)))
        }
        let tomorrow = Calendar.current.date(bySettingHour: 9, minute: 30, second: 0,
                                             of: now.addingTimeInterval(24 * 3600)) ?? now.addingTimeInterval(24 * 3600)
        return [
            meeting("design", "Design review", firstStart, minutes: 30, calendar: "shot-work",
                    link: "https://zoom.us/j/5550100200"),
            meeting("standup", "Team standup", firstStart.addingTimeInterval(55 * 60), minutes: 15, calendar: "shot-work",
                    link: "https://teams.microsoft.com/l/meetup-join/demo"),
            meeting("lunch", "Lunch with Sam", firstStart.addingTimeInterval(3 * 3600), minutes: 60, calendar: "shot-home",
                    link: nil),
            meeting("planning", "Sprint planning", tomorrow, minutes: 60, calendar: "shot-work",
                    link: "https://meet.google.com/abc-defg-hij"),
        ]
    }

    /// 22 calendars over five accounts, like a phone with work, family, school and subscriptions.
    static let manyCalendars: [CalendarInfo] = {
        let sets: [(String, [String])] = [
            ("iCloud", ["Home", "Family", "Kids", "Birthdays", "Anniversaries"]),
            ("Exchange", ["Calendar", "Team", "Projects", "Out of office", "Training", "Holidays"]),
            ("Gmail", ["Personal", "Soccer", "Band", "School"]),
            ("Subscribed", ["US Holidays", "Moon phases", "Hockey schedule", "Sunrise and sunset"]),
            ("Other", ["Siri Suggestions", "Scheduled Reminders", "Found in Mail"]),
        ]
        let colors = ["#FF5A8A", "#34A0FF", "#2EC27E", "#F5A623", "#9B5CFF", "#8E8E93"]
        var out: [CalendarInfo] = []
        for (i, set) in sets.enumerated() {
            for (j, title) in set.1.enumerated() {
                out.append(CalendarInfo(id: "many-\(i)-\(j)", title: title, source: set.0, colorHex: colors[(i + j) % colors.count]))
            }
        }
        return out
    }()

    static let calendars: [CalendarInfo] = [
        CalendarInfo(id: "shot-work", title: "Work", source: "Exchange", colorHex: "#FF5A8A"),
        CalendarInfo(id: "shot-home", title: "Home", source: "iCloud", colorHex: "#34A0FF"),
        CalendarInfo(id: "shot-family", title: "Family", source: "iCloud", colorHex: "#2EC27E"),
    ]
}
