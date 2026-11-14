import SwiftUI

/// First run: one screen per permission, each saying why before iOS asks (the alarm screen also shows how the
/// alarm looks locked and unlocked, so nobody expects a takeover mid-app), then the calendar choices, then
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
                            if step == .alarms { AlarmLooksPreview().padding(.top, 6) }
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
            return "Meetings with a video link ring like an alarm, even in Silent and Focus. Other events get a quiet notification. iPhone decides how the alarm looks:"
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

/// Sketches of Apple's alarm in its two looks: full screen when locked, a banner when the phone is in use.
/// AlarmKit decides this, not Pop In, so showing both up front keeps the first unlocked alarm from feeling broken.
struct AlarmLooksPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            look("Phone locked", "Full screen. Tap Open to join.") { LockedAlarmPreview() }
            look("Using your phone", "A banner at the top. Tap it for the bubble.") { UnlockedBannerPreview() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("When your phone is locked, the alarm fills the screen with Open and Stop. When you're using your phone, it shows as a banner at the top; tap it for the bubble.")
    }

    private func look<Content: View>(_ label: String, _ caption: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.footnote.weight(.semibold)).foregroundStyle(Brand.ink)
            content()
            Text(caption).font(.footnote).foregroundStyle(Brand.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A sketch of the AlarmKit banner over another app: a dark pill at the top with the meeting and two round buttons.
struct UnlockedBannerPreview: View {
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                GumBall().frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Design review").font(.caption.weight(.semibold)).foregroundStyle(.white)
                    Text("Pop In").font(.caption2).foregroundStyle(.white.opacity(0.7))
                }
                Spacer(minLength: 4)
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 32, height: 32).background(Circle().fill(.white.opacity(0.2)))
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 32, height: 32).background(Circle().fill(Brand.coralDark))
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Capsule().fill(Color(white: 0.12)))
            // Faint lines stand in for whatever app is open underneath.
            VStack(alignment: .leading, spacing: 7) {
                ForEach([0.9, 0.7, 0.8], id: \.self) { w in
                    GeometryReader { g in
                        Capsule().fill(Color.black.opacity(0.07)).frame(width: g.size.width * w, height: 8)
                    }
                    .frame(height: 8)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.black.opacity(0.04)))
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
