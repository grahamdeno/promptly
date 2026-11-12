import SwiftUI
import UIKit

/// Home: the next meeting and how long until it. The gum bubble inflates underneath; tap it to pop it and join.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var showCalendars = ScreenshotMode.scene == .settings || ScreenshotMode.scene == .pro

    @Environment(\.horizontalSizeClass) private var sizeClass
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 32
    @ScaledMetric(relativeTo: .largeTitle) private var countSize: CGFloat = 60
    @ScaledMetric(relativeTo: .title2) private var unitSize: CGFloat = 22

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let upcoming = model.upcoming(at: now)
            let next = model.calendarAuthorized && model.alarmsAuthorized ? upcoming.first : nil
            let progress = next.map { Countdown.progress(now: now, start: $0.start) } ?? 0
            let overdue = next.map { model.sinceRing($0, now: now) } ?? 0

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
                        bubble(next: next, progress: progress, overdue: overdue, maxSize: 760)
                            .frame(maxWidth: .infinity)
                            .ignoresSafeArea()
                    }
                }
            } else {
                ZStack {
                    Color.white.ignoresSafeArea()
                    bubble(next: next, progress: progress, overdue: overdue, maxSize: 880)
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
        .hapticRamp(until: model.upcoming(at: .now).first?.start, enabled: model.buzz && model.arrived == nil)
        .overlay(alignment: .bottom) { undoToast }
        .sheet(isPresented: $showCalendars) {
            SettingsView()
                .environment(model)
                .onAppear { model.settingsOpen = true }
                .onDisappear { model.settingsOpen = false }
        }
    }

    private func bubble(next: Meeting?, progress: Double, overdue: TimeInterval, maxSize: CGFloat) -> some View {
        BubbleView(
            progress: progress,
            overdue: overdue,
            style: model.ballStyle,
            popCount: model.popCount,
            accessibilityTitle: next.map { ($0.joinURL == nil ? "Pop the bubble to clear " : "Pop the bubble to join ") + $0.title } ?? "",
            maxSize: maxSize,
            onPop: next.map { meeting -> () -> Void in
                { if let url = model.join(meeting), !ScreenshotMode.isOn { openURL(url) } }
            }
        )
    }

    /// The text sits on a glass pane so it stays readable when the bubble rises behind it.
    private func textColumn(now: Date, upcoming: [Meeting], next: Meeting?, showThen: Bool) -> some View {
        Group {
            if !model.calendarAuthorized || !model.alarmsAuthorized {
                permissionNotice.glassCard()
            } else if let next {
                meetingBlock(next, now: now, then: showThen ? upcoming.dropFirst().first : nil)
            } else {
                emptyBlock.glassCard()
            }
        }
        .padding(.horizontal, -12)
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
                        .lineLimit(1)
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
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Brand.ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, 8)
    }

    /// One card holds the meeting and its countdown; what comes after is a quiet line below it.
    private func meetingBlock(_ meeting: Meeting, now: Date, then: Meeting?) -> some View {
        let parts = Countdown.parts(now: now, start: meeting.start)
        let started = meeting.start <= now
        let label = [started ? "Happening now" : "Next", meeting.service?.rawValue].compactMap { $0 }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Brand.secondary)
                        .padding(.bottom, 12)
                    Text(meeting.title)
                        .font(.system(size: titleSize, weight: .semibold))
                        .tracking(-0.8)
                        .foregroundStyle(Brand.ink)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(parts.big)
                            .font(.system(size: countSize, weight: .medium))
                            .tracking(-2.5)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        if !parts.unit.isEmpty {
                            Text(parts.unit)
                                .font(.system(size: unitSize, weight: .medium))
                                .foregroundStyle(Brand.secondary)
                        }
                    }
                    .foregroundStyle(Brand.ink)
                    .padding(.top, 28)
                    Text(Countdown.span(meeting, now: now))
                        .font(.callout)
                        .foregroundStyle(Brand.secondary)
                        .padding(.top, 6)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAction(named: meeting.joinURL == nil ? "Clear" : "Join") {
                    if let url = model.join(meeting) { openURL(url) }
                }
                .accessibilityAction(named: "Not going") { model.clear(meeting) }
                if !model.taughtPop {
                    Text("Tap the bubble to pop it and join.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Brand.ink)
                        .transition(.opacity)
                }
                Button("Not going") { model.clear(meeting) }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Brand.secondary)
                    .underline()
                    .frame(minHeight: 44)
            }
            .padding(.vertical, 8)
            .glassCard()

            if let then {
                Text("Then \(Countdown.time(then.start, now: now)), \(then.title)")
                    .font(.subheadline)
                    .foregroundStyle(Brand.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, 20)
            }
        }
    }

    private var emptyBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nothing coming up")
                .font(.system(size: titleSize, weight: .semibold))
                .tracking(-0.8)
                .foregroundStyle(Brand.ink)
            Text("Your next two days are clear on the calendars Pop In watches.")
                .font(.callout)
                .foregroundStyle(Brand.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try a pop") { model.startDemo() }
                .buttonStyle(SecondaryButtonStyle(height: 44))
        }
    }

    /// Five seconds to take back a pop or a "Not going".
    @ViewBuilder
    private var undoToast: some View {
        if let last = model.lastCleared {
            HStack(spacing: 12) {
                Text("Cleared \(last.title)")
                    .font(.subheadline)
                    .foregroundStyle(Brand.ink)
                    .lineLimit(1)
                Button("Undo") { model.undoClear() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Brand.ink)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 18)
            .glassEffect(.regular, in: .capsule)
            .padding(.bottom, 28)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: last.id) {
                try? await Task.sleep(for: .seconds(5))
                if model.lastCleared?.id == last.id { model.lastCleared = nil }
            }
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

    private func subtitle(_ meeting: Meeting, now: Date) -> String {
        [Countdown.span(meeting, now: now), meeting.service?.rawValue].compactMap { $0 }.joined(separator: " · ")
    }
}
