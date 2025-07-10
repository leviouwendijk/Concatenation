// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Concatenation",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Concatenation",
            targets: ["Concatenation"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/plate.git",
            branch: "master"
        ),
    ],
    targets: [
        .target(
            name: "Concatenation",
            dependencies: [
                .product(name: "plate", package: "plate"),
            ],
            resources: [
                .process("Resources")
            ],
        ),
        .testTarget(
            name: "ConcatenationTests",
            dependencies: [
                "Concatenation",
                .product(name: "plate", package: "plate"),
            ]
        ),
    ]
)
