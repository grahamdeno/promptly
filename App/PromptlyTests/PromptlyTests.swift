import XCTest
@testable import Promptly

final class MeetingLinkDetectorTests: XCTestCase {
    func testFindsServicesIncludingGovernmentTeams() {
        XCTAssertEqual(MeetingLinkDetector.service(for: URL(string: "https://us02web.zoom.us/j/123")!), .zoom)
        XCTAssertEqual(MeetingLinkDetector.service(for: URL(string: "https://teams.microsoft.com/l/meetup-join/abc")!), .teams)
        XCTAssertEqual(MeetingLinkDetector.service(for: URL(string: "https://dod.teams.microsoft.us/l/meetup-join/abc")!), .teams)
        XCTAssertEqual(MeetingLinkDetector.service(for: URL(string: "https://meet.google.com/abc-defg-hij")!), .meet)
        XCTAssertNil(MeetingLinkDetector.service(for: URL(string: "https://example.com/zoom.us")!))
        XCTAssertNil(MeetingLinkDetector.service(for: URL(string: "https://notzoom.us/j/1")!))
    }

    func testPicksTheMeetingLinkFromNotes() {
        let notes = "Agenda: https://example.com/doc\nJoin: https://teams.microsoft.com/l/meetup-join/xyz thanks"
        let url = MeetingLinkDetector.firstMeetingLink(in: [nil, "Room 4", notes])
        XCTAssertEqual(url?.host, "teams.microsoft.com")
    }

    func testNoLink() {
        XCTAssertNil(MeetingLinkDetector.firstMeetingLink(in: ["Dentist", nil, "Bring card"]))
    }
}

final class AlarmPlannerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func meeting(_ id: String, inMinutes m: Double, title: String = "Sync") -> Meeting {
        let start = now.addingTimeInterval(m * 60)
        return Meeting(id: Meeting.makeID(eventID: id, start: start), eventID: id, title: title,
                       start: start, end: start.addingTimeInterval(1800), calendarID: "c", joinURL: nil)
    }

    func testPlansFutureAlarmsInOrderAndSkipsClearedAndPast() {
        let a = meeting("a", inMinutes: 30)
        let b = meeting("b", inMinutes: 10)
        let past = meeting("p", inMinutes: 0.5) // alarm time already passed with a 1 minute lead
        let cleared = meeting("c", inMinutes: 20)
        let plan = AlarmPlanner.plan(meetings: [a, b, past, cleared], leadMinutes: 1, now: now, cleared: [cleared.id])
        XCTAssertEqual(plan.map(\.meeting.id), [b.id, a.id])
        XCTAssertEqual(plan.first?.fireDate, b.start.addingTimeInterval(-60))
    }

    func testStableIDsChangeWhenTheMeetingChanges() {
        let a = meeting("a", inMinutes: 30)
        XCTAssertEqual(AlarmPlanner.stableID(for: a, leadMinutes: 1), AlarmPlanner.stableID(for: a, leadMinutes: 1))
        XCTAssertNotEqual(AlarmPlanner.stableID(for: a, leadMinutes: 1), AlarmPlanner.stableID(for: a, leadMinutes: 5))
        let renamed = meeting("a", inMinutes: 30, title: "Renamed")
        XCTAssertNotEqual(AlarmPlanner.stableID(for: a, leadMinutes: 1), AlarmPlanner.stableID(for: renamed, leadMinutes: 1))
    }

    func testRespectsLimit() {
        let many = (1...40).map { meeting("m\($0)", inMinutes: Double($0 * 10)) }
        XCTAssertEqual(AlarmPlanner.plan(meetings: many, leadMinutes: 1, now: now, cleared: []).count, AlarmPlanner.defaultLimit)
    }
}

final class CountdownTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testProgress() {
        XCTAssertEqual(Countdown.progress(now: now, start: now.addingTimeInterval(7200)), 0)
        XCTAssertEqual(Countdown.progress(now: now, start: now.addingTimeInterval(1800)), 0.5, accuracy: 0.0001)
        XCTAssertEqual(Countdown.progress(now: now, start: now), 1)
    }

    func testParts() {
        XCTAssertEqual(Countdown.parts(now: now, start: now.addingTimeInterval(11 * 60 + 5)).big, "12")
        XCTAssertEqual(Countdown.parts(now: now, start: now.addingTimeInterval(11 * 60 + 5)).unit, "min")
        let later = Countdown.parts(now: now, start: now.addingTimeInterval(125 * 60))
        XCTAssertEqual(later.big, "2 h")
        XCTAssertEqual(later.unit, "05")
        XCTAssertEqual(Countdown.parts(now: now, start: now.addingTimeInterval(-5)).big, "Now")
    }
}

final class PendingJoinTests: XCTestCase {
    func testTakeOnceAndExpire() {
        let defaults = UserDefaults(suiteName: "promptly.tests.\(UUID().uuidString)")!
        PendingJoin.save(meetingID: "m", joinURL: "https://zoom.us/j/1", defaults: defaults)
        XCTAssertEqual(PendingJoin.take(defaults: defaults)?.meetingID, "m")
        XCTAssertNil(PendingJoin.take(defaults: defaults))
        PendingJoin.save(meetingID: "m", joinURL: "", defaults: defaults)
        XCTAssertNil(PendingJoin.take(now: Date().addingTimeInterval(700), defaults: defaults))
    }
}
