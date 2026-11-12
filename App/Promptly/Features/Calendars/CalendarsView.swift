import SwiftUI

/// The calendar step of first run: which calendars Pop In watches. Everything else lives in Settings.
struct CalendarsView: View {
    var onDone: () -> Void
    @Environment(AppModel.self) private var model
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 32

    var body: some View {
        ZStack(alignment: .bottom) {
            SettingsPage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Which calendars?")
                        .font(.system(size: titleSize, weight: .semibold))
                        .tracking(-0.8)
                        .foregroundStyle(Brand.ink)
                    Text("Pop In rings for meetings with a video link and sends a quiet notification for the rest. Turn off any calendar you don't want.")
                        .font(.subheadline)
                        .foregroundStyle(Brand.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)
                .padding(.top, 56)
                CalendarsList()
                Color.clear.frame(height: 90)
            }
            Button("Done", action: onDone)
                .buttonStyle(PrimaryButtonStyle(height: 56))
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .task { await model.refresh() }
        .sheet(isPresented: Binding(get: { model.showPro }, set: { model.showPro = $0 })) {
            ProView().environment(model)
        }
    }
}
