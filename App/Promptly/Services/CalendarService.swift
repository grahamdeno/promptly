import EventKit
import UIKit

/// Read-only access to the iPhone's calendars, including Google and Exchange accounts added in Settings.
/// Never saves, edits or removes events. CI's read-only guard enforces it.
final class CalendarService {
    let store = EKEventStore()

    var isAuthorized: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }
    var wasAsked: Bool { EKEventStore.authorizationStatus(for: .event) != .notDetermined }

    // MARK: Reminders (read only)

    static let remindersCalendarID = "apple-reminders"

    var remindersAuthorized: Bool { EKEventStore.authorizationStatus(for: .reminder) == .fullAccess }

    func requestRemindersAccess() async -> Bool {
        (try? await store.requestFullAccessToReminders()) ?? false
    }

    /// Unfinished reminders with a due time in the next two days (ones you ask Siri for: "remind me at 3 to call
    /// Mom"), as meetings so they ring the same way. Reminders with only a date and no time are skipped.
    /// Read only: Pop In never completes or changes a reminder.
    func timedReminders(hours: Double = 48, now: Date = .now) async -> [Meeting] {
        guard remindersAuthorized else { return [] }
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: now.addingTimeInterval(-3600),
                                                              ending: now.addingTimeInterval(hours * 3600), calendars: nil)
        let found: [EKReminder] = await withCheckedContinuation { done in
            store.fetchReminders(matching: predicate) { done.resume(returning: $0 ?? []) }
        }
        return found.compactMap { r -> Meeting? in
            guard let c = r.dueDateComponents, c.hour != nil, let due = Calendar.current.date(from: c) else { return nil }
            let title = (r.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let key = "rem-\(r.calendarItemIdentifier)"
            return Meeting(id: Meeting.makeID(eventID: key, start: due), eventID: key, title: title.isEmpty ? "Reminder" : title,
                           start: due, end: due.addingTimeInterval(5 * 60), calendarID: Self.remindersCalendarID, joinURL: nil)
        }
    }

    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    func calendars() -> [CalendarInfo] {
        store.calendars(for: .event)
            .map { CalendarInfo(id: $0.calendarIdentifier, title: $0.title, source: $0.source.title,
                                colorHex: Self.hex($0.cgColor)) }
            .sorted { ($0.source, $0.title) < ($1.source, $1.title) }
    }

    /// Timed events from now (and the last 15 minutes) through the next `hours`, skipping all-day,
    /// canceled and declined events.
    func upcoming(hours: Double = 48, disabled: Set<String>, acceptedOnly: Bool = false, now: Date = .now) -> [Meeting] {
        let calendars = store.calendars(for: .event).filter { !disabled.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-15 * 60),
                                                 end: now.addingTimeInterval(hours * 3600),
                                                 calendars: calendars)
        return store.events(matching: predicate).compactMap { event -> Meeting? in
            guard !event.isAllDay, event.status != .canceled else { return nil }
            if let me = event.attendees?.first(where: { $0.isCurrentUser }) {
                if me.participantStatus == .declined { return nil }
                if acceptedOnly, me.participantStatus == .tentative || me.participantStatus == .pending { return nil }
            }
            let link = MeetingLinkDetector.firstMeetingLink(in: [event.url?.absoluteString, event.location, event.notes])
            let eventID = event.eventIdentifier ?? event.calendarItemIdentifier
            let title = MeetingMerge.cleanTitle(event.title ?? "")
            return Meeting(id: Meeting.makeID(eventID: eventID, start: event.startDate),
                           eventID: eventID,
                           title: title.isEmpty ? "Untitled event" : title,
                           start: event.startDate,
                           end: event.endDate,
                           calendarID: event.calendar.calendarIdentifier,
                           joinURL: link)
        }
        .sorted { $0.start < $1.start }
    }

    private static func hex(_ color: CGColor?) -> String {
        guard let color, let c = UIColor(cgColor: color).cgColor.converted(
            to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
              let comps = c.components, comps.count >= 3 else { return "#8E8E93" }
        return String(format: "#%02X%02X%02X", Int(comps[0] * 255), Int(comps[1] * 255), Int(comps[2] * 255))
    }
}
