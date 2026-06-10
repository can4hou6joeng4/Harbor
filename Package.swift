// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ReaderMacApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ReaderMacApp", targets: ["ReaderMacApp"])
    ],
    targets: [
        .target(name: "ReaderCore"),
        .executableTarget(
            name: "ReaderMacApp",
            dependencies: ["ReaderCore"]
        ),
        .testTarget(
            name: "ReaderCoreTests",
            dependencies: ["ReaderCore"]
        )
    ]
)
