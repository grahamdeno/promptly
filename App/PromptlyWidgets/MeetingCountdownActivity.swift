import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

@main
struct PromptlyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MeetingCountdownActivity()
        NextMeetingWidget()
    }
}

/// The card AlarmKit shows on the Lock Screen and in the Dynamic Island while a meeting's countdown runs.
/// Apple draws and updates it, so the bubble stays still and a coral ring fills around it instead.
/// Tapping it opens Promptly's Now screen, where the bubble can be popped.
struct MeetingCountdownActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<MeetingAlarmMetadata>.self) { context in
            LockScreenCard(state: context.state, meta: context.attributes.metadata)
                .activityBackgroundTint(Color.white.opacity(0.92))
                .activitySystemActionForegroundColor(GumColors.coral)
                .widgetURL(context.attributes.metadata?.openURL)
        } dynamicIsland: { context in
            let meta = context.attributes.metadata
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RingedBall(state: context.state, meta: meta)
                        .frame(width: 44, height: 44)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownLabel(state: context.state)
                        .font(.system(size: 28, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meta?.title ?? "Meeting")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(subtitle(meta) + "  ·  Tap to pop it")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                GumBall().frame(width: 18, height: 18)
            } compactTrailing: {
                CountdownLabel(state: context.state)
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(maxWidth: 52)
            } minimal: {
                GumBall().frame(width: 16, height: 16)
            }
            .widgetURL(meta?.openURL)
            .keylineTint(GumColors.coral)
        }
    }
}

private struct LockScreenCard: View {
    let state: AlarmPresentationState
    let meta: MeetingAlarmMetadata?

    var body: some View {
        HStack(spacing: 14) {
            RingedBall(state: state, meta: meta)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(meta?.title ?? "Meeting")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(white: 0.08))
                    .lineLimit(1)
                Text(subtitle(meta))
                    .font(.system(size: 14))
                    .foregroundStyle(Color(white: 0.42))
                    .lineLimit(1)
                Text("Tap to pop it")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(GumColors.dark)
            }
            Spacer(minLength: 8)
            CountdownLabel(state: state)
                .font(.system(size: 32, weight: .medium).monospacedDigit())
                .foregroundStyle(Color(white: 0.08))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110, alignment: .trailing)
        }
        .padding(16)
    }
}

/// The still gum ball with a coral ring that fills as the countdown runs.
private struct RingedBall: View {
    let state: AlarmPresentationState
    let meta: MeetingAlarmMetadata?

    var body: some View {
        ZStack {
            if case .countdown(let countdown) = state.mode,
               let seconds = meta?.countdownSeconds, seconds > 0 {
                let start = countdown.fireDate.addingTimeInterval(-seconds)
                ProgressView(timerInterval: start...countdown.fireDate, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)
                .tint(GumColors.coral)
            }
            GumBall().padding(7)
        }
    }
}

private struct CountdownLabel: View {
    let state: AlarmPresentationState

    var body: some View {
        switch state.mode {
        case .countdown(let countdown):
            Text(timerInterval: Date.now...countdown.fireDate, countsDown: true)
        case .alert:
            Text("Now")
        default:
            Text("Soon")
        }
    }
}

private func subtitle(_ meta: MeetingAlarmMetadata?) -> String {
    guard let meta else { return "" }
    let f = DateFormatter()
    f.timeStyle = .short
    f.dateStyle = .none
    return [f.string(from: meta.start), meta.service.isEmpty ? nil : meta.service].compactMap { $0 }.joined(separator: " · ")
}
