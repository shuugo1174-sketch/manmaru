import Foundation
import Combine

// MARK: - App Group の共有場所
// アプリとウィジェットで同じ場所を使う。IDは両ターゲットで同じにする。
// 無料のApple IDだと App Groups が使えない場合がある。
// そのときは suite が取れないので、標準のUserDefaultsに落ちる。
// アプリ本体はそれでも動く（URL保存・取得・キャッシュはアプリ内で完結）。
// ウィジェットは標準UserDefaultsを読めないので、代わりに
// ウィジェット設定のURLから直接JSONを取りに行く（ManmaruWidget.swift）。
enum AppGroup {
    static let suiteName = "group.manmaru"
    static let widgetJsonUrlKey = "widgetJsonUrl"
    static let trackerUrlKey = "trackerUrl"
    static let cachedJsonKey = "cachedWidgetJson"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    /// App Group が本当に使えているかどうか。
    /// suite が作れれば true。使えなくて .standard に落ちていたら false。
    static var isAppGroupAvailable: Bool {
        UserDefaults(suiteName: suiteName) != nil
    }
}

// MARK: - widget.json の形
struct TrackerFeed: Codable, Equatable {
    var version: Int = 1
    var date: String = ""
    var level: Int = 1
    var stage: Int = 1
    var stageName: String = "まんまる"
    var totalEx: Int = 0
    var exInLevel: Int = 0
    var exToNextLevel: Int = 100
    var progressPercent: Int = 0
    var friendship: Int = 0
    var parameters: [TrackerParameter] = []
    var tasks: [TrackerTask] = []
    var tasksDone: Int = 0
    var tasksTotal: Int = 0
    var characterImageUrl: String?
    var characterImages: [TrackerCharacterImage] = []
    var updatedAt: String = ""

    // このレベルで必要なEXの合計（= 今までの分 + 残り）
    // JSONの exToNextLevel は「残り」なので、合計は exInLevel + exToNextLevel。
    var exNeeded: Int { exInLevel + exToNextLevel }

    // 次のレベルまでの残りEX（JSONの値をそのまま使う）
    var exRemaining: Int { max(exToNextLevel, 0) }

    // EXバーの進み具合 0.0〜1.0
    var progress: Double {
        guard exNeeded > 0 else { return 0 }
        return min(max(Double(exInLevel) / Double(exNeeded), 0), 1)
    }

    // なつき度 0〜255 を 0.0〜1.0 にする
    var friendshipProgress: Double {
        min(max(Double(friendship) / 255.0, 0), 1)
    }
}

struct TrackerParameter: Codable, Equatable, Identifiable {
    var id: String { key }
    var key: String
    var label: String
    var level: Int
    var totalEx: Int
}

struct TrackerTask: Codable, Equatable, Identifiable {
    var id: String { name }
    var name: String
    var parameter: String
    var points: Int
    var done: Bool
}

struct TrackerCharacterImage: Codable, Equatable {
    var stage: Int
    var name: String
    var url: String
}

// MARK: - URLの解決
enum TrackerURLs {
    /// JSONのURLからトラッカーのトップURLを作る。
    /// 「.../blobs/widget.json」なら「blobs/widget.json」を除いたもの。
    /// それ以外ならJSONのURL自体を返す。
    static func trackerURL(from jsonURLString: String) -> URL? {
        guard let url = URL(string: jsonURLString) else { return nil }
        if jsonURLString.contains("blobs/widget.json") {
            let base = jsonURLString.replacingOccurrences(of: "blobs/widget.json", with: "")
            return URL(string: base)
        }
        return url
    }

    /// 相対URL（./blobs/...）を絶対URLにする。
    /// JSONのURLが「.../blobs/widget.json」で終わるなら、その部分を除いたものがルート。
    /// それ以外ならJSONのURLのディレクトリを基準にする。
    static func resolveImageURL(_ relative: String, jsonURLString: String) -> URL? {
        if relative.hasPrefix("http://") || relative.hasPrefix("https://") {
            return URL(string: relative)
        }
        let cleaned = relative.hasPrefix("./") ? String(relative.dropFirst(2)) : relative
        if jsonURLString.hasSuffix("blobs/widget.json") {
            let root = jsonURLString.replacingOccurrences(of: "blobs/widget.json", with: "")
            return URL(string: root + cleaned)
        }
        guard let base = URL(string: jsonURLString) else { return nil }
        return URL(string: cleaned, relativeTo: base)?.absoluteURL
    }

    /// レベル n → n+1 に必要なEX。最大Lv100。
    /// 表示はJSONの exInLevel / exToNextLevel を使う。ここは予備の計算。
    static func exToNextLevel(level: Int) -> Int {
        guard level < 100 else { return 0 }
        return 100 + 10 * (level - 1)
    }
}

// MARK: - 取得とキャッシュ
@MainActor
final class TrackerStore: ObservableObject {
    @Published var feed: TrackerFeed?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    var jsonURLString: String {
        AppGroup.defaults?.string(forKey: AppGroup.widgetJsonUrlKey) ?? ""
    }

    var hasURL: Bool { !jsonURLString.trimmingCharacters(in: .whitespaces).isEmpty }

    var trackerURL: URL? {
        if let saved = AppGroup.defaults?.string(forKey: AppGroup.trackerUrlKey),
           !saved.isEmpty, let url = URL(string: saved) {
            return url
        }
        return TrackerURLs.trackerURL(from: jsonURLString)
    }

    init() {
        loadCachedFeed()
    }

    /// App Groupに保存してある最後のJSONを読む（ウィジェットと同じもの）。
    func loadCachedFeed() {
        guard let data = AppGroup.defaults?.data(forKey: AppGroup.cachedJsonKey),
              let decoded = try? JSONDecoder().decode(TrackerFeed.self, from: data) else { return }
        feed = decoded
    }

    /// URLSessionでJSONを取ってデコードし、App Groupにキャッシュする。
    func refresh() async {
        let urlString = jsonURLString.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            errorMessage = "URLがまだないよ。設定でURLを貼ってね。"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                errorMessage = "取れなかったよ（\(http.statusCode)）"
                return
            }
            let decoded = try JSONDecoder().decode(TrackerFeed.self, from: data)
            feed = decoded
            lastUpdated = Date()
            // ウィジェット用に生JSONをそのまま保存する
            AppGroup.defaults?.set(data, forKey: AppGroup.cachedJsonKey)
        } catch {
            errorMessage = "取れなかったよ。URLを確認してね。"
        }
    }

    /// テスト取得：URLを入れて1回だけ取る。成功したら保存もする。
    func testFetch(urlString: String) async -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed), !trimmed.isEmpty else { return false }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
            let decoded = try JSONDecoder().decode(TrackerFeed.self, from: data)
            feed = decoded
            lastUpdated = Date()
            AppGroup.defaults?.set(data, forKey: AppGroup.cachedJsonKey)
            return true
        } catch {
            return false
        }
    }
}
