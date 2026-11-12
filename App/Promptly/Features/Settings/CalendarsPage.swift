import SwiftUI

/// Settings › Calendars.
struct CalendarsPage: View {
    var body: some View {
        SettingsPage { CalendarsList() }
            .navigationTitle("Calendars")
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// The calendars, grouped by account so a long list reads as a few short ones. Big accounts start folded; search
/// appears when there are many. Each calendar has an on/off switch and, when on, how it alerts.
struct CalendarsList: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var expanded: Set<String> = []
    @State private var seeded = false

    private static let foldAbove = 5

    var body: some View {
        let groups = CalendarGroups.group(model.calendars, matching: query)
        VStack(alignment: .leading, spacing: 22) {
            if model.calendars.isEmpty {
                Text(model.calendarAuthorized ? "No calendars on this device yet." : "Calendar access is off.")
                    .font(.body).foregroundStyle(Brand.secondary).padding(.horizontal, 18)
            }
            if model.calendars.count > 8 {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Brand.secondary)
                    TextField("Find a calendar", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Brand.secondary) }
                            .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white))
            }
            if !query.isEmpty && groups.isEmpty {
                Text("No calendar called \"\(query)\".").font(.body).foregroundStyle(Brand.secondary).padding(.horizontal, 18)
            }
            ForEach(groups) { group in
                accountGroup(group, open: !query.isEmpty || expanded.contains(group.source))
            }
            Text("Smart rings full screen for meetings with a video link and sends a quiet notification for the rest. Pick Always rings or Quiet for a whole calendar.")
                .font(.footnote).foregroundStyle(Brand.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 18)
        }
        .onAppear {
            guard !seeded else { return }
            seeded = true
            expanded = Set(CalendarGroups.group(model.calendars).filter { $0.calendars.count <= Self.foldAbove }.map(\.source))
        }
    }

    private func accountGroup(_ group: CalendarGroup, open: Bool) -> some View {
        let on = group.onCount(disabled: model.disabledCalendarIDs)
        let allOn = on == group.calendars.count
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expanded.contains(group.source) { expanded.remove(group.source) } else { expanded.insert(group.source) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .rotationEffect(.degrees(open ? 90 : 0))
                            .foregroundStyle(Brand.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.source).font(.body.weight(.semibold)).foregroundStyle(Brand.ink)
                            Text("\(on) of \(group.calendars.count) on").font(.footnote).foregroundStyle(Brand.secondary)
                        }
                        Spacer()
                    }
                    .frame(minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(group.source), \(on) of \(group.calendars.count) calendars on")
                .accessibilityHint(open ? "Folds the list" : "Shows the calendars")
                Button(allOn ? "Turn all off" : "Turn all on") {
                    var disabled = model.disabledCalendarIDs
                    for cal in group.calendars {
                        if allOn { disabled.insert(cal.id) } else { disabled.remove(cal.id) }
                    }
                    model.disabledCalendarIDs = disabled
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Brand.coralDark)
                .frame(minHeight: 44)
            }
            if open {
                ForEach(group.calendars) { cal in
                    Divider().overlay(Brand.hairline)
                    calendarRow(cal)
                }
            }
        }
        .padding(.horizontal, 18)
        .background(RoundedRectangle(cornerRadius: 20).fill(.white))
    }

    private func calendarRow(_ calendar: CalendarInfo) -> some View {
        let isOn = Binding<Bool>(
            get: { !model.disabledCalendarIDs.contains(calendar.id) },
            set: { on in
                if on { model.disabledCalendarIDs.remove(calendar.id) } else { model.disabledCalendarIDs.insert(calendar.id) }
            }
        )
        let rule = model.rule(forCalendar: calendar.id)
        return HStack(alignment: .center, spacing: 12) {
            Circle().fill(Brand.color(hex: calendar.colorHex)).frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(calendar.title).font(.body).foregroundStyle(Brand.ink)
                if isOn.wrappedValue {
                    Menu {
                        Picker("Alerts", selection: Binding(get: { rule }, set: { new in
                            if new == .smart || model.store.isPro { model.setRule(new, forCalendar: calendar.id) } else { model.showPro = true }
                        })) {
                            Text("Smart: rings for video meetings").tag(AppModel.AlertRule.smart)
                            Text(model.store.isPro ? "Always rings" : "Always rings (Pro)").tag(AppModel.AlertRule.alarm)
                            Text(model.store.isPro ? "Quiet: notifications only" : "Quiet: notifications only (Pro)").tag(AppModel.AlertRule.gentle)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(ruleText(rule))
                            Image(systemName: "chevron.up.chevron.down").font(.caption2)
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Brand.coralDark)
                        .frame(minHeight: 28)
                    }
                    .accessibilityLabel("\(calendar.title) alerts: \(ruleText(rule))")
                } else {
                    Text("Off").font(.footnote).foregroundStyle(Brand.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(Brand.coralDark)
                .accessibilityLabel(calendar.title)
        }
        .frame(minHeight: 60)
    }

    private func ruleText(_ rule: AppModel.AlertRule) -> String {
        switch rule {
        case .smart: "Smart"
        case .alarm: "Always rings"
        case .gentle: "Quiet"
        }
    }
}
