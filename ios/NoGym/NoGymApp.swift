import SwiftUI

/// The app's entry point. It creates the store once and hands it to every screen.
@main
struct NoGymApp: App {
    @State private var store = RoutineStore()

    var body: some Scene {
        WindowGroup {
            RoutineListView()
                .environment(store)
        }
    }
}
