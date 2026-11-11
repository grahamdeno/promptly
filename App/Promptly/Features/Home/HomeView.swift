import SwiftUI
import UIKit

/// Home: the next meeting and how long until it, with the bubble growing underneath.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var showCalendars = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let upcoming = model.upcoming(at: now)
            let next = upcoming.first
            let progress = next.map { Countdown.progress(now: now, start: $0.start) } ?? 0

            ZStack {
                Color.white.ignoresSafeArea()

                BubbleView(progress: progress, style: model.ballStyle, popCount: model.popCount)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    header
                    Spacer(minLength: 24)
                    if !model.calendarAuthorized || !model.alarmsAuthorized {
                        permissionNotice
                    } else if let next {
                        meetingBlock(next, now: now)
                    } else {
                        emptyBlock
                    }
                    Spacer()
                    if let next {
                        actionPane(next, then: upcoming.dropFirst().first)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showCalendars) {
            CalendarsView(firstRun: false)
                .environment(model)
        }
    }

    private var header: some View {
        HStack {
            Wordmark()
            Spacer()
            Button { showCalendars = true } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Brand.ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Calendars and settings")
        }
        .padding(.top, 8)
    }

    private func meetingBlock(_ meeting: Meeting, now: Date) -> some View {
        let parts = Countdown.parts(now: now, start: meeting.start)
        let started = meeting.start <= now
        return VStack(alignment: .leading, spacing: 10) {
            Text(started ? "Happening now" : "Next")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Brand.secondary)
            Text(meeting.title)
                .font(Brand.display(34))
                .tracking(-0.8)
                .foregroundStyle(Brand.ink)
                .lineLimit(3)
            Text(subtitle(meeting))
                .font(.system(size: 16))
                .foregroundStyle(Brand.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(parts.big)
                    .font(.system(size: 76, weight: .medium))
                    .tracking(-3)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if !parts.unit.isEmpty {
                    Text(parts.unit)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Brand.secondary)
                }
            }
            .foregroundStyle(Brand.ink)
            .padding(.top, 18)
            .accessibilityElement(children: .combine)
        }
    }

    private var emptyBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nothing coming up")
                .font(Brand.display(34))
                .tracking(-0.8)
                .foregroundStyle(Brand.ink)
            Text("Your next two days are clear on the calendars Promptly watches.")
                .font(.system(size: 16))
                .foregroundStyle(Brand.secondary)
        }
    }

    private var permissionNotice: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.calendarAuthorized ? "Alarms are off" : "Promptly can't see your calendar")
                .font(Brand.display(30))
                .tracking(-0.6)
                .foregroundStyle(Brand.ink)
            Text(model.calendarAuthorized
                 ? "Turn on Alarms for Promptly in Settings so it can ring before your meetings."
                 : "Allow Full Access to Calendars for Promptly in Settings. It only reads, and nothing leaves this iPhone.")
                .font(.system(size: 16))
                .foregroundStyle(Brand.secondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private func actionPane(_ meeting: Meeting, then: Meeting?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let then {
                HStack(spacing: 6) {
                    Text("Then").foregroundStyle(Brand.secondary)
                    Text("\(Countdown.time(then.start)) \(then.title)")
                        .fontWeight(.medium)
                        .foregroundStyle(Brand.ink)
                        .lineLimit(1)
                }
                .font(.system(size: 15))
                .padding(.horizontal, 6)
            }
            HStack(spacing: 10) {
                if meeting.joinURL != nil {
                    Button(joinTitle(meeting)) {
                        if let url = model.join(meeting) { openURL(url) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                Button("Clear") { model.clear(meeting) }
                    .buttonStyle(SecondaryButtonStyle(fill: meeting.joinURL == nil))
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    private func subtitle(_ meeting: Meeting) -> String {
        [Countdown.span(meeting), meeting.service?.rawValue].compactMap { $0 }.joined(separator: " · ")
    }

    private func joinTitle(_ meeting: Meeting) -> String {
        meeting.service.map { "Join \($0.rawValue)" } ?? "Join"
    }
}
