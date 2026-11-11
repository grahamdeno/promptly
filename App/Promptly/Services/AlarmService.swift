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

    /// Cancels alarms that are no longer wanted and schedules the missing ones.
    func sync(_ planned: [PlannedAlarm]) async throws {
        let existing = Set(((try? manager.alarms) ?? []).map(\.id))
        let wanted = Dictionary(planned.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for id in existing where wanted[id] == nil {
            try? manager.cancel(id: id)
        }
        for (id, alarm) in wanted where !existing.contains(id) {
            try await schedule(alarm)
        }
    }

    func cancelAll() {
        for alarm in (try? manager.alarms) ?? [] { try? manager.cancel(id: alarm.id) }
    }

    private func schedule(_ planned: PlannedAlarm) async throws {
        let meeting = planned.meeting
        let joinText = LocalizedStringResource(stringLiteral: meeting.service.map { "Join \($0.rawValue)" } ?? "Open")
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: meeting.title),
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
            secondaryIntent: OpenMeetingIntent(meetingID: meeting.id, joinURL: meeting.joinURL?.absoluteString ?? ""),
            sound: .default
        )
        _ = try await manager.schedule(id: planned.id, configuration: configuration)
    }
}
