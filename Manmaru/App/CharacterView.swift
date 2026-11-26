import SwiftUI

// 今日の様子からセリフを選ぶ。同じセリフは続けない。
enum ManmaruSpeech {
    static func line(feed: TrackerFeed, previous: String, justLeveledUp: Bool) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        var lines: [String]
        if justLeveledUp {
            lines = [
                "Lv.\(feed.level)になったよ！いっしょに成長したね！",
                "レベルアップ！きょうは+\(feed.todayPlusEx) EX、ありがとう！"
            ]
        } else if feed.exRemaining <= 30 {
            lines = [
                "あと\(feed.exRemaining) EXでレベルアップ！もう少し！",
                "いまLv.\(feed.level)！次まであと\(feed.exRemaining) EXだよ。"
            ]
        } else if feed.tasksTotal > 0 && feed.tasksDone >= feed.tasksTotal {
            lines = [
                "\(feed.tasksDone)/\(feed.tasksTotal)できた！ぜんぶ達成、おつかれさま！",
                "きょうは+\(feed.todayPlusEx) EX！ぜんぶできてうれしいね。"
            ]
        } else if feed.tasksDone > 0 {
            lines = [
                "もう\(feed.tasksDone)/\(feed.tasksTotal)できたね！その調子！",
                "きょうは+\(feed.todayPlusEx) EX！次のレベルまであと\(feed.exRemaining) EXだよ。"
            ]
        } else {
            lines = [
                "きょうは\(feed.tasksDone)/\(feed.tasksTotal)できたよ。まずはひとつ、いっしょに！",
                "いまLv.\(feed.level)！あと\(feed.exRemaining) EXでまた育つよ。"
            ]
        }
        if !justLeveledUp {
            if hour >= 5 && hour < 12 {
                lines.append("おはよう！きょうの\(feed.tasksDone)/\(feed.tasksTotal)、自分のペースでね。")
            } else if hour >= 20 || hour < 5 {
                lines.append("きょうは+\(feed.todayPlusEx) EX。夜はゆっくり休もうね。")
            } else {
                lines.append("Lv.\(feed.level)のぼくと、午後もひとつずつ！きょうは+\(feed.todayPlusEx) EXだよ。")
            }
        }
        return lines.filter { $0 != previous }.randomElement() ?? lines.first ?? "いっしょに育とうね。"
    }
}

struct CharacterPlaygroundView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var feed: TrackerFeed
    var justLeveledUp: Bool

    @State private var speech = ""
    @State private var hopToken = 0
    @State private var isHappy = false

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 0) {
                Text(speech)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(14)
                    .background(ManmaruPalette.border)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                Image(systemName: "triangle.fill")
                    .font(.system(size: 16))
                    .rotationEffect(.degrees(180))
                    .foregroundStyle(ManmaruPalette.border)
                    .offset(y: -3)
            }
            .accessibilityElement(children: .combine)

            Button {
                speak()
                hopToken += 1
            } label: {
                ManmaruCharacterImage(level: feed.level, size: 190)
                    .phaseAnimator([false, true]) { content, phase in
                        content
                            .scaleEffect(reduceMotion ? 1 : (phase ? 1.025 : 0.985))
                            .rotationEffect(.degrees(reduceMotion ? 0 : (phase ? 2 : -2)))
                            .offset(y: reduceMotion ? 0 : (phase ? -3 : 3))
                    } animation: { _ in
                        .easeInOut(duration: 1.8)
                    }
                    .offset(y: isHappy && !reduceMotion ? -25 : 0)
                    .rotationEffect(.degrees(isHappy && !reduceMotion ? -8 : 0))
                    .scaleEffect(isHappy && !reduceMotion ? 1.06 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.45), value: isHappy)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(ManmaruStage.name(level: feed.level))と話す")
            .accessibilityHint("タップするとセリフが変わります")
            .padding(.vertical, 8)
            .task(id: hopToken) {
                guard hopToken > 0 else { return }
                isHappy = true
                do {
                    try await Task.sleep(nanoseconds: 280_000_000)
                } catch { return }
                isHappy = false
            }

            Text("タップして話しかけてね")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(ManmaruPalette.caption)
        }
        .frame(maxWidth: .infinity)
        .manmaruCard()
        .onAppear { speak() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { speak() }
        }
        .onChange(of: feed) { _, _ in speak() }
        .onChange(of: justLeveledUp) { _, value in
            if value { speak() }
        }
    }

    private func speak() {
        speech = ManmaruSpeech.line(feed: feed, previous: speech, justLeveledUp: justLeveledUp)
    }
}

struct LevelUpCelebrationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let celebration: LevelUpCelebration
    let dismiss: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            ManmaruPalette.background.opacity(0.96).ignoresSafeArea()
            confetti
                .allowsHitTesting(false)
            VStack(spacing: 20) {
                Text(celebration.evolved ? "しんかした！" : "レベルアップ！")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(ManmaruPalette.yellow)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("Lv.\(celebration.level)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                if celebration.evolved {
                    Text(ManmaruStage.name(level: celebration.level))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
                ManmaruCharacterImage(level: celebration.level, size: 210)
                    .phaseAnimator([false, true]) { content, phase in
                        content
                            .offset(y: phase && !reduceMotion ? -25 : 0)
                            .rotationEffect(.degrees(reduceMotion ? 0 : (phase ? 7 : -7)))
                    } animation: { _ in
                        .spring(response: 0.35, dampingFraction: 0.5)
                    }
                Text("タップでとじる")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(ManmaruPalette.caption)
            }
            .padding(24)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.55)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.45, dampingFraction: 0.55), value: appeared)
        }
        .foregroundStyle(.white)
        .contentShape(Rectangle())
        .onTapGesture(perform: dismiss)
        .accessibilityAddTraits(.isModal)
        .task {
            appeared = true
            do {
                try await Task.sleep(nanoseconds: 2_500_000_000)
            } catch { return }
            dismiss()
        }
    }

    private var confetti: some View {
        GeometryReader { geometry in
            ForEach(0..<28, id: \.self) { index in
                RoundedRectangle(cornerRadius: index.isMultiple(of: 2) ? 5 : 1)
                    .fill(confettiColor(index))
                    .frame(width: 8, height: index.isMultiple(of: 2) ? 8 : 16)
                    .rotationEffect(.degrees(appeared ? Double(index * 47) : 0))
                    .position(
                        x: geometry.size.width * CGFloat((index * 37) % 100) / 100,
                        y: appeared && !reduceMotion
                            ? geometry.size.height + 30
                            : geometry.size.height * CGFloat((index * 19) % 100) / 100
                    )
                    .opacity(reduceMotion ? 0.35 : (appeared ? 0 : 1))
                    .animation(
                        .easeIn(duration: 2.2).delay(Double(index % 7) * 0.04),
                        value: appeared
                    )
            }
        }
    }

    private func confettiColor(_ index: Int) -> Color {
        switch index % 3 {
        case 0: return ManmaruPalette.yellow
        case 1: return ManmaruPalette.pink
        default: return ManmaruPalette.green
        }
    }
}
