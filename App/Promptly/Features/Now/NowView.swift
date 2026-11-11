import SwiftUI

/// The meeting that just rang, full screen: the bubble has risen. Pop it to join, or say you're not going.
struct NowView: View {
    let meeting: Meeting
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var pops = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            ZStack {
                Color.white.ignoresSafeArea()

                BubbleView(
                    progress: 1,
                    overdue: max(0, now.timeIntervalSince(meeting.start)),
                    style: model.ballStyle,
                    popCount: pops,
                    hint: meeting.joinURL == nil ? "Pop when ready" : "Pop to join",
                    accessibilityTitle: (meeting.joinURL == nil ? "Pop the bubble to clear " : "Pop the bubble to join ") + meeting.title,
                    minSize: 920, maxSize: 920, steadySize: 560,
                    onPop: {
                        let url = model.join(meeting)
                        leave { if let url { openURL(url) } }
                    }
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 10) {
                    Text(status(now))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Brand.secondary)
                    Text(meeting.title)
                        .font(Brand.display(40))
                        .tracking(-1)
                        .foregroundStyle(Brand.ink)
                        .lineLimit(4)
                    Text([Countdown.span(meeting), meeting.service?.rawValue].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 16))
                        .foregroundStyle(Brand.secondary)
                    Button("Not going") {
                        pops += 1
                        model.clear(meeting)
                        leave {}
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Brand.secondary)
                    .underline()
                    .frame(minHeight: 44)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .glassEffect(.regular, in: .rect(cornerRadius: 26))
                .padding(.horizontal, 12)
                .padding(.top, 60)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .hapticRamp(until: meeting.start, enabled: model.buzz)
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
