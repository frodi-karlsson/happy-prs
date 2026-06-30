import HappyPRs
import SwiftUI

@main
struct HappyPRsApp: App {
  @State private var settings: HappyPRs.Settings
  @State private var store: PRStore

  init() {
    let settings = HappyPRs.Settings()
    let auth = GitHubAuth()
    let client = GitHubClient(tokenProvider: { try auth.token() })
    let fetcher = PRFetcher(client: client)
    let teamResolver = TeamResolver(client: client)
    let store = PRStore(
      auth: auth, fetcher: fetcher,
      teamResolver: teamResolver, settings: settings,
      notifier: Notifier.shared)
    _settings = State(initialValue: settings)
    _store = State(initialValue: store)
  }

  var body: some Scene {
    MenuBarExtra {
      MenuView(store: store)
        .task(id: "background-loop") { await runBackgroundLoop() }
    } label: {
      HStack(spacing: 2) {
        Image(systemName: "checkmark.seal")
        let count = store.prs.filter { $0.bucket.needsApproval }.count
        if count > 0 {
          Text("\(count)")
        }
      }
    }
    .menuBarExtraStyle(.window)

    Window("Settings", id: "settings") {
      SettingsView(settings: settings)
    }
    .windowResizability(.contentSize)
    .defaultPosition(.center)
  }

  private func runBackgroundLoop() async {
    Notifier.shared.requestAuthorization()
    await store.refresh()
    while !Task.isCancelled {
      // Re-read on each iteration so changes in Settings take effect at
      // the next refresh tick rather than only after relaunch.
      let interval = TimeInterval(settings.refreshIntervalSeconds)
      try? await Task.sleep(for: .seconds(interval))
      if Task.isCancelled { break }
      await store.refresh()
    }
  }
}
