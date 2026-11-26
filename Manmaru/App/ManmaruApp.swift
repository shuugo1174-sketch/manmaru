import SwiftUI

@main
struct ManmaruApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = TrackerStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .task {
                    // キャッシュがあっても、起動時に新しいJSONを取得する。
                    await wakeUp()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await wakeUp() }
                    }
                }
        }
    }

    /// 開いたとき：データ・歩数を取り直して、上のバーのまんまるをつなぎ直す（消えていたら出し直す）。
    @MainActor
    private func wakeUp() async {
        if store.hasURL { await store.refresh() }
        await HealthSteps.shared.refresh()
        LiveActivityManager.shared.restoreIfWanted(feed: store.feed)
    }
}
