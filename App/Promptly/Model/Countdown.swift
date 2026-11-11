import Foundation

/// Countdown text and bubble growth. Pure logic, unit tested.
enum Countdown {
    /// The bubble grows over the last hour before a meeting.
    static let growWindow: TimeInterval = 60 * 60

    /// 0 when the meeting is an hour or more away, 1 at its start.
    static func progress(now: Date, start: Date, window: TimeInterval = growWindow) -> Double {
        let remaining = start.timeIntervalSince(now)
        guard remaining > 0 else { return 1 }
        return min(1, max(0, 1 - remaining / window))
    }

    /// The big number and its unit, as on the Home design: "12" "min", "2 h" "05", "Now".
    static func parts(now: Date, start: Date) -> (big: String, unit: String) {
        let seconds = Int(start.timeIntervalSince(now).rounded(.up))
        if seconds <= 0 { return ("Now", "") }
        let minutes = Int((Double(seconds) / 60).rounded(.up))
        if minutes < 60 { return ("\(minutes)", "min") }
        let hours = minutes / 60
        if hours < 24 { return ("\(hours) h", String(format: "%02d", minutes % 60)) }
        let days = hours / 24
        return ("\(days)", days == 1 ? "day" : "days")
    }

    /// "10:00 to 10:30" in the phone's own time format.
    /// "Tomorrow 4:35 PM to 5:05 PM", or just the times for today.
    static func span(_ meeting: Meeting, now: Date = .now) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return day(meeting.start, now: now) + "\(f.string(from: meeting.start)) to \(f.string(from: meeting.end))"
    }

    /// "10:30 AM" today, "Tomorrow 10:30 AM", or "Fri 10:30 AM".
    static func time(_ date: Date, now: Date = .now) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return day(date, now: now) + f.string(from: date)
    }

    static func day(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow "
        }
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f.string(from: date) + " "
    }
}
