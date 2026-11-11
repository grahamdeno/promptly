import AlarmKit
import Foundation

/// Carried by each alarm and read by the Lock Screen and Dynamic Island card. Shared by the app and the widget extension.
struct MeetingAlarmMetadata: AlarmMetadata {
    var meetingID: String
    var title: String
    var start: Date
    var service: String
    /// Length of the Lock Screen countdown before the alarm rings, in seconds. 0 when there is no countdown.
    var countdownSeconds: Double

    /// Opens Promptly on this meeting's Now screen.
    var openURL: URL? {
        var c = URLComponents()
        c.scheme = "promptly"
        c.host = "meeting"
        c.queryItems = [URLQueryItem(name: "id", value: meetingID)]
        return c.url
    }
}
