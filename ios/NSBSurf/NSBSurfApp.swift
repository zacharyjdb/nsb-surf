import SwiftUI
import UIKit

@main
struct NSBSurfApp: App {
    @State private var store = ForecastStore()

    init() {
        // The same squared-off DIN in the UIKit-drawn bars, so they match the SwiftUI screens.
        let nav = UINavigationBar.appearance()
        if let f = UIFont(name: "DINAlternate-Bold", size: 19) { nav.titleTextAttributes = [.font: f] }
        if let f = UIFont(name: "DINCondensed-Bold", size: 42) { nav.largeTitleTextAttributes = [.font: f] }
        if let f = UIFont(name: "DINAlternate-Bold", size: 10) {
            UITabBarItem.appearance().setTitleTextAttributes([.font: f], for: .normal)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    @Environment(ForecastStore.self) private var store

    var body: some View {
        TabView {
            Tab("Home", image: "TabWave") { HomeView() }
            Tab("Spots", systemImage: "water.waves") { SpotListView() }
        }
        .task { await store.refresh() }
    }
}
