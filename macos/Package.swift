// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FocoDS",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "FocoDS",
            targets: ["FocoDS"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "FocoDS",
            dependencies: [],
            path: "Sources/FocoDS"
        )
    ]
)
