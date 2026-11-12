import Foundation

/// Tidies meeting titles and folds duplicate copies of one meeting together. Pure logic, unit tested.
///
/// The same meeting often sits in a calendar twice: the original invite and a forwarded copy ("FW: ..."), or the
/// same event in a work and a personal calendar. Without this, each copy gets its own alarm and heads-up.
enum MeetingMerge {
    private static let prefixes = ["fw:", "fwd:", "re:", "aw:", "wg:", "tr:", "[external]", "external:"]

    /// The title without leading "FW:", "Fwd:", "RE:" (and similar) tags, which only crowd the alarm banner.
    static func cleanTitle(_ title: String) -> String {
        var t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var changed = true
        while changed {
            changed = false
            for p in prefixes where t.lowercased().hasPrefix(p) {
                t = String(t.dropFirst(p.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                changed = true
            }
        }
        return t.isEmpty ? title.trimmingCharacters(in: .whitespacesAndNewlines) : t
    }

    /// Copies are the same meeting when they start within a minute of each other and either share a video link
    /// or have the same title once tidied. The copy kept is the one `preferred` says rings (when only one does),
    /// then the one with a link, else the first.
    static func merge(_ meetings: [Meeting], preferred: (Meeting) -> Bool = { _ in false }) -> [Meeting] {
        var kept: [Meeting] = []
        for m in meetings.sorted(by: { $0.start < $1.start }) {
            if let i = kept.firstIndex(where: { same($0, m) }) {
                let old = kept[i]
                if preferred(m) != preferred(old) {
                    if preferred(m) { kept[i] = m }
                } else if old.joinURL == nil && m.joinURL != nil {
                    kept[i] = m
                }
            } else {
                kept.append(m)
            }
        }
        return kept
    }

    static func same(_ a: Meeting, _ b: Meeting) -> Bool {
        guard abs(a.start.timeIntervalSince(b.start)) < 60 else { return false }
        if let la = a.joinURL, let lb = b.joinURL, linkKey(la) == linkKey(lb) { return true }
        return cleanTitle(a.title).lowercased() == cleanTitle(b.title).lowercased()
    }

    /// Host and path, ignoring the query (trackers and passwords differ between copies of the same invite).
    private static func linkKey(_ url: URL) -> String {
        (url.host?.lowercased() ?? "") + url.path.lowercased()
    }
}
