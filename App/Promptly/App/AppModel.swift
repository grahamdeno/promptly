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
    @ObservationIgnored let prefs: Prefs
    @ObservationIgnored private var storeObserver: NSObjectProtocol?

    var meetings: [Meeting] = []
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
        keepAwake = prefs.keepAwake
        alarmService.sound = prefs.alarmSound
        nudges = prefs.nudges
        cleared = prefs.clearedMeetingIDs
        taughtPop = prefs.taughtPop
        calendarAuthorized = calendarService.isAuthorized
        alarmsAuthorized = alarmService.isAuthorized
        storeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: calendarService.store, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    // MARK: Upcoming

    /// Meetings not yet cleared that haven't ended.
    func upcoming(at now: Date) -> [Meeting] {
        meetings.filter { !cleared.contains($0.id) && $0.end > now }
    }

    // MARK: Permissions and first run

    func requestPermissions() async {
        calendarAuthorized = await calendarService.requestAccess()
        alarmsAuthorized = await alarmService.requestAccess()
        await refresh()
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

    private func startWatching() {
        watcher?.cancel()
        watcher = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, UIApplication.shared.applicationState == .active, self.arrived == nil else { continue }
                let now = Date.now
                let lead = TimeInterval(self.leadMinutes * 60)
                if let due = self.upcoming(at: now).first(where: {
                    now >= $0.start.addingTimeInterval(-lead) && now <= $0.start.addingTimeInterval(5 * 60)
                }), !self.shownNowFor.contains(due.id) {
                    self.show(due)
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
        let alarmMeetings = meetings.filter { !gentleCalendarIDs.contains($0.calendarID) }
        let gentleMeetings = meetings.filter { gentleCalendarIDs.contains($0.calendarID) }
        let planned = AlarmPlanner.plan(meetings: alarmMeetings, leadMinutes: leadMinutes, now: .now, cleared: cleared,
                                        countdown: countdownCard)
        let gentlePlanned = AlarmPlanner.plan(meetings: gentleMeetings, leadMinutes: leadMinutes, now: .now, cleared: cleared)
        nextAlarm = planned.first?.fireDate
        do {
            try await alarmService.sync(planned)
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
            if withCountdown {
                try await alarmService.scheduleTest(in: 90, countdown: 60)
                testMessage = "Lock your phone now. The countdown card shows in about 30 seconds, then it rings 60 seconds later."
            } else {
                try await alarmService.scheduleTest(in: 20, countdown: nil)
                testMessage = "Lock your phone now. It rings in 20 seconds."
            }
            scheduledAlarms = alarmService.scheduledCount
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
            now >= $0.start.addingTimeInterval(-lead - 60) && now <= $0.start.addingTimeInterval(5 * 60)
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

    private func show(_ meeting: Meeting) {
        shownNowFor.insert(meeting.id)
        arrived = meeting
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
        cleared.insert(meeting.id)
        prefs.clearedMeetingIDs = cleared
        popCount += 1
        if !taughtPop { taughtPop = true; prefs.taughtPop = true }
        writeWidgetSnapshot()
        Task { await syncAlarms() }
    }
}
