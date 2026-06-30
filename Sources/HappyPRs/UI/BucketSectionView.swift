import SwiftUI

struct BucketSectionView: View {
    let title: String
    let items: [PRStore.ClassifiedPR]
    let bucketLabel: String
    let store: PRStore

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(title) (\(items.count))")
                    .font(.headline)
                    .padding(.bottom, 2)
                ForEach(items) { item in
                    PRRowView(item: item, bucketLabel: bucketLabel, store: store)
                }
            }
        }
    }
}
