import SwiftUI
import UIKit

/// Home: the next meeting and how long until it. The gum bubble inflates underneath; tap it to pop it and join.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var addingReminder = false
    @State private var playing = false
    @State private var showGallery = false
    @State private var showCalendars = ScreenshotMode.scene.map { [ScreenshotScene.settings, .pro, .manycals].contains($0) } ?? false

    @Environment(\.horizontalSizeClass) private var sizeClass
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 32
    @ScaledMetric(relativeTo: .largeTitle) private var countSize: CGFloat = 60
    @ScaledMetric(relativeTo: .title2) private var unitSize: CGFloat = 22

    @State private var lastTouch = Date()
    @Environment(\.scenePhase) private var scenePhase
    @State private var quiet = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let upcoming = model.upcoming(at: now)
            let next = model.calendarAuthorized && model.alarmsAuthorized ? upcoming.first : nil
            let progress = next.map { Countdown.progress(now: now, start: $0.start) } ?? 0
            let overdue = next.map { model.sinceRing($0, now: now) } ?? 0
            let quietNow = QuietMode.isQuiet(now: now, lastTouch: lastTouch, nextStart: next?.start)

            Group {
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
            .onChange(of: quietNow, initial: true) { _, q in quiet = q }
        }
        .environment(\.themeStill, quiet || PowerWatch.shared.strained)
        // Coming back to Pop In counts as a touch, so it never opens already in quiet mode.
        .onChange(of: scenePhase) { _, p in if p == .active { lastTouch = .now; quiet = false } }
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in
            lastTouch = .now
            quiet = false
        })
        .hapticRamp(until: model.upcoming(at: .now).first?.start, enabled: model.buzz && model.arrived == nil)
        .overlay { DiscoLights().ignoresSafeArea().environment(\.themeStill, quiet || PowerWatch.shared.strained) }
        .overlay(alignment: .bottom) { undoToast }
        .sheet(isPresented: $showGallery) {
            NavigationStack { ThemeGalleryPage() }
                .environment(model)
                .sheet(isPresented: Binding(get: { model.showPro }, set: { model.showPro = $0 })) {
                    ProView().environment(model)
                }
        }
        .fullScreenCover(isPresented: $playing) { PopPlayground() }
        .onAppear { if ScreenshotMode.scene == .playground { playing = true } }
        .sheet(isPresented: $addingReminder) {
            AddReminderSheet().environment(model)
        }
        .sheet(isPresented: $showCalendars) {
            SettingsView()
                .environment(model)
                .onAppear { model.settingsOpen = true }
                .onDisappear { model.settingsOpen = false }
        }
    }

    /// The Fortune ball's words: in the last fifteen minutes before a real meeting, and always on the Practice demo.
    private func fortune(for next: Meeting?, now: Date) -> String? {
        guard model.gumColor == .fortune, model.fortunes, let next else { return nil }
        guard isDemo(next) || Fortunes.shows(start: next.start, now: now) else { return nil }
        return Fortunes.fortune(for: next.id)
    }

    private func bubble(next: Meeting?, progress: Double, overdue: TimeInterval, maxSize: CGFloat) -> some View {
        let words = fortune(for: next, now: .now)
        return BubbleView(
            progress: progress,
            overdue: overdue,
            style: model.ballStyle,
            popCount: model.popCount,
            skipCount: model.skipCount,
            accessibilityTitle: next.map { ($0.joinURL == nil ? "Pop the bubble to clear " : "Pop the bubble to join ") + $0.title
                + (words.map { ". Fortune: " + $0 } ?? "") } ?? "",
            maxSize: maxSize,
            onPop: next.map { meeting -> () -> Void in
                { if let url = model.join(meeting), !ScreenshotMode.isOn { openURL(url) } }
            }
        )
        .environment(\.fortuneText, words)
    }

    /// The text sits on a glass pane so it stays readable when the bubble rises behind it.
    private func textColumn(now: Date, upcoming: [Meeting], next: Meeting?, showThen: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Group {
                if !model.calendarAuthorized || !model.alarmsAuthorized {
                    permissionNotice.glassCard()
                } else if let next {
                    meetingBlock(next, now: now, then: showThen ? upcoming.dropFirst().first : nil)
                } else {
                    emptyBlock.glassCard()
                }
            }
            whatsNewCard
        }
        .padding(.horizontal, -12)
    }

    /// At most once a month: the themes that just arrived. Opening it or waving it away both count as seen.
    @ViewBuilder
    private var whatsNewCard: some View {
        let _ = model.whatsNewTick
        let fresh = model.whatsNew
        if !fresh.isEmpty {
            HStack(spacing: 12) {
                HStack(spacing: -10) {
                    ForEach(fresh.prefix(3), id: \.self) { SwatchBall(palette: $0).frame(width: 30, height: 30) }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("New this month").font(.footnote.weight(.medium)).foregroundStyle(Brand.secondary)
                    Text(fresh.map(\.label).formatted(.list(type: .and)))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink).lineLimit(2)
                    Text(model.store.isPro ? "Included with Pro" : "Try one free for a day")
                        .font(.footnote).foregroundStyle(Brand.accentText)
                }
                Spacer(minLength: 4)
                Button { model.whatsNewDismissed(fresh) } label: {
                    Image(systemName: "xmark").font(.footnote.weight(.semibold)).foregroundStyle(Brand.secondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Dismiss")
            }
            .padding(.leading, 16)
            .contentShape(Rectangle())
            .onTapGesture { model.whatsNewOpened(fresh); showGallery = true }
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
        }
    }

    private func todayList(_ items: [Meeting]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !items.isEmpty {
                Text("Later")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Brand.secondary)
                    .padding(.top, 40)
            }
            ForEach(items) { item in
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(Countdown.time(item.start))
                        .lineLimit(1)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Brand.accentText)
                        .fixedSize()
                        .frame(minWidth: 72, alignment: .leading)
                    Text(item.title)
                        .font(.body)
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
            Menu {
                Button("Add a reminder", systemImage: "plus") { addingReminder = true }
                Button("Pop for fun", systemImage: "circle.hexagongrid") { playing = true }
                if let until = model.pausedUntil, until > .now {
                    Button("Resume alerts", systemImage: "bell") { model.resume() }
                } else {
                    Menu("Pause alerts", systemImage: "pause") {
                        Button("For 1 hour") { model.pause(until: .now.addingTimeInterval(3600)) }
                        Button("For 2 hours") { model.pause(until: .now.addingTimeInterval(7200)) }
                        Button("For the rest of today") { model.pause(until: PauseRule.endOfDay(from: .now)) }
                    }
                }
                Divider()
                Button("Settings", systemImage: "gearshape") { showCalendars = true }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundStyle(Brand.ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("More: add a reminder, pop for fun, pause alerts, settings")
        }
        .padding(.top, 8)
        .overlay(alignment: .bottomLeading) {
            if let until = model.pausedUntil, until > .now {
                Button { model.resume() } label: {
                    Label("Paused until \(until.formatted(date: .omitted, time: .shortened)) · Resume", systemImage: "pause.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Brand.accentText)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular, in: .capsule)
                .offset(y: 42)
            }
        }
    }

    /// One card holds the meeting and its countdown; what comes after is a quiet line below it.
    private func meetingBlock(_ meeting: Meeting, now: Date, then: Meeting?) -> some View {
        let parts = Countdown.parts(now: now, start: meeting.start)
        let started = meeting.start <= now
        let nextWord = model.gumColor == .moon ? "Next transmission" : "Next"
        let label = isDemo(meeting) ? "Practice" : meeting.calendarID == OwnReminder.calendarID ? "Reminder" : [started ? "Happening now" : nextWord, meeting.service?.rawValue].compactMap { $0 }.joined(separator: " · ")
        // How Pop In will alert, so a quiet one is never a surprise.
        let paused = model.isPaused(meeting, now: now)
        let rings = model.ringsFully(meeting) && !paused
        let how: String = paused ? "Paused until \(model.pausedUntil.map { $0.formatted(date: .omitted, time: .shortened) } ?? "later")"
            : rings ? (model.earlyMinutes > model.leadMinutes ? "Rings \(model.earlyMinutes) and \(model.leadMinutes) min before" : "Rings \(model.leadMinutes) min before")
            : model.workHours.contains(meeting.start) ? "Quiet notification only" : "Outside work hours, quiet notification"
        return VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Brand.secondary)
                        .padding(.bottom, 4)
                    if !isDemo(meeting) && !started {
                        Label(how, systemImage: rings ? "bell.fill" : "bell.slash")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(rings ? Brand.accentText : Brand.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 10)
                    }
                    Text(meeting.title)
                        .font(.system(size: titleSize, weight: .semibold))
                        .tracking(-0.8)
                        .foregroundStyle(Brand.ink)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                    if !isDemo(meeting) {
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
                    }
                    Text(isDemo(meeting) ? "Practice: pop the bubble below." : Countdown.span(meeting, now: now))
                        .font(.callout)
                        .foregroundStyle(Brand.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, isDemo(meeting) ? 20 : 6)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAction(named: meeting.joinURL == nil ? "Clear" : "Join") {
                    if let url = model.join(meeting) { openURL(url) }
                }
                .accessibilityAction(named: "Not going") { model.clear(meeting) }
                if model.taughtPop, !isDemo(meeting), meeting.joinURL != nil,
                   meeting.start.timeIntervalSince(now) < 10 * 60 {
                    Label("Pop the bubble to join", systemImage: "hand.tap")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Brand.accentText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !model.taughtPop {
                    Text("Tap the bubble to pop it and join.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Brand.ink)
                        .transition(.opacity)
                }
                Button { model.clear(meeting) } label: {
                    Text(isDemo(meeting) ? "Skip" : "Not going")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Brand.secondary)
                        .underline()
                        .padding(.vertical, 12)
                        .padding(.trailing, 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, -8)
            }
            .padding(.vertical, 8)
            .glassCard()

            if let then {
                Text("Then \(Countdown.time(then.start, now: now)), \(then.title)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Brand.ink.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    // A glass pill, so the line reads over any bubble, including Fortune's black glass.
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.horizontal, -14)
                    .padding(.horizontal, 20)
            }
        }
    }

    /// The "Try a pop" practice meeting: no countdown to wait for, just pop it.
    private func isDemo(_ meeting: Meeting) -> Bool { meeting.eventID == "demo" }

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
                .font(.callout)
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
