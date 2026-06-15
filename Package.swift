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
    dependencies: [
        .package(url: "https://github.com/nmdias/FeedKit.git", from: "9.1.2"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0")
    ],
    targets: [
        .target(
            name: "ReaderCore",
            dependencies: [
                .product(name: "FeedKit", package: "FeedKit"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "SwiftSoup", package: "SwiftSoup")
            ]
        ),
        .executableTarget(
            name: "ReaderMacApp",
            dependencies: ["ReaderCore"]
        ),
        .testTarget(
            name: "ReaderCoreTests",
            dependencies: [
                "ReaderCore",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
