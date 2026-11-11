import SwiftUI

/// First run: one sentence, one button that asks for calendar and alarm access, then the calendar list.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @State private var asked = false
    @State private var asking = false

    var body: some View {
        if asked {
            CalendarsView(firstRun: true)
        } else {
            ZStack {
                Color.white.ignoresSafeArea()
                BubbleView(progress: 0.35, style: .bubble, popCount: 0).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 14) {
                    Wordmark().padding(.top, 8)
                    Spacer()
                    Text("Never miss the start of a meeting.")
                        .font(Brand.display(36))
                        .tracking(-0.9)
                        .foregroundStyle(Brand.ink)
                    Text("Promptly reads your calendars and rings like an alarm a minute before each meeting, with Join right on the alert. Nothing leaves this iPhone.")
                        .font(.system(size: 16))
                        .foregroundStyle(Brand.secondary)
                    Spacer()
                    Button(asking ? "Asking…" : "Allow calendars and alarms") {
                        asking = true
                        Task {
                            await model.requestPermissions()
                            asking = false
                            asked = true
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(height: 56))
                    .disabled(asking)
                    .padding(14)
                    .glassEffect(.regular, in: .rect(cornerRadius: 28))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
    }
}
