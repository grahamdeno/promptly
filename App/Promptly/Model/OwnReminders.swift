import Foundation

/// A reminder made inside Pop In ("Pick up Nora at 3:15"). Kept on this iPhone only; never written to a calendar.
struct OwnReminder: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var title: String
    var date: Date

    static let calendarID = "pop-in-reminders"

    /// As a Meeting, so it gets the same bubble, alarm and alarm screen.
    var meeting: Meeting {
        Meeting(id: "own-\(id)", eventID: "own-\(id)", title: title, start: date, end: date.addingTimeInterval(5 * 60),
                calendarID: Self.calendarID, joinURL: nil)
    }

    /// Reminders still worth keeping: not more than an hour past.
    static func live(_ all: [OwnReminder], now: Date) -> [OwnReminder] {
        all.filter { $0.date > now.addingTimeInterval(-3600) }.sorted { $0.date < $1.date }
    }
}
