// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pixelatolor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Pixelatolor",
            path: "Pixelatolor",
            exclude: ["App/Info.plist"]
        )
    ]
)
