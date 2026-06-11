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
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0")
    ],
    targets: [
        .target(
            name: "ReaderCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
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
            ]
        )
    ]
)
