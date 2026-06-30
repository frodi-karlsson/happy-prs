import SwiftUI

public struct ArchivedSectionView: View {
  let items: [ClassifiedPR]
  @Binding var isExpanded: Bool
  let store: PRStore
  @Environment(\.rowActionsEnabled) private var rowActionsEnabled

  public init(items: [ClassifiedPR], isExpanded: Binding<Bool>, store: PRStore) {
    self.items = items
    self._isExpanded = isExpanded
    self.store = store
  }

  public var body: some View {
    if !items.isEmpty {
      VStack(alignment: .leading, spacing: 4) {
        Button {
          isExpanded.toggle()
        } label: {
          HStack(spacing: 4) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
              .imageScale(.small)
            Text("Archived (\(items.count))").font(.headline)
            Spacer()
          }
        }
        .buttonStyle(.plain)

        if isExpanded {
          ForEach(items) { item in
            HStack(spacing: 8) {
              VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "\(item.pr.repo) #\(item.pr.number)")
                  .font(.system(.caption, design: .monospaced))
                  .foregroundStyle(.secondary)
                Text(item.pr.title)
                  .lineLimit(1)
                  .truncationMode(.tail)
              }
              Spacer()
              if rowActionsEnabled {
                Button("Unarchive") {
                  store.unarchive(id: item.id)
                }
                .font(.caption)
              }
            }
            .contentShape(Rectangle())
            .onTapGesture {
              NSWorkspace.shared.open(item.pr.url)
            }
            .padding(.vertical, 2)
          }
        }
      }
    }
  }
}
