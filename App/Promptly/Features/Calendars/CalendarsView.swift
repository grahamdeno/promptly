import SwiftUI

/// Settings, in three levels: calendars and alerts up front, Advanced folded away, and Diagnostics hidden until the
/// version line is tapped five times. Also the calendar step of first run.
struct CalendarsView: View {
    let firstRun: Bool
    var onDone: (() -> Void)? = nil
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var showAdvanced = false
    @State private var versionTaps = 0
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 32

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(firstRun ? "Which calendars?" : "Settings")
                            .font(.system(size: titleSize, weight: .semibold))
                            .tracking(-0.8)
                            .foregroundStyle(Brand.ink)
                        Text("Smart: meetings with a video link ring like an alarm; other events get a quiet notification. Change it per calendar.")
                            .font(.subheadline)
                            .foregroundStyle(Brand.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 20)

                    if model.calendars.isEmpty {
                        Text(model.calendarAuthorized ? "No calendars on this device yet." : "Calendar access is off.")
                            .font(.body)
                            .foregroundStyle(Brand.secondary)
                            .padding(8)
                    }
                    ForEach(model.calendars) { calendar in
                        calendarRow(calendar)
                    }

                    sectionLabel("Ring before")
                    choiceRow(options: [1, 2, 5, 10], selected: model.leadMinutes, label: { "\($0) min" },
                              locked: { $0 > 5 && !model.store.isPro }) {
                        model.leadMinutes = $0
                    }

                    sectionLabel("Alarm sound")
                    choiceRow(options: AlarmSoundChoice.allCases, selected: model.alarmSound, label: { $0.label },
                              locked: { $0.isPro && !model.store.isPro }) {
                        model.alarmSound = $0
                        if $0 != .appleDefault { AlarmLoop.preview($0) }
                    }
                    Text(model.alarmSound == .appleDefault
                         ? "Apple's tone rings on the Lock Screen. While Pop In is open you'll hear Gum pops, because apps can't play Apple's alarm tones."
                         : "Tap a sound to hear it. The pop when you clear a meeting matches: Chimes sparkle, the others pop.")
                        .font(.footnote)
                        .foregroundStyle(Brand.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)

                    sectionLabel("Bubble color")
                    choiceRow(options: GumPalette.allCases, selected: model.gumColor, label: { $0.label },
                              locked: { $0.isPro && !model.store.isPro }) {
                        model.gumColor = $0
                    }

                    if !firstRun {
                        Button { model.showPro = true } label: {
                            HStack {
                                Image(systemName: "sparkles").foregroundStyle(Brand.coralDark)
                                Text(model.store.isPro ? "Pop In Pro: unlocked" : "Pop In Pro: Unicorn mode and more")
                                    .font(.body.weight(.medium)).foregroundStyle(Brand.ink)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Brand.secondary)
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 56)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Brand.ink.opacity(0.05)))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 24)
                        .padding(.horizontal, 8)
                    }

                    if !firstRun {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) { showAdvanced.toggle() }
                        } label: {
                            HStack {
                                Text("Advanced").font(.body.weight(.medium)).foregroundStyle(Brand.ink)
                                Spacer()
                                Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                                    .foregroundStyle(Brand.secondary)
                            }
                            .padding(.horizontal, 8)
                            .frame(minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 24)
                        .accessibilityAddTraits(.isHeader)

                        if showAdvanced {
                            settingToggle("Countdown on Lock Screen", detail: "A card with the bubble for the last ten minutes",
                                          isOn: Binding(get: { model.countdownCard }, set: { model.countdownCard = $0 }))
                            settingToggle("Buzz as it gets close", detail: "Builds while Pop In is open (iPhone)",
                                          isOn: Binding(get: { model.buzz }, set: { model.buzz = $0 }))
                            settingToggle("Pop sound", detail: "A soft gum pop; quiet when the phone is on silent",
                                          isOn: Binding(get: { model.popSound }, set: { model.popSound = $0 }))
                            settingToggle("Keep screen on", detail: model.store.isPro ? "While Pop In is open, like a desk clock" : "Pro: desk mode while Pop In is open",
                                          isOn: Binding(get: { model.keepAwake }, set: { on in
                                              if on && !model.store.isPro { model.showPro = true } else { model.keepAwake = on }
                                          }))
                            settingToggle("Nudges at 5 and 2 minutes", detail: "One buzz each, even when locked",
                                          isOn: Binding(get: { model.nudges }, set: { model.nudges = $0 }))
                        }

                        if versionTaps >= 5 { diagnostics }

                        Text("Pop In \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                            .font(.footnote)
                            .foregroundStyle(Brand.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                            .onTapGesture { versionTaps += 1 }
                            .padding(.top, 24)
                            .accessibilityHidden(true)
                    }

                    Color.clear.frame(height: 120)
                }
                .padding(.horizontal, 20)
                .padding(.top, firstRun ? 72 : 32)
            }

            Button("Done") {
                if firstRun { onDone?() } else { dismiss() }
            }
            .buttonStyle(PrimaryButtonStyle(height: 56))
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .task { await model.refresh() }
        .sheet(isPresented: Binding(get: { model.showPro }, set: { model.showPro = $0 })) {
            ProView().environment(model)
        }
    }

    /// For the owner and for support: alarm count, test alarms, and the bubble rollback switch.
    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Diagnostics")
            Text(alarmStatus)
                .font(.subheadline)
                .foregroundStyle(Brand.secondary)
                .padding(.horizontal, 8)
            HStack(spacing: 8) {
                Button("Ring in 20 s") { Task { await model.testAlarm(withCountdown: false) } }
                    .buttonStyle(SecondaryButtonStyle(height: 44, fill: true))
                Button("Card, then ring") { Task { await model.testAlarm(withCountdown: true) } }
                    .buttonStyle(SecondaryButtonStyle(height: 44, fill: true))
            }
            .padding(.horizontal, 8)
            if let message = model.testMessage {
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Brand.ink)
                    .padding(.horizontal, 8)
            }
            choiceRow(options: BallStyle.allCases, selected: model.ballStyle,
                      label: { $0 == .bubble ? "Bubble" : "Steady ball" }) {
                model.ballStyle = $0
            }
        }
    }

    private func calendarRow(_ calendar: CalendarInfo) -> some View {
        let isOn = Binding<Bool>(
            get: { !model.disabledCalendarIDs.contains(calendar.id) },
            set: { on in
                if on { model.disabledCalendarIDs.remove(calendar.id) } else { model.disabledCalendarIDs.insert(calendar.id) }
            }
        )
        let rule = model.rule(forCalendar: calendar.id)
        let ruleLabel = rule == .smart ? "Smart" : (rule == .alarm ? "Alarm" : "Gentle")
        return Toggle(isOn: isOn) {
            HStack(spacing: 14) {
                Circle().fill(Brand.color(hex: calendar.colorHex)).frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(calendar.title).font(.body).foregroundStyle(Brand.ink)
                    Text(calendar.source).font(.footnote).foregroundStyle(Brand.secondary)
                }
                Spacer(minLength: 8)
                if isOn.wrappedValue {
                    Menu {
                        Button("Smart: alarm for video meetings") { model.setRule(.smart, forCalendar: calendar.id) }
                        Button(model.store.isPro ? "Alarm: everything rings" : "Alarm: everything rings (Pro)") {
                            if model.store.isPro { model.setRule(.alarm, forCalendar: calendar.id) } else { model.showPro = true }
                        }
                        Button(model.store.isPro ? "Gentle: notifications only" : "Gentle: notifications only (Pro)") {
                            if model.store.isPro { model.setRule(.gentle, forCalendar: calendar.id) } else { model.showPro = true }
                        }
                    } label: {
                        Text(ruleLabel)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Brand.ink)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 32)
                            .background(Capsule().fill(Brand.ink.opacity(0.07)))
                    }
                    .accessibilityLabel("\(calendar.title) alerts: \(ruleLabel)")
                }
            }
        }
        .tint(Brand.ink)
        .padding(.horizontal, 8)
        .frame(minHeight: 60)
        .overlay(alignment: .bottom) { Rectangle().fill(Brand.hairline).frame(height: 1) }
    }

    private var alarmStatus: String {
        if !model.alarmsAuthorized { return "Alarms are off for Pop In. Turn them on in Settings." }
        if !model.calendarAuthorized { return "Calendar access is off." }
        let count = "\(model.scheduledAlarms) alarm\(model.scheduledAlarms == 1 ? "" : "s") set"
        guard let next = model.nextAlarm else { return "\(count). No meetings in the next two days." }
        let f = DateFormatter()
        f.dateStyle = Calendar.current.isDateInToday(next) ? .none : .short
        f.timeStyle = .short
        return "\(count). Next rings at \(f.string(from: next))."
    }

    private func settingToggle(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.body).foregroundStyle(Brand.ink)
                Text(detail).font(.footnote).foregroundStyle(Brand.secondary)
            }
        }
        .tint(Brand.ink)
        .padding(.horizontal, 8)
        .frame(minHeight: 60)
        .overlay(alignment: .bottom) { Rectangle().fill(Brand.hairline).frame(height: 1) }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Brand.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 32)
            .padding(.bottom, 12)
    }

    private func choiceRow<T: Hashable>(options: [T], selected: T, label: @escaping (T) -> String,
                                        locked: @escaping (T) -> Bool = { _ in false },
                                        pick: @escaping (T) -> Void) -> some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selected
                let isLocked = locked(option)
                Button { if isLocked { model.showPro = true } else { pick(option) } } label: {
                    Text(isLocked ? "\(label(option)) ✦" : label(option))
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(isSelected ? .white : Brand.ink)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Capsule().fill(isSelected ? Brand.ink : .white))
                        .overlay(Capsule().stroke(isSelected ? Brand.ink : Color(white: 0.89), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityLabel(isLocked ? "\(label(option)), Pro" : label(option))
            }
        }
        .padding(.horizontal, 8)
    }
}
