// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "HappyPRs",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "HappyPRsApp", targets: ["HappyPRsApp"]),
    .executable(name: "Screenshot", targets: ["Screenshot"]),
  ],
  targets: [
    // Library — everything except the @main App entry. Tests and tooling
    // (e.g. the screenshot generator) depend on this.
    .target(
      name: "HappyPRs",
      path: "Sources/HappyPRs"
    ),
    // Thin executable shim that wires SwiftUI's @main to the library.
    .executableTarget(
      name: "HappyPRsApp",
      dependencies: ["HappyPRs"],
      path: "Sources/HappyPRsApp"
    ),
    // CLI tool that renders MenuView against mock data and writes PNGs.
    .executableTarget(
      name: "Screenshot",
      dependencies: ["HappyPRs"],
      path: "Sources/Screenshot"
    ),
    .testTarget(
      name: "HappyPRsTests",
      dependencies: ["HappyPRs"],
      path: "Tests/HappyPRsTests",
      resources: [.copy("Fixtures")]
    ),
  ]
)
