import SwiftUI
import UIKit

/// Home: the next meeting and how long until it. The gum bubble inflates underneath; tap it to pop it and join.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var showCalendars = false

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let upcoming = model.upcoming(at: now)
            let next = model.calendarAuthorized && model.alarmsAuthorized ? upcoming.first : nil
            let progress = next.map { Countdown.progress(now: now, start: $0.start) } ?? 0

            if sizeClass == .regular {
                // iPad: the meeting and the rest of today on the left, the bubble on the right.
                ZStack {
                    Color.white.ignoresSafeArea()
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            header
                            Spacer(minLength: 24).frame(maxHeight: 96)
                            textColumn(now: now, upcoming: upcoming, next: next, showThen: false)
                            if next != nil { todayList(Array(upcoming.dropFirst().prefix(5))) }
                            Spacer()
                        }
                        .frame(maxWidth: 480, alignment: .leading)
                        .padding(.horizontal, 48)
                        bubble(next: next, progress: progress, maxSize: 760)
                            .frame(maxWidth: .infinity)
                            .ignoresSafeArea()
                    }
                }
            } else {
                ZStack {
                    Color.white.ignoresSafeArea()
                    bubble(next: next, progress: progress, maxSize: 880)
                        .ignoresSafeArea()
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        Spacer(minLength: 24).frame(maxHeight: 64)
                        textColumn(now: now, upcoming: upcoming, next: next, showThen: true)
                        Spacer()
                    }
                    .padding(.horizontal, 28)
                }
            }
        }
        .hapticRamp(until: model.upcoming(at: .now).first?.start, enabled: model.buzz)
        .sheet(isPresented: $showCalendars) {
            CalendarsView(firstRun: false)
                .environment(model)
        }
    }

    private func bubble(next: Meeting?, progress: Double, maxSize: CGFloat) -> some View {
        BubbleView(
            progress: progress,
            style: model.ballStyle,
            popCount: model.popCount,
            accessibilityTitle: next.map { ($0.joinURL == nil ? "Pop the bubble to clear " : "Pop the bubble to join ") + $0.title } ?? "",
            maxSize: maxSize,
            onPop: next.map { meeting -> () -> Void in
                { if let url = model.join(meeting) { openURL(url) } }
            }
        )
    }

    @ViewBuilder
    private func textColumn(now: Date, upcoming: [Meeting], next: Meeting?, showThen: Bool) -> some View {
        if !model.calendarAuthorized || !model.alarmsAuthorized {
            permissionNotice
        } else if let next {
            meetingBlock(next, now: now, then: showThen ? upcoming.dropFirst().first : nil)
        } else {
            emptyBlock
        }
    }

    private func todayList(_ items: [Meeting]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !items.isEmpty {
                Text("Later")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Brand.secondary)
                    .padding(.top, 40)
            }
            ForEach(items) { item in
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(Countdown.time(item.start))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Brand.coralDark)
                        .frame(width: 72, alignment: .leading)
                    Text(item.title)
                        .font(.system(size: 17))
                        .foregroundStyle(Brand.ink)
                        .lineLimit(1)
                }
            }
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

    private func meetingBlock(_ meeting: Meeting, now: Date, then: Meeting?) -> some View {
        let parts = Countdown.parts(now: now, start: meeting.start)
        let started = meeting.start <= now
        return VStack(alignment: .leading, spacing: 8) {
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
                    .font(.system(size: 64, weight: .medium))
                    .tracking(-2.5)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if !parts.unit.isEmpty {
                    Text(parts.unit)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Brand.secondary)
                }
            }
            .foregroundStyle(Brand.ink)
            .padding(.top, 14)
            .accessibilityElement(children: .combine)

            if !model.taughtPop {
                Text("Tap the bubble to pop it and join.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Brand.ink)
                    .padding(.top, 10)
                    .transition(.opacity)
            }

            HStack(spacing: 4) {
                Button("Not going") { model.clear(meeting) }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Brand.secondary)
                    .underline()
                    .frame(minHeight: 44)
                if let then {
                    Text("·  Then \(Countdown.time(then.start)) \(then.title)")
                        .font(.system(size: 15))
                        .foregroundStyle(Brand.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.top, 6)
        }
    }

    private var emptyBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nothing coming up")
                .font(Brand.display(34))
                .tracking(-0.8)
                .foregroundStyle(Brand.ink)
            Text("Your next two days are clear on the calendars Pop In watches.")
                .font(.system(size: 16))
                .foregroundStyle(Brand.secondary)
        }
    }

    private var permissionNotice: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.calendarAuthorized ? "Alarms are off" : "Pop In can't see your calendar")
                .font(Brand.display(30))
                .tracking(-0.6)
                .foregroundStyle(Brand.ink)
            Text(model.calendarAuthorized
                 ? "Turn on Alarms for Pop In in Settings so it can ring before your meetings."
                 : "Allow Full Access to Calendars for Pop In in Settings. It only reads, and nothing leaves this iPhone.")
                .font(.system(size: 16))
                .foregroundStyle(Brand.secondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private func subtitle(_ meeting: Meeting) -> String {
        [Countdown.span(meeting), meeting.service?.rawValue].compactMap { $0 }.joined(separator: " · ")
    }
}
