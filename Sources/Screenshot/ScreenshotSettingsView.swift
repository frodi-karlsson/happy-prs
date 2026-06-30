import HappyPRs
import SwiftUI

/// SettingsView re-composed for offscreen rendering. The live
/// `SettingsView` uses `Form { Section { … } }` and `Picker`, all of
/// which lean on AppKit chrome that ImageRenderer can't host — the
/// rendered card comes out empty. This view mirrors the same content
/// using plain primitives so the README image actually shows the
/// settings UI.
struct ScreenshotSettingsView: View {
  let settings: HappyPRs.Settings

  var body: some View {
    card
      .background(Color.white)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
      .padding(36)
      .background(backdrop)
      .environment(\.rowActionsEnabled, false)
  }

  private var card: some View {
    VStack(alignment: .leading, spacing: 20) {
      sectionBox(title: "Refresh") {
        HStack {
          Text("Refresh every")
          Spacer()
          HStack(spacing: 4) {
            Text(intervalLabel(settings.refreshIntervalSeconds))
              .foregroundStyle(.primary)
            Image(systemName: "chevron.up.chevron.down")
              .imageScale(.small)
              .foregroundStyle(.secondary)
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
        }
      }

      sectionBox(
        title: "Hidden repos",
        footer: "PRs in these repos won't appear in any bucket."
      ) {
        VStack(spacing: 6) {
          ForEach(settings.hiddenRepos, id: \.self) { repo in
            HStack {
              Text(repo).font(.system(.body, design: .monospaced))
              Spacer()
              Image(systemName: "minus.circle.fill").foregroundStyle(.red)
            }
          }
          HStack {
            Text("owner/repo")
              .foregroundStyle(.secondary)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(Color.white, in: RoundedRectangle(cornerRadius: 5))
              .overlay(
                RoundedRectangle(cornerRadius: 5)
                  .stroke(Color.gray.opacity(0.3), lineWidth: 0.5))
            Text("Hide").foregroundStyle(.secondary)
          }
        }
      }
    }
    .padding(20)
    .frame(width: 460)
    .fixedSize(horizontal: false, vertical: true)
  }

  @ViewBuilder
  private func sectionBox<Content: View>(
    title: String,
    footer: String? = nil,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.headline)
      VStack(alignment: .leading, spacing: 8) {
        content()
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
      if let footer {
        Text(footer)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
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

  private func intervalLabel(_ seconds: Int) -> String {
    switch seconds {
    case ..<60: return "\(seconds) seconds"
    case 60: return "1 minute"
    case let n where n % 60 == 0: return "\(n / 60) minutes"
    default: return "\(seconds) seconds"
    }
  }
}
