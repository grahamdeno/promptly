import Foundation

/// What the full-screen alarm should do on each tick while Pop In is open. Pure, so a whole day can be simulated
/// in tests with a fake clock; AppModel's watcher runs exactly this.
enum AlarmScreenRule {
    struct State: Equatable {
        /// The meeting on the alarm screen, if one is up.
        var showing: String?
        /// Meetings whose alarm screen has already been shown (so it isn't shown twice).
        var shown: Set<String> = []
        /// Snoozed meetings and when they ring again.
        var snoozedUntil: [String: Date] = [:]
    }

    enum Action: Equatable {
        case none
        /// Close the alarm screen (its meeting was missed because a newer one took over).
        case close
        /// Show this meeting's alarm screen and ring.
        case show(String)
        /// Close the current screen, then show this one.
        case replace(String)
    }

    struct Config {
        var lead: TimeInterval
        /// Rings full screen (calendar rule, work hours).
        var rings: (Meeting) -> Bool
        var paused: (Meeting) -> Bool
    }

    /// Meetings still open, minus the ones a newer meeting has taken over from, soonest first.
    static func upcoming(_ open: [Meeting], now: Date, config: Config) -> [Meeting] {
        open.filter { !missed($0, open: open, now: now, config: config) }.sorted { $0.start < $1.start }
    }

    static func missed(_ m: Meeting, open: [Meeting], now: Date, config: Config) -> Bool {
        NewestWins.isMissed(m, among: open, now: now, lead: config.lead, rings: { config.rings($0) && !config.paused($0) })
    }

    /// One tick. `open` is every meeting not popped and not yet over.
    static func tick(open: [Meeting], state: State, now: Date, config: Config) -> (Action, State) {
        var s = state
        var closed = false
        if let showing = s.showing {
            guard let m = open.first(where: { $0.id == showing }), missed(m, open: open, now: now, config: config) else {
                // Still the right screen, or its meeting was popped elsewhere: leave it alone.
                if !open.contains(where: { $0.id == showing }) { s.showing = nil; return (.close, s) }
                return (.none, s)
            }
            s.showing = nil
            closed = true
        }
        let list = upcoming(open, now: now, config: config)
        if let hit = s.snoozedUntil.filter({ $0.value <= now }).min(by: { $0.value < $1.value }) {
            s.snoozedUntil[hit.key] = nil
            if list.contains(where: { $0.id == hit.key }) {
                s.showing = hit.key
                s.shown.insert(hit.key)
                return (closed ? .replace(hit.key) : .show(hit.key), s)
            }
        }
        let due = list.first {
            config.rings($0) && !config.paused($0) && s.snoozedUntil[$0.id] == nil && !s.shown.contains($0.id)
                && now >= $0.start.addingTimeInterval(-config.lead) && now <= $0.start.addingTimeInterval(5 * 60)
        }
        if let due {
            s.showing = due.id
            s.shown.insert(due.id)
            return (closed ? .replace(due.id) : .show(due.id), s)
        }
        return (closed ? .close : .none, s)
    }
}
