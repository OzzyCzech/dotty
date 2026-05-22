// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "dotty",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "dotty", targets: ["dotty"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "dotty",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            resources: [
                .process("Resources/schemas"),
            ]
        ),
    ]
)
