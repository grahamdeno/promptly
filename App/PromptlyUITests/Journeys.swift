import XCTest

/// The journeys of the UX audit (docs/audit/ux-audit.md), in the order a person meets them. Each is one job, walked
/// step by step in Pop In's demo mode. A check that fails is written down and the walk goes on.
@MainActor
final class Journeys: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    private func popBubble(_ a: Audit, title: String = "Design review") -> Bool {
        let bubble = a.any(containing: "Pop the bubble to join \(title)")
        guard a.expect("the bubble is a button named for the meeting", bubble, severity: 3) else {
            a.tapAt(0.5, 0.82)
            return false
        }
        a.tap("the bubble", bubble)
        return true
    }

    // J1. First run: hello, calendars, alarms, choose calendars, covered, Home.
    func test01_FirstRun() {
        let a = Audit("J1-first-run")
        defer { a.finish() }
        a.launch("welcome")
        a.shot("hello")
        a.accessibility("hello")
        a.labels("hello")
        a.check("hello says what Pop In does", a.text(containing: "rings before each meeting").exists, severity: 2)
        a.tap("Get started", a.app.buttons["Get started"], severity: 4)
        a.pause(0.8)
        a.shot("calendars-why")
        a.accessibility("calendars-why")
        a.tap("Allow calendar access", a.button(startingWith: "Allow calendar"), severity: 4)
        a.pause(1.2)
        a.shot("alarms-why")
        a.accessibility("alarms-why")
        a.tap("Allow alarms", a.button(startingWith: "Allow alarms"), severity: 4)
        a.pause(1.2)
        a.shot("which-calendars")
        a.accessibility("which-calendars")
        a.labels("which-calendars")
        a.expect("calendars are listed by account", a.text(containing: "Exchange"), severity: 3)
        a.tap("Done", a.app.buttons["Done"], severity: 4)
        a.pause(1.2)
        a.shot("covered")
        a.accessibility("covered")
        a.check("covered names the next meeting", a.text(containing: "Next up").exists, severity: 2)
        a.tap("Done (covered)", a.app.buttons["Done"], severity: 4)
        a.pause(1.5)
        a.shot("home-after-first-run")
        a.expect("Home shows the next meeting", a.any(containing: "Design review"), severity: 4)
    }

    // J2. Home with a meeting minutes away: read it, pop to join, Undo.
    func test02_HomeSoon() {
        let a = Audit("J2-home-soon")
        defer { a.finish() }
        a.launch("home")
        a.shot("home")
        a.accessibility("home")
        a.labels("home")
        a.expect("the card names the meeting", a.any(containing: "Design review"), severity: 4)
        a.expect("the card says how long", a.any(containing: "min"), severity: 3)
        a.expect("Not going is visible", a.app.buttons["Not going"], severity: 4)
        a.expect("Settings is reachable", a.app.buttons["Settings"], severity: 3)
        a.begin("Join the next meeting")
        let ok = popBubble(a)
        a.pause(0.3)
        a.shot("popping", note: "mid-pop")
        a.pause(1.5)
        a.shot("after-pop")
        let undo = a.app.buttons["Undo"]
        a.done("Join the next meeting", ok)
        a.check("Undo is offered after the pop", undo.waitForExistence(timeout: 2), severity: 3)
        a.begin("Undo a pop")
        a.tap("Undo", undo)
        a.pause(1)
        a.shot("after-undo")
        a.done("Undo a pop", a.any(containing: "Pop the bubble to join Design review").waitForExistence(timeout: 3))
    }

    // J3. Not going, then Undo.
    func test03_NotGoing() {
        let a = Audit("J3-not-going")
        defer { a.finish() }
        a.launch("home")
        a.begin("Skip a meeting")
        a.tap("Not going", a.app.buttons["Not going"], severity: 4)
        a.pause(0.8)
        a.shot("after-not-going")
        a.done("Skip a meeting", a.any(containing: "Team standup").waitForExistence(timeout: 3))
        a.check("Undo is offered", a.app.buttons["Undo"].waitForExistence(timeout: 2), severity: 3)
        a.tap("Undo", a.app.buttons["Undo"])
        a.pause(0.8)
        a.shot("after-undo")
        a.check("the meeting is back", a.any(containing: "Design review").waitForExistence(timeout: 3), severity: 3)
    }

    // J4. Home a day ahead: the calm state.
    func test04_HomeFar() {
        let a = Audit("J4-home-far")
        defer { a.finish() }
        a.launch("far")
        a.shot("home-far")
        a.accessibility("home-far")
        a.labels("home-far")
        a.expect("the day is named", a.any(containing: "Tomorrow"), severity: 2)
        a.expect("Not going is visible", a.app.buttons["Not going"], severity: 3)
    }

    // J5. The takeover when it rings, then late with buds.
    func test05_Takeover() {
        let a = Audit("J5-takeover")
        defer { a.finish() }
        a.launch("now")
        a.shot("ringing")
        a.accessibility("ringing")
        a.labels("ringing")
        a.expect("Not going on the takeover", a.app.buttons["Not going"], severity: 4)
        a.expect("the meeting title", a.any(containing: "Design review"), severity: 4)
        a.launch("late", settle: 3)
        a.shot("late-50s", note: "50 s after the ring: the first bud should be out")
        a.pause(25)
        a.shot("late-75s", note: "75 s after the ring: two or three buds")
        a.begin("Pop the late bubble")
        a.done("Pop the late bubble", popBubble(a))
        a.pause(0.4)
        a.shot("late-popping")
    }

    // J6. Settings: every row opens its screen and comes back.
    func test06_Settings() {
        let a = Audit("J6-settings")
        defer { a.finish() }
        a.launch("settings", free: true, settle: 3)
        a.shot("settings-top")
        a.accessibility("settings")
        a.labels("settings")
        for row in ["Calendars", "Ring before", "Sound"] {
            a.expect("row \(row) shows", a.any(containing: row), severity: 3)
        }
        a.tap("Ring before", a.any(containing: "Ring before"))
        a.pause(0.8)
        a.shot("ring-before")
        a.accessibility("ring-before")
        a.begin("Ring 2 minutes before")
        a.tap("2 minutes", a.any(containing: "2 minutes"))
        a.tap("Back", a.app.navigationBars.buttons.firstMatch)
        a.pause(0.6)
        a.done("Ring 2 minutes before", a.any(containing: "2 min").exists)
        a.tap("Sound", a.any(containing: "Sound"))
        a.pause(0.8)
        a.shot("sound")
        a.accessibility("sound")
        a.check("Pro sounds are marked", a.any(containing: "Pro").exists, severity: 2)
        a.tap("Back", a.app.navigationBars.buttons.firstMatch)
        a.pause(0.6)
        a.app.swipeUp()
        a.pause(0.6)
        a.shot("settings-bottom")
        a.accessibility("settings-bottom")
        a.labels("settings-bottom")
        a.tap("Pop sound", a.any(containing: "Pop sound"))
        a.pause(0.8)
        a.shot("pop-sound")
        a.tap("Back", a.app.navigationBars.buttons.firstMatch)
        a.pause(0.6)
        a.tap("Unicorn (locked)", a.app.buttons["Unicorn, Pro"])
        a.pause(1.2)
        a.shot("pro-sheet-from-locked")
        a.expect("a locked choice opens Pop In Pro", a.any(containing: "Pop In Pro"), severity: 3)
        a.expect("Restore purchase", a.app.buttons["Restore purchase"], severity: 3)
        a.accessibility("pro-sheet")
    }

    // J7. A long list of calendars: fold, search, turn a whole account off.
    func test07_ManyCalendars() {
        let a = Audit("J7-many-calendars")
        defer { a.finish() }
        a.launch("manycals", settle: 3)
        a.begin("Find and turn off one calendar")
        a.tap("Calendars", a.any(containing: "Calendars"))
        a.pause(0.8)
        a.shot("calendars")
        a.accessibility("calendars")
        a.labels("calendars")
        let search = a.app.textFields["Find a calendar"]
        if a.expect("search shows with many calendars", search, severity: 2) {
            a.tap("search", search)
            search.typeText("soccer")
            a.pause(0.8)
            a.shot("search-soccer")
            let toggle = a.app.switches["Soccer"]
            a.done("Find and turn off one calendar", a.tap("Soccer switch", toggle))
            a.pause(0.5)
            a.shot("soccer-off")
        } else {
            a.done("Find and turn off one calendar", false)
        }
        a.tap("clear search", a.app.buttons["Clear search"], severity: 2)
        a.pause(0.6)
        a.begin("Turn off a whole account")
        let allOff = a.app.buttons["Turn all off"].firstMatch
        a.done("Turn off a whole account", a.tap("Turn all off", allOff))
        a.pause(0.6)
        a.shot("account-off")
    }

    // J8. Nothing coming up: the empty Home and the demo pop.
    func test08_Empty() {
        let a = Audit("J8-empty")
        defer { a.finish() }
        a.launch("empty")
        a.shot("empty")
        a.accessibility("empty")
        a.labels("empty")
        a.expect("says nothing is coming up", a.any(containing: "Nothing coming up"), severity: 3)
        a.tap("Try a pop", a.app.buttons["Try a pop"], severity: 3)
        a.pause(1.5)
        a.shot("demo")
        a.labels("demo")
    }

    // J9. Unicorn mode: the bubble, the pop with confetti, sprinkles and unicorns.
    func test09_Unicorn() {
        let a = Audit("J9-unicorn")
        defer { a.finish() }
        a.launch("unicorn")
        a.shot("unicorn-home")
        a.accessibility("unicorn-home")
        _ = popBubble(a)
        a.pause(0.25)
        a.shot("unicorn-pop-early")
        a.pause(0.3)
        a.shot("unicorn-pop-late")
    }
}
