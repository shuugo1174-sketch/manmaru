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
                    if store.hasURL { await store.refresh() }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active && store.hasURL {
                        Task { await store.refresh() }
                    }
                }
        }
    }
}
