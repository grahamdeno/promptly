import SwiftUI

/// The meeting that just rang, full screen: the bubble has risen, one decision to make.
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

                BubbleView(progress: 1, style: model.ballStyle, popCount: pops,
                           minSize: 760, maxSize: 760, steadySize: 520)
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
                    Spacer()
                    pane
                }
                .padding(.horizontal, 28)
                .padding(.top, 72)
                .padding(.bottom, 40)
            }
        }
    }

    private var pane: some View {
        VStack(spacing: 10) {
            if meeting.joinURL != nil {
                Button {
                    let url = model.join(meeting)
                    finish { if let url { openURL(url) } }
                } label: {
                    Label(meeting.service.map { "Join \($0.rawValue)" } ?? "Join", systemImage: "video.fill")
                }
                .buttonStyle(PrimaryButtonStyle(height: 56))
            }
            Button(meeting.joinURL == nil ? "Got it" : "Not going") {
                model.clear(meeting)
                finish {}
            }
            .buttonStyle(SecondaryButtonStyle(height: 48, fill: true))
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 30))
    }

    /// Pop the bubble, then leave.
    private func finish(_ then: @escaping () -> Void) {
        pops += 1
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(550))
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
