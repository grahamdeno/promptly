import SwiftUI

/// Work hours: inside them meetings ring full screen; outside, they get the quiet notification instead.
struct WorkHoursPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        SettingsPage {
            SettingsGroup("Work hours", note: "Inside these hours meetings ring full screen. Outside them, a quiet notification, so evening and weekend events don't set off the alarm.") {
                SettingsToggle("Only ring in work hours", detail: model.workHours.summary(),
                               isOn: Binding(get: { model.workHours.on }, set: { model.workHours.on = $0 }))
                if model.workHours.on {
                    DatePicker("Starts", selection: time(\.start), displayedComponents: .hourAndMinute)
                        .padding(.vertical, 6)
                    DatePicker("Ends", selection: time(\.end), displayedComponents: .hourAndMinute)
                        .padding(.vertical, 6)
                    days
                        .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Work hours")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var days: some View {
        let cal = Calendar.current
        // Start the row on the locale's first weekday.
        let order = (0..<7).map { (cal.firstWeekday - 1 + $0) % 7 + 1 }
        return HStack(spacing: 6) {
            ForEach(order, id: \.self) { day in
                let on = model.workHours.days.contains(day)
                Button {
                    if on { model.workHours.days.remove(day) } else { model.workHours.days.insert(day) }
                } label: {
                    Text(cal.veryShortWeekdaySymbols[day - 1])
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(on ? .white : Brand.ink)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Circle().fill(on ? GumColors.dark : Color.black.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(cal.weekdaySymbols[day - 1])
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private func time(_ key: WritableKeyPath<WorkHours, Int>) -> Binding<Date> {
        Binding {
            let m = model.workHours[keyPath: key]
            return Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
            model.workHours[keyPath: key] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
    }
}
