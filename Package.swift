// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "dab",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "dab",
            path: "dab",
            exclude: ["App/Info.plist"]
        )
    ]
)
