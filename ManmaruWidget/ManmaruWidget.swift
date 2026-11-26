import WidgetKit
import SwiftUI
import AppIntents

// App Groupが共有できないときも、このURLから直接取得できる。
struct ManmaruConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "まんまるの設定"
    static var description = IntentDescription("widget.jsonのURLを貼ると、ウィジェットが直接データを取得するよ。")

    @Parameter(title: "JSONのURL", description: "空欄なら、アプリに保存したURLとキャッシュを使うよ。", default: "")
    var jsonUrl: String
}

struct ManmaruEntry: TimelineEntry {
    var date: Date
    var feed: TrackerFeed?
    var trackerURL: URL?
}

struct ManmaruProvider: AppIntentTimelineProvider {
    typealias Entry = ManmaruEntry
    typealias Intent = ManmaruConfigurationIntent

    func placeholder(in context: Context) -> ManmaruEntry {
        ManmaruEntry(date: Date(), feed: TrackerFeed(), trackerURL: nil)
    }

    func snapshot(for configuration: ManmaruConfigurationIntent, in context: Context) async -> ManmaruEntry {
        await loadEntry(configuration: configuration)
    }

    func timeline(for configuration: ManmaruConfigurationIntent, in context: Context) async -> Timeline<ManmaruEntry> {
        let entry = await loadEntry(configuration: configuration)
        let next = TrackerURLs.nextWidgetRefresh(after: Date())
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func loadEntry(configuration: ManmaruConfigurationIntent) async -> ManmaruEntry {
        let configuredURL = configuration.jsonUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let sharedURL = (AppGroup.defaults?.string(forKey: AppGroup.widgetJsonUrlKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let source = configuredURL.isEmpty ? sharedURL : configuredURL
        let trackerURL = source.isEmpty ? cachedTrackerURL() : TrackerURLs.trackerURL(from: source)
        let cacheKey = "widgetFeedCache." + source
        let usesSharedSource = configuredURL.isEmpty || configuredURL == sharedURL

        // URLごとのキャッシュを持ち、別のウィジェットのデータと混ぜない。
        let localData = source.isEmpty ? nil : UserDefaults.standard.data(forKey: cacheKey)
        let sharedData = usesSharedSource ? AppGroup.defaults?.data(forKey: AppGroup.cachedJsonKey) : nil
        let cachedFeed = decode(sharedData) ?? decode(localData)

        // キャッシュがあっても、まず新しいJSONを取得する。
        if let url = TrackerURLs.feedURL(from: source) {
            do {
                let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                let feed = try JSONDecoder().decode(TrackerFeed.self, from: data)
                UserDefaults.standard.set(data, forKey: cacheKey)
                if usesSharedSource {
                    AppGroup.defaults?.set(data, forKey: AppGroup.cachedJsonKey)
                }
                return ManmaruEntry(date: Date(), feed: feed, trackerURL: trackerURL)
            } catch {
                // 通信できないときは、保存済みのデータを表示する。
            }
        }
        return ManmaruEntry(date: Date(), feed: cachedFeed, trackerURL: trackerURL)
    }

    private func decode(_ data: Data?) -> TrackerFeed? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(TrackerFeed.self, from: data)
    }

    private func cachedTrackerURL() -> URL? {
        guard let saved = AppGroup.defaults?.string(forKey: AppGroup.trackerUrlKey), !saved.isEmpty else { return nil }
        return URL(string: saved)
    }
}

struct ManmaruWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ManmaruEntry

    private var isSystemWidget: Bool { family == .systemSmall || family == .systemMedium }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: accessoryCircular
            case .accessoryRectangular: accessoryRectangular
            case .accessoryInline: accessoryInline
            case .systemMedium: mediumView
            default: smallView
            }
        }
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .padding(isSystemWidget ? 14 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if isSystemWidget {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(ManmaruPalette.border, lineWidth: 2)
            }
        }
        .widgetURL(entry.trackerURL)
    }

    private var smallView: some View {
        Group {
            if let feed = entry.feed {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        ManmaruCharacterImage(level: feed.level, size: 50)
                            .overlay(alignment: .topTrailing) { ManmaruMoodBadge(mood: feed.mood, size: 12).offset(x: 4, y: -4) }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lv.\(feed.level)")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Text(ManmaruStage.name(level: feed.level))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(ManmaruPalette.caption)
                        }
                    }
                    ManmaruProgressBar(value: feed.progress, height: 6)
                    Text("あと \(feed.exRemaining) EX")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(ManmaruPalette.caption)
                    if let steps = StepsRule.todaySteps(feed: feed) {
                        // 歩数があるときは、なつき度の代わりに歩数を出す
                        stepsRow(steps, fontSize: 10)
                    } else {
                        Text("なつき度 \(feed.friendship) / 255")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                        ManmaruProgressBar(value: feed.friendshipProgress, tint: ManmaruPalette.pink, height: 4)
                    }
                    todayText(feed)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            } else { emptyView }
        }
    }

    private var mediumView: some View {
        Group {
            if let feed = entry.feed {
                HStack(spacing: 14) {
                    ManmaruCharacterImage(level: feed.level, size: 96)
                        .overlay(alignment: .topTrailing) { ManmaruMoodBadge(mood: feed.mood, size: 16).offset(x: 5, y: -5) }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("Lv.\(feed.level)")
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                            Text(ManmaruStage.name(level: feed.level))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(ManmaruPalette.caption)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        ManmaruProgressBar(value: feed.progress, height: 8)
                        // 悲しいときは、まんまるのひとことを出す（責めない）
                        Text(moodOrExLine(feed))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(ManmaruPalette.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let steps = StepsRule.todaySteps(feed: feed) {
                            stepsRow(steps, fontSize: 12)
                        } else {
                            Text("なつき度 \(feed.friendship) / 255")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                            ManmaruProgressBar(value: feed.friendshipProgress, tint: ManmaruPalette.pink, height: 5)
                        }
                        todayText(feed)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            } else { emptyView }
        }
    }

    private func moodOrExLine(_ feed: TrackerFeed) -> String {
        if feed.mood == .sleepySad || feed.mood == .worried, let line = ManmaruMoodLine.short(feed.mood) {
            return line
        }
        return "\(feed.exInLevel) / \(feed.exNeeded) EX · あと\(feed.exRemaining)"
    }

    // 歩数の行：くつのマーク＋歩数＋細いバー（10k/15k/20kの線）
    private func stepsRow(_ steps: Int, fontSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                Text("\(steps.formatted()) 歩")
                Spacer(minLength: 2)
                Text("+\(StepsRule.ex(for: steps)) EX")
                    .foregroundStyle(ManmaruPalette.green)
            }
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            StepsGoalBar(steps: steps, height: 4, showLabels: false)
        }
    }

    private func todayText(_ feed: TrackerFeed) -> Text {
        let summary = feed.summaryDisplay
        return Text("\(summary.label) ")
            + Text("+\(summary.plusEx) EX").foregroundColor(ManmaruPalette.green)
            + Text(" (\(summary.done)/\(summary.total) できた)")
    }

    private var accessoryCircular: some View {
        VStack(spacing: 1) {
            ManmaruCharacterImage(level: entry.feed?.level ?? 1, size: 36)
            Text("Lv.\(entry.feed?.level ?? 1)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
    }

    private var accessoryRectangular: some View {
        Group {
            if let feed = entry.feed {
                HStack(spacing: 6) {
                    ManmaruCharacterImage(level: feed.level, size: 38)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Lv.\(feed.level)")
                        ManmaruProgressBar(value: feed.progress, height: 5)
                        Text("あと \(feed.exRemaining) EX")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                }
            } else { Text("URLを設定してね") }
        }
    }

    private var accessoryInline: some View {
        Group {
            if let feed = entry.feed {
                Text("Lv.\(feed.level) · \(feed.totalEx) EX")
            } else { Text("まんまる · URLを設定してね") }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            ManmaruCharacterImage(level: 1, size: 50)
            Text("URLを設定してね")
                .multilineTextAlignment(.center)
            Text("長押し → ウィジェットを編集")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(ManmaruPalette.caption)
                .multilineTextAlignment(.center)
        }
    }
}

struct ManmaruWidget: Widget {
    let kind = "ManmaruWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ManmaruConfigurationIntent.self, provider: ManmaruProvider()) { entry in
            ManmaruWidgetEntryView(entry: entry)
                .containerBackground(ManmaruPalette.card, for: .widget)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("まんまる")
        .description("レベル・EX・今日のタスクを見るよ。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct ManmaruWidgetBundle: WidgetBundle {
    var body: some Widget {
        ManmaruWidget()
        ManmaruLiveActivityWidget()
    }
}
