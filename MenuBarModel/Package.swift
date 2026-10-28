// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "MenuBarModel",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "MenuBarModel", type: .dynamic, targets: ["MenuBarModel"]),
    ],
    dependencies: [
        .package(path: "../ThawConcurrency"),
    ],
    targets: [
        .target(
            name: "MenuBarModel",
            dependencies: [.product(name: "ThawConcurrency", package: "ThawConcurrency")]
        ),
        .testTarget(
            name: "MenuBarModelTests",
            dependencies: ["MenuBarModel"]
        ),
    ]
)
