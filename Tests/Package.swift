// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ConcatenationTests",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "t_concatenation",
            targets: ["ConcatenationTestFlows"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-lco/Position.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Path.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/IO.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Writers.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Readers.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Selection.git", branch: "master"),
        .package(url: "https://github.com/swift-tooling/TestFlows.git", branch: "master"),
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "ConcatenationTestFlows",
            dependencies: [
                .product(name: "Concatenation", package: "Concatenation"),
                .product(name: "ConcatenationLegacy", package: "Concatenation"),
                .product(name: "ConcatenationServiceTransport", package: "Concatenation"),
                .product(name: "Position", package: "Position"),
                .product(name: "Path", package: "Path"),
                .product(name: "PathParsing", package: "Path"),
                .product(name: "Selection", package: "Selection"),
                .product(name: "IO", package: "IO"),
                .product(name: "Readers", package: "Readers"),
                .product(name: "Writers", package: "Writers"),
                .product(name: "TestFlows", package: "TestFlows"),
            ]
        ),
    ]
)
