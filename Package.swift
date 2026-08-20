// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "FountainCodexLaneKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "FountainCodexLaneKit", targets: ["FountainCodexLaneKit"])
    ],
    targets: [
        .target(name: "FountainCodexLaneKit"),
        .testTarget(name: "FountainCodexLaneKitTests", dependencies: ["FountainCodexLaneKit"])
    ]
)
