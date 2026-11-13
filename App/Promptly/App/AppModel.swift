import BackgroundTasks
import EventKit
import Observation
import SwiftUI
import UIKit

/// Holds the meetings, settings and permissions, and keeps AlarmKit in step with the calendar.
@MainActor
@Observable
final class AppModel {
    static let refreshTaskID = "com.grahamdeno.promptly.refresh"

    @ObservationIgnored let calendarService = CalendarService()
    @ObservationIgnored let alarmService = AlarmService()
    @ObservationIgnored let nudgeService = NudgeService()
    /// Pop In Pro (observable, so views update when it unlocks).
    let store = ProStore()
    /// Shows the Pro sheet from anywhere a locked choice is tapped.
    var showPro = false
    @ObservationIgnored let prefs: Prefs
    @ObservationIgnored private var storeObserver: NSObjectProtocol?

    var meetings: [Meeting] = []
    /// Pretend meetings from the "Check the alarm" buttons, so the test also shows the bubble and the takeover.
    var testMeetings: [Meeting] = []
    /// Alarms for the test meetings (kept with the meeting alarms so the same open/closed rules apply).
    @ObservationIgnored private var testPlanned: [PlannedAlarm] = []
    /// True while Pop In is on screen. Then Pop In itself takes over at ring time, so Apple's alarm (and its banner
    /// and Lock Screen card) is held back for meetings in the next 20 minutes, and put back the moment Pop In leaves
    /// the screen or the phone locks.
    @ObservationIgnored private var isForeground = false
    static let openQuietWindow: TimeInterval = 20 * 60
    /// Set while the settings sheet is open, so a takeover waits until it closes.
    @ObservationIgnored var settingsOpen = false
    var calendars: [CalendarInfo] = []
    var calendarAuthorized = false
    var alarmsAuthorized = false
    var onboarded: Bool
    var cleared: Set<String>
    /// The meeting shown full screen on the Now screen.
    var arrived: Meeting?
    /// A meeting link waiting for the view to open it.
    var linkToOpen: URL?
    /// Increments each time a meeting is joined or cleared; the bubble pops on change.
    var popCount = 0
    /// Increments on "Not going"; the bubble deflates quietly instead of popping (popping means join).
    var skipCount = 0
    var taughtPop: Bool
    var syncProblem: String?
    /// For the settings screen's alarm check.
    var nextAlarm: Date?
    var scheduledAlarms = 0
    var testMessage: String?

    var leadMinutes: Int {
        didSet { prefs.leadMinutes = leadMinutes; Task { await syncAlarms() } }
    }
    var ballStyle: BallStyle {
        didSet { prefs.ballStyle = ballStyle }
    }
    var countdownCard: Bool {
        didSet { prefs.countdownCard = countdownCard; Task { await syncAlarms() } }
    }
    // MARK: Try a theme, and New this month

    /// Whether this theme can be used now: owned, or today's one-day trial.
    func canUse(_ palette: GumPalette) -> Bool {
        store.unlocks(palette)
            || ThemeTrial.active(theme: palette.rawValue, day: ThemeTrial.today(), trialTheme: prefs.trialTheme, trialDay: prefs.trialDay)
    }

    /// A free user hasn't tried this theme yet.
    func canTry(_ palette: GumPalette) -> Bool {
        palette.isPro && !store.isPro && !prefs.triedThemes.contains(palette.rawValue)
    }

    /// Use a Pro theme for the rest of today. Once per theme.
    func tryTheme(_ palette: GumPalette) {
        guard canTry(palette) else { showPro = true; return }
        prefs.triedThemes.insert(palette.rawValue)
        prefs.trialTheme = palette.rawValue
        prefs.trialDay = ThemeTrial.today()
        surprise = false
        gumColor = palette
    }

    /// A trial ends with the day: back to Bubblegum unless the theme is owned.
    func endTrialIfOver() {
        if !canUse(gumColor) { gumColor = .bubblegum }
    }

    /// Themes for the "New this month" card on Home, or empty when it shouldn't show.
    var whatsNew: [GumPalette] {
        let fresh = GumPalette.recentlyReleased(at: .now)
        guard !ScreenshotMode.isOn, WhatsNew.shouldShow(new: fresh.map(\.rawValue), seen: prefs.whatsNewSeen,
                                                       ignoredInARow: prefs.whatsNewIgnored, lastShown: prefs.whatsNewLastShown, now: .now)
        else { return [] }
        return fresh
    }

    /// Opened the card (tried or looked): it counts as seen and resets the wave-away count.
    func whatsNewOpened(_ themes: [GumPalette]) {
        prefs.whatsNewSeen.formUnion(themes.map(\.rawValue))
        prefs.whatsNewIgnored = 0
        prefs.whatsNewLastShown = .now
        whatsNewTick += 1
    }

    /// Waved away: seen, and two in a row stops the cards.
    func whatsNewDismissed(_ themes: [GumPalette]) {
        prefs.whatsNewSeen.formUnion(themes.map(\.rawValue))
        prefs.whatsNewIgnored += 1
        prefs.whatsNewLastShown = .now
        whatsNewTick += 1
    }

    /// Bumped so Home redraws after the card is handled.
    var whatsNewTick = 0

    /// Reminders made inside Pop In; they ring like meetings.
    var ownReminders: [OwnReminder] = [] {
        didSet { prefs.ownReminders = ownReminders }
    }

    func addReminder(title: String, at date: Date) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        ownReminders.append(OwnReminder(id: UUID().uuidString, title: t.isEmpty ? "Reminder" : t, date: date))
        Task { await refresh() }
    }

    func deleteReminder(_ id: String) {
        ownReminders.removeAll { $0.id == id }
        Task { await refresh() }
    }

    /// A second, earlier alarm (a heads-up), minutes before the start; 0 for none.
    var earlyMinutes: Int {
        didSet { prefs.earlyMinutes = earlyMinutes; Task { await syncAlarms() } }
    }
    /// Skip tentative and unanswered meetings.
    var acceptedOnly: Bool {
        didSet { prefs.acceptedOnly = acceptedOnly; Task { await refresh() } }
    }
    /// Ring full screen only inside these hours; outside, a quiet notification.
    var workHours: WorkHours {
        didSet { prefs.workHours = workHours; writeWidgetSnapshot(); Task { await syncAlarms() } }
    }
    /// Alerts paused until this time (Home's pause menu).
    var pausedUntil: Date? {
        didSet { prefs.pausedUntil = pausedUntil; Task { await syncAlarms() } }
    }
    /// Meetings snoozed from the alarm screen, and when to ring again.
    var snoozedUntil: [String: Date] = [:]
    @ObservationIgnored private var snoozePlanned: [PlannedAlarm] = []
    var buzz: Bool {
        didSet { prefs.buzz = buzz }
    }
    /// Pop, Sparkle or Off. Follows the bubble color (Sparkle for Unicorn) until the owner picks one.
    var popChoice: PopChoice {
        didSet { if !followingColor { prefs.popChoiceSaved = popChoice } }
    }
    @ObservationIgnored private var followingColor = false
    /// Bubble color. Also tints the alarm's buttons, so a change reschedules the alarms; widgets redraw.
    var gumColor: GumPalette {
        didSet {
            prefs.gumColor = gumColor
            if prefs.popChoiceSaved == nil {
                followingColor = true
                popChoice = prefs.popChoice
                followingColor = false
            }
            // The app icon follows the bubble color (iOS shows a one-line notice when it changes).
            // Each color has a matching app icon named after it (AppIcon-Coral, AppIcon-Moon…); Bubblegum is the main one.
            // Surprise me changes the theme daily; the icon stays put so iOS doesn't show its notice every morning.
            let icon: String? = surprise ? UIApplication.shared.alternateIconName : !gumColor.hasIcon ? nil : "AppIcon-" + gumColor.rawValue.prefix(1).uppercased() + String(gumColor.rawValue.dropFirst())
            if UIApplication.shared.alternateIconName != icon {
                UIApplication.shared.setAlternateIconName(icon) { _ in }
            }
            alarmService.cancelOwned()
            writeWidgetSnapshot()
            Task { await syncAlarms() }
        }
    }
    var alarmSound: AlarmSoundChoice {
        didSet {
            prefs.alarmSound = alarmSound
            alarmService.sound = alarmSound
            alarmService.cancelOwned()
            Task { await syncAlarms() }
        }
    }
    var gentleCalendarIDs: Set<String> {
        didSet {
            prefs.gentleCalendarIDs = gentleCalendarIDs
            Task {
                if !gentleCalendarIDs.isEmpty, !ScreenshotMode.isOn { _ = await nudgeService.requestAccess() }
                await syncAlarms()
            }
        }
    }
    var surprise: Bool {
        didSet { prefs.surprise = surprise }
    }
    var fortunes: Bool {
        didSet { prefs.fortunes = fortunes }
    }
    var keepAwake: Bool {
        didSet { prefs.keepAwake = keepAwake; applyKeepAwake() }
    }
    var nudges: Bool {
        didSet {
            prefs.nudges = nudges
            Task {
                if nudges, !ScreenshotMode.isOn, !(await nudgeService.requestAccess()) { nudges = false; return }
                await syncAlarms()
            }
        }
    }
    var disabledCalendarIDs: Set<String> {
        didSet { prefs.disabledCalendarIDs = disabledCalendarIDs; Task { await refresh() } }
    }

    @ObservationIgnored private var shownNowFor: Set<String> = []

    init() {
        let prefs = Prefs()
        self.prefs = prefs
        onboarded = prefs.onboarded
        leadMinutes = prefs.leadMinutes
        ballStyle = prefs.ballStyle
        disabledCalendarIDs = prefs.disabledCalendarIDs
        countdownCard = prefs.countdownCard
        acceptedOnly = prefs.acceptedOnly
        earlyMinutes = prefs.earlyMinutes
        ownReminders = OwnReminder.live(prefs.ownReminders, now: .now)
        workHours = prefs.workHours
        pausedUntil = prefs.pausedUntil
        buzz = prefs.buzz
        popChoice = prefs.popChoice
        alarmSound = prefs.alarmSound
        gumColor = prefs.gumColor
        gentleCalendarIDs = prefs.gentleCalendarIDs
        alarmCalendarIDs = prefs.alarmCalendarIDs
        keepAwake = prefs.keepAwake
        fortunes = prefs.fortunes
        surprise = prefs.surprise
        alarmService.sound = prefs.alarmSound
        nudges = prefs.nudges
        cleared = prefs.clearedMeetingIDs
        taughtPop = prefs.taughtPop
        calendarAuthorized = calendarService.isAuthorized
        alarmsAuthorized = alarmService.isAuthorized
        // If Pro goes away (refund), fall back to free choices.
        store.onLost = { [weak self] in
            guard let self else { return }
            if !self.canUse(self.gumColor) { self.gumColor = .bubblegum }
            guard !self.store.isPro else { return }
            if self.alarmSound.isPro { self.alarmSound = .bubbleBlow }
            if self.popChoice.isPro { self.popChoice = .pop }
            if self.store.ownedPacks.isEmpty { self.surprise = false }
            if self.leadMinutes > 5 { self.leadMinutes = 5 }
            if self.keepAwake { self.keepAwake = false }
        }
        PopHaptics.prepare()
        if let scene = ScreenshotMode.scene {
            // App Store screenshots: demo meetings, no alarms, everything unlocked. didSet doesn't run in init,
            // so none of this is saved or scheduled.
            onboarded = scene != .welcome
            calendarAuthorized = scene != .welcome
            alarmsAuthorized = scene != .welcome
            taughtPop = true
            buzz = false
            popChoice = .off
            keepAwake = false
            gumColor = switch scene {
            case .unicorn: .unicorn
            case .fortune: .fortune
            case .moon: .moon
            case .grenade: .grenade
            default: ScreenshotMode.theme ?? .bubblegum
            }
            ballStyle = .bubble
            leadMinutes = 2
            cleared = []
            calendars = scene == .manycals ? ScreenshotMode.manyCalendars : ScreenshotMode.calendars
            meetings = scene == .empty ? [] : ScreenshotMode.meetings()
            // The Pro sheet scene shows the App Store version of the sheet (price and buy button), for Apple's
            // in-app purchase review screenshot; every other scene shows Pro features unlocked.
            store.setDemoAccess(![.pro, .settings].contains(scene) && !ScreenshotMode.free)   // App Store pictures of Settings and Pro show the price
            if scene == .now || scene == .late { arrived = meetings.first }
            if scene == .pro { showPro = true }
            return
        }
        Task { await store.load() }
        storeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: calendarService.store, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        // Travel and clock changes: re-plan so alarms follow each meeting's real time.
        for name in [Notification.Name.NSSystemTimeZoneDidChange, UIApplication.significantTimeChangeNotification] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in await self?.refresh() }
            }
        }
    }

    // MARK: Upcoming

    /// Surprise me: once a day, a different theme from the ones available (Pro only).
    func surpriseIfNewDay(now: Date = .now) {
        guard surprise, store.isPro || !store.ownedPacks.isEmpty else { return }
        let day = Calendar.current.startOfDay(for: now).formatted(.iso8601.year().month().day())
        guard prefs.lastSurpriseDay != day else { return }
        prefs.lastSurpriseDay = day
        if let next = GumPalette.available.filter({ $0 != gumColor && store.unlocks($0) }).randomElement() { gumColor = next }
    }

    /// Seconds since this meeting's alarm rang (0 before it). The extra bubbles bud off from here, so the first
    /// appears about 15 seconds after the ring rather than after the start time.
    func sinceRing(_ meeting: Meeting, now: Date) -> TimeInterval {
        guard ringsFully(meeting) else { return max(0, now.timeIntervalSince(meeting.start)) }
        return max(0, now.timeIntervalSince(meeting.start.addingTimeInterval(-TimeInterval(leadMinutes * 60))))
    }

    /// Meetings not yet cleared that haven't ended.
    func upcoming(at now: Date) -> [Meeting] {
        let open = (meetings + testMeetings).filter { !cleared.contains($0.id) && $0.end > now }
        return open.filter { !isMissed($0, among: open, now: now) }.sorted { $0.start < $1.start }
    }

    /// The rules the alarm screen runs by right now.
    func screenConfig(_ now: Date) -> AlarmScreenRule.Config {
        AlarmScreenRule.Config(lead: TimeInterval(leadMinutes * 60), rings: { self.ringsFully($0) },
                               paused: { self.isPaused($0, now: now) })
    }

    /// Superseded by a later meeting whose alarm has come due (see NewestWins).
    func isMissed(_ m: Meeting, among open: [Meeting], now: Date) -> Bool {
        NewestWins.isMissed(m, among: open, now: now, lead: TimeInterval(leadMinutes * 60),
                            rings: { self.ringsFully($0) && !self.isPaused($0, now: now) })
    }

    /// Meetings missed because this one took over and still running, for the alarm screen's "Missed" line.
    func missed(before meeting: Meeting, now: Date = .now) -> [Meeting] {
        let open = (meetings + testMeetings).filter { !cleared.contains($0.id) && $0.end > now }
        return open.filter { $0.start < meeting.start && isMissed($0, among: open, now: now) }.sorted { $0.start < $1.start }
    }

    // MARK: Permissions and first run

    func requestPermissions() async {
        await requestCalendarAccess()
        await requestAlarmAccess()
    }

    func requestCalendarAccess() async {
        if ScreenshotMode.isOn { calendarAuthorized = true; return }   // the audit walks first run without system prompts
        calendarAuthorized = await calendarService.requestAccess()
        await refresh()
    }

    func requestAlarmAccess() async {
        if ScreenshotMode.isOn { alarmsAuthorized = true; return }
        alarmsAuthorized = await alarmService.requestAccess()
        await refresh()
    }

    // MARK: Alert rules

    enum AlertRule: String, CaseIterable { case smart, alarm, gentle }

    /// Per calendar: Smart (the default: a full alarm for meetings with a video link, a gentle notification for the
    /// rest), Always alarm, or Gentle.
    func rule(forCalendar id: String) -> AlertRule {
        if alarmCalendarIDs.contains(id) { return .alarm }
        if gentleCalendarIDs.contains(id) { return .gentle }
        return .smart
    }

    func setRule(_ rule: AlertRule, forCalendar id: String) {
        var alarms = alarmCalendarIDs, gentles = gentleCalendarIDs
        alarms.remove(id); gentles.remove(id)
        if rule == .alarm { alarms.insert(id) }
        if rule == .gentle { gentles.insert(id) }
        alarmCalendarIDs = alarms
        gentleCalendarIDs = gentles
    }

    /// Whether this meeting gets the full alarm (and Pop In's takeover) rather than a gentle notification.
    func ringsFully(_ meeting: Meeting) -> Bool {
        if meeting.calendarID == "test" || meeting.calendarID == OwnReminder.calendarID { return true }
        guard workHours.contains(meeting.start) else { return false }
        switch rule(forCalendar: meeting.calendarID) {
        case .alarm: return true
        case .gentle: return false
        case .smart: return meeting.joinURL != nil
        }
    }

    /// Whether alerts are paused for this meeting.
    func isPaused(_ meeting: Meeting, now: Date = .now) -> Bool {
        meeting.calendarID != "test" && PauseRule.silences(meeting.start, pausedUntil: pausedUntil, now: now)
    }

    func pause(until date: Date) { pausedUntil = date }
    func resume() { pausedUntil = nil }

    /// Snooze from the alarm screen: silence it now and ring again in two minutes, with the alarm screen.
    func snooze(_ meeting: Meeting) {
        alarmService.stopAlerting()
        AlarmLoop.stop()
        let when = Date.now.addingTimeInterval(Snooze.length)
        snoozedUntil[meeting.id] = when
        snoozePlanned.removeAll { $0.meeting.id == meeting.id }
        snoozePlanned.append(PlannedAlarm(id: UUID(), meeting: meeting, fireDate: when, countdownSeconds: nil))
        arrived = nil
        Task { await syncAlarms() }
    }

    var alarmCalendarIDs: Set<String> {
        didSet { prefs.alarmCalendarIDs = alarmCalendarIDs; Task { await syncAlarms() } }
    }

    // MARK: Demo and undo

    /// A pretend meeting so a new user can feel the bubble and the pop right away. No Apple alarm, just Pop In.
    func startDemo() {
        let start = Date.now.addingTimeInterval(TimeInterval(leadMinutes * 60) + 12)
        testMeetings = [Meeting(id: "demo-\(UUID().uuidString)", eventID: "demo", title: "Try a pop", start: start,
                                end: start.addingTimeInterval(5 * 60), calendarID: "test", joinURL: nil)]
    }

    /// The last meeting popped or marked Not going, for the 5-second Undo.
    var lastCleared: Meeting?

    func undoClear() {
        guard let meeting = lastCleared else { return }
        lastCleared = nil
        cleared.remove(meeting.id)
        prefs.clearedMeetingIDs = cleared
        shownNowFor.remove(meeting.id)
        writeWidgetSnapshot()
        Task { await syncAlarms() }
    }

    func finishOnboarding() {
        onboarded = true
        prefs.onboarded = true
    }

    // MARK: Lifecycle

    /// Keeps the screen on while Pop In is open, when the owner turns that on.
    func applyKeepAwake() {
        UIApplication.shared.isIdleTimerDisabled = keepAwake && onboarded
    }

    func becameActive() async {
        isForeground = true
        if ScreenshotMode.isOn { return }
        surpriseIfNewDay()
        endTrialIfOver()
        applyKeepAwake()
        calendarAuthorized = calendarService.isAuthorized
        alarmsAuthorized = alarmService.isAuthorized
        await refresh()
        // Opening Pop In while an alarm rings (say by tapping the banner) counts as seeing it: silence it and show
        // the meeting full screen, even if Pop In showed it once already.
        let ringing = alarmService.isAlerting
        alarmService.stopAlerting()
        handleArrival(force: ringing)
        scheduleBackgroundRefresh()
        startWatching()
    }

    /// While Pop In is open (say, on an iPad left on the desk), take over the screen with the Now view when a
    /// meeting's alarm time arrives, like In Your Face. Apple's alarm still rings alongside.
    @ObservationIgnored private var watcher: Task<Void, Never>?

    /// Pop In left the screen or the phone locked: put Apple's alarms back for everything, right away.
    func wentToBackground() async {
        isForeground = false
        if ScreenshotMode.isOn { return }
        watcher?.cancel()
        AlarmLoop.stop()
        let task = UIApplication.shared.beginBackgroundTask(withName: "restore-alarms")
        await syncAlarms()
        UIApplication.shared.endBackgroundTask(task)
    }

    private func startWatching() {
        watcher?.cancel()
        watcher = Task { @MainActor [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                tick += 1
                // Every half minute, hold back any alarm that has come within the quiet window.
                if tick % 15 == 0 { await self?.syncAlarms() }
                guard let self, UIApplication.shared.applicationState == .active, !self.settingsOpen, !ScreenshotMode.isOn else { continue }
                let now = Date.now
                let open = (self.meetings + self.testMeetings).filter { !self.cleared.contains($0.id) && $0.end > now }
                let state = AlarmScreenRule.State(showing: self.arrived?.id, shown: self.shownNowFor, snoozedUntil: self.snoozedUntil)
                let (action, next) = AlarmScreenRule.tick(open: open, state: state, now: now, config: self.screenConfig(now))
                self.snoozedUntil = next.snoozedUntil
                switch action {
                case .none:
                    break
                case .close:
                    AlarmLoop.stop()
                    self.arrived = nil
                case .show(let id), .replace(let id):
                    if case .replace = action { AlarmLoop.stop(); self.arrived = nil }
                    if let m = open.first(where: { $0.id == id }) { self.show(m, ring: true) }
                }
            }
        }
    }

    func backgroundRefresh() async {
        scheduleBackgroundRefresh()
        await refresh()
    }

    func refresh() async {
        if ScreenshotMode.isOn { return }
        guard calendarAuthorized else { meetings = []; calendars = []; return }
        calendars = calendarService.calendars()
        // One meeting in two calendars (say the invite and a forwarded copy) gets one alarm, not two.
        let live = OwnReminder.live(ownReminders, now: .now)
        if live != ownReminders { ownReminders = live }
        meetings = (MeetingMerge.merge(calendarService.upcoming(disabled: disabledCalendarIDs, acceptedOnly: acceptedOnly), preferred: { self.ringsFully($0) })
            + live.map(\.meeting)).sorted { $0.start < $1.start }
        // Forget cleared meetings that have dropped out of the window.
        // Test and practice meetings live outside the calendar list; keep them cleared too, or a popped test
        // alarm comes back the next time Settings refreshes the calendar.
        let liveIDs = Set((meetings + testMeetings).map(\.id))
        let pruned = cleared.intersection(liveIDs)
        if pruned != cleared { cleared = pruned; prefs.clearedMeetingIDs = pruned }
        writeWidgetSnapshot()
        await syncAlarms()
    }

    func syncAlarms() async {
        if ScreenshotMode.isOn { return }
        guard alarmsAuthorized else { return }
        let now = Date.now
        if let p = pausedUntil, p <= now { pausedUntil = nil; return }
        let open = meetings.filter { !cleared.contains($0.id) && $0.end > now }
        let live = meetings.filter { !isPaused($0, now: now) && !isMissed($0, among: open, now: now) }
        let alarmMeetings = live.filter { ringsFully($0) }
        let gentleMeetings = live.filter { !ringsFully($0) }
        let planned = AlarmPlanner.plan(meetings: alarmMeetings, leadMinutes: leadMinutes, now: now, cleared: cleared,
                                        countdown: countdownCard)
        let gentlePlanned = AlarmPlanner.plan(meetings: gentleMeetings, leadMinutes: leadMinutes, now: now, cleared: cleared)
        testPlanned = testPlanned.filter { $0.fireDate > now && !cleared.contains($0.meeting.id) }
        snoozePlanned = snoozePlanned.filter { $0.fireDate > now && !cleared.contains($0.meeting.id) }
        // A snoozed meeting's original alarm is replaced by the snooze.
        let snoozedIDs = Set(snoozePlanned.map(\.meeting.id))
        let all = (planned.filter { !snoozedIDs.contains($0.meeting.id) } + testPlanned + snoozePlanned)
            .sorted { $0.fireDate < $1.fireDate }
        nextAlarm = all.first?.fireDate
        // While Pop In is open it handles anything soon itself; Apple's alarm covers later meetings, and a backup one
        // minute after each soon ring covers Pop In being killed. A meeting Pop In has already taken over gets none.
        // The early heads-up alarm, when set and earlier than the main one. Always left to Apple's alarm.
        let early: [PlannedAlarm] = earlyMinutes > leadMinutes
            ? AlarmPlanner.plan(meetings: alarmMeetings.filter { m in !snoozedIDs.contains(m.id) },
                                leadMinutes: earlyMinutes, now: now, cleared: cleared)
            : []
        var toSchedule: [PlannedAlarm]
        if isForeground {
            let soonCutoff = now.addingTimeInterval(Self.openQuietWindow)
            let later = all.filter { $0.scheduleDate > soonCutoff }
            let backups = all.filter { $0.scheduleDate <= soonCutoff && !shownNowFor.contains($0.meeting.id) }
                .map(AlarmPlanner.safetyBackup)
            toSchedule = later + backups
        } else {
            toSchedule = all
        }
        toSchedule += early
        do {
            try await alarmService.sync(toSchedule, keep: Set((testPlanned + snoozePlanned).map(\.id)))
            syncProblem = nil
            scheduledAlarms = alarmService.scheduledCount
        } catch {
            syncProblem = "Couldn't set an alarm: \(error.localizedDescription)"
        }
        await nudgeService.sync(planned, enabled: nudges, gentle: gentlePlanned)
    }

    /// Rings a test alarm so the full-screen alert can be checked with the phone locked.
    func testAlarm(withCountdown: Bool) async {
        alarmsAuthorized = alarmService.isAuthorized
        guard alarmsAuthorized else {
            testMessage = "Alarms are off for Pop In. Turn them on in Settings, then try again."
            return
        }
        do {
            // A pretend meeting that starts one lead time after the ring, like a real one.
            let fire = Date.now.addingTimeInterval(withCountdown ? 90 : 20)
            let start = fire.addingTimeInterval(TimeInterval(max(1, leadMinutes) * 60))
            let meeting = Meeting(id: "test-\(UUID().uuidString)", eventID: "test", title: "Test meeting",
                                  start: start, end: start.addingTimeInterval(10 * 60), calendarID: "test", joinURL: nil)
            testMeetings = [meeting]
            testPlanned = [PlannedAlarm(id: UUID(), meeting: meeting, fireDate: fire, countdownSeconds: withCountdown ? 60 : nil)]
            await syncAlarms()
            testMessage = withCountdown
                ? "Set. Close Settings to see the bubble take over in about 90 seconds, or lock your phone to see the locked alarm."
                : "Set for 20 seconds from now. Close Settings to see the bubble take over, or lock your phone to see the locked alarm."
        } catch {
            testMessage = "Couldn't set the test alarm: \(error.localizedDescription)"
        }
    }

    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: Arriving from an alarm

    /// After the alarm's Join button: open the link straight away, or show the Now screen when there is none.
    /// Opening Promptly near a meeting's alarm time also shows the Now screen, as a fallback in case the
    /// alarm button's intent doesn't reach the app.
    private func handleArrival(now: Date = .now, force: Bool = false) {
        if let pending = PendingJoin.take(now: now) {
            let meeting = meetings.first { $0.id == pending.meetingID }
            if let url = URL(string: pending.joinURL), !pending.joinURL.isEmpty {
                if let meeting { markCleared(meeting, skipped: false) }
                linkToOpen = url
            } else if let meeting {
                show(meeting)
            }
            return
        }
        let lead = TimeInterval(leadMinutes * 60)
        if let due = upcoming(at: now).first(where: {
            ringsFully($0) && !isPaused($0, now: now) && (force || snoozedUntil[$0.id] == nil)
                && now >= $0.start.addingTimeInterval(-lead - 60) && now <= $0.start.addingTimeInterval(5 * 60)
        }), force || !shownNowFor.contains(due.id) {
            show(due)
        }
    }

    /// From the Lock Screen or Dynamic Island card (promptly://meeting?id=…) or the Home Screen widget's bubble
    /// (promptly://pop?id=…, which pops it on Home and then opens the meeting link).
    func open(_ url: URL) async {
        guard url.scheme == "promptly", url.host == "meeting" || url.host == "pop",
              let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value
        else { return }
        if meetings.first(where: { $0.id == id }) == nil { await refresh() }
        guard let meeting = meetings.first(where: { $0.id == id }), !cleared.contains(id) else { return }
        if url.host == "meeting" {
            show(meeting)
            return
        }
        // Let Home appear, pop the bubble there, then open the link once the pop has played.
        shownNowFor.insert(meeting.id)
        arrived = nil
        try? await Task.sleep(for: .milliseconds(450))
        let link = join(meeting)
        try? await Task.sleep(for: .milliseconds(450))
        if let link { linkToOpen = link }
    }

    private func writeWidgetSnapshot() {
        let items = meetings.filter { !cleared.contains($0.id) }.prefix(12).map {
            WidgetSnapshot.Item(id: $0.id, title: $0.title, start: $0.start, end: $0.end,
                                service: $0.service?.rawValue ?? "", hasLink: $0.joinURL != nil)
        }
        WidgetSnapshot(items: Array(items)).save()
    }

    /// `ring`: Pop In was open at ring time, so Apple's alarm was held back and Pop In rings itself until the
    /// bubble is popped. Arriving from Apple's alarm (already heard) doesn't ring again.
    private func show(_ meeting: Meeting, ring: Bool = false) {
        guard !settingsOpen else { return }   // the watcher tries again once settings close
        shownNowFor.insert(meeting.id)
        arrived = meeting
        if ring && isForeground { AlarmLoop.start(meetingStart: meeting.start) }
        Task { await syncAlarms() }   // drops the backup alarm for this meeting
    }

    // MARK: Join and clear

    /// Returns the link to open, if any, and clears the meeting so the bubble pops.
    func join(_ meeting: Meeting) -> URL? {
        markCleared(meeting, skipped: false)
        return meeting.joinURL
    }

    /// Not going: cleared with a quiet deflate, not a pop.
    func clear(_ meeting: Meeting) {
        markCleared(meeting, skipped: true)
    }

    private func markCleared(_ meeting: Meeting, skipped: Bool) {
        alarmService.stopAlerting()
        AlarmLoop.stop()
        cleared.insert(meeting.id)
        if meeting.calendarID == "test" { testPlanned.removeAll { $0.meeting.id == meeting.id } }
        if !ScreenshotMode.isOn { prefs.clearedMeetingIDs = cleared }
        lastCleared = meeting
        if skipped { skipCount += 1 } else { popCount += 1 }
        if !taughtPop { taughtPop = true; prefs.taughtPop = true }
        writeWidgetSnapshot()
        Task { await syncAlarms() }
    }
}
