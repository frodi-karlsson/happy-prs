import SwiftUI

struct PRRowView: View {
    let item: PRStore.ClassifiedPR
    let bucketLabel: String              // "needs" | "wants" | "mentions"

    var body: some View {
        Button(action: open) {
            HStack(spacing: 6) {
                if item.isNew { Text("•").foregroundStyle(.tint) }
                Text("\(item.pr.repo) #\(item.pr.number)").bold()
                Text("·").foregroundStyle(.secondary)
                Text(item.pr.title).lineLimit(1).truncationMode(.tail)
                Spacer()
                Text(item.pr.authorLogin).foregroundStyle(.secondary)
                Text(relativeAge(item.pr.latestCommitDate)).foregroundStyle(.secondary)
                if item.bucket.staleFlag && bucketLabel != "mentions" {
                    Text("stale")
                        .font(.caption)
                        .padding(.horizontal, 4)
                        .background(.yellow.opacity(0.3))
                }
            }
        }
        .buttonStyle(.plain)
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
