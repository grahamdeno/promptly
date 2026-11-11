import Foundation

enum MeetingService: String, Sendable {
    case zoom = "Zoom"
    case teams = "Teams"
    case meet = "Meet"
    case webex = "Webex"
    case goTo = "GoTo"
    case chime = "Chime"
    case whereby = "Whereby"
    case slack = "Slack"
}

/// Finds the video-call link in an event's URL, location or notes. Pure logic, unit tested.
enum MeetingLinkDetector {
    /// Host suffixes. Includes the US government and DoD Teams clouds.
    static let hosts: [(suffix: String, service: MeetingService)] = [
        ("zoom.us", .zoom),
        ("zoomgov.com", .zoom),
        ("teams.microsoft.com", .teams),
        ("teams.microsoft.us", .teams),
        ("teams.live.com", .teams),
        ("teams.cloud.microsoft", .teams),
        ("meet.google.com", .meet),
        ("webex.com", .webex),
        ("webex.us", .webex),
        ("gotomeeting.com", .goTo),
        ("meet.goto.com", .goTo),
        ("chime.aws", .chime),
        ("whereby.com", .whereby),
        ("app.slack.com", .slack),
    ]

    static func service(for url: URL) -> MeetingService? {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host?.lowercased() else { return nil }
        return hosts.first { host == $0.suffix || host.hasSuffix("." + $0.suffix) }?.service
    }

    /// The first meeting link found, checking each text in order (event URL first, then location, then notes).
    static func firstMeetingLink(in texts: [String?]) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        for text in texts.compactMap({ $0 }) where !text.isEmpty {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, range: range) {
                if let url = match.url, service(for: url) != nil { return url }
            }
        }
        return nil
    }
}
