import Foundation

/// Groups the device's calendars by account (iCloud, Exchange, Gmail…) so a long list reads as a few short ones.
/// Pure logic, unit tested.
struct CalendarGroup: Identifiable, Equatable {
    let source: String
    let calendars: [CalendarInfo]
    var id: String { source }

    func onCount(disabled: Set<String>) -> Int { calendars.filter { !disabled.contains($0.id) }.count }
}

enum CalendarGroups {
    /// Accounts in alphabetical order (blank names under "Other"), calendars by title within each.
    /// `matching` filters by calendar or account name, case and accent insensitive.
    static func group(_ calendars: [CalendarInfo], matching query: String = "") -> [CalendarGroup] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let shown = q.isEmpty ? calendars : calendars.filter {
            $0.title.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                || $0.source.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
        let bySource = Dictionary(grouping: shown) { $0.source.isEmpty ? "Other" : $0.source }
        return bySource.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.map { source in
            CalendarGroup(source: source, calendars: bySource[source, default: []]
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending })
        }
    }

    /// "6 of 14", for the Settings row.
    static func summary(_ calendars: [CalendarInfo], disabled: Set<String>) -> String {
        let on = calendars.filter { !disabled.contains($0.id) }.count
        if calendars.isEmpty { return "None" }
        return on == calendars.count ? "All \(on)" : "\(on) of \(calendars.count)"
    }
}
