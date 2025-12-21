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
        .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Strings.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Indentation.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Terminal.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Clipboard.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "Concatenation",
            dependencies: [
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Strings", package: "Strings"),
                .product(name: "Indentation", package: "Indentation"),
                .product(name: "Terminal", package: "Terminal"),
                .product(name: "Clipboard", package: "Clipboard"),
            ],
            // resources: [
            //     .process("Resources")
            // ],
        ),
        .testTarget(
            name: "ConcatenationTests",
            dependencies: [
                "Concatenation",
            ]
        ),
    ]
)
