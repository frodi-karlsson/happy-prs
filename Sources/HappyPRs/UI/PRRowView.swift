import SwiftUI

struct PRRowView: View {
    let item: PRStore.ClassifiedPR
    let bucketLabel: String              // "needs" | "wants" | "mentions"

    // Native NSMenu items (which `.menuBarExtraStyle(.menu)` renders to)
    // only support a single string label — they drop any HStack/Spacer
    // layout. Compose everything into one line.
    var body: some View {
        Button(label) { open() }
    }

    private var label: String {
        var parts: [String] = []
        if item.isNew { parts.append("•") }
        parts.append("\(item.pr.repo) #\(item.pr.number)")
        parts.append("·")
        parts.append(item.pr.title)
        parts.append("—")
        parts.append(item.pr.authorLogin)
        parts.append("·")
        parts.append(relativeAge(item.pr.latestCommitDate))
        if item.bucket.staleFlag && bucketLabel != "mentions" {
            parts.append("(stale)")
        }
        return parts.joined(separator: " ")
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
