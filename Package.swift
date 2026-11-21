// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Concatenation",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Concatenation",
            targets: ["Concatenation"]
        ),
        .executable(
            name: "con",
            targets: ["con"]
        ),
        .library(name: "ConcatenationServiceTransport", targets: ["ConcatenationServiceTransport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Errors.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Strings.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Indentation.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Terminal.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Clipboard.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Position.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Path.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/IO.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Writers.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Readers.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Selection.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Partition.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Arguments.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "Concatenation",
            dependencies: [
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Errors", package: "Errors"),
                .product(name: "Strings", package: "Strings"),
                .product(name: "Indentation", package: "Indentation"),
                .product(name: "Terminal", package: "Terminal"),
                .product(name: "Clipboard", package: "Clipboard"),
                .product(name: "Position", package: "Position"),
                .product(name: "Path", package: "Path"),
                .product(name: "PathParsing", package: "Path"),
                .product(name: "IO", package: "IO"),
                .product(name: "Writers", package: "Writers"),
                .product(name: "Readers", package: "Readers"),
                .product(name: "Selection", package: "Selection"),
                .product(name: "SelectionParsing", package: "Selection"),
                .product(name: "Partition", package: "Partition"),
            ]
        ),
        .target(
            name: "ConcatenationServiceTransport",
            dependencies: [
                .target(name: "Concatenation"),
            ]
        ),
        .executableTarget(
            name: "con",
            dependencies: [
                .target(name: "Concatenation"),
                .target(name: "ConcatenationServiceTransport"),
                .product(name: "Arguments", package: "Arguments"),
                .product(name: "IO", package: "IO"),
                .product(name: "Terminal", package: "Terminal")
            ],
            path: "Sources/ConcatenatorCLI"
        ),
    ]
)
