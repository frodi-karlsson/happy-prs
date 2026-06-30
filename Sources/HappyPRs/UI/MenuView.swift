import SwiftUI

struct MenuView: View {
    let store: PRStore

    var body: some View {
        let needs = store.prs.filter { $0.bucket.needsApproval }
        let wants = store.prs.filter { $0.bucket.wantsApproval }
        let mentions = store.prs.filter { $0.bucket.mentions }

        Group {
            BucketSectionView(title: "🔴 Needs your approval", items: needs, bucketLabel: "needs")
            BucketSectionView(title: "🟡 Wants your approval", items: wants, bucketLabel: "wants")
            BucketSectionView(title: "💬 Mentions you", items: mentions, bucketLabel: "mentions")
        }

        Divider()

        switch store.refreshState {
        case .idle:
            if let when = store.lastRefreshAt {
                Text("Updated \(relativeAge(when))").foregroundStyle(.secondary)
            } else {
                Text("Not refreshed yet").foregroundStyle(.secondary)
            }
        case .refreshing:
            Text("Refreshing…").foregroundStyle(.secondary)
        case .error(let msg):
            Text("⚠ \(msg)").foregroundStyle(.red)
        case .rateLimited(let resetAt):
            Text("Rate limited until \(resetAt.formatted(date: .omitted, time: .shortened))")
                .foregroundStyle(.orange)
        case .notAuthenticated:
            Text("Run `gh auth login`").foregroundStyle(.orange)
        case .ghNotInstalled:
            Button("Install gh CLI…") {
                NSWorkspace.shared.open(URL(string: "https://cli.github.com")!)
            }
        }

        Button("Refresh") { Task { await store.refresh() } }
            .keyboardShortcut("r")
        Button("Quit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func relativeAge(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
