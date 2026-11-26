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
    // アプリがHealthKitから読んだ今日の歩数（ウィジェット用）
    static let todayStepsKey = "todaySteps"
    static let todayStepsDateKey = "todayStepsDate"
    // 上のバー（ライブアクティビティ）を出しておきたいか
    static let liveActivityWantedKey = "liveActivityWanted"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static var isAppGroupAvailable: Bool {
        UserDefaults(suiteName: suiteName) != nil
    }
}

struct TrackerDaySummary: Codable, Equatable {
    var date: String = ""
    var tasksDone: Int = 0
    var tasksTotal: Int = 0
    var plusEx: Int = 0

    init() {}

    private enum CodingKeys: String, CodingKey {
        case date, tasksDone, tasksTotal, plusEx
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        date = try values.decodeIfPresent(String.self, forKey: .date) ?? ""
        tasksDone = try values.decodeIfPresent(Int.self, forKey: .tasksDone) ?? 0
        tasksTotal = try values.decodeIfPresent(Int.self, forKey: .tasksTotal) ?? 0
        plusEx = try values.decodeIfPresent(Int.self, forKey: .plusEx) ?? 0
    }
}

// 体のデータ（トラッカーが入れる。どれも無くてもいい）
struct TrackerHealth: Codable, Equatable {
    var date: String?
    var steps: Int?
    var calories: Int?
    var calorieLimit: Int?
    var weightKg: Double?
    var bedtime: String?
    var lateNight: Bool?

    private enum CodingKeys: String, CodingKey {
        case date, steps, calories, calorieLimit, weightKg, bedtime, lateNight
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        date = try? values.decodeIfPresent(String.self, forKey: .date)
        steps = try? values.decodeIfPresent(Int.self, forKey: .steps)
        calories = try? values.decodeIfPresent(Int.self, forKey: .calories)
        calorieLimit = try? values.decodeIfPresent(Int.self, forKey: .calorieLimit)
        weightKg = try? values.decodeIfPresent(Double.self, forKey: .weightKg)
        bedtime = try? values.decodeIfPresent(String.self, forKey: .bedtime)
        lateNight = try? values.decodeIfPresent(Bool.self, forKey: .lateNight)
    }

    // 寝た時間が 0:00〜4:59 なら夜更かし
    var isLateNight: Bool {
        if lateNight == true { return true }
        guard let bedtime, let hour = Int(bedtime.split(separator: ":").first ?? "") else { return false }
        return hour >= 0 && hour < 5
    }

    var isOverCalories: Bool {
        guard let calories else { return false }
        return calories > (calorieLimit ?? 2200)
    }
}

// 週の振り返りの材料（トラッカーが入れる。どれも無くてもいい）
struct TrackerWeek: Codable, Equatable {
    var from: String?
    var to: String?
    var tasksDone: Int?
    var tasksTotal: Int?
    var plusEx: Int?
    var doneOften: [String]?
    var missedOften: [String]?
    var parameterGains: [String: Int]?
    var stepsAvg: Int?
    var weightChangeKg: Double?
    var overCalorieDays: Int?
    var lateNightDays: Int?
    var chatNotes: String?

    private enum CodingKeys: String, CodingKey {
        case from, to, tasksDone, tasksTotal, plusEx, doneOften, missedOften
        case parameterGains, stepsAvg, weightChangeKg, overCalorieDays, lateNightDays, chatNotes
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        from = try? values.decodeIfPresent(String.self, forKey: .from)
        to = try? values.decodeIfPresent(String.self, forKey: .to)
        tasksDone = try? values.decodeIfPresent(Int.self, forKey: .tasksDone)
        tasksTotal = try? values.decodeIfPresent(Int.self, forKey: .tasksTotal)
        plusEx = try? values.decodeIfPresent(Int.self, forKey: .plusEx)
        doneOften = try? values.decodeIfPresent([String].self, forKey: .doneOften)
        missedOften = try? values.decodeIfPresent([String].self, forKey: .missedOften)
        parameterGains = try? values.decodeIfPresent([String: Int].self, forKey: .parameterGains)
        stepsAvg = try? values.decodeIfPresent(Int.self, forKey: .stepsAvg)
        weightChangeKg = try? values.decodeIfPresent(Double.self, forKey: .weightChangeKg)
        overCalorieDays = try? values.decodeIfPresent(Int.self, forKey: .overCalorieDays)
        lateNightDays = try? values.decodeIfPresent(Int.self, forKey: .lateNightDays)
        chatNotes = try? values.decodeIfPresent(String.self, forKey: .chatNotes)
    }

    // 振り返りを保存するときの名前
    var cacheKey: String { "weeklyReview." + (from ?? "") + "_" + (to ?? "") }
}

// まんまるの気もち。責めない。悲しむだけ。
enum ManmaruMood: Equatable {
    case normal
    case happy
    case sleepySad
    case worried
}

// 歩数のEXルール（トラッカーと同じ。表示だけ）
enum StepsRule {
    static let goals = [10_000, 15_000, 20_000]

    static func ex(for steps: Int) -> Int {
        switch steps {
        case 20_000...: return 30
        case 15_000..<20_000: return 20
        case 10_000..<15_000: return 10
        case 5_000..<10_000: return 5
        default: return 0
        }
    }

    // 次の目標ライン（全部こえたら nil）
    static func nextGoal(after steps: Int) -> Int? {
        ([5_000] + goals).first { steps < $0 }
    }

    // 今日の歩数：アプリが今日読んだ値 → 無ければJSONの値
    static func todaySteps(feed: TrackerFeed?) -> Int? {
        let defaults = AppGroup.defaults
        if let saved = defaults?.object(forKey: AppGroup.todayStepsDateKey) as? Date,
           Calendar.current.isDateInToday(saved),
           defaults?.object(forKey: AppGroup.todayStepsKey) != nil {
            return defaults?.integer(forKey: AppGroup.todayStepsKey)
        }
        return feed?.health?.steps
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
    var yesterday: TrackerDaySummary?
    var health: TrackerHealth?
    var week: TrackerWeek?
    var characterImageUrl: String?
    var characterImages: [TrackerCharacterImage] = []
    var updatedAt: String = ""

    init() {}

    private enum CodingKeys: String, CodingKey {
        case version, date, level, stage, stageName, totalEx, exInLevel
        case exToNextLevel, progressPercent, friendship, parameters, tasks
        case tasksDone, tasksTotal, todayPlusEx, todayMinusEx, yesterday, health, week
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
        yesterday = (try? values.decodeIfPresent(TrackerDaySummary.self, forKey: .yesterday)) ?? nil
        health = (try? values.decodeIfPresent(TrackerHealth.self, forKey: .health)) ?? nil
        week = (try? values.decodeIfPresent(TrackerWeek.self, forKey: .week)) ?? nil
        characterImageUrl = try values.decodeIfPresent(String.self, forKey: .characterImageUrl)
        characterImages = try values.decodeIfPresent([TrackerCharacterImage].self, forKey: .characterImages) ?? []
        updatedAt = try values.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }

    struct DaySummaryDisplay {
        let label: String
        let plusEx: Int
        let done: Int
        let total: Int
        let isYesterday: Bool
    }

    var summaryDisplay: DaySummaryDisplay {
        if let yesterday = yesterday {
            return DaySummaryDisplay(label: "きのう", plusEx: yesterday.plusEx,
                                     done: yesterday.tasksDone, total: yesterday.tasksTotal,
                                     isYesterday: true)
        }
        return DaySummaryDisplay(label: "きょう", plusEx: todayPlusEx,
                                 done: tasksDone, total: tasksTotal, isYesterday: false)
    }

    // 気もちの決め方：夜更かし → 食べすぎ → きのう全部できた → ふつう
    var mood: ManmaruMood {
        if health?.isLateNight == true { return .sleepySad }
        if health?.isOverCalories == true { return .worried }
        if let yesterday, yesterday.tasksTotal > 0, yesterday.tasksDone >= yesterday.tasksTotal { return .happy }
        return .normal
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

// 上のバー（ライブアクティビティ）用の小さい絵。大きい絵だと表示されないので、160pxの絵を使う。
struct ManmaruSmallCharacterImage: View {
    var level: Int
    var size: CGFloat
    var framed: Bool = true

    private var corner: CGFloat { size * 0.24 }

    var body: some View {
        let name = ManmaruStage.imageName(level: level) + "_small"
        ZStack {
            if framed { ManmaruPalette.cream }
            Image(name)
                .resizable()
                .scaledToFit()
                .padding(framed ? size * 0.04 : 0)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: framed ? corner : 0))
    }
}

// 気もちの小さい印（ウィジェット・上のバー用。動かない）
struct ManmaruMoodBadge: View {
    var mood: ManmaruMood
    var size: CGFloat = 14

    var body: some View {
        switch mood {
        case .sleepySad:
            Image(systemName: "moon.zzz.fill").font(.system(size: size)).foregroundStyle(ManmaruPalette.caption)
        case .worried:
            Image(systemName: "drop.fill").font(.system(size: size)).foregroundStyle(Color(red: 0.45, green: 0.7, blue: 1))
        case .happy:
            Image(systemName: "sparkles").font(.system(size: size)).foregroundStyle(ManmaruPalette.yellow)
        case .normal:
            EmptyView()
        }
    }
}

// 気もちの決まったひとこと（AIが使えないときと、ウィジェット用）
enum ManmaruMoodLine {
    static func short(_ mood: ManmaruMood) -> String? {
        switch mood {
        case .sleepySad: return "ねむい…もう寝ようよ"
        case .worried: return "お腹、大丈夫？"
        case .happy: return "きのうはぜんぶできたね！"
        case .normal: return nil
        }
    }
}

// 歩数のバー。20,000歩までを1本にして、10,000 / 15,000 の所に線を引く。
struct StepsGoalBar: View {
    var steps: Int
    var height: CGFloat = 8
    var showLabels = true

    private let maxSteps = 20_000.0

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(ManmaruPalette.background)
                    Capsule().fill(ManmaruPalette.green)
                        .frame(width: width * CGFloat(min(Double(steps) / maxSteps, 1)))
                    ForEach([10_000, 15_000], id: \.self) { goal in
                        Rectangle()
                            .fill(Color.white.opacity(0.7))
                            .frame(width: 2, height: height + 4)
                            .offset(x: width * CGFloat(Double(goal) / maxSteps) - 1)
                    }
                }
            }
            .frame(height: height)
            if showLabels {
                GeometryReader { geometry in
                    ForEach(StepsRule.goals, id: \.self) { goal in
                        Text("\(goal / 1000)k")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(steps >= goal ? ManmaruPalette.yellow : ManmaruPalette.caption)
                            .fixedSize()
                            .position(x: min(geometry.size.width * CGFloat(Double(goal) / maxSteps), geometry.size.width - 8), y: 6)
                    }
                }
                .frame(height: 12)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("歩数 \(steps)歩")
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
