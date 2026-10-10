// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OneToOneKit",
    defaultLocalization: "ru",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "MovieAPI", targets: ["MovieAPI"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
    ],
    targets: [
        .target(name: "Core"),
        .target(name: "MovieAPI", dependencies: ["Core"]),
        .target(name: "DesignSystem"),
        .testTarget(name: "CoreTests", dependencies: ["Core"]),
        .testTarget(name: "MovieAPITests", dependencies: ["MovieAPI"]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
    ]
)
