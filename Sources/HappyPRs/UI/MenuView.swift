import SwiftUI

struct MenuView: View {
    let store: PRStore
    @State private var showArchived = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if store.prs.isEmpty && store.archived.isEmpty {
                        Text("Nothing waiting on you. 🎉")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    } else {
                        BucketSectionView(
                            title: "🔴 Needs your approval",
                            items: needs, bucketLabel: "needs", store: store
                        )
                        BucketSectionView(
                            title: "🟡 Wants your approval",
                            items: wants, bucketLabel: "wants", store: store
                        )
                        BucketSectionView(
                            title: "💬 Mentions you",
                            items: mentions, bucketLabel: "mentions", store: store
                        )
                        ArchivedSectionView(
                            items: store.archived,
                            isExpanded: $showArchived,
                            store: store
                        )
                    }
                }
                .padding(12)
            }
            Divider()
            footer
        }
        .frame(width: 480)
        .frame(minHeight: 200, maxHeight: 640)
    }

    private var needs: [PRStore.ClassifiedPR] { store.prs.filter { $0.bucket.needsApproval } }
    private var wants: [PRStore.ClassifiedPR] { store.prs.filter { $0.bucket.wantsApproval } }
    private var mentions: [PRStore.ClassifiedPR] { store.prs.filter { $0.bucket.mentions } }

    private var footer: some View {
        HStack(spacing: 8) {
            statusText
            Spacer()
            Button("Refresh") { Task { await store.refresh() } }
                .keyboardShortcut("r")
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding(10)
    }

    @ViewBuilder
    private var statusText: some View {
        switch store.refreshState {
        case .idle:
            if let when = store.lastRefreshAt {
                Text("Updated \(relativeAge(when))").foregroundStyle(.secondary).font(.caption)
            } else {
                Text("Not refreshed yet").foregroundStyle(.secondary).font(.caption)
            }
        case .refreshing:
            Text("Refreshing…").foregroundStyle(.secondary).font(.caption)
        case .error(let msg):
            Text("⚠ \(msg)").foregroundStyle(.red).font(.caption).lineLimit(1)
        case .rateLimited(let resetAt):
            Text("Rate limited until \(resetAt.formatted(date: .omitted, time: .shortened))")
                .foregroundStyle(.orange).font(.caption)
        case .notAuthenticated:
            Text("Run `gh auth login`").foregroundStyle(.orange).font(.caption)
        case .ghNotInstalled:
            Button("Install gh CLI…") {
                NSWorkspace.shared.open(URL(string: "https://cli.github.com")!)
            }
            .font(.caption)
        }
    }

    private func relativeAge(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
