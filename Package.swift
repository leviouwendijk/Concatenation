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
        .library(name: "ConcatenationLegacy", targets: ["ConcatenationLegacy"]),
        .library(name: "ConcatenationServiceTransport", targets: ["ConcatenationServiceTransport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-lco/Primitives.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Errors.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Strings.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Indentation.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Terminal.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Clipboard.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Position.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Path.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/IO.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Writers.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Readers.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Selection.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Partition.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Arguments.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "Concatenation",
            dependencies: [
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Errors", package: "Errors"),
                .product(name: "Strings", package: "Strings"),
                .product(name: "Position", package: "Position"),
                .product(name: "Path", package: "Path"),
                .product(name: "PathParsing", package: "Path"),
                .product(name: "IO", package: "IO"),
                .product(name: "Writers", package: "Writers"),
                .product(name: "Readers", package: "Readers"),
                .product(name: "Selection", package: "Selection"),
                .product(name: "SelectionParsing", package: "Selection"),
            ]
        ),
        .target(
            name: "ConcatenationLegacy",
            dependencies: [
                .target(name: "Concatenation"),
                .product(name: "IO", package: "IO"),
                .product(name: "Path", package: "Path"),
                .product(name: "PathParsing", package: "Path"),
                .product(name: "Readers", package: "Readers"),
                .product(name: "Selection", package: "Selection"),
                .product(name: "SelectionParsing", package: "Selection"),
                .product(name: "Partition", package: "Partition"),
                .product(name: "PartitionFrame", package: "Partition"),
                .product(name: "Writers", package: "Writers"),
            ]
        ),
        .target(
            name: "ConcatenationServiceTransport",
            dependencies: [
                .target(name: "Concatenation"),
                .target(name: "ConcatenationLegacy"),
                .product(name: "IO", package: "IO"),
            ]
        ),
        .executableTarget(
            name: "con",
            dependencies: [
                .target(name: "Concatenation"),
                .target(name: "ConcatenationLegacy"),
                .target(name: "ConcatenationServiceTransport"),
                .product(name: "Arguments", package: "Arguments"),
                .product(name: "Clipboard", package: "Clipboard"),
                .product(name: "Indentation", package: "Indentation"),
                .product(name: "IO", package: "IO"),
                .product(name: "Writers", package: "Writers"),
                .product(name: "Terminal", package: "Terminal")
            ],
            path: "Sources/ConcatenatorCLI"
        ),
    ]
)
