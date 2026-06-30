import SwiftUI

struct PRRowView: View {
  let item: ClassifiedPR
  let bucketLabel: String  // "needs" | "wants" | "mentions"
  let store: PRStore
  @Environment(\.rowActionsEnabled) private var rowActionsEnabled

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      // New-since-last-seen indicator
      if item.isNew {
        Circle().fill(.tint).frame(width: 6, height: 6).padding(.top, 6)
      } else {
        Color.clear.frame(width: 6, height: 6)
      }

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(verbatim: "\(item.pr.repo) #\(item.pr.number)")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
          if item.bucket.staleFlag && bucketLabel != "mentions" {
            Text("stale")
              .font(.caption2)
              .padding(.horizontal, 4)
              .padding(.vertical, 1)
              .background(.yellow.opacity(0.3), in: RoundedRectangle(cornerRadius: 3))
          }
        }
        Text(item.pr.title)
          .lineLimit(2)
          .truncationMode(.tail)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 2) {
        Text(item.pr.authorLogin)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(relativeAge(item.pr.latestCommitDate))
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      if rowActionsEnabled {
        Menu {
          Button("Archive until activity") {
            store.archive(id: item.id, mode: .untilActivity)
          }
          Button("Archive forever") {
            store.archive(id: item.id, mode: .forever)
          }
          Divider()
          Button("Snooze 1 day") {
            store.archive(id: item.id, mode: .snoozeUntil(Date().addingTimeInterval(86_400)))
          }
          Button("Snooze 3 days") {
            store.archive(id: item.id, mode: .snoozeUntil(Date().addingTimeInterval(3 * 86_400)))
          }
          Button("Snooze 1 week") {
            store.archive(id: item.id, mode: .snoozeUntil(Date().addingTimeInterval(7 * 86_400)))
          }
        } label: {
          Image(systemName: "ellipsis.circle")
            .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
      } else {
        Image(systemName: "ellipsis.circle")
          .foregroundStyle(.secondary)
      }
    }
    .contentShape(Rectangle())
    .onTapGesture { open() }
    .padding(.vertical, 4)
  }

  private func open() {
    NSWorkspace.shared.open(item.pr.url)
  }

  private func relativeAge(_ date: Date) -> String {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .abbreviated
    return f.localizedString(for: date, relativeTo: Date())
  }
}
