import Foundation

/// Work hours: Pop In rings full screen only inside them; outside, meetings get the quiet notification. Pure, tested.
struct WorkHours: Equatable, Sendable {
    var on: Bool
    /// Minutes after midnight.
    var start: Int
    var end: Int
    /// Calendar weekday numbers (1 Sunday ... 7 Saturday).
    var days: Set<Int>

    static let standard = WorkHours(on: false, start: 8 * 60, end: 17 * 60, days: [2, 3, 4, 5, 6])

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard on else { return true }
        let c = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let day = c.weekday, days.contains(day) else { return false }
        let minute = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return start <= end ? (minute >= start && minute < end) : (minute >= start || minute < end)
    }

    /// "Weekdays 8:00 AM to 5:00 PM", or "Off".
    func summary(calendar: Calendar = .current) -> String {
        guard on else { return "Off" }
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        func time(_ m: Int) -> String {
            f.string(from: calendar.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date(timeIntervalSince1970: 0)) ?? .now)
        }
        let dayText: String
        switch days {
        case [2, 3, 4, 5, 6]: dayText = "Weekdays"
        case Set(1...7): dayText = "Every day"
        default: dayText = days.sorted().map { calendar.veryShortWeekdaySymbols[$0 - 1] }.joined(separator: " ")
        }
        return "\(dayText) \(time(start)) to \(time(end))"
    }
}

/// Pausing alerts for a while (lunch, focus time). Pure, tested.
enum PauseRule {
    /// A meeting starting before the pause ends gets no alarm and no notification.
    static func silences(_ start: Date, pausedUntil: Date?, now: Date) -> Bool {
        guard let pausedUntil, pausedUntil > now else { return false }
        return start < pausedUntil
    }

    /// Until the start of tomorrow.
    static func endOfDay(from now: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: now.addingTimeInterval(24 * 3600))
    }
}

/// Snooze on the alarm screen: ring again a little later.
enum Snooze {
    static let length: TimeInterval = 2 * 60
}
