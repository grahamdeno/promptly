import SwiftUI

/// The meeting that just rang, full screen: the bubble has risen. Pop it to join, or say you're not going.
struct NowView: View {
    let meeting: Meeting
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var pops = 0
    @State private var skips = 0
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 40

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            ZStack {
                Color.white.ignoresSafeArea()

                BubbleView(
                    progress: 1,
                    overdue: model.sinceRing(meeting, now: now),
                    style: model.ballStyle,
                    popCount: pops,
                    skipCount: skips,
                    hint: meeting.joinURL == nil ? "Pop when ready" : "Pop to join",
                    accessibilityTitle: (meeting.joinURL == nil ? "Pop the bubble to clear " : "Pop the bubble to join ") + meeting.title,
                    minSize: 920, maxSize: 920, steadySize: 560,
                    onPop: {
                        let url = model.join(meeting)
                        leave { if let url { openURL(url) } }
                    }
                )
                .environment(\.themeStill, PowerWatch.shared.strained)
                .environment(\.fortuneText, model.gumColor == .fortune && model.fortunes ? Fortunes.fortune(for: meeting.id) : nil)
                .ignoresSafeArea()

                DiscoLights().ignoresSafeArea()
                    .environment(\.themeStill, PowerWatch.shared.strained)

                VStack(alignment: .leading, spacing: 14) {
                    Text(status(now))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Brand.secondary)
                    Text(meeting.title)
                        .font(.system(size: titleSize, weight: .semibold))
                        .tracking(-1)
                        .foregroundStyle(Brand.ink)
                        .lineLimit(4)
                    Text([Countdown.span(meeting), meeting.service?.rawValue].compactMap { $0 }.joined(separator: " · "))
                        .font(.callout)
                        .foregroundStyle(Brand.secondary)
                }
                .glassCard()
                .frame(maxWidth: 680, alignment: .leading)
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 10) {
                        pill("Not going") {
                            skips += 1
                            model.clear(meeting)
                            leave {}
                        }
                        pill("In 2 min", icon: "zzz") {
                            model.snooze(meeting)
                            dismiss()
                        }
                        .accessibilityLabel("Snooze two minutes")
                    }
                    .offset(y: 60)
                }
                .padding(.horizontal, 12)
                .padding(.top, 60)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .hapticRamp(until: meeting.start, enabled: model.buzz)
        .onDisappear { AlarmLoop.stop() }
    }

    private func pill(_ text: String, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.footnote.weight(.semibold)) }
                Text(text).font(.subheadline.weight(.medium))
            }
            .foregroundStyle(Brand.ink)
            .padding(.horizontal, 20)
            .frame(minHeight: 48)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .capsule)
    }

    /// Let the pop play, then leave.
    private func leave(_ then: @escaping () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1000))
            dismiss()
            then()
        }
    }

    private func status(_ now: Date) -> String {
        let seconds = meeting.start.timeIntervalSince(now)
        if seconds <= 0 { return "Starting now" }
        let minutes = Int((seconds / 60).rounded(.up))
        return minutes <= 1 ? "Starts in 1 min" : "Starts in \(minutes) min"
    }
}
