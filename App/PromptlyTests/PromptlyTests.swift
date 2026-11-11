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

final class CountdownCardAndBuzzTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func meeting(inMinutes m: Double) -> Meeting {
        let start = now.addingTimeInterval(m * 60)
        return Meeting(id: Meeting.makeID(eventID: "e", start: start), eventID: "e", title: "Sync",
                       start: start, end: start.addingTimeInterval(1800), calendarID: "c", joinURL: nil)
    }

    func testCountdownStartsTenMinutesBeforeTheRing() {
        let m = meeting(inMinutes: 60)
        let plan = AlarmPlanner.plan(meetings: [m], leadMinutes: 1, now: now, cleared: [], countdown: true)
        XCTAssertEqual(plan.first?.countdownSeconds, AlarmPlanner.countdownWindow)
        XCTAssertEqual(plan.first?.fireDate, m.start.addingTimeInterval(-60))
        XCTAssertEqual(plan.first?.scheduleDate, m.start.addingTimeInterval(-60 - AlarmPlanner.countdownWindow))
    }

    func testNoCountdownWhenTooClose() {
        let plan = AlarmPlanner.plan(meetings: [meeting(inMinutes: 8)], leadMinutes: 1, now: now, cleared: [], countdown: true)
        XCTAssertNil(plan.first?.countdownSeconds)
        XCTAssertEqual(plan.first?.scheduleDate, plan.first?.fireDate)
    }

    func testCountdownChangesTheAlarmID() {
        let m = meeting(inMinutes: 60)
        XCTAssertNotEqual(AlarmPlanner.stableID(for: m, leadMinutes: 1, countdown: true),
                          AlarmPlanner.stableID(for: m, leadMinutes: 1, countdown: false))
    }

    func testBuzzBuildsTowardTheStart() {
        XCTAssertNil(HapticCurve.at(remaining: 11 * 60))
        let early = HapticCurve.at(remaining: 9 * 60)!
        let late = HapticCurve.at(remaining: 30)!
        XCTAssertLessThan(early.intensity, late.intensity)
        XCTAssertGreaterThan(early.interval, late.interval)
        XCTAssertEqual(HapticCurve.at(remaining: 0)?.intensity, 1)
        XCTAssertNil(HapticCurve.at(remaining: -61))
    }

    func testMetadataLinkCarriesTheMeetingID() {
        let meta = MeetingAlarmMetadata(meetingID: "ABC:12/3@1800000000", title: "Sync", start: now, service: "Teams",
                                        countdownSeconds: 600)
        let url = meta.openURL!
        XCTAssertEqual(url.scheme, "promptly")
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "ABC:12/3@1800000000")
    }
}

final class WidgetTimelineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testMinuteStepsInTheLastHourAndFiveMinuteStepsBefore() {
        let start = now.addingTimeInterval(90 * 60)
        let dates = WidgetTimeline.entryDates(now: now, start: start, end: start.addingTimeInterval(1800))
        XCTAssertEqual(dates.first, now)
        XCTAssertTrue(dates.contains(start))
        XCTAssertTrue(dates.contains(start.addingTimeInterval(1800)))
        XCTAssertEqual(dates[1].timeIntervalSince(dates[0]), 300)
        let lastHour = dates.filter { $0 > start.addingTimeInterval(-3600) && $0 < start }
        XCTAssertGreaterThanOrEqual(lastHour.count, 55)
        XCTAssertLessThanOrEqual(dates.count, 92)
    }

    func testNothingUpcoming() {
        XCTAssertEqual(WidgetTimeline.entryDates(now: now, start: nil, end: nil), [now])
    }

    func testPopLink() {
        let url = WidgetTimeline.popURL(meetingID: "A:1@2")!
        XCTAssertEqual(url.host, "pop")
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "A:1@2")
    }

    func testSnapshotRoundTripAndUpcoming() {
        let defaults = UserDefaults(suiteName: "promptly.tests.\(UUID().uuidString)")!
        let past = WidgetSnapshot.Item(id: "p", title: "Done", start: now.addingTimeInterval(-7200),
                                       end: now.addingTimeInterval(-3600), service: "", hasLink: false)
        let next = WidgetSnapshot.Item(id: "n", title: "Sync", start: now.addingTimeInterval(600),
                                       end: now.addingTimeInterval(2400), service: "Zoom", hasLink: true)
        WidgetSnapshot(items: [next, past]).save(defaults: defaults)
        let loaded = WidgetSnapshot.load(defaults: defaults)
        XCTAssertEqual(loaded.upcoming(at: now).map(\.id), ["n"])
    }
}

final class DayLabelTests: XCTestCase {
    func testTodayTomorrowAndLater() {
        let cal = Calendar.current
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 17))!
        XCTAssertEqual(Countdown.day(now.addingTimeInterval(3600), now: now), "")
        XCTAssertEqual(Countdown.day(now.addingTimeInterval(23 * 3600), now: now), "Tomorrow ")
        XCTAssertFalse(Countdown.day(now.addingTimeInterval(3 * 86400), now: now).isEmpty)
    }
}

final class MergeAndBackupTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func meeting(_ id: String, inMinutes m: Double, title: String) -> Meeting {
        let start = now.addingTimeInterval(m * 60)
        return Meeting(id: Meeting.makeID(eventID: id, start: start), eventID: id, title: title,
                       start: start, end: start.addingTimeInterval(1800), calendarID: "c", joinURL: nil)
    }

    func testSameMinuteMeetingsShareOneAlarm() {
        let a = meeting("a", inMinutes: 30, title: "Sprint review")
        let b = meeting("b", inMinutes: 30, title: "Customer sync")
        let c = meeting("c", inMinutes: 60, title: "Later")
        let plan = AlarmPlanner.plan(meetings: [a, b, c], leadMinutes: 1, now: now, cleared: [])
        XCTAssertEqual(plan.count, 2)
        XCTAssertEqual(plan.first?.meeting.title, "Sprint review + Customer sync")
    }

    func testBackupRingsOneMinuteLaterWithItsOwnID() {
        let plan = AlarmPlanner.plan(meetings: [meeting("a", inMinutes: 30, title: "A")], leadMinutes: 1, now: now, cleared: [])
        let backup = AlarmPlanner.safetyBackup(for: plan[0])
        XCTAssertEqual(backup.fireDate, plan[0].fireDate.addingTimeInterval(60))
        XCTAssertNotEqual(backup.id, plan[0].id)
        XCTAssertEqual(backup.id, AlarmPlanner.safetyBackup(for: plan[0]).id)
    }
}
