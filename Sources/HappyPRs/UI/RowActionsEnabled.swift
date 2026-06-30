import SwiftUI

/// Whether PR rows should render their action affordances (the ellipsis
/// archive menu, the Unarchive button on archived rows). Defaults to
/// `true` for the live menubar. Set to `false` in offscreen contexts
/// like the screenshot tool, where SwiftUI's native Menu/Button chrome
/// falls back to placeholder glyphs because ImageRenderer can't host
/// them.
extension EnvironmentValues {
  @Entry public var rowActionsEnabled: Bool = true
}
