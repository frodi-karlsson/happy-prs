import AppKit
import HappyPRs
import SwiftUI

@main
struct HappyPRsApp: App {
  // Owning the store + settings on the AppDelegate lets the background
  // refresh loop live for the entire app process lifetime, rather than
  // being tied to the popover's appear/disappear (`.task` on
  // `MenuView` was being cancelled every time the popover closed,
  // which silently broke notifications for PRs arriving while the
  // popover wasn't open).
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    MenuBarExtra {
      MenuView(store: appDelegate.store)
    } label: {
      HStack(spacing: 2) {
        Image(systemName: "checkmark.seal")
        let count = appDelegate.store.prs.filter { $0.bucket.needsApproval }.count
        if count > 0 {
          Text("\(count)")
        }
      }
    }
    .menuBarExtraStyle(.window)

    Window("Settings", id: "settings") {
      SettingsView(settings: appDelegate.settings)
    }
    .windowResizability(.contentSize)
    .defaultPosition(.center)
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let settings: HappyPRs.Settings
  let store: PRStore
  private var refreshTask: Task<Void, Never>?

  override init() {
    let settings = HappyPRs.Settings()
    let auth = GitHubAuth()
    let client = GitHubClient(tokenProvider: { try auth.token() })
    let fetcher = PRFetcher(client: client)
    let teamResolver = TeamResolver(client: client)
    self.settings = settings
    self.store = PRStore(
      auth: auth, fetcher: fetcher,
      teamResolver: teamResolver, settings: settings,
      notifier: Notifier.shared)
    super.init()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    Notifier.shared.requestAuthorization()
    refreshTask = Task { [settings, store] in
      await store.refresh()
      while !Task.isCancelled {
        // Re-read each iteration so a Settings change takes effect at
        // the next tick instead of waiting for relaunch.
        let interval = TimeInterval(settings.refreshIntervalSeconds)
        try? await Task.sleep(for: .seconds(interval))
        if Task.isCancelled { break }
        await store.refresh()
      }
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    refreshTask?.cancel()
  }
}
