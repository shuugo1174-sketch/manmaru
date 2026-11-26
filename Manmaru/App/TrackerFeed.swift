import Foundation
import Combine
import SwiftUI
import UIKit
import WidgetKit

// アプリとウィジェットで使う保存先。
// 共有できないときは、ウィジェット設定のURLから直接取得する。
enum AppGroup {
    static let suiteName = "group.manmaru"
    static let widgetJsonUrlKey = "widgetJsonUrl"
    static let trackerUrlKey = "trackerUrl"
    static let cachedJsonKey = "cachedWidgetJson"
    static let lastSeenLevelKey = "lastSeenLevel"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static var isAppGroupAvailable: Bool {
        UserDefaults(suiteName: suiteName) != nil
    }
}

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
    var todayPlusEx: Int = 0
    var todayMinusEx: Int = 0
    var characterImageUrl: String?
    var characterImages: [TrackerCharacterImage] = []
    var updatedAt: String = ""

    init() {}

    private enum CodingKeys: String, CodingKey {
        case version, date, level, stage, stageName, totalEx, exInLevel
        case exToNextLevel, progressPercent, friendship, parameters, tasks
        case tasksDone, tasksTotal, todayPlusEx, todayMinusEx
        case characterImageUrl, characterImages, updatedAt
    }

    // キーが無い場合とnullの場合は、初期値を使う。
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 1
        date = try values.decodeIfPresent(String.self, forKey: .date) ?? ""
        level = try values.decodeIfPresent(Int.self, forKey: .level) ?? 1
        stage = try values.decodeIfPresent(Int.self, forKey: .stage) ?? 1
        stageName = try values.decodeIfPresent(String.self, forKey: .stageName) ?? "まんまる"
        totalEx = try values.decodeIfPresent(Int.self, forKey: .totalEx) ?? 0
        exInLevel = try values.decodeIfPresent(Int.self, forKey: .exInLevel) ?? 0
        exToNextLevel = try values.decodeIfPresent(Int.self, forKey: .exToNextLevel) ?? 100
        progressPercent = try values.decodeIfPresent(Int.self, forKey: .progressPercent) ?? 0
        friendship = try values.decodeIfPresent(Int.self, forKey: .friendship) ?? 0
        parameters = try values.decodeIfPresent([TrackerParameter].self, forKey: .parameters) ?? []
        tasks = try values.decodeIfPresent([TrackerTask].self, forKey: .tasks) ?? []
        tasksDone = try values.decodeIfPresent(Int.self, forKey: .tasksDone) ?? 0
        tasksTotal = try values.decodeIfPresent(Int.self, forKey: .tasksTotal) ?? 0
        todayPlusEx = try values.decodeIfPresent(Int.self, forKey: .todayPlusEx) ?? 0
        todayMinusEx = try values.decodeIfPresent(Int.self, forKey: .todayMinusEx) ?? 0
        characterImageUrl = try values.decodeIfPresent(String.self, forKey: .characterImageUrl)
        characterImages = try values.decodeIfPresent([TrackerCharacterImage].self, forKey: .characterImages) ?? []
        updatedAt = try values.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }

    // exToNextLevelは、次のレベルまでの残りEX。
    var exNeeded: Int { exInLevel + exToNextLevel }
    var exRemaining: Int { max(exToNextLevel, 0) }

    var progress: Double {
        guard exNeeded > 0 else { return 0 }
        return min(max(Double(exInLevel) / Double(exNeeded), 0), 1)
    }

    var friendshipProgress: Double {
        min(max(Double(friendship) / 255.0, 0), 1)
    }

    func parameterLabel(for key: String) -> String {
        if let label = parameters.first(where: { $0.key == key })?.label, !label.isEmpty {
            return label
        }
        switch key {
        case "strength": return "力"
        case "body": return "体"
        case "knowledge": return "知"
        case "skill": return "技"
        case "heart": return "心"
        default: return key.isEmpty ? "その他" : key
        }
    }
}

struct TrackerParameter: Codable, Equatable, Identifiable {
    var id: String { key }
    var key: String
    var label: String
    var level: Int
    var totalEx: Int
    var exToLevel10: Int?
    var goldSkill: TrackerGoldSkill?
    var skills: [TrackerSkill]?

    private enum CodingKeys: String, CodingKey {
        case key, label, level, totalEx, exToLevel10, goldSkill, skills
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        key = try values.decodeIfPresent(String.self, forKey: .key) ?? ""
        label = try values.decodeIfPresent(String.self, forKey: .label) ?? ""
        level = try values.decodeIfPresent(Int.self, forKey: .level) ?? 1
        totalEx = try values.decodeIfPresent(Int.self, forKey: .totalEx) ?? 0
        exToLevel10 = try values.decodeIfPresent(Int.self, forKey: .exToLevel10)
        goldSkill = try values.decodeIfPresent(TrackerGoldSkill.self, forKey: .goldSkill)
        skills = try values.decodeIfPresent([TrackerSkill].self, forKey: .skills)
    }
}

struct TrackerGoldSkill: Codable, Equatable {
    var name: String?
    var unlocked: Bool
    var unlockLevel: Int?

    private enum CodingKeys: String, CodingKey { case name, unlocked, unlockLevel }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        unlocked = try values.decodeIfPresent(Bool.self, forKey: .unlocked) ?? false
        unlockLevel = try values.decodeIfPresent(Int.self, forKey: .unlockLevel)
    }
}

struct TrackerSkill: Codable, Equatable {
    var name: String?
    var unlocked: Bool

    init(name: String? = nil, unlocked: Bool = false) {
        self.name = name
        self.unlocked = unlocked
    }

    private enum CodingKeys: String, CodingKey { case name, unlocked }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        unlocked = try values.decodeIfPresent(Bool.self, forKey: .unlocked) ?? false
    }
}

struct TrackerTask: Codable, Equatable, Identifiable {
    var id: String { name }
    var name: String
    var parameter: String
    var points: Int
    var done: Bool

    private enum CodingKeys: String, CodingKey { case name, parameter, points, done }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
        parameter = try values.decodeIfPresent(String.self, forKey: .parameter) ?? ""
        points = try values.decodeIfPresent(Int.self, forKey: .points) ?? 0
        done = try values.decodeIfPresent(Bool.self, forKey: .done) ?? false
    }
}

struct TrackerCharacterImage: Codable, Equatable {
    var stage: Int
    var name: String
    var url: String

    private enum CodingKeys: String, CodingKey { case stage, name, url }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        stage = try values.decodeIfPresent(Int.self, forKey: .stage) ?? 1
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
        url = try values.decodeIfPresent(String.self, forKey: .url) ?? ""
    }
}

enum TrackerURLs {
    static func trackerURL(from jsonURLString: String) -> URL? {
        guard let url = URL(string: jsonURLString), !jsonURLString.isEmpty else { return nil }
        if jsonURLString.contains("blobs/widget.json") {
            let base = jsonURLString.replacingOccurrences(of: "blobs/widget.json", with: "")
            return URL(string: base)
        }
        return url
    }

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

    static func exToNextLevel(level: Int) -> Int {
        guard level < 100 else { return 0 }
        return 100 + 10 * (max(level, 1) - 1)
    }

    static func feedURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http", url.host != nil else { return nil }
        return url
    }

    // 朝の再生成後に更新する。実際の更新時刻はiOSが決める。
    static func nextWidgetRefresh(after now: Date, calendar: Calendar = .current) -> Date {
        let twoHours = now.addingTimeInterval(2 * 60 * 60)
        let nextMorning = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 3, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? twoHours
        return min(nextMorning, twoHours)
    }
}

struct LevelUpCelebration: Equatable, Identifiable {
    let id = UUID()
    let level: Int
    let evolved: Bool
}

@MainActor
final class TrackerStore: ObservableObject {
    @Published var feed: TrackerFeed?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published var celebration: LevelUpCelebration?

    var jsonURLString: String {
        AppGroup.defaults?.string(forKey: AppGroup.widgetJsonUrlKey) ?? ""
    }

    var hasURL: Bool { !jsonURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

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

    func loadCachedFeed() {
        guard let data = AppGroup.defaults?.data(forKey: AppGroup.cachedJsonKey),
              let decoded = try? JSONDecoder().decode(TrackerFeed.self, from: data) else { return }
        feed = decoded
    }

    func refresh() async {
        guard !isLoading else { return }
        guard let url = TrackerURLs.feedURL(from: jsonURLString) else {
            errorMessage = "設定でJSONのURLを貼ってね。"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let data = try await fetchData(from: url)
            let decoded = try JSONDecoder().decode(TrackerFeed.self, from: data)
            accept(decoded, data: data)
        } catch {
            errorMessage = "更新できなかったよ。保存済みのデータがあれば表示しているよ。"
        }
    }

    func testFetch(urlString: String) async -> Bool {
        guard !isLoading, let url = TrackerURLs.feedURL(from: urlString) else { return false }
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await fetchData(from: url)
            let decoded = try JSONDecoder().decode(TrackerFeed.self, from: data)
            accept(decoded, data: data)
            return true
        } catch {
            return false
        }
    }

    private func fetchData(from url: URL) async throws -> Data {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private func accept(_ decoded: TrackerFeed, data: Data) {
        let defaults = AppGroup.defaults
        // 初回は記録だけ行い、お祝いは出さない。
        if defaults?.object(forKey: AppGroup.lastSeenLevelKey) != nil {
            let previous = defaults?.integer(forKey: AppGroup.lastSeenLevelKey) ?? decoded.level
            if decoded.level > previous {
                let evolved = (previous < 34 && decoded.level >= 34)
                    || (previous < 67 && decoded.level >= 67)
                celebration = LevelUpCelebration(level: decoded.level, evolved: evolved)
            }
        }
        defaults?.set(decoded.level, forKey: AppGroup.lastSeenLevelKey)
        defaults?.set(data, forKey: AppGroup.cachedJsonKey)
        feed = decoded
        lastUpdated = Date()
        errorMessage = nil
        LiveActivityManager.shared.update(feed: decoded)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// レベルによる進化は、全画面で同じ判定を使う。
enum ManmaruStage {
    static func number(level: Int) -> Int {
        if level >= 67 { return 3 }
        if level >= 34 { return 2 }
        return 1
    }

    static func imageName(level: Int) -> String {
        "stage\(number(level: level))"
    }

    static func name(level: Int) -> String {
        switch number(level: level) {
        case 3: return "キング"
        case 2: return "ムキムキ"
        default: return "まんまる"
        }
    }
}

// 配色もアプリとウィジェットで共有する。
enum ManmaruPalette {
    static let background = Color(red: 15 / 255.0, green: 22 / 255.0, blue: 38 / 255.0)
    static let card = Color(red: 20 / 255.0, green: 28 / 255.0, blue: 46 / 255.0)
    static let border = Color(red: 46 / 255.0, green: 58 / 255.0, blue: 92 / 255.0)
    static let yellow = Color(red: 1, green: 200 / 255.0, blue: 0)
    static let cream = Color(red: 253 / 255.0, green: 235 / 255.0, blue: 200 / 255.0)
    static let caption = Color(red: 165 / 255.0, green: 175 / 255.0, blue: 197 / 255.0)
    static let pink = Color(red: 1, green: 95 / 255.0, blue: 137 / 255.0)
    static let green = Color(red: 103 / 255.0, green: 222 / 255.0, blue: 157 / 255.0)
}

struct ManmaruCharacterImage: View {
    var level: Int
    var size: CGFloat

    private var corner: CGFloat { min(24, size * 0.2) }

    var body: some View {
        ZStack {
            ManmaruPalette.cream
            if let image = UIImage(named: ManmaruStage.imageName(level: level)) ?? UIImage(named: "stage1") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(3)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner))
        .overlay {
            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(ManmaruPalette.yellow, lineWidth: 2)
        }
        .accessibilityLabel(ManmaruStage.name(level: level))
    }
}

struct ManmaruProgressBar: View {
    var value: Double
    var tint: Color = ManmaruPalette.yellow
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(ManmaruPalette.background)
                Capsule().fill(tint)
                    .frame(width: geometry.size.width * CGFloat(min(max(value, 0), 1)))
            }
        }
        .frame(height: height)
        .accessibilityValue("\(Int(min(max(value, 0), 1) * 100))パーセント")
    }
}

struct ManmaruCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(ManmaruPalette.card)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(ManmaruPalette.border, lineWidth: 2)
            }
    }
}

extension View {
    func manmaruCard() -> some View {
        modifier(ManmaruCardModifier())
    }
}
