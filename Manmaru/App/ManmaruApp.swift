import SwiftUI

@main
struct ManmaruApp: App {
    @StateObject private var store = TrackerStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
