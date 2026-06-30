import HappyPRs
import SwiftUI

@main
struct HappyPRsApp: App {
  @State private var store: PRStore = HappyPRsApp.makeStore()
  @State private var refreshTask: Task<Void, Never>? = nil

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
  }

  @MainActor
  private static func makeStore() -> PRStore {
    let auth = GitHubAuth()
    let client = GitHubClient(tokenProvider: { try auth.token() })
    let fetcher = PRFetcher(client: client)
    let teamResolver = TeamResolver(client: client)
    let settings = Settings()
    let notifier = Notifier.shared
    return PRStore(
      auth: auth, fetcher: fetcher,
      teamResolver: teamResolver, settings: settings,
      notifier: notifier)
  }

  private func runBackgroundLoop() async {
    Notifier.shared.requestAuthorization()
    let interval = TimeInterval(Settings().refreshIntervalSeconds)
    await store.refresh()
    while !Task.isCancelled {
      try? await Task.sleep(for: .seconds(interval))
      if Task.isCancelled { break }
      await store.refresh()
    }
  }
}
