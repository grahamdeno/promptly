import SwiftUI
import WidgetKit

/// Home Screen widget: the next meeting, a live countdown, and the bubble growing in steps over the last hour.
/// Tapping the bubble opens Pop In and pops it there (with the full gum animation), then opens the meeting link.
struct NextMeetingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: NextMeetingKind.kind, provider: NextMeetingProvider()) { entry in
            NextMeetingView(entry: entry)
                .containerBackground(.white, for: .widget)
        }
        .configurationDisplayName("Next meeting")
        .description("The next meeting and its bubble. Tap the bubble to pop it.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct NextMeetingEntry: TimelineEntry {
    let date: Date
    let next: WidgetSnapshot.Item?
    let then: [WidgetSnapshot.Item]
}

struct NextMeetingProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextMeetingEntry {
        NextMeetingEntry(date: .now,
                         next: .init(id: "p", title: "Sprint review", start: .now.addingTimeInterval(720),
                                     end: .now.addingTimeInterval(2520), service: "Teams", hasLink: true),
                         then: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (NextMeetingEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: .now, snapshot: WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextMeetingEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let now = Date.now
        let first = snapshot.upcoming(at: now).first
        let dates = WidgetTimeline.entryDates(now: now, start: first?.start, end: first?.end)
        let entries = dates.map { entry(at: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date, snapshot: WidgetSnapshot) -> NextMeetingEntry {
        let upcoming = snapshot.upcoming(at: date)
        return NextMeetingEntry(date: date, next: upcoming.first, then: Array(upcoming.dropFirst().prefix(4)))
    }
}

struct NextMeetingView: View {
    let entry: NextMeetingEntry
    @Environment(\.widgetFamily) private var family

    private static let ink = Color(white: 0.08)
    private static let secondary = Color(white: 0.42)

    var body: some View {
        if let next = entry.next {
            let progress = WidgetTimeline.progress(now: entry.date, start: next.start)
            switch family {
            case .systemMedium: medium(next, progress: progress)
            case .systemLarge: large(next, progress: progress)
            default: small(next, progress: progress)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nothing coming up").font(.system(size: 15, weight: .semibold)).foregroundStyle(Self.ink)
                Text("Next two days are clear").font(.system(size: 12)).foregroundStyle(Self.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)
            .overlay(alignment: .bottomTrailing) { bubble(progress: 0, base: 70).offset(x: 24, y: 28) }
        }
    }

    private func small(_ next: WidgetSnapshot.Item, progress: Double) -> some View {
        ZStack(alignment: .bottomTrailing) {
            bubble(progress: progress, base: 96).offset(x: 30, y: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(next.start <= entry.date ? "Now" : "Next")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Self.secondary)
                Text(next.title)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Self.ink).lineLimit(2)
                countdown(next).font(.system(size: 28, weight: .medium).monospacedDigit()).padding(.top, 4)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)
        }
        .widgetURL(WidgetTimeline.popURL(meetingID: next.id))
    }

    private func medium(_ next: WidgetSnapshot.Item, progress: Double) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(next.start <= entry.date ? "Now" : "Next")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Self.secondary)
                Text(next.title)
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Self.ink).lineLimit(2)
                Text(subtitle(next)).font(.system(size: 12)).foregroundStyle(Self.secondary).lineLimit(1)
                countdown(next).font(.system(size: 30, weight: .medium).monospacedDigit()).padding(.top, 4)
                Spacer(minLength: 4)
                ForEach(entry.then.prefix(2), id: \.id) { item in
                    HStack(spacing: 6) {
                        Text(time(item.start)).font(.system(size: 11, weight: .semibold)).foregroundStyle(GumColors.dark)
                        Text(item.title).font(.system(size: 11)).foregroundStyle(Self.ink).lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)

            Link(destination: WidgetTimeline.popURL(meetingID: next.id) ?? URL(string: "promptly://")!) {
                ZStack(alignment: .bottom) {
                    bubble(progress: progress, base: 120).offset(y: 40)
                    Text(next.hasLink ? "Pop to join" : "Pop")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                        .padding(.bottom, 24 + 40 * progress)
                }
                .frame(width: 140)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
    }

    private func large(_ next: WidgetSnapshot.Item, progress: Double) -> some View {
        ZStack(alignment: .bottom) {
            Link(destination: WidgetTimeline.popURL(meetingID: next.id) ?? URL(string: "promptly://")!) {
                ZStack(alignment: .bottom) {
                    bubble(progress: progress, base: 170).offset(y: 70)
                    Text(next.hasLink ? "Pop to join" : "Pop")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                        .padding(.bottom, 36 + 60 * progress)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(next.start <= entry.date ? "Now" : "Next")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(Self.secondary)
                Text(next.title)
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(Self.ink).lineLimit(2)
                Text(subtitle(next)).font(.system(size: 13)).foregroundStyle(Self.secondary).lineLimit(1)
                countdown(next).font(.system(size: 40, weight: .medium).monospacedDigit()).padding(.top, 4)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.then, id: \.id) { item in
                        HStack(spacing: 8) {
                            Text(time(item.start)).font(.system(size: 13, weight: .semibold)).foregroundStyle(GumColors.dark)
                            Text(item.title).font(.system(size: 13)).foregroundStyle(Self.ink).lineLimit(1)
                        }
                    }
                }
                .padding(.top, 10)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(18)
        }
    }

    /// Grows from `base` up to 1.8 times as the meeting nears, easing between redraws.
    private func bubble(progress: Double, base: CGFloat) -> some View {
        let size = base * (1 + 0.8 * CGFloat(progress))
        return GumBall()
            .frame(width: size, height: size * (1 + 0.08 * CGFloat(progress)))
            .shadow(color: GumColors.accent.opacity(0.25), radius: 10, y: -4)
            .animation(.easeOut(duration: 1.5), value: progress)
    }

    @ViewBuilder
    private func countdown(_ next: WidgetSnapshot.Item) -> some View {
        if next.start > entry.date {
            Text(timerInterval: entry.date...next.start, countsDown: true)
                .foregroundStyle(Self.ink)
        } else {
            Text("Now").foregroundStyle(GumColors.dark)
        }
    }

    private func subtitle(_ item: WidgetSnapshot.Item) -> String {
        [time(item.start), item.service.isEmpty ? nil : item.service].compactMap { $0 }.joined(separator: " · ")
    }

    private func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }
}
