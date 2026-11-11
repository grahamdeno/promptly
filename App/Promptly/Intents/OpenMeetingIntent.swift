import AlarmKit
import AppIntents
import Foundation

/// The alarm's Join button. Opens Promptly, which then opens the meeting link (or the Now screen when
/// there is no link). The link travels inside the alarm, so this works even before the calendar reloads.
struct OpenMeetingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open meeting"
    static var description = IntentDescription("Opens Pop In on the meeting that just rang.")
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = false

    @Parameter(title: "Meeting")
    var meetingID: String

    @Parameter(title: "Link")
    var joinURL: String

    @Parameter(title: "Alarm")
    var alarmID: String

    init() {}

    init(meetingID: String, joinURL: String, alarmID: String) {
        self.meetingID = meetingID
        self.joinURL = joinURL
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        // The custom button doesn't stop the alarm on its own; without this it keeps ringing.
        if let id = UUID(uuidString: alarmID) { try? AlarmManager.shared.stop(id: id) }
        PendingJoin.save(meetingID: meetingID, joinURL: joinURL)
        return .result()
    }
}
