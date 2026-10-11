// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OneToOneKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "MovieAPI", targets: ["MovieAPI"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Sync", targets: ["Sync"]),
    ],
    targets: [
        .target(name: "Core"),
        // movies.json — базовый каталог фильмов для подбора без сети (обновляет `swift run UpdateMovies`).
        .target(name: "MovieAPI", dependencies: ["Core"], resources: [.copy("Resources/movies.json")]),
        .target(name: "DesignSystem"),
        .target(name: "Sync", dependencies: ["Core"]),
        // Скрипт обновления movies.json: swift run UpdateMovies (нужен ключ Кинопоиска).
        .executableTarget(name: "UpdateMovies", dependencies: ["Core", "MovieAPI"]),
        .testTarget(name: "CoreTests", dependencies: ["Core"]),
        .testTarget(name: "MovieAPITests", dependencies: ["MovieAPI"], resources: [.copy("Fixtures")]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
        .testTarget(name: "SyncTests", dependencies: ["Sync"]),
    ]
)
