import Foundation

/// Fortune theme: a light one-liner that surfaces inside the ball before a meeting. Things everyone recognizes from meetings, said
/// lightly; no coaching. Each meeting keeps the same one (picked from its id with a stable hash, since Swift's own
/// hash changes every launch). Pure logic, unit tested.
enum Fortunes {
    static let all: [String] = [
        "Bring coffee.",
        "You'll be on mute.",
        "This could have been an email.",
        "Someone will say \u{201C}circle back.\u{201D}",
        "Fix your hair. Just kidding, you look great.",
        "Good things are on the agenda.",
        "You'll end early. Maybe.",
        "Unmute before you talk.",
        "Take the good notes.",
        "Someone will share the wrong screen.",
        "Today's word: \u{201C}alignment.\u{201D}",
        "Stand up and stretch first.",
        "Someone will say \u{201C}can you see my screen?\u{201D}",
        "Listen twice, talk once.",
        "Your Wi-Fi will hold. Probably.",
        "Someone will say \u{201C}you're on mute.\u{201D}",
        "Someone will join late and ask what they missed.",
        "Two people will start talking at once.",
        "\u{201C}Let's take this offline.\u{201D}",
        "Someone's still eating lunch.",
        "The first two minutes are about the weather.",
        "\u{201C}Sorry, go ahead.\u{201D} \u{201C}No, you go.\u{201D}",
        "Someone will be frozen mid-sentence.",
        "There will be an echo. Nobody knows whose.",
        "\u{201C}I'll keep this short.\u{201D} It won't be.",
        "Someone will forget to stop sharing.",
        "A calendar invite for the follow-up is coming.",
        "Someone will say \u{201C}great question.\u{201D}",
        "\u{201C}Can everyone hear me?\u{201D}",
        "You'll hear a keyboard. Loudly.",
        "Someone will be walking somewhere.",
        "\u{201C}I think you're frozen.\u{201D}",
        "The agenda is a suggestion.",
        "\u{201C}Let's give it two more minutes for people to join.\u{201D}",
        "Someone will say \u{201C}low-hanging fruit.\u{201D}",
        "A baby or a doorbell will make a guest appearance.",
        "\u{201C}Is this being recorded?\u{201D}",
        "Someone's camera is pointed at the ceiling.",
        "\u{201C}We're at time, but quickly...\u{201D}",
        "Today's other word: \u{201C}bandwidth.\u{201D}",
    ]

    /// The same fortune every time for the same meeting.
    static func fortune(for meetingID: String) -> String {
        var h: UInt64 = 1469598103934665603   // FNV-1a
        for b in meetingID.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return all[Int(h % UInt64(all.count))]
    }

    /// Shown on the ball in the last fifteen minutes before the start (and on the alarm screen).
    static func shows(start: Date, now: Date) -> Bool {
        let left = start.timeIntervalSince(now)
        return left > 0 && left <= 15 * 60
    }
}
