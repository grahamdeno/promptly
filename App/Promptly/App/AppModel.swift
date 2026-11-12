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
    var buzz: Bool {
        didSet { prefs.buzz = buzz }
    }
    var popSound: Bool {
        didSet { prefs.popSound = popSound }
    }
    /// Bubble color. Also tints the alarm's buttons, so a change reschedules the alarms; widgets redraw.
    var gumColor: GumPalette {
        didSet {
            prefs.gumColor = gumColor
            // The app icon follows the bubble color (iOS shows a one-line notice when it changes).
            let icon: String? = gumColor == .coral ? "AppIcon-Coral" : (gumColor == .unicorn ? "AppIcon-Unicorn" : nil)
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
                if !gentleCalendarIDs.isEmpty { _ = await nudgeService.requestAccess() }
                await syncAlarms()
            }
        }
    }
    var keepAwake: Bool {
        didSet { prefs.keepAwake = keepAwake; applyKeepAwake() }
    }
    var nudges: Bool {
        didSet {
            prefs.nudges = nudges
            Task {
                if nudges, !(await nudgeService.requestAccess()) { nudges = false; return }
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
        buzz = prefs.buzz
        popSound = prefs.popSound
        alarmSound = prefs.alarmSound
        gumColor = prefs.gumColor
        gentleCalendarIDs = prefs.gentleCalendarIDs
        alarmCalendarIDs = prefs.alarmCalendarIDs
        keepAwake = prefs.keepAwake
        alarmService.sound = prefs.alarmSound
        nudges = prefs.nudges
        cleared = prefs.clearedMeetingIDs
        taughtPop = prefs.taughtPop
        calendarAuthorized = calendarService.isAuthorized
        alarmsAuthorized = alarmService.isAuthorized
        // If Pro goes away (refund), fall back to free choices.
        store.onLost = { [weak self] in
            guard let self else { return }
            if self.gumColor.isPro { self.gumColor = .bubblegum }
            if self.alarmSound.isPro { self.alarmSound = .bubbleBlow }
            if self.leadMinutes > 5 { self.leadMinutes = 5 }
            if self.keepAwake { self.keepAwake = false }
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

    /// Meetings not yet cleared that haven't ended.
    func upcoming(at now: Date) -> [Meeting] {
        (meetings + testMeetings).filter { !cleared.contains($0.id) && $0.end > now }.sorted { $0.start < $1.start }
    }

    // MARK: Permissions and first run

    func requestPermissions() async {
        await requestCalendarAccess()
        await requestAlarmAccess()
    }

    func requestCalendarAccess() async {
        calendarAuthorized = await calendarService.requestAccess()
        await refresh()
    }

    func requestAlarmAccess() async {
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
        if meeting.calendarID == "test" { return true }
        switch rule(forCalendar: meeting.calendarID) {
        case .alarm: return true
        case .gentle: return false
        case .smart: return meeting.joinURL != nil
        }
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
        applyKeepAwake()
        calendarAuthorized = calendarService.isAuthorized
        alarmsAuthorized = alarmService.isAuthorized
        await refresh()
        // Opening Pop In while an alarm rings counts as seeing it: silence it, show the meeting full screen.
        alarmService.stopAlerting()
        handleArrival()
        scheduleBackgroundRefresh()
        startWatching()
    }

    /// While Pop In is open (say, on an iPad left on the desk), take over the screen with the Now view when a
    /// meeting's alarm time arrives, like In Your Face. Apple's alarm still rings alongside.
    @ObservationIgnored private var watcher: Task<Void, Never>?

    /// Pop In left the screen or the phone locked: put Apple's alarms back for everything, right away.
    func wentToBackground() async {
        isForeground = false
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
                guard let self, UIApplication.shared.applicationState == .active, self.arrived == nil,
                      !self.settingsOpen else { continue }
                let now = Date.now
                let lead = TimeInterval(self.leadMinutes * 60)
                if let due = self.upcoming(at: now).first(where: {
                    self.ringsFully($0) && now >= $0.start.addingTimeInterval(-lead) && now <= $0.start.addingTimeInterval(5 * 60)
                }), !self.shownNowFor.contains(due.id) {
                    self.show(due, ring: true)
                }
            }
        }
    }

    func backgroundRefresh() async {
        scheduleBackgroundRefresh()
        await refresh()
    }

    func refresh() async {
        guard calendarAuthorized else { meetings = []; calendars = []; return }
        calendars = calendarService.calendars()
        meetings = calendarService.upcoming(disabled: disabledCalendarIDs)
        // Forget cleared meetings that have dropped out of the window.
        let live = Set(meetings.map(\.id))
        let pruned = cleared.intersection(live)
        if pruned != cleared { cleared = pruned; prefs.clearedMeetingIDs = pruned }
        writeWidgetSnapshot()
        await syncAlarms()
    }

    func syncAlarms() async {
        guard alarmsAuthorized else { return }
        let alarmMeetings = meetings.filter { ringsFully($0) }
        let gentleMeetings = meetings.filter { !ringsFully($0) }
        let now = Date.now
        let planned = AlarmPlanner.plan(meetings: alarmMeetings, leadMinutes: leadMinutes, now: now, cleared: cleared,
                                        countdown: countdownCard)
        let gentlePlanned = AlarmPlanner.plan(meetings: gentleMeetings, leadMinutes: leadMinutes, now: now, cleared: cleared)
        testPlanned = testPlanned.filter { $0.fireDate > now && !cleared.contains($0.meeting.id) }
        let all = (planned + testPlanned).sorted { $0.fireDate < $1.fireDate }
        nextAlarm = all.first?.fireDate
        // While Pop In is open it handles anything soon itself; Apple's alarm covers later meetings, and a backup one
        // minute after each soon ring covers Pop In being killed. A meeting Pop In has already taken over gets none.
        let toSchedule: [PlannedAlarm]
        if isForeground {
            let soonCutoff = now.addingTimeInterval(Self.openQuietWindow)
            let later = all.filter { $0.scheduleDate > soonCutoff }
            let backups = all.filter { $0.scheduleDate <= soonCutoff && !shownNowFor.contains($0.meeting.id) }
                .map(AlarmPlanner.safetyBackup)
            toSchedule = later + backups
        } else {
            toSchedule = all
        }
        do {
            try await alarmService.sync(toSchedule)
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
                ? "Close this and either leave Pop In open (the bubble takes over in about 90 seconds) or lock your phone (Apple's card in about 30 seconds, then the alarm)."
                : "Close this and either leave Pop In open (the bubble takes over in 20 seconds) or lock your phone (Apple's alarm in 20 seconds)." 
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
    private func handleArrival(now: Date = .now) {
        if let pending = PendingJoin.take(now: now) {
            let meeting = meetings.first { $0.id == pending.meetingID }
            if let url = URL(string: pending.joinURL), !pending.joinURL.isEmpty {
                if let meeting { markCleared(meeting) }
                linkToOpen = url
            } else if let meeting {
                show(meeting)
            }
            return
        }
        let lead = TimeInterval(leadMinutes * 60)
        if let due = upcoming(at: now).first(where: {
            ringsFully($0) && now >= $0.start.addingTimeInterval(-lead - 60) && now <= $0.start.addingTimeInterval(5 * 60)
        }), !shownNowFor.contains(due.id) {
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
        if ring && isForeground { AlarmLoop.start() }
        Task { await syncAlarms() }   // drops the backup alarm for this meeting
    }

    // MARK: Join and clear

    /// Returns the link to open, if any, and clears the meeting so the bubble pops.
    func join(_ meeting: Meeting) -> URL? {
        markCleared(meeting)
        return meeting.joinURL
    }

    func clear(_ meeting: Meeting) {
        markCleared(meeting)
    }

    private func markCleared(_ meeting: Meeting) {
        alarmService.stopAlerting()
        AlarmLoop.stop()
        cleared.insert(meeting.id)
        prefs.clearedMeetingIDs = cleared
        lastCleared = meeting
        popCount += 1
        if !taughtPop { taughtPop = true; prefs.taughtPop = true }
        writeWidgetSnapshot()
        Task { await syncAlarms() }
    }
}
