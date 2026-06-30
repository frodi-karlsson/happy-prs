import SwiftUI

@main
struct HappyPRsApp: App {
    var body: some Scene {
        MenuBarExtra("Happy PRs", systemImage: "checkmark.seal") {
            Text("Hello")
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)
    }
}
