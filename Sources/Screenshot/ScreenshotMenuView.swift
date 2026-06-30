import HappyPRs
import SwiftUI

/// MenuView re-composed for offscreen rendering via `ImageRenderer`:
/// no `ScrollView` (the host has no scroll layout context) and no
/// `Button` chrome in the footer (default Button style can't render
/// its native appearance offscreen — it falls back to placeholder
/// glyphs). The visible layout matches what the live menubar popover
/// shows for content that fits without scrolling.
struct ScreenshotMenuView: View {
  let store: PRStore
  @State private var archiveExpanded = true

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 14) {
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
          isExpanded: $archiveExpanded,
          store: store
        )
      }
      .padding(12)

      Divider()

      HStack(spacing: 12) {
        Text("Updated just now")
          .foregroundStyle(.secondary)
          .font(.caption)
        Spacer()
        Text("Refresh ⌘R")
          .foregroundStyle(.secondary)
          .font(.caption)
        Text("Quit ⌘Q")
          .foregroundStyle(.secondary)
          .font(.caption)
      }
      .padding(10)
    }
    .frame(width: 480)
    .fixedSize(horizontal: false, vertical: true)
    .environment(\.rowActionsEnabled, false)
  }

  private var needs: [ClassifiedPR] { store.prs.filter { $0.bucket.needsApproval } }
  private var wants: [ClassifiedPR] { store.prs.filter { $0.bucket.wantsApproval } }
  private var mentions: [ClassifiedPR] { store.prs.filter { $0.bucket.mentions } }
}
