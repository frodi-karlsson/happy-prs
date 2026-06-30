import AppKit
import Foundation
import HappyPRs
import SwiftUI

/// Renders `MenuView` against mock data and writes PNGs to a directory.
/// Usage: `swift run Screenshot [output-dir]` (default `docs/screenshots`).
@main
@MainActor
struct ScreenshotTool {
  static func main() async throws {
    let args = Array(CommandLine.arguments.dropFirst())
    let outputDir = URL(fileURLWithPath: args.first ?? "docs/screenshots")
    try FileManager.default.createDirectory(
      at: outputDir, withIntermediateDirectories: true)

    let store = await PreviewData.loadedStore()
    let view = ScreenshotMenuView(store: store)

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2.0

    guard let nsImage = renderer.nsImage else {
      FileHandle.standardError.write(Data("error: ImageRenderer returned nil\n".utf8))
      exit(1)
    }

    let outputPath = outputDir.appendingPathComponent("loaded.png")
    try writePNG(nsImage, to: outputPath)
    print("wrote \(outputPath.path)")
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

enum ScreenshotError: Error { case encodeFailed }
