import SwiftUI

@main
struct AgareApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 460, height: 400)
        .windowResizability(.contentMinSize)
    }
}
