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
        a.check("shows both alarm looks before iOS asks", a.app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "phone is locked")).firstMatch.exists, severity: 3)
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
        a.expect("the card says it will ring", a.any(containing: "Rings"), severity: 3)
        a.expect("Not going is visible", a.app.buttons["Not going"], severity: 4)
        a.expect("Settings is reachable", a.app.buttons["More: add a reminder, pop for fun, pause alerts, settings"], severity: 3)
        a.begin("Join the next meeting")
        let ok = popBubble(a)
        a.pause(0.3)
        a.shot("popping", note: "mid-pop")
        let undo = a.app.buttons["Undo"]
        a.done("Join the next meeting", ok)
        // Undo lasts 5 s; tap it first and take the pictures after, so slow UI queries can't outlast it.
        a.check("Undo is offered after the pop", undo.waitForExistence(timeout: 2), severity: 3)
        a.begin("Undo a pop")
        a.tap("Undo", undo)
        a.pause(1.2)
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
        a.pause(0.6)
        a.shot("after-not-going")
        a.check("Undo is offered", a.app.buttons["Undo"].waitForExistence(timeout: 2), severity: 3)
        a.tap("Undo", a.app.buttons["Undo"])
        a.done("Skip a meeting", true)
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
        a.expect("Test the alarm is visible", a.any(containing: "Test the alarm"), severity: 3)
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
        a.tap("Theme", a.any(containing: "Theme"))
        a.pause(0.8)
        a.shot("theme-gallery")
        a.accessibility("theme-gallery")
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

    // J10. Fortune: the black ball, the fortune on the card, the mist pop.
    func test10_Fortune() {
        let a = Audit("J10-fortune")
        defer { a.finish() }
        a.launch("fortune")
        a.shot("fortune-home")
        a.accessibility("fortune-home")
        a.labels("fortune-home")
        a.expect("the card shows a fortune", a.any(containing: "Fortune:"), severity: 3)
        _ = popBubble(a)
        a.pause(0.3)
        a.shot("fortune-pop")
    }

    // J11. Moon and Grenade: the ball, its marks and topper, the pop.
    func test11_MoonAndGrenade() {
        let a = Audit("J11-moon-grenade")
        defer { a.finish() }
        for theme in ["moon", "grenade"] {
            a.launch(theme)
            a.shot("\(theme)-home")
            a.accessibility("\(theme)-home")
            _ = popBubble(a)
            a.pause(0.3)
            a.shot("\(theme)-pop")
        }
        a.launch("moon")
        a.check("Moon says Next transmission", a.any(containing: "Next transmission").exists, severity: 2)
    }

    // J12. Every held theme (holiday and novelty): the ball and the pop, one picture each.
    func test12_AllThemes() {
        let a = Audit("J12-all-themes")
        defer { a.finish() }
        for theme in ["snowball", "ornament", "pumpkin", "disco", "soap", "planet", "basketball", "donut",
                      "waterBalloon", "eyeball", "fishbowl", "moodRing", "lavaLamp", "soccer", "hockey", "tennis", "golf", "baseball", "bowling", "pixel", "gumball", "cherry", "orange", "macaron", "cakePop", "earth", "sun", "dandelion", "atom", "geode", "yarn", "arcadeButton", "clock", "marble", "duck", "easterEgg", "valentine", "fireworks", "beachBall", "zen"] {
            a.launch("fortune", theme: theme, settle: 2)
            a.shot("\(theme)")
            _ = popBubble(a)
            a.pause(0.3)
            a.shot("\(theme)-pop")
        }
    }

    // J13. Edge cases: the screens a person meets on an awkward day, for a sticking-point review.
    func test13_EdgeCases() {
        let a = Audit("J13-edge-cases")
        defer { a.finish() }
        a.launch("missed")
        a.shot("missed-under-new-alarm", note: "New alarm up; the unpopped earlier meeting shows as Missed with Join")
        a.accessibility("missed")
        a.launch("paused")
        a.shot("paused-home", note: "Paused until pill under the header; card says Paused until")
        a.launch("outside")
        a.shot("outside-work-hours", note: "Card says Outside work hours, quiet notification")
        a.launch("reminder")
        a.shot("own-reminder-next", note: "An own reminder is next: card label Reminder")
        a.launch("dupes")
        a.shot("duplicate-merged", note: "Design review and its FW copy show as one meeting")
        a.launch("home")
        let more = a.app.buttons["More: add a reminder, pop for fun, pause alerts, settings"]
        if more.waitForExistence(timeout: 4) {
            more.tap()
            a.pause(0.8)
            a.shot("more-menu", note: "Add a reminder, Pop for fun, Pause alerts, Settings")
            let add = a.app.buttons["Add a reminder"]
            if add.waitForExistence(timeout: 2) {
                add.tap()
                a.pause(1)
                a.shot("add-reminder-sheet")
                a.accessibility("add-reminder")
            }
        }
        a.launch("playground", settle: 3)
        a.shot("pop-for-fun")
        let ball = a.app.descendants(matching: .any).matching(NSPredicate(format: "label ENDSWITH 'bubble'")).firstMatch
        if ball.waitForExistence(timeout: 3) {
            ball.tap()
            a.pause(0.25)
            a.shot("pop-for-fun-popped")
        }
        a.accessibility("playground")
    }
}
