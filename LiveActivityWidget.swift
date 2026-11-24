import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Dynamic Island の表示
// ManmaruAttributes はアプリ側の LiveActivityManager.swift と同じファイルを使う
// （project.yml でウィジェットターゲットにも同じファイルを入れている）。
// ライブアクティビティはアプリから直接データを渡すので、App Group は要らない。

struct ManmaruLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ManmaruAttributes.self) { context in
            // ロック画面の表示
            HStack(spacing: 10) {
                WidgetCharacterView(stage: context.attributes.stage, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text("まんまる Lv \(context.state.level)")
                        .font(.headline)
                    ProgressView(value: progress(of: context.state))
                    Text("\(context.state.exInLevel) / \(exNeeded(of: context.state)) EX")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("タスク \(context.state.tasksDone)/\(context.state.tasksTotal)")
                    .font(.caption)
            }
            .padding()
            .activityBackgroundTint(Color.orange.opacity(0.15))
            .activitySystemActionForegroundColor(Color.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                // 広げた表示：キャラ＋レベル＋EXバー＋今日のタスクの進み具合
                DynamicIslandExpandedRegion(.leading) {
                    WidgetCharacterView(stage: context.attributes.stage, size: 48)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Lv \(context.state.level)")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        ProgressView(value: progress(of: context.state))
                        Text("タスク \(context.state.tasksDone) / \(context.state.tasksTotal)")
                            .font(.caption)
                        moodText(for: context.state.mood)
                            .font(.caption)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.state.totalEx) EX ・ \(context.state.exInLevel) / \(exNeeded(of: context.state)) EX")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                // 島の小さい表示：キャラ
                WidgetCharacterView(stage: context.attributes.stage, size: 22)
            } compactTrailing: {
                Text("Lv\(context.state.level)")
                    .font(.caption)
                    .fontWeight(.bold)
            } minimal: {
                WidgetCharacterView(stage: context.attributes.stage, size: 22)
            }
            .keylineTint(Color.orange)
        }
    }

    // JSONの exToNextLevel は「残り」なので、合計は exInLevel + exToNextLevel。
    private func exNeeded(of state: ManmaruAttributes.ContentState) -> Int {
        state.exInLevel + state.exToNextLevel
    }

    private func progress(of state: ManmaruAttributes.ContentState) -> Double {
        let needed = exNeeded(of: state)
        guard needed > 0 else { return 0 }
        return min(max(Double(state.exInLevel) / Double(needed), 0), 1)
    }

    // mood で島の表示を変える
    @ViewBuilder
    private func moodText(for mood: String) -> some View {
        switch mood {
        case "sleep":
            Text("Zzz… 寝てるよ")
        case "run":
            Text("走ってるよ →")
        case "peek":
            Text("！ ひょっこり")
        default:
            Text("待ってるよ")
        }
    }
}
