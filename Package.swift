// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "DeepseekBalance",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "DeepseekBalance", targets: ["DeepseekBalance"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DeepseekBalance",
            dependencies: []
        )
    ]
)
