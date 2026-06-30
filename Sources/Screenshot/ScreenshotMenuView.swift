import HappyPRs
import SwiftUI

/// MenuView re-composed for offscreen rendering via `ImageRenderer`:
/// no `ScrollView` (the host has no scroll layout context) and no
/// `Button` chrome in the footer (default Button style can't render
/// its native appearance offscreen — it falls back to placeholder
/// glyphs). The card sits on a contrasting backdrop so the README
/// hero image reads on both light and dark page themes.
struct ScreenshotMenuView: View {
  let store: PRStore
  @State private var archiveExpanded = true

  var body: some View {
    card
      .padding(36)
      .background(backdrop)
      .environment(\.rowActionsEnabled, false)
  }

  private var card: some View {
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
    .background(Color.white)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
  }

  private var backdrop: some View {
    LinearGradient(
      colors: [
        Color(red: 0.18, green: 0.22, blue: 0.32),
        Color(red: 0.10, green: 0.13, blue: 0.20),
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private var needs: [ClassifiedPR] { store.prs.filter { $0.bucket.needsApproval } }
  private var wants: [ClassifiedPR] { store.prs.filter { $0.bucket.wantsApproval } }
  private var mentions: [ClassifiedPR] { store.prs.filter { $0.bucket.mentions } }
}
