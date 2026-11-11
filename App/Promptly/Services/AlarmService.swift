import ActivityKit
import AlarmKit
import SwiftUI

/// Makes AlarmKit's scheduled alarms match the planner's list. AlarmKit alarms ring like the Clock app:
/// full screen on the Lock Screen, in the Dynamic Island, and through Silent and Focus. With a countdown,
/// AlarmKit also shows Promptly's card (PromptlyWidgets) on the Lock Screen and in the Dynamic Island first.
@MainActor
final class AlarmService {
    private let manager = AlarmManager.shared

    var isAuthorized: Bool { manager.authorizationState == .authorized }
    var wasAsked: Bool { manager.authorizationState != .notDetermined }

    func requestAccess() async -> Bool {
        do { return try await manager.requestAuthorization() == .authorized } catch { return false }
    }

    /// Meeting alarms this service scheduled. Test alarms are never in here, so a sync never cancels them.
    private var ownedIDs: Set<UUID> {
        get { Set((UserDefaults.standard.stringArray(forKey: "ownedAlarmIDs") ?? []).compactMap(UUID.init(uuidString:))) }
        set { UserDefaults.standard.set(newValue.map(\.uuidString), forKey: "ownedAlarmIDs") }
    }

    /// How many alarms are waiting, for the check on the settings screen.
    var scheduledCount: Int { ((try? manager.alarms) ?? []).count }

    /// Cancels meeting alarms that are no longer wanted and schedules the missing ones.
    var sound: AlarmSoundChoice = .bubbleBlow

    /// Cancels every meeting alarm this service set, so the next sync reschedules them (e.g. after a sound change).
    func cancelOwned() {
        for id in ownedIDs { try? manager.cancel(id: id) }
        ownedIDs = []
    }

    func sync(_ planned: [PlannedAlarm]) async throws {
        let existing = Set(((try? manager.alarms) ?? []).map(\.id))
        let wanted = Dictionary(planned.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var owned = ownedIDs
        for id in existing where wanted[id] == nil && owned.contains(id) {
            try? manager.cancel(id: id)
            owned.remove(id)
        }
        for (id, alarm) in wanted where !existing.contains(id) {
            try await schedule(alarm)
            owned.insert(id)
        }
        ownedIDs = owned.intersection(Set(wanted.keys))
    }



    /// Silences any alarm that is ringing right now (the owner has opened Pop In or popped the bubble).
    func stopAlerting() {
        for alarm in (try? manager.alarms) ?? [] where alarm.state == .alerting {
            try? manager.stop(id: alarm.id)
        }
    }

    func cancelAll() {
        for alarm in (try? manager.alarms) ?? [] { try? manager.cancel(id: alarm.id) }
    }

    private func schedule(_ planned: PlannedAlarm) async throws {
        let meeting = planned.meeting
        let joinText = LocalizedStringResource(stringLiteral: meeting.service.map { "Join \($0.rawValue)" } ?? "Open")
        let minutes = Int((meeting.start.timeIntervalSince(planned.fireDate) / 60).rounded())
        let when = minutes <= 0 ? "starting now" : "in \(minutes) min"
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: "\(meeting.title) · \(when)"),
            stopButton: AlarmButton(text: "Dismiss", textColor: .white, systemImageName: "xmark"),
            secondaryButton: AlarmButton(text: joinText, textColor: .white,
                                         systemImageName: meeting.joinURL == nil ? "arrow.up.forward.app" : "video.fill"),
            secondaryButtonBehavior: .custom
        )
        let presentation: AlarmPresentation
        if planned.countdownSeconds != nil {
            presentation = AlarmPresentation(
                alert: alert,
                countdown: AlarmPresentation.Countdown(title: LocalizedStringResource(stringLiteral: meeting.title))
            )
        } else {
            presentation = AlarmPresentation(alert: alert)
        }
        let metadata = MeetingAlarmMetadata(meetingID: meeting.id, title: meeting.title, start: meeting.start,
                                            service: meeting.service?.rawValue ?? "",
                                            countdownSeconds: planned.countdownSeconds ?? 0)
        let attributes = AlarmAttributes<MeetingAlarmMetadata>(presentation: presentation, metadata: metadata,
                                                               tintColor: Brand.coral)
        let configuration = AlarmManager.AlarmConfiguration<MeetingAlarmMetadata>(
            countdownDuration: planned.countdownSeconds.map { Alarm.CountdownDuration(preAlert: $0, postAlert: nil) },
            schedule: .fixed(planned.scheduleDate),
            attributes: attributes,
            stopIntent: nil,
            secondaryIntent: OpenMeetingIntent(meetingID: meeting.id, joinURL: meeting.joinURL?.absoluteString ?? "",
                                               alarmID: planned.id.uuidString),
            sound: sound == .appleDefault ? .default : .named(sound.fileName)
        )
        _ = try await manager.schedule(id: planned.id, configuration: configuration)
    }
}
