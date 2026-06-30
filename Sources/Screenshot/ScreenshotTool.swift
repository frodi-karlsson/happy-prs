import AppKit
import Foundation
import HappyPRs
import SwiftUI

/// Renders the app's main views against mock data and writes PNGs to a
/// directory. Usage: `swift run Screenshot [output-dir]` (default
/// `screenshots`).
@main
@MainActor
struct ScreenshotTool {
  static func main() async throws {
    let args = Array(CommandLine.arguments.dropFirst())
    let outputDir = URL(fileURLWithPath: args.first ?? "screenshots")
    try FileManager.default.createDirectory(
      at: outputDir, withIntermediateDirectories: true)

    let store = await PreviewData.loadedStore()
    try render(ScreenshotMenuView(store: store), to: outputDir.appendingPathComponent("loaded.png"))

    let settings = PreviewData.settingsScreenshotData()
    try render(
      ScreenshotSettingsView(settings: settings),
      to: outputDir.appendingPathComponent("settings.png"))
  }

  static func render<V: View>(_ view: V, to url: URL) throws {
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2.0
    guard let nsImage = renderer.nsImage else {
      FileHandle.standardError.write(
        Data("error: ImageRenderer returned nil for \(url.lastPathComponent)\n".utf8))
      throw ScreenshotError.renderFailed
    }
    try writePNG(nsImage, to: url)
    print("wrote \(url.path)")
  }

  static func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let data = bitmap.representation(using: .png, properties: [:])
    else {
      throw ScreenshotError.encodeFailed
    }
    try data.write(to: url)
  }
}

enum ScreenshotError: Error { case renderFailed, encodeFailed }
