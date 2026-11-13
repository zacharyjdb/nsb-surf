import SwiftUI

@main
struct NSBSurfApp: App {
    @State private var store = ForecastStore()

    var body: some Scene {
        WindowGroup {
            SpotListView()
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
