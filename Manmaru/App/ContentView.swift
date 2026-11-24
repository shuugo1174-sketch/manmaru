import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TrackerStore
    @State private var showSettings = false
    @State private var liveActivityOn = false
    @State private var liveActivityMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !store.hasURL {
                        // URLが未設定のとき
                        VStack(spacing: 12) {
                            CharacterImageView(stage: 1, size: 120)
                            Text("設定でURLを貼ってね")
                                .font(.headline)
                            Text("トラッカーの widget.json のURLを\n設定画面で貼ると、まんまるが動き出すよ。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("設定へ行く") { showSettings = true }
                                .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    } else if let feed = store.feed {
                        // 遊び場（画面上部の広めのエリア）
                        CharacterPlaygroundView(stage: feed.stage)

                        // レベルとEX
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Lv \(feed.level)")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                Text(feed.stageName)
                                    .font(.headline)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .clipShape(Capsule())
                                Spacer()
                                Text("\(feed.totalEx) EX")
                                    .font(.headline)
                            }
                            ProgressView(value: feed.progress)
                            HStack {
                                Text("次のレベルまで あと \(feed.exRemaining) EX")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(feed.exInLevel) / \(feed.exNeeded) EX")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // なつき度
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("なつき度")
                                    .font(.headline)
                                Spacer()
                                Text("\(feed.friendship) / 255")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: feed.friendshipProgress)
                                .tint(.pink)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // パラメータ5つ
                        VStack(alignment: .leading, spacing: 8) {
                            Text("パラメータ")
                                .font(.headline)
                            ForEach(feed.parameters) { param in
                                HStack {
                                    Text(param.label)
                                        .fontWeight(.semibold)
                                        .frame(width: 28, alignment: .leading)
                                    Text("Lv \(param.level)")
                                    Spacer()
                                    Text("\(param.totalEx) EX")
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // 今日のタスク
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("今日のタスク")
                                    .font(.headline)
                                Spacer()
                                Text("\(feed.tasksDone) / \(feed.tasksTotal)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(feed.tasks) { task in
                                HStack(spacing: 10) {
                                    Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(task.done ? Color.green : Color.gray)
                                    Text(task.name)
                                        .strikethrough(task.done)
                                        .foregroundStyle(task.done ? .secondary : .primary)
                                    Spacer()
                                    Text("\(task.points) EX")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        if let updated = store.lastUpdated {
                            Text("最終更新：\(updated.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        // URLはあるけど、まだ取れていないとき
                        VStack(spacing: 12) {
                            CharacterImageView(stage: 1, size: 120)
                            if store.isLoading {
                                ProgressView("読み込み中…")
                            } else {
                                Text(store.errorMessage ?? "更新ボタンで取り込むよ。")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }

                    // ボタン類
                    VStack(spacing: 10) {
                        Button {
                            Task { await store.refresh() }
                        } label: {
                            Label("更新する", systemImage: "arrow.clockwise")
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

                        Button {
                            toggleLiveActivity()
                        } label: {
                            Label(
                                liveActivityOn ? "島からしまう" : "島にキャラを出す",
                                systemImage: liveActivityOn ? "rectangle.compress.vertical" : "rectangle.expand.vertical"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        if let message = liveActivityMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                await store.refresh()
            }
            .navigationTitle("まんまる")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task {
                // キャッシュが無ければ、開いたときに1回取る
                if store.feed == nil && store.hasURL {
                    await store.refresh()
                }
            }
        }
    }

    private func toggleLiveActivity() {
        guard let feed = store.feed else {
            liveActivityMessage = "まずデータを取ってね。"
            return
        }
        if liveActivityOn {
            LiveActivityManager.shared.stop()
            liveActivityOn = false
            liveActivityMessage = "島からしまったよ。"
        } else {
            let ok = LiveActivityManager.shared.start(feed: feed)
            liveActivityOn = ok
            liveActivityMessage = ok ? "島に出したよ。8時間で終わるよ。" : "島に出せなかったよ。"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TrackerStore())
}
