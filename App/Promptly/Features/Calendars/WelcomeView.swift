import SwiftUI

/// First run: one screen per permission, each saying why before iOS asks, then the calendar choices, then
/// "You're covered" with the next meeting (or a demo pop when nothing is coming up).
struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @State private var step: Step = .hello
    @State private var asking = false
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 34
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 16

    enum Step { case hello, calendars, alarms, locked, choose, covered }

    var body: some View {
        switch step {
        case .choose:
            CalendarsView(onDone: { step = .covered })
        default:
            ZStack {
                Color.white.ignoresSafeArea()
                BubbleView(progress: bubbleProgress, style: .bubble, popCount: 0).ignoresSafeArea()
                // The words scroll if they're large (big text sizes); the button always stays on screen.
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Wordmark().padding(.top, 8)
                        Spacer(minLength: 24)
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
                            if step == .locked { LockedAlarmPreview().padding(.top, 6) }
                        }
                        .glassCard()
                        Spacer(minLength: 24)
                    }
                    .frame(minHeight: 520)
                    .padding(.horizontal, 24)
                }
                .scrollBounceBehavior(.basedOnSize)
                .safeAreaInset(edge: .bottom) {
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
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private var bubbleProgress: Double {
        switch step {
        case .hello: 0.2
        case .calendars: 0.4
        case .alarms: 0.6
        case .locked: 0.7
        default: 0.8
        }
    }

    private var title: String {
        switch step {
        case .hello: "Never miss the start of a meeting."
        case .calendars: "First, your calendars"
        case .alarms: "Then, permission to ring"
        case .locked: "When your phone is locked"
        default: model.upcoming(at: .now).first.map { _ in "You're covered" } ?? "You're all set"
        }
    }

    private var message: String {
        switch step {
        case .hello:
            return "Pop In watches your calendar and rings before each meeting. Pop the bubble to join the call."
        case .calendars:
            return "Pop In reads the calendars on this device, including Google and Outlook accounts added in Settings. It never changes them, and nothing leaves this device."
        case .locked:
            return "iPhone shows its own alarm, like this. Tap Open to join the call. Open Pop In any time to see the bubble."
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
        case .locked: "Got it"
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
                step = .locked
            }
        case .locked:
            step = .choose
        case .choose:
            step = .covered
        case .covered:
            model.finishOnboarding()
        }
    }
}

/// A sketch of Apple's alarm as it appears on the Lock Screen, so the first real one isn't a surprise.
struct LockedAlarmPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                GumBall().frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Design review · in 1 min").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text("Pop In").font(.caption).foregroundStyle(.white.opacity(0.7))
                }
            }
            HStack(spacing: 10) {
                Text("Open")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Capsule().fill(Brand.coralDark))
                Text("Stop")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Capsule().fill(.white.opacity(0.2)))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color(white: 0.12)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example: the locked alarm shows the meeting, an Open button and a Stop button.")
    }
}
