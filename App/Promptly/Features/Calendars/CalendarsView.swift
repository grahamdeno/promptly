import SwiftUI

/// Which calendars ring, how early, and the ball style. Also the last step of first run.
struct CalendarsView: View {
    let firstRun: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What should reach you?")
                            .font(Brand.display(32))
                            .tracking(-0.8)
                            .foregroundStyle(Brand.ink)
                        Text("Pop In rings for meetings on these calendars, even in Silent and Focus.")
                            .font(.system(size: 15))
                            .foregroundStyle(Brand.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 24)

                    if model.calendars.isEmpty {
                        Text(model.calendarAuthorized ? "No calendars on this iPhone yet." : "Calendar access is off.")
                            .font(.system(size: 16))
                            .foregroundStyle(Brand.secondary)
                            .padding(8)
                    }
                    ForEach(model.calendars) { calendar in
                        calendarRow(calendar)
                    }

                    sectionLabel("Ring before")
                    choiceRow(options: [1, 2, 5], selected: model.leadMinutes, label: { "\($0) min" }) {
                        model.leadMinutes = $0
                    }

                    sectionLabel("Alarm sound")
                    choiceRow(options: AlarmSoundChoice.allCases, selected: model.alarmSound,
                              label: { $0 == .bubbleBlow ? "Bubble blow" : "Apple default" }) {
                        model.alarmSound = $0
                    }

                    sectionLabel("Before it rings")
                    settingToggle("Countdown on Lock Screen", detail: "A card with the bubble for the last ten minutes",
                                  isOn: Binding(get: { model.countdownCard }, set: { model.countdownCard = $0 }))
                    settingToggle("Buzz as it gets close", detail: "Builds while Pop In is open",
                                  isOn: Binding(get: { model.buzz }, set: { model.buzz = $0 }))
                    settingToggle("Pop sound", detail: "A soft gum pop; quiet when the phone is on silent",
                                  isOn: Binding(get: { model.popSound }, set: { model.popSound = $0 }))
                    settingToggle("Keep screen on", detail: "While Pop In is open, like a desk clock",
                                  isOn: Binding(get: { model.keepAwake }, set: { model.keepAwake = $0 }))
                    settingToggle("Nudges at 5 and 2 minutes", detail: "One buzz each, even when locked",
                                  isOn: Binding(get: { model.nudges }, set: { model.nudges = $0 }))

                    sectionLabel("Check the alarm")
                    VStack(alignment: .leading, spacing: 10) {
                        Text(alarmStatus)
                            .font(.system(size: 15))
                            .foregroundStyle(Brand.secondary)
                        HStack(spacing: 8) {
                            Button("Ring in 20 s") { Task { await model.testAlarm(withCountdown: false) } }
                                .buttonStyle(SecondaryButtonStyle(height: 44, fill: true))
                            Button("Card, then ring") { Task { await model.testAlarm(withCountdown: true) } }
                                .buttonStyle(SecondaryButtonStyle(height: 44, fill: true))
                        }
                        if let message = model.testMessage {
                            Text(message)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Brand.ink)
                        }
                        Text("The alarm fills the screen when the phone is locked. While you're using the phone, iPhone shows it as a large banner at the top instead.")
                            .font(.system(size: 13))
                            .foregroundStyle(Brand.secondary)
                    }
                    .padding(.horizontal, 8)

                    sectionLabel("Ball")
                    choiceRow(options: BallStyle.allCases, selected: model.ballStyle,
                              label: { $0 == .bubble ? "Bubble" : "Steady" }) {
                        model.ballStyle = $0
                    }

                    Color.clear.frame(height: 140)
                }
                .padding(.horizontal, 20)
                .padding(.top, firstRun ? 80 : 40)
            }

            Button("Done") {
                if firstRun { model.finishOnboarding() } else { dismiss() }
            }
            .buttonStyle(PrimaryButtonStyle(height: 56))
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .task { await model.refresh() }
    }

    private func calendarRow(_ calendar: CalendarInfo) -> some View {
        let isOn = Binding<Bool>(
            get: { !model.disabledCalendarIDs.contains(calendar.id) },
            set: { on in
                if on { model.disabledCalendarIDs.remove(calendar.id) } else { model.disabledCalendarIDs.insert(calendar.id) }
            }
        )
        let gentle = model.gentleCalendarIDs.contains(calendar.id)
        return Toggle(isOn: isOn) {
            HStack(spacing: 14) {
                Circle().fill(Brand.color(hex: calendar.colorHex)).frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(calendar.title).font(.system(size: 17)).foregroundStyle(Brand.ink)
                    Text(calendar.source).font(.system(size: 13)).foregroundStyle(Brand.secondary)
                }
                Spacer(minLength: 8)
                if isOn.wrappedValue {
                    Menu {
                        Button("Alarm: full screen, rings") { model.gentleCalendarIDs.remove(calendar.id) }
                        Button("Gentle: one notification") { model.gentleCalendarIDs.insert(calendar.id) }
                    } label: {
                        Text(gentle ? "Gentle" : "Alarm")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Brand.ink)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 32)
                            .background(Capsule().fill(Brand.ink.opacity(0.07)))
                    }
                    .accessibilityLabel("\(calendar.title) alert style: \(gentle ? "Gentle" : "Alarm")")
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
                Text(title).font(.system(size: 17)).foregroundStyle(Brand.ink)
                Text(detail).font(.system(size: 13)).foregroundStyle(Brand.secondary)
            }
        }
        .tint(Brand.ink)
        .padding(.horizontal, 8)
        .frame(minHeight: 60)
        .overlay(alignment: .bottom) { Rectangle().fill(Brand.hairline).frame(height: 1) }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Brand.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 32)
            .padding(.bottom, 12)
    }

    private func choiceRow<T: Hashable>(options: [T], selected: T, label: @escaping (T) -> String,
                                        pick: @escaping (T) -> Void) -> some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selected
                Button { pick(option) } label: {
                    Text(label(option))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isSelected ? .white : Brand.ink)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Capsule().fill(isSelected ? Brand.ink : .white))
                        .overlay(Capsule().stroke(isSelected ? Brand.ink : Color(white: 0.89), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
    }
}
