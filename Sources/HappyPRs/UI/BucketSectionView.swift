import SwiftUI

struct BucketSectionView: View {
    let title: String
    let items: [PRStore.ClassifiedPR]
    let bucketLabel: String

    var body: some View {
        if !items.isEmpty {
            Section(header: Text("\(title) (\(items.count))").font(.headline)) {
                ForEach(items) { item in
                    PRRowView(item: item, bucketLabel: bucketLabel)
                }
            }
        }
    }
}
