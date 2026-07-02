import SwiftUI

/// `Text` that shows the relative age of `date` (e.g. "5m ago") and
/// re-renders on a periodic schedule so the label stays accurate as
/// wall-clock time advances. SwiftUI otherwise only re-evaluates a
/// body when observed state changes, which leaves a `Date()`-derived
/// string frozen until the next store mutation.
///
/// `resolution` bounds how often the timeline ticks — minute
/// granularity is enough for "Xm ago"/"Xh ago" labels.
struct RelativeAgeText: View {
  let date: Date
  var resolution: TimeInterval = 60

  var body: some View {
    TimelineView(.periodic(from: .now, by: resolution)) { context in
      Text(formatted(date: date, relativeTo: context.date))
    }
  }

  private func formatted(date: Date, relativeTo now: Date) -> String {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .abbreviated
    return f.localizedString(for: date, relativeTo: now)
  }
}
