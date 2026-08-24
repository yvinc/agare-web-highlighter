import SwiftUI

@main
struct AgareApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 440, height: 360)
        .windowResizability(.contentSize)
    }
}
