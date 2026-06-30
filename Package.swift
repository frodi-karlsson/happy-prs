// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HappyPRs",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "HappyPRs", targets: ["HappyPRs"]),
    ],
    targets: [
        .executableTarget(
            name: "HappyPRs",
            path: "Sources/HappyPRs"
        ),
        .testTarget(
            name: "HappyPRsTests",
            dependencies: ["HappyPRs"],
            path: "Tests/HappyPRsTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
