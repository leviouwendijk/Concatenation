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
        .package(url: "https://github.com/leviouwendijk/Position.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Path.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Writers.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Readers.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Selection.git", branch: "master"),
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
                .product(name: "Position", package: "Position"),
                .product(name: "Path", package: "Path"),
                .product(name: "PathParsing", package: "Path"),
                .product(name: "Writers", package: "Writers"),
                .product(name: "Readers", package: "Readers"),
                .product(name: "Selection", package: "Selection"),
                .product(name: "SelectionParsing", package: "Selection"),
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
