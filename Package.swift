// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CosmicTile",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "CosmicTile", targets: ["CosmicTile"])],
    targets: [
        .target(name: "TileCore"),
        .executableTarget(name: "CosmicTile", dependencies: ["TileCore"], resources: [.process("Resources")]),
        .testTarget(name: "TileCoreTests", dependencies: ["TileCore"]),
        .testTarget(name: "AppTests", dependencies: ["CosmicTile"])
    ]
)
