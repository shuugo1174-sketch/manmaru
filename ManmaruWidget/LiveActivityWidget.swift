import WidgetKit
import SwiftUI
import ActivityKit

struct ManmaruLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ManmaruAttributes.self) { context in
            HStack(spacing: 14) {
                ManmaruCharacterImage(level: context.state.level, size: 72)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("Lv.\(context.state.level)")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                        Text(ManmaruStage.name(level: context.state.level))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(ManmaruPalette.caption)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    ManmaruProgressBar(value: progress(of: context.state), height: 8)
                    Text("あと \(max(context.state.exToNextLevel, 0)) EX · \(context.state.tasksDone)/\(context.state.tasksTotal) できた")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(ManmaruPalette.caption)
                }
            }
            .foregroundStyle(.white)
            .manmaruCard()
            .padding(8)
            .activityBackgroundTint(ManmaruPalette.background)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ManmaruCharacterImage(level: context.state.level, size: 52)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Lv.\(context.state.level)")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 5) {
                        Text(ManmaruStage.name(level: context.state.level))
                            .foregroundStyle(ManmaruPalette.yellow)
                        Text("\(context.state.tasksDone)/\(context.state.tasksTotal) できた")
                            .foregroundStyle(.white)
                        Text(moodText(for: context.state.mood))
                            .foregroundStyle(ManmaruPalette.caption)
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ManmaruProgressBar(value: progress(of: context.state), height: 8)
                        Text("\(context.state.exInLevel) / \(exNeeded(of: context.state)) EX · 合計 \(context.state.totalEx) EX")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(ManmaruPalette.caption)
                    }
                }
            } compactLeading: {
                ManmaruCharacterImage(level: context.state.level, size: 22)
            } compactTrailing: {
                Text("Lv.\(context.state.level)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(ManmaruPalette.yellow)
            } minimal: {
                ManmaruCharacterImage(level: context.state.level, size: 22)
            }
            .keylineTint(ManmaruPalette.yellow)
        }
    }

    private func exNeeded(of state: ManmaruAttributes.ContentState) -> Int {
        state.exInLevel + state.exToNextLevel
    }

    private func progress(of state: ManmaruAttributes.ContentState) -> Double {
        let needed = exNeeded(of: state)
        guard needed > 0 else { return 0 }
        return min(max(Double(state.exInLevel) / Double(needed), 0), 1)
    }

    private func moodText(for mood: String) -> String {
        switch mood {
        case "sleep": return "Zzz… 休憩中だよ"
        case "run": return "いっしょに進もう！"
        case "peek": return "ひょっこり！"
        default: return "待ってるよ"
        }
    }
}
