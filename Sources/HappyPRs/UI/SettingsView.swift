import SwiftUI

public struct SettingsView: View {
  @Bindable var settings: Settings
  @State private var newRepoInput: String = ""
  @Environment(\.rowActionsEnabled) private var rowActionsEnabled

  public init(settings: Settings) {
    self.settings = settings
  }

  private let intervals: [Int] = [30, 60, 120, 300, 900]

  public var body: some View {
    Form {
      Section("Refresh") {
        Picker("Refresh every", selection: $settings.refreshIntervalSeconds) {
          ForEach(intervals, id: \.self) { interval in
            Text(intervalLabel(interval)).tag(interval)
          }
        }
      }
      Section {
        if settings.hiddenRepos.isEmpty {
          Text("No repos hidden.")
            .foregroundStyle(.secondary)
        } else {
          ForEach(settings.hiddenRepos, id: \.self) { repo in
            HStack {
              Text(repo).font(.system(.body, design: .monospaced))
              Spacer()
              if rowActionsEnabled {
                Button {
                  settings.hiddenRepos.removeAll { $0 == repo }
                } label: {
                  Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
              } else {
                Image(systemName: "minus.circle.fill").foregroundStyle(.red)
              }
            }
          }
        }
        HStack {
          TextField("owner/repo", text: $newRepoInput)
            .textFieldStyle(.roundedBorder)
            .onSubmit(addRepo)
          if rowActionsEnabled {
            Button("Hide") { addRepo() }
              .disabled(newRepoInput.trimmingCharacters(in: .whitespaces).isEmpty)
          } else {
            Text("Hide").foregroundStyle(.secondary)
          }
        }
      } header: {
        Text("Hidden repos")
      } footer: {
        Text("PRs in these repos won't appear in any bucket.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(width: 460, height: 360)
  }

  private func addRepo() {
    let trimmed = newRepoInput.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    if !settings.hiddenRepos.contains(trimmed) {
      settings.hiddenRepos.append(trimmed)
    }
    newRepoInput = ""
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
