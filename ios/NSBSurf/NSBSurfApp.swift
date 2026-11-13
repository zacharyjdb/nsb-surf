import SwiftUI

@main
struct NSBSurfApp: App {
    @State private var store = ForecastStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.light)
                .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    @Environment(ForecastStore.self) private var store

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") { HomeView() }
            Tab("Spots", systemImage: "water.waves") { SpotListView() }
        }
        .task { await store.refresh() }
    }
}
