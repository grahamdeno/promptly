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
                        Text("Promptly rings for meetings on these calendars, even in Silent and Focus.")
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
        return Toggle(isOn: isOn) {
            HStack(spacing: 14) {
                Circle().fill(Brand.color(hex: calendar.colorHex)).frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(calendar.title).font(.system(size: 17)).foregroundStyle(Brand.ink)
                    Text(calendar.source).font(.system(size: 13)).foregroundStyle(Brand.secondary)
                }
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
