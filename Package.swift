// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "DeepSeekBalance",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "DeepSeekBalance", targets: ["DeepSeekBalance"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DeepSeekBalance",
            dependencies: []
        )
    ]
)
