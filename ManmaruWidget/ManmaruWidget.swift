import WidgetKit
import SwiftUI
import AppIntents

// MARK: - ウィジェットの設定（AppIntent）
// 無料のApple IDだと App Groups が使えない場合がある。
// そのときは App Group のキャッシュが読めないので、
// ここに widget.json のURLを直接貼ると、ウィジェット自身が取りに行く。
// 優先順位：
//   1. App Group のキャッシュJSON（アプリが保存したもの）
//   2. ここのURLから直接取得
//   3. どちらも無ければ「URLを設定してね」
struct ManmaruConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "まんまるの設定"
    static var description = IntentDescription("widget.json のURLを貼ると、App Groups が使えないときでも動くよ。")

    @Parameter(title: "JSONのURL", description: IntentDescription("widget.json のURL。空っぽでもOK（そのときはアプリのキャッシュを使うよ）。"), default: "")
    var jsonUrl: String
}

// MARK: - エントリー
struct ManmaruEntry: TimelineEntry {
    var date: Date
    var feed: TrackerFeed?
    var trackerURL: URL?
}

// MARK: - プロバイダ
// AppIntentConfiguration を使うので、IntentTimelineProvider ではなく
// AppIntentTimelineProvider にする（古い方だとビルドが通らない）。
struct ManmaruProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ManmaruEntry {
        ManmaruEntry(date: Date(), feed: nil, trackerURL: nil)
    }

    func getSnapshot(for configuration: ManmaruConfigurationIntent, in context: Context) async -> ManmaruEntry {
        await loadEntry(configuration: configuration)
    }

    func getTimeline(for configuration: ManmaruConfigurationIntent, in context: Context) async -> Timeline<ManmaruEntry> {
        let entry = await loadEntry(configuration: configuration)
        // 15分ごとに更新する
        let next = Date().addingTimeInterval(15 * 60)
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func loadEntry(configuration: ManmaruConfigurationIntent) async -> ManmaruEntry {
        // 1. App Group のキャッシュJSONを読む
        if let data = AppGroup.defaults?.data(forKey: AppGroup.cachedJsonKey),
           let feed = try? JSONDecoder().decode(TrackerFeed.self, from: data) {
            return ManmaruEntry(date: Date(), feed: feed, trackerURL: cachedTrackerURL())
        }

        // 2. キャッシュが無ければ、設定のURLから直接取りに行く
        let urlString = configuration.jsonUrl.trimmingCharacters(in: .whitespaces)
        if !urlString.isEmpty, let url = URL(string: urlString) {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    return ManmaruEntry(date: Date(), feed: nil, trackerURL: nil)
                }
                let feed = try JSONDecoder().decode(TrackerFeed.self, from: data)
                return ManmaruEntry(
                    date: Date(),
                    feed: feed,
                    trackerURL: TrackerURLs.trackerURL(from: urlString)
                )
            } catch {
                return ManmaruEntry(date: Date(), feed: nil, trackerURL: nil)
            }
        }

        // 3. どちらも無ければ空っぽ
        return ManmaruEntry(date: Date(), feed: nil, trackerURL: nil)
    }

    /// App Group に保存してあるトラッカーのURL。無ければJSONのURLから作る。
    private func cachedTrackerURL() -> URL? {
        if let saved = AppGroup.defaults?.string(forKey: AppGroup.trackerUrlKey),
           !saved.isEmpty, let url = URL(string: saved) {
            return url
        }
        let jsonURL = AppGroup.defaults?.string(forKey: AppGroup.widgetJsonUrlKey) ?? ""
        return TrackerURLs.trackerURL(from: jsonURL)
    }
}

// MARK: - キャラ画像（ウィジェット用）
// バンドルの "stage1" / "stage2" / "stage3" を使う。無ければ描く。
struct WidgetCharacterView: View {
    var stage: Int
    var size: CGFloat

    var body: some View {
        Group {
            if let uiImage = UIImage(named: "stage\(stage)") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let uiImage = UIImage(named: "stage1") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                // フォールバック：白い丸＋点の目＋笑った口
                ZStack {
                    Circle().fill(Color.white)
                    HStack(spacing: 22) {
                        Circle().fill(Color.black).frame(width: 8, height: 10)
                        Circle().fill(Color.black).frame(width: 8, height: 10)
                    }
                    .offset(y: -4)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addQuadCurve(to: CGPoint(x: 20, y: 0), control: CGPoint(x: 10, y: 14))
                    }
                    .stroke(Color.black, lineWidth: 3)
                    .frame(width: 20, height: 14)
                    .offset(y: 12)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - ウィジェットの見た目
struct ManmaruWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ManmaruEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                accessoryCircular
            case .accessoryRectangular:
                accessoryRectangular
            case .accessoryInline:
                accessoryInline
            case .systemMedium:
                mediumView
            default:
                smallView
            }
        }
        // タップでトラッカーを開く
        .widgetURL(entry.trackerURL)
    }

    // 小サイズ：キャラ画像＋レベル＋EXバー
    private var smallView: some View {
        Group {
            if let feed = entry.feed {
                VStack(spacing: 6) {
                    WidgetCharacterView(stage: feed.stage, size: 64)
                    Text("Lv \(feed.level)")
                        .font(.headline)
                    ProgressView(value: feed.progress)
                    Text("\(feed.exInLevel) / \(feed.exNeeded) EX")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                emptyView
            }
        }
    }

    // 中サイズ：小サイズ＋今日のタスク（終わった数／全部）
    private var mediumView: some View {
        Group {
            if let feed = entry.feed {
                HStack(spacing: 12) {
                    WidgetCharacterView(stage: feed.stage, size: 72)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Lv \(feed.level)")
                                .font(.headline)
                            Text(feed.stageName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(feed.totalEx) EX")
                                .font(.subheadline)
                        }
                        ProgressView(value: feed.progress)
                        Text("今日のタスク \(feed.tasksDone) / \(feed.tasksTotal)")
                            .font(.subheadline)
                        Text("なつき度 \(feed.friendship) / 255")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            } else {
                emptyView
            }
        }
    }

    // ロック画面：丸（キャラ＋レベル）
    private var accessoryCircular: some View {
        Group {
            if let feed = entry.feed {
                ZStack {
                    WidgetCharacterView(stage: feed.stage, size: 56)
                    Text("Lv\(feed.level)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .offset(y: 24)
                }
            } else {
                Image(systemName: "circle.dashed")
            }
        }
    }

    // ロック画面：長方形（レベル＋EX）
    private var accessoryRectangular: some View {
        Group {
            if let feed = entry.feed {
                VStack(alignment: .leading, spacing: 2) {
                    Text("まんまる Lv \(feed.level)")
                        .font(.headline)
                    Text("\(feed.exInLevel) / \(feed.exNeeded) EX")
                        .font(.subheadline)
                    ProgressView(value: feed.progress)
                }
            } else {
                Text("URLを設定してね")
                    .font(.subheadline)
            }
        }
    }

    // ロック画面：インライン（1行）
    private var accessoryInline: some View {
        Group {
            if let feed = entry.feed {
                Text("Lv\(feed.level)・\(feed.totalEx)EX")
            } else {
                Text("まんまる")
            }
        }
    }

    // キャッシュもURLも無いとき
    private var emptyView: some View {
        VStack(spacing: 8) {
            WidgetCharacterView(stage: 1, size: 56)
            Text("URLを設定してね")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            Text("長押し → ウィジェットを編集")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: - ウィジェット本体
struct ManmaruWidget: Widget {
    let kind: String = "ManmaruWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ManmaruConfigurationIntent.self, provider: ManmaruProvider()) { entry in
            ManmaruWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("まんまる")
        .description("レベル・EX・今日のタスクを見るよ。")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - ウィジェットの束ね役
@main
struct ManmaruWidgetBundle: WidgetBundle {
    var body: some Widget {
        ManmaruWidget()
        ManmaruLiveActivityWidget()
    }
}

#Preview(as: .systemSmall) {
    ManmaruWidget()
} timeline: {
    ManmaruEntry(date: Date(), feed: nil, trackerURL: nil)
}
