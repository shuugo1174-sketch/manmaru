import ActivityKit
import Foundation
import Combine

// MARK: - Dynamic Island のライブアクティビティ
// 島の中にキャラ画像＋レベル。広げた表示はキャラ＋レベル＋EXバー＋タスクの進み具合。
// mood（"run" / "sleep" / "peek"）を約20秒ごとに変えて、島のペットにも生きてる感を出す。
// Live Activityは8時間で終わる（iOSの仕様）。

struct ManmaruAttributes: ActivityAttributes {
    // 変わらないもの
    var stage: Int
    var stageName: String

    // 変わるもの
    struct ContentState: Codable, Hashable {
        var level: Int
        var totalEx: Int
        var exInLevel: Int
        var exToNextLevel: Int
        var tasksDone: Int
        var tasksTotal: Int
        var mood: String // "run" / "sleep" / "peek" / "idle"
    }
}

@MainActor
final class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    private var activity: Activity<ManmaruAttributes>?
    private var moodTimer: Timer?
    private var currentFeed: TrackerFeed?
    private var moodIndex = 0

    private let moods = ["run", "sleep", "peek", "idle"]

    var isActive: Bool { activity != nil }

    /// 上のバーにまんまるを出しておきたいか（「島にキャラを出す」でオン、「島からしまう」でオフ）
    var isWanted: Bool {
        get { UserDefaults.standard.bool(forKey: AppGroup.liveActivityWantedKey) }
        set { UserDefaults.standard.set(newValue, forKey: AppGroup.liveActivityWantedKey) }
    }

    /// アプリを開いたときに呼ぶ。前のライブアクティビティが残っていればつなぎ直す。
    /// 8時間で消えていたら（iOSの決まり）、出しておきたいときは出し直す。
    func restoreIfWanted(feed: TrackerFeed?) {
        if activity == nil {
            let running = Activity<ManmaruAttributes>.activities.filter { $0.activityState == .active }
            if let first = running.first {
                activity = first
                startMoodTimer()
                // 2つ以上あったら、残りは消す
                for extra in running.dropFirst() {
                    Task { await extra.end(nil, dismissalPolicy: .immediate) }
                }
            }
        } else if let current = activity, current.activityState != .active {
            activity = nil
        }
        guard let feed else { return }
        if activity != nil {
            update(feed: feed)
        } else if isWanted {
            start(feed: feed)
        }
    }

    /// ライブアクティビティを始める。すでにあれば何もしない。
    @discardableResult
    func start(feed: TrackerFeed) -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        isWanted = true
        if activity != nil { return true }
        currentFeed = feed
        let attributes = ManmaruAttributes(
            stage: ManmaruStage.number(level: feed.level),
            stageName: ManmaruStage.name(level: feed.level)
        )
        let state = ManmaruAttributes.ContentState(
            level: feed.level,
            totalEx: feed.totalEx,
            exInLevel: feed.exInLevel,
            exToNextLevel: feed.exToNextLevel,
            tasksDone: feed.tasksDone,
            tasksTotal: feed.tasksTotal,
            mood: "idle"
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: Date().addingTimeInterval(8 * 60 * 60)),
                pushType: nil
            )
            startMoodTimer()
            return true
        } catch {
            return false
        }
    }

    /// 最新のデータで更新する（moodは今のものを残す）。
    func update(feed: TrackerFeed) {
        currentFeed = feed
        guard let activity else { return }
        let state = ManmaruAttributes.ContentState(
            level: feed.level,
            totalEx: feed.totalEx,
            exInLevel: feed.exInLevel,
            exToNextLevel: feed.exToNextLevel,
            tasksDone: feed.tasksDone,
            tasksTotal: feed.tasksTotal,
            mood: activity.content.state.mood
        )
        Task { await activity.update(.init(state: state, staleDate: Date().addingTimeInterval(8 * 60 * 60))) }
    }

    func stop() {
        isWanted = false
        moodTimer?.invalidate()
        moodTimer = nil
        guard let activity else { return }
        let state = activity.content.state
        Task { await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate) }
        self.activity = nil
        currentFeed = nil
    }

    /// 約20秒ごとに mood を変えて Activity.update する。
    private func startMoodTimer() {
        moodTimer?.invalidate()
        moodTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.cycleMood()
            }
        }
    }

    private func cycleMood() {
        guard let activity, let feed = currentFeed else { return }
        moodIndex = (moodIndex + 1) % moods.count
        let state = ManmaruAttributes.ContentState(
            level: feed.level,
            totalEx: feed.totalEx,
            exInLevel: feed.exInLevel,
            exToNextLevel: feed.exToNextLevel,
            tasksDone: feed.tasksDone,
            tasksTotal: feed.tasksTotal,
            mood: moods[moodIndex]
        )
        Task { await activity.update(.init(state: state, staleDate: Date().addingTimeInterval(8 * 60 * 60))) }
    }
}
