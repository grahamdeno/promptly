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

    init() {}

    init(meetingID: String, joinURL: String) {
        self.meetingID = meetingID
        self.joinURL = joinURL
    }

    func perform() async throws -> some IntentResult {
        PendingJoin.save(meetingID: meetingID, joinURL: joinURL)
        return .result()
    }
}
