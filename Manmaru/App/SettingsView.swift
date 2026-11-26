import SwiftUI
import WidgetKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TrackerStore
    @State private var urlText = ""
    @State private var statusMessage: String?
    @State private var isTesting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("トラッカーのJSON")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        TextField("https://…/blobs/widget.json", text: $urlText, axis: .vertical)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .lineLimit(2...5)
                            .padding(12)
                            .background(ManmaruPalette.background)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        PasteButton(payloadType: String.self) { strings in
                            if let text = strings.first { urlText = text }
                        }
                        .buttonStyle(.bordered)
                        Text("widget.jsonのURLを貼ってね。トラッカーのURLはここから作るよ。")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(ManmaruPalette.caption)
                    }
                    .manmaruCard()

                    VStack(spacing: 12) {
                        Button("保存する") { save() }
                            .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isLoading)
                        Button(isTesting ? "取得中…" : "テスト取得") {
                            Task { await test() }
                        }
                        .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isLoading || isTesting)
                        Button("クリア", role: .destructive) { clear() }
                            .disabled(store.isLoading)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .manmaruCard()

                    if let message = statusMessage {
                        Text(message)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .manmaruCard()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("AIと歩数")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Label(ManmaruAI.statusText, systemImage: ManmaruAI.isAvailable ? "checkmark.seal.fill" : "info.circle")
                        Label(stepsStatusText, systemImage: "figure.walk")
                        Text("AIはiPhoneの中だけで動くよ。データは外に送らないよ。")
                    }
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(ManmaruPalette.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .manmaruCard()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("いまの保存")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                        Text("JSONのURL：\(savedURLText)")
                        Text("トラッカーのURL：\(savedTrackerText)")
                        Text("ウィジェットで表示されないときは、ウィジェットを長押しして「ウィジェットを編集」から同じJSONのURLを貼ってね。")
                    }
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(ManmaruPalette.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .manmaruCard()
                }
                .padding(18)
            }
            .background(ManmaruPalette.background)
            .navigationTitle("設定")
            .toolbarBackground(ManmaruPalette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear { urlText = store.jsonURLString }
        }
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .tint(ManmaruPalette.yellow)
        .preferredColorScheme(.dark)
    }

    private var savedURLText: String {
        let saved = store.jsonURLString
        return saved.isEmpty ? "未設定" : saved
    }

    private var stepsStatusText: String {
        if let steps = HealthSteps.shared.todaySteps {
            return "ヘルスケアから歩数を読めたよ（きょう \(steps)歩）。"
        }
        if !HealthSteps.shared.isAvailable {
            return "ヘルスケアが使えないよ。トラッカーの歩数を出すね。"
        }
        return "歩数はまだ読めてないよ。設定 → ヘルスケア → データアクセス で、まんまるを許可してね。"
    }

    private var savedTrackerText: String {
        let saved = AppGroup.defaults?.string(forKey: AppGroup.trackerUrlKey) ?? ""
        return saved.isEmpty ? "未設定" : saved
    }

    private func save() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard TrackerURLs.feedURL(from: trimmed) != nil else {
            statusMessage = "URLの形がおかしいよ。確認してね。"
            return
        }
        if trimmed != store.jsonURLString { resetData() }
        AppGroup.defaults?.set(trimmed, forKey: AppGroup.widgetJsonUrlKey)
        if let tracker = TrackerURLs.trackerURL(from: trimmed) {
            AppGroup.defaults?.set(tracker.absoluteString, forKey: AppGroup.trackerUrlKey)
        }
        statusMessage = "保存したよ。"
        Task { await store.refresh() }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func test() async {
        isTesting = true
        defer { isTesting = false }
        let ok = await store.testFetch(urlString: urlText)
        statusMessage = ok
            ? "取れたよ。Lv.\(store.feed?.level ?? 1)・\(store.feed?.totalEx ?? 0) EX。URLは「保存する」で保存してね。"
            : "取れなかったよ。URLを確認してね。"
    }

    private func resetData() {
        AppGroup.defaults?.removeObject(forKey: AppGroup.cachedJsonKey)
        AppGroup.defaults?.removeObject(forKey: AppGroup.lastSeenLevelKey)
        store.feed = nil
        store.lastUpdated = nil
        store.errorMessage = nil
        store.celebration = nil
        LiveActivityManager.shared.stop()
    }

    private func clear() {
        AppGroup.defaults?.removeObject(forKey: AppGroup.widgetJsonUrlKey)
        AppGroup.defaults?.removeObject(forKey: AppGroup.trackerUrlKey)
        resetData()
        urlText = ""
        statusMessage = "消したよ。"
        WidgetCenter.shared.reloadAllTimelines()
    }
}
