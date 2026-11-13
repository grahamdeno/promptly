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

final class CalendarGroupsTests: XCTestCase {
    private let cals = [
        CalendarInfo(id: "1", title: "Work", source: "Exchange", colorHex: "#000000"),
        CalendarInfo(id: "2", title: "Home", source: "iCloud", colorHex: "#000000"),
        CalendarInfo(id: "3", title: "Family", source: "iCloud", colorHex: "#000000"),
        CalendarInfo(id: "4", title: "Holidays", source: "", colorHex: "#000000"),
    ]

    func testGroupsByAccountSorted() {
        let groups = CalendarGroups.group(cals)
        XCTAssertEqual(groups.map(\.source), ["Exchange", "iCloud", "Other"])
        XCTAssertEqual(groups[1].calendars.map(\.title), ["Family", "Home"])
    }

    func testSearchMatchesTitleOrAccount() {
        XCTAssertEqual(CalendarGroups.group(cals, matching: "fam").flatMap(\.calendars).map(\.id), ["3"])
        XCTAssertEqual(CalendarGroups.group(cals, matching: "ICLOUD").flatMap(\.calendars).count, 2)
        XCTAssertTrue(CalendarGroups.group(cals, matching: "zzz").isEmpty)
    }

    func testSummaryAndCounts() {
        XCTAssertEqual(CalendarGroups.summary(cals, disabled: []), "All 4")
        XCTAssertEqual(CalendarGroups.summary(cals, disabled: ["2", "4"]), "2 of 4")
        XCTAssertEqual(CalendarGroups.summary([], disabled: []), "None")
        XCTAssertEqual(CalendarGroups.group(cals)[1].onCount(disabled: ["2"]), 1)
    }

    func testPopChoiceFollowsColorUntilPicked() {
        let defaults = UserDefaults(suiteName: "test-pop-\(UUID().uuidString)")!
        let prefs = Prefs(defaults: defaults)
        XCTAssertEqual(prefs.popChoice, .pop)
        prefs.gumColor = .unicorn
        XCTAssertEqual(prefs.popChoice, .sparkle)
        prefs.popChoiceSaved = .pop
        XCTAssertEqual(prefs.popChoice, .pop)
    }

    func testAlarmVolumeRampsOverLastTwoMinutes() {
        let start = Date(timeIntervalSince1970: 10_000)
        XCTAssertEqual(AlarmLoop.volume(now: start.addingTimeInterval(-300), start: start), AlarmLoop.quiet)
        XCTAssertEqual(AlarmLoop.volume(now: start.addingTimeInterval(-60), start: start), (AlarmLoop.quiet + 1) / 2, accuracy: 0.001)
        XCTAssertEqual(AlarmLoop.volume(now: start, start: start), 1)
    }
}

final class FortuneTests: XCTestCase {
    func testFortyFortunesAndStablePick() {
        XCTAssertEqual(Fortunes.all.count, 40)
        XCTAssertEqual(Fortunes.fortune(for: "abc@123"), Fortunes.fortune(for: "abc@123"))
        let picks = Set((0..<200).map { Fortunes.fortune(for: "meeting-\($0)") })
        XCTAssertGreaterThan(picks.count, 20, "picks should spread across the list")
        XCTAssertFalse(Fortunes.all.contains { $0.contains("\u{2014}") }, "no em-dashes")
    }

    func testShowsOnlyInLastTenMinutes() {
        let start = Date(timeIntervalSince1970: 50_000)
        XCTAssertFalse(Fortunes.shows(start: start, now: start.addingTimeInterval(-16 * 60)))
        XCTAssertTrue(Fortunes.shows(start: start, now: start.addingTimeInterval(-14 * 60)))
        XCTAssertFalse(Fortunes.shows(start: start, now: start.addingTimeInterval(1)))
    }

    func testFortuneDefaultsToStarPop() {
        let prefs = Prefs(defaults: UserDefaults(suiteName: "test-fortune-\(UUID().uuidString)")!)
        prefs.gumColor = .fortune
        XCTAssertEqual(prefs.popChoice, .star)
        XCTAssertTrue(GumPalette.fortune.isPro)
        XCTAssertTrue(AlarmSoundChoice.oracle.isPro)
    }
}

final class ThemeTests: XCTestCase {
    func testReleaseCalendar() {
        XCTAssertFalse(GumPalette.seasonsInStore, "the App Store copy follows the release calendar")
        let cal = Calendar.current
        let before = cal.date(from: DateComponents(year: 2026, month: 11, day: 29, hour: 12))!
        let after = cal.date(from: DateComponents(year: 2026, month: 11, day: 30, hour: 9))!
        XCTAssertFalse(GumPalette.snowball.isReleased(at: before))
        XCTAssertTrue(GumPalette.snowball.isReleased(at: after))
        XCTAssertTrue(GumPalette.unicorn.isReleased(at: before), "1.0 themes have no date")
        XCTAssertTrue(GumPalette.disco.isReleased(at: before))
        XCTAssertFalse(GumPalette.moon.isReleased(at: after), "Moon waits for the Apollo 11 anniversary")
        XCTAssertEqual(Set(GumPalette.recentlyReleased(at: after)), [.snowball, .ornament])
        let launchSet = GumPalette.allCases.filter { $0.releaseDate == nil }
        XCTAssertEqual(Set(launchSet), [.bubblegum, .coral, .unicorn, .fortune, .gumball, .planet, .soap, .lavaLamp, .moodRing, .zen, .fishbowl, .disco, .clock, .marble])
        XCTAssertTrue(AlarmSoundChoice.available.contains(.sonar))
    }

    func testEachThemeHasItsPopAndIsPro() {
        let prefs = Prefs(defaults: UserDefaults(suiteName: "test-themes-\(UUID().uuidString)")!)
        let expected: [GumPalette: PopChoice] = [.moon: .bloop, .grenade: .pinPull, .snowball: .crunch, .ornament: .glassTing, .pumpkin: .leafThunk]
        for (palette, pop) in expected {
            prefs.gumColor = palette
            XCTAssertEqual(prefs.popChoice, pop)
            XCTAssertTrue(palette.isPro)
            XCTAssertTrue(pop.isPro)
            XCTAssertNotNil(pop.fileName)
        }
        XCTAssertFalse(GumPalette.coral.isPro)
        XCTAssertFalse(PopChoice.pop.isPro)
        for palette in GumPalette.novelty {
            prefs.gumColor = palette
            XCTAssertEqual(prefs.popChoice, .themeSound)
            XCTAssertFalse(palette.popFile.isEmpty)
        }
    }
}

final class PackTests: XCTestCase {
    func testProOnlyNoPacks() {
        XCTAssertTrue(ThemeGroup.allCases.allSatisfy { $0.packID == nil })
    }
}


final class QuietModeTests: XCTestCase {
    func testQuietAfterTwoMinutesUntouchedWhenMeetingIsFar() {
        let now = Date()
        XCTAssertFalse(QuietMode.isQuiet(now: now, lastTouch: now.addingTimeInterval(-60), nextStart: nil))
        XCTAssertTrue(QuietMode.isQuiet(now: now, lastTouch: now.addingTimeInterval(-121), nextStart: nil))
        XCTAssertTrue(QuietMode.isQuiet(now: now, lastTouch: now.addingTimeInterval(-300), nextStart: now.addingTimeInterval(40 * 60)))
    }

    func testWakesWithinFifteenMinutesOfAMeeting() {
        let now = Date()
        XCTAssertFalse(QuietMode.isQuiet(now: now, lastTouch: now.addingTimeInterval(-600), nextStart: now.addingTimeInterval(14 * 60)))
        XCTAssertFalse(QuietMode.isQuiet(now: now, lastTouch: now.addingTimeInterval(-600), nextStart: now.addingTimeInterval(-60)))
    }
}


final class MeetingMergeTests: XCTestCase {
    private func m(_ id: String, _ title: String, _ start: Date, link: String? = nil, cal: String = "a") -> Meeting {
        Meeting(id: id, eventID: id, title: title, start: start, end: start.addingTimeInterval(1800), calendarID: cal,
                joinURL: link.flatMap(URL.init(string:)))
    }

    func testCleanTitleStripsForwardAndReplyTags() {
        XCTAssertEqual(MeetingMerge.cleanTitle("FW: 1430: Scale and User Support WG"), "1430: Scale and User Support WG")
        XCTAssertEqual(MeetingMerge.cleanTitle("RE: Fwd: fw:  Standup"), "Standup")
        XCTAssertEqual(MeetingMerge.cleanTitle("Firmware review"), "Firmware review")
        XCTAssertEqual(MeetingMerge.cleanTitle("FW:"), "FW:")
    }

    func testForwardedCopyMergesIntoOne() {
        let t = Date(timeIntervalSince1970: 1_800_000_000)
        let merged = MeetingMerge.merge([m("1", "1430: Scale WG", t), m("2", "FW: 1430: Scale WG", t)])
        XCTAssertEqual(merged.count, 1)
    }

    func testSameLinkDifferentTitleMerges() {
        let t = Date(timeIntervalSince1970: 1_800_000_000)
        let merged = MeetingMerge.merge([m("1", "Sync", t, link: "https://zoom.us/j/123?pwd=a"),
                                         m("2", "Weekly sync", t, link: "https://zoom.us/j/123?pwd=b")])
        XCTAssertEqual(merged.count, 1)
    }

    func testDifferentTimesStaySeparate() {
        let t = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(MeetingMerge.merge([m("1", "Standup", t), m("2", "Standup", t.addingTimeInterval(3600))]).count, 2)
    }

    func testKeepsTheCopyThatRingsThenTheOneWithALink() {
        let t = Date(timeIntervalSince1970: 1_800_000_000)
        let quiet = m("1", "Review", t, link: "https://zoom.us/j/9", cal: "quiet")
        let loud = m("2", "FW: Review", t, cal: "loud")
        XCTAssertEqual(MeetingMerge.merge([quiet, loud], preferred: { $0.calendarID == "loud" }).first?.id, "2")
        XCTAssertEqual(MeetingMerge.merge([loud, quiet]).first?.id, "1")
    }

    func testMoreVideoServicesAreRecognized() {
        for link in ["https://facetime.apple.com/join#v=1", "https://meet.jit.si/room", "https://acme.bluejeans.com/123",
                     "https://v.ringcentral.com/join/1", "https://join.skype.com/abc", "https://8x8.vc/acme/room"] {
            XCTAssertNotNil(MeetingLinkDetector.service(for: URL(string: link)!), link)
        }
    }
}


final class AlertRulesTests: XCTestCase {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/New_York")!; return c }
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func testWorkHoursOffAllowsEverything() {
        XCTAssertTrue(WorkHours.standard.contains(date(2026, 11, 14, 22), calendar: cal))
    }

    func testWorkHoursWeekdaysNineToFive() {
        var w = WorkHours.standard; w.on = true
        XCTAssertTrue(w.contains(date(2026, 11, 12, 9), calendar: cal))     // Thursday morning
        XCTAssertFalse(w.contains(date(2026, 11, 12, 17), calendar: cal))   // 5 PM is the end
        XCTAssertFalse(w.contains(date(2026, 11, 12, 7, 59), calendar: cal))
        XCTAssertFalse(w.contains(date(2026, 11, 14, 10), calendar: cal))   // Saturday
    }

    func testOvernightHours() {
        let w = WorkHours(on: true, start: 22 * 60, end: 6 * 60, days: Set(1...7))
        XCTAssertTrue(w.contains(date(2026, 11, 12, 23), calendar: cal))
        XCTAssertTrue(w.contains(date(2026, 11, 12, 5), calendar: cal))
        XCTAssertFalse(w.contains(date(2026, 11, 12, 12), calendar: cal))
    }

    func testPauseSilencesMeetingsBeforeItEnds() {
        let now = Date()
        XCTAssertTrue(PauseRule.silences(now.addingTimeInterval(1800), pausedUntil: now.addingTimeInterval(3600), now: now))
        XCTAssertFalse(PauseRule.silences(now.addingTimeInterval(4000), pausedUntil: now.addingTimeInterval(3600), now: now))
        XCTAssertFalse(PauseRule.silences(now.addingTimeInterval(60), pausedUntil: now.addingTimeInterval(-1), now: now))
        XCTAssertFalse(PauseRule.silences(now, pausedUntil: nil, now: now))
    }
}


final class TrialTests: XCTestCase {
    func testOneDayTrialPerTheme() {
        let day = "2026-12-01"
        XCTAssertTrue(ThemeTrial.active(theme: "disco", day: day, trialTheme: "disco", trialDay: day))
        XCTAssertFalse(ThemeTrial.active(theme: "disco", day: "2026-12-02", trialTheme: "disco", trialDay: day))
        XCTAssertFalse(ThemeTrial.active(theme: "soap", day: day, trialTheme: "disco", trialDay: day))
    }

    func testWhatsNewAtMostMonthly() {
        let now = Date()
        XCTAssertTrue(WhatsNew.shouldShow(new: ["snowball"], seen: [], ignoredInARow: 0, lastShown: nil, now: now))
        XCTAssertFalse(WhatsNew.shouldShow(new: ["snowball"], seen: ["snowball"], ignoredInARow: 0, lastShown: nil, now: now))
        XCTAssertFalse(WhatsNew.shouldShow(new: ["duck"], seen: [], ignoredInARow: 2, lastShown: nil, now: now))
        XCTAssertFalse(WhatsNew.shouldShow(new: ["duck"], seen: [], ignoredInARow: 0, lastShown: now.addingTimeInterval(-10 * 86400), now: now))
        XCTAssertTrue(WhatsNew.shouldShow(new: ["duck"], seen: [], ignoredInARow: 1, lastShown: now.addingTimeInterval(-29 * 86400), now: now))
    }
}


final class NewestWinsTests: XCTestCase {
    private func m(_ id: String, _ start: Date) -> Meeting {
        Meeting(id: id, eventID: id, title: id, start: start, end: start.addingTimeInterval(3600), calendarID: "a", joinURL: nil)
    }

    func testOlderMeetingIsMissedWhenTheNextOneRings() {
        let now = Date()
        let old = m("old", now.addingTimeInterval(-25 * 60))
        let next = m("next", now.addingTimeInterval(60))
        XCTAssertTrue(NewestWins.isMissed(old, among: [old, next], now: now, lead: 120, rings: { _ in true }))
        XCTAssertFalse(NewestWins.isMissed(next, among: [old, next], now: now, lead: 120, rings: { _ in true }))
    }

    func testNotMissedBeforeTheNextAlarm() {
        let now = Date()
        let old = m("old", now.addingTimeInterval(-10 * 60))
        let next = m("next", now.addingTimeInterval(20 * 60))
        XCTAssertFalse(NewestWins.isMissed(old, among: [old, next], now: now, lead: 120, rings: { _ in true }))
    }

    func testQuietMeetingsDoNotTakeOver() {
        let now = Date()
        let old = m("old", now.addingTimeInterval(-25 * 60))
        let quiet = m("quiet", now.addingTimeInterval(60))
        XCTAssertFalse(NewestWins.isMissed(old, among: [old, quiet], now: now, lead: 120, rings: { $0.id != "quiet" }))
    }
}
