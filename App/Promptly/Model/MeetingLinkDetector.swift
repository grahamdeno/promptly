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
    case faceTime = "FaceTime"
    case blueJeans = "BlueJeans"
    case ringCentral = "RingCentral"
    case jitsi = "Jitsi"
    case eightByEight = "8x8"
    case skype = "Skype"
    case discord = "Discord"
    case dialpad = "Dialpad"
    case zoho = "Zoho"
    case lifesize = "Lifesize"
    case vonage = "Vonage"
    case gather = "Gather"
    case around = "Around"
    case tuple = "Tuple"
    case pop = "Pop"
    case livestorm = "Livestorm"
    case streamYard = "StreamYard"
    case riverside = "Riverside"
    case butter = "Butter"
    case teamViewer = "TeamViewer"
    case adobeConnect = "Adobe Connect"
    case bigBlueButton = "BigBlueButton"
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
        ("facetime.apple.com", .faceTime),
        ("bluejeans.com", .blueJeans),
        ("ringcentral.com", .ringCentral),
        ("meet.jit.si", .jitsi),
        ("8x8.vc", .eightByEight),
        ("join.skype.com", .skype),
        ("meet.lync.com", .skype),
        ("discord.gg", .discord),
        ("discord.com", .discord),
        ("meetings.dialpad.com", .dialpad),
        ("meeting.zoho.com", .zoho),
        ("meeting.zoho.eu", .zoho),
        ("lifesizecloud.com", .lifesize),
        ("lifesize.com", .lifesize),
        ("meetings.vonage.com", .vonage),
        ("app.gather.town", .gather),
        ("around.co", .around),
        ("tuple.app", .tuple),
        ("pop.com", .pop),
        ("app.livestorm.co", .livestorm),
        ("streamyard.com", .streamYard),
        ("riverside.fm", .riverside),
        ("butter.us", .butter),
        ("teamviewer.com", .teamViewer),
        ("adobeconnect.com", .adobeConnect),
        ("bigbluebutton.org", .bigBlueButton),
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
