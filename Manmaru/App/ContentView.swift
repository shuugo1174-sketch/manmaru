import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TrackerStore
    @State private var showSettings = false
    @State private var liveActivityOn = false
    @State private var liveActivityMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if let feed = store.feed {
                        CharacterPlaygroundView(feed: feed, justLeveledUp: store.celebration != nil)
                        levelCard(feed)
                        friendshipCard(feed)
                        parameterLink(feed)
                        tasksCard(feed)
                        if let updated = store.lastUpdated {
                            Text("最終更新：\(updated.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(ManmaruPalette.caption)
                        }
                    } else {
                        welcomeCard
                    }
                    if let error = store.errorMessage, store.hasURL {
                        Text(error)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(ManmaruPalette.caption)
                            .multilineTextAlignment(.center)
                    }
                    controls
                }
                .padding(18)
            }
            .background(ManmaruPalette.background)
            .refreshable { await store.refresh() }
            .navigationTitle("まんまる")
            .toolbarBackground(ManmaruPalette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("設定")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .onAppear { liveActivityOn = LiveActivityManager.shared.isActive }
            .onChange(of: showSettings) { _, isPresented in
                if !isPresented { liveActivityOn = LiveActivityManager.shared.isActive }
            }
        }
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .tint(ManmaruPalette.yellow)
        .overlay {
            if let celebration = store.celebration, !showSettings {
                LevelUpCelebrationView(celebration: celebration) {
                    if store.celebration?.id == celebration.id {
                        store.celebration = nil
                    }
                }
                .id(celebration.id)
            }
        }
    }

    private var welcomeCard: some View {
        VStack(spacing: 18) {
            ManmaruCharacterImage(level: 1, size: 160)
            Text(store.hasURL ? "まんまるに会いにいこう" : "設定でURLを貼ってね")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            if store.isLoading {
                ProgressView("読み込み中…")
            } else {
                Text(store.hasURL ? "更新ボタンで今日のデータを取り込むよ。" : "トラッカーのwidget.jsonのURLを貼ると、\nまんまるが育つよ。")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(ManmaruPalette.caption)
                    .multilineTextAlignment(.center)
            }
            Button("設定を開く") { showSettings = true }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .manmaruCard()
    }

    private func levelCard(_ feed: TrackerFeed) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Lv.\(feed.level)")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.7)
                Spacer()
                Text(ManmaruStage.name(level: feed.level))
                    .foregroundStyle(ManmaruPalette.yellow)
            }
            HStack {
                Text("合計 \(feed.totalEx) EX")
                Spacer()
                Text("\(feed.exInLevel) / \(feed.exNeeded) EX")
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(ManmaruPalette.caption)
            ManmaruProgressBar(value: feed.progress, height: 12)
            Text("次のレベルまで あと \(feed.exRemaining) EX")
                .font(.system(size: 15, weight: .bold, design: .rounded))
            todayLine(feed)
            if feed.todayMinusEx > 0 {
                Text("きょうのマイナス: -\(feed.todayMinusEx) EX")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(ManmaruPalette.pink)
            }
        }
        .manmaruCard()
    }

    private func todayLine(_ feed: TrackerFeed) -> some View {
        let summary = feed.summaryDisplay
        return (Text("\(summary.label): ")
            + Text("+\(summary.plusEx) EX").foregroundColor(ManmaruPalette.green)
            + Text(" (\(summary.done)/\(summary.total) できた)"))
            .font(.system(size: 15, weight: .bold, design: .rounded))
    }

    private func friendshipCard(_ feed: TrackerFeed) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("なつき度 \(feed.friendship) / 255")
                .font(.system(size: 17, weight: .bold, design: .rounded))
            ManmaruProgressBar(value: feed.friendshipProgress, tint: ManmaruPalette.pink)
        }
        .manmaruCard()
    }

    private func parameterLink(_ feed: TrackerFeed) -> some View {
        NavigationLink {
            ParameterScreen()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("パラメータ・スキル")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(ManmaruPalette.yellow)
                }
                ForEach(feed.parameters.indices, id: \.self) { index in
                    let parameter = feed.parameters[index]
                    HStack {
                        Text(parameter.label.isEmpty ? feed.parameterLabel(for: parameter.key) : parameter.label)
                            .frame(minWidth: 28, alignment: .leading)
                        Text("Lv.\(parameter.level)")
                        Spacer()
                        Text("\(parameter.totalEx) EX")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(ManmaruPalette.caption)
                    }
                }
                Text("金スキルと技を見てみよう")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(ManmaruPalette.caption)
            }
            .manmaruCard()
        }
        .buttonStyle(.plain)
    }

    private func tasksCard(_ feed: TrackerFeed) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("今日のタスク")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Spacer()
                Text("\(feed.tasksDone) / \(feed.tasksTotal)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(ManmaruPalette.caption)
            }
            ForEach(feed.tasks.indices, id: \.self) { index in
                let task = feed.tasks[index]
                HStack(spacing: 12) {
                    Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(task.done ? ManmaruPalette.green : ManmaruPalette.caption)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.name.isEmpty ? "タスク" : task.name)
                            .strikethrough(task.done)
                            .foregroundStyle(task.done ? ManmaruPalette.caption : Color.white)
                        HStack(spacing: 8) {
                            Text(feed.parameterLabel(for: task.parameter))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(ManmaruPalette.border)
                                .clipShape(Capsule())
                            Text("\(task.points) EX")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(ManmaruPalette.yellow)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(task.done ? "完了" : "未完了")
            }
            if feed.tasks.isEmpty {
                Text("今日のタスクはまだないよ。")
                    .foregroundStyle(ManmaruPalette.caption)
            }
        }
        .manmaruCard()
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Button {
                Task { await store.refresh() }
            } label: {
                Label(store.isLoading ? "更新中…" : "更新する", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(store.isLoading || !store.hasURL)

            if let trackerURL = store.trackerURL {
                Link(destination: trackerURL) {
                    Label("トラッカーを開く", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button { toggleLiveActivity() } label: {
                Label(liveActivityOn ? "島からしまう" : "島にキャラを出す", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(store.feed == nil && !liveActivityOn)

            if let message = liveActivityMessage {
                Text(message)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(ManmaruPalette.caption)
            }
        }
    }

    private func toggleLiveActivity() {
        if LiveActivityManager.shared.isActive {
            LiveActivityManager.shared.stop()
            liveActivityOn = false
            liveActivityMessage = "島からしまったよ。"
        } else if let feed = store.feed {
            let ok = LiveActivityManager.shared.start(feed: feed)
            liveActivityOn = ok
            liveActivityMessage = ok ? "島に出したよ。8時間で終わるよ。" : "島に出せなかったよ。"
        }
    }
}
