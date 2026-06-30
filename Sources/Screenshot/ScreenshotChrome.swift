import SwiftUI

/// Common card-on-backdrop chrome shared by every screenshot view. The
/// backdrop fakes an iOS-style frosted-glass look: a vibrant diagonal
/// gradient with soft blurred color blobs underneath a translucent
/// white card. We can't use a real `Material` because `ImageRenderer`
/// has no window to blur against — Material would render as flat gray
/// — so we approximate the visual instead.
struct ScreenshotChrome<Content: View>: View {
  let content: Content

  init(@ViewBuilder _ content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    content
      .background(Color.white.opacity(0.82))
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(Color.white.opacity(0.35), lineWidth: 1)
      )
      .shadow(color: .black.opacity(0.28), radius: 22, x: 0, y: 12)
      .padding(40)
      .background(backdrop)
      .environment(\.rowActionsEnabled, false)
  }

  private var backdrop: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.45, green: 0.18, blue: 0.85),  // deep purple
          Color(red: 0.16, green: 0.40, blue: 0.95),  // electric blue
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      // Soft color blobs for depth + a wallpaper-y feel.
      Circle()
        .fill(Color(red: 1.0, green: 0.42, blue: 0.65))  // hot pink
        .frame(width: 260, height: 260)
        .blur(radius: 80)
        .offset(x: -180, y: -220)
      Circle()
        .fill(Color(red: 0.20, green: 0.85, blue: 0.95))  // cyan
        .frame(width: 320, height: 320)
        .blur(radius: 100)
        .offset(x: 220, y: 260)
      Circle()
        .fill(Color(red: 0.75, green: 0.30, blue: 0.90))  // magenta
        .frame(width: 200, height: 200)
        .blur(radius: 70)
        .offset(x: 180, y: -180)
    }
  }
}
