import BackgroundTasks
import EventKit
import Observation
import SwiftUI

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
    var syncProblem: String?

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
        nudges = prefs.nudges
        cleared = prefs.clearedMeetingIDs
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

    func becameActive() async {
        calendarAuthorized = calendarService.isAuthorized
        alarmsAuthorized = alarmService.isAuthorized
        await refresh()
        handleArrival()
        scheduleBackgroundRefresh()
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
        let planned = AlarmPlanner.plan(meetings: meetings, leadMinutes: leadMinutes, now: .now, cleared: cleared,
                                        countdown: countdownCard)
        do {
            try await alarmService.sync(planned)
            syncProblem = nil
        } catch {
            syncProblem = "Couldn't set an alarm: \(error.localizedDescription)"
        }
        await nudgeService.sync(planned, enabled: nudges)
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
        cleared.insert(meeting.id)
        prefs.clearedMeetingIDs = cleared
        popCount += 1
        writeWidgetSnapshot()
        Task { await syncAlarms() }
    }
}
