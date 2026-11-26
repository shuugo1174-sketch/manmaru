import SwiftUI

// きょうの歩数。iPhoneのヘルスケアから読む（だめならトラッカーのJSON）。
// 目標ライン 10,000 / 15,000 / 20,000 歩。
struct StepsCard: View {
    var feed: TrackerFeed
    @ObservedObject private var health = HealthSteps.shared

    private var steps: Int? { health.todaySteps ?? StepsRule.todaySteps(feed: feed) }

    var body: some View {
        if let steps {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("きょうの歩数")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Spacer()
                    Text("+\(StepsRule.ex(for: steps)) EX")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(ManmaruPalette.green)
                }
                Text("\(steps.formatted()) 歩")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                StepsGoalBar(steps: steps, height: 12)
                if let next = StepsRule.nextGoal(after: steps) {
                    Text("あと \((next - steps).formatted()) 歩で +\(StepsRule.ex(for: next)) EX")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(ManmaruPalette.caption)
                } else {
                    Text("20,000歩こえ！さいこう！")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(ManmaruPalette.yellow)
                }
            }
            .manmaruCard()
        }
    }
}
