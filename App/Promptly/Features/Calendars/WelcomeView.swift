import SwiftUI

/// First run: one screen per permission, each saying why before iOS asks, then the calendar choices, then
/// "You're covered" with the next meeting (or a demo pop when nothing is coming up).
struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @State private var step: Step = .hello
    @State private var asking = false
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 34
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 16

    enum Step { case hello, calendars, alarms, choose, covered }

    var body: some View {
        switch step {
        case .choose:
            CalendarsView(onDone: { step = .covered })
        default:
            ZStack {
                Color.white.ignoresSafeArea()
                BubbleView(progress: bubbleProgress, style: .bubble, popCount: 0).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Wordmark().padding(.top, 8)
                    Spacer()
                    VStack(alignment: .leading, spacing: 12) {
                        Text(title)
                            .font(.system(size: titleSize, weight: .semibold))
                            .tracking(-0.9)
                            .foregroundStyle(Brand.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(message)
                            .font(.system(size: bodySize))
                            .foregroundStyle(Brand.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .glassCard()
                    Spacer()
                    VStack(spacing: 10) {
                        Button(asking ? "One moment…" : buttonTitle) { advance() }
                            .buttonStyle(PrimaryButtonStyle(height: 56))
                            .disabled(asking)
                        if step == .covered && model.upcoming(at: .now).isEmpty {
                            Button("Try a pop") {
                                model.finishOnboarding()
                                model.startDemo()
                            }
                            .buttonStyle(SecondaryButtonStyle(height: 48, fill: true))
                        }
                    }
                    .padding(14)
                    .glassEffect(.regular, in: .rect(cornerRadius: 28))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private var bubbleProgress: Double {
        switch step {
        case .hello: 0.2
        case .calendars: 0.4
        case .alarms: 0.6
        default: 0.8
        }
    }

    private var title: String {
        switch step {
        case .hello: "Never miss the start of a meeting."
        case .calendars: "First, your calendars"
        case .alarms: "Then, permission to ring"
        default: model.upcoming(at: .now).first.map { _ in "You're covered" } ?? "You're all set"
        }
    }

    private var message: String {
        switch step {
        case .hello:
            return "Pop In watches your calendar and rings before each meeting. Pop the bubble to join the call."
        case .calendars:
            return "Pop In reads the calendars on this device, including Google and Outlook accounts added in Settings. It never changes them, and nothing leaves this device."
        case .alarms:
            return "For meetings with a video link, Pop In rings like an alarm, even in Silent and Focus, with Join on the alert. Other events get a quiet notification. You can change this per calendar."
        default:
            if let next = model.upcoming(at: .now).first {
                return "Next up: \(next.title), \(Countdown.time(next.start)). Pop In will ring \(model.leadMinutes) min before."
            }
            return "Nothing in the next two days. Want to see what a meeting feels like?"
        }
    }

    private var buttonTitle: String {
        switch step {
        case .hello: "Get started"
        case .calendars: "Allow calendar access"
        case .alarms: "Allow alarms"
        default: "Done"
        }
    }

    private func advance() {
        switch step {
        case .hello:
            step = .calendars
        case .calendars:
            asking = true
            Task {
                await model.requestCalendarAccess()
                asking = false
                step = .alarms
            }
        case .alarms:
            asking = true
            Task {
                await model.requestAlarmAccess()
                asking = false
                step = .choose
            }
        case .choose:
            step = .covered
        case .covered:
            model.finishOnboarding()
        }
    }
}
