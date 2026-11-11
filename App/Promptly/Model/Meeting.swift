import Foundation

/// One upcoming calendar event, read from EventKit. Promptly never writes events back.
struct Meeting: Identifiable, Hashable, Sendable {
    /// Stable key: the event identifier plus its start time, so each occurrence of a repeating event is distinct.
    let id: String
    let eventID: String
    let title: String
    let start: Date
    let end: Date
    let calendarID: String
    let joinURL: URL?

    var service: MeetingService? { joinURL.flatMap(MeetingLinkDetector.service(for:)) }

    static func makeID(eventID: String, start: Date) -> String {
        "\(eventID)@\(Int(start.timeIntervalSince1970))"
    }
}

struct CalendarInfo: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let source: String
    let colorHex: String
}
