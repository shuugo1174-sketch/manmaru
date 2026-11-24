import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TrackerStore

    @State private var urlText: String = ""
    @State private var statusMessage: String?
    @State private var isTesting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("トラッカーのJSON") {
                    TextField("https://…/blobs/widget.json", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Text("widget.json のURLを貼ってね。トラッカーのURLはここから作るよ。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("保存する") { save() }
                        .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button("テスト取得") {
                        Task { await test() }
                    }
                    .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || isTesting)

                    Button("クリア", role: .destructive) { clear() }
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .font(.subheadline)
                    }
                }

                Section("いまの保存") {
                    Text("JSONのURL：\(savedURLText)")
                    Text("トラッカーのURL：\(savedTrackerText)")
                }
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear {
                urlText = AppGroup.defaults?.string(forKey: AppGroup.widgetJsonUrlKey) ?? ""
            }
        }
    }

    private var savedURLText: String {
        let saved = AppGroup.defaults?.string(forKey: AppGroup.widgetJsonUrlKey) ?? ""
        return saved.isEmpty ? "未設定" : saved
    }

    private var savedTrackerText: String {
        let saved = AppGroup.defaults?.string(forKey: AppGroup.trackerUrlKey) ?? ""
        return saved.isEmpty ? "未設定" : saved
    }

    private func save() {
        let trimmed = urlText.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed), !trimmed.isEmpty else {
            statusMessage = "URLの形がおかしいよ。確認してね。"
            return
        }
        AppGroup.defaults?.set(trimmed, forKey: AppGroup.widgetJsonUrlKey)
        // トラッカーのURLも同じ場所に保存する
        if let tracker = TrackerURLs.trackerURL(from: trimmed) {
            AppGroup.defaults?.set(tracker.absoluteString, forKey: AppGroup.trackerUrlKey)
        }
        statusMessage = "保存したよ。"
        Task { await store.refresh() }
        _ = url
    }

    private func test() async {
        isTesting = true
        defer { isTesting = false }
        let ok = await store.testFetch(urlString: urlText)
        statusMessage = ok ? "取れたよ。Lv \(store.feed?.level ?? 0)・\(store.feed?.totalEx ?? 0) EX" : "取れなかったよ。URLを確認してね。"
    }

    private func clear() {
        AppGroup.defaults?.removeObject(forKey: AppGroup.widgetJsonUrlKey)
        AppGroup.defaults?.removeObject(forKey: AppGroup.trackerUrlKey)
        AppGroup.defaults?.removeObject(forKey: AppGroup.cachedJsonKey)
        urlText = ""
        store.feed = nil
        statusMessage = "消したよ。"
    }
}

#Preview {
    SettingsView()
        .environmentObject(TrackerStore())
}
