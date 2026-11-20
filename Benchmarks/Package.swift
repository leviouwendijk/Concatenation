// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ConcatenationBenchmarks",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "b_concatenation", targets: ["ConcatenationBenchmark"]),
    ],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/leviouwendijk/IO.git", branch: "master"),
    ],
    targets: [
        .executableTarget(
            name: "ConcatenationBenchmark",
            dependencies: [
                .product(name: "Concatenation", package: "Concatenation"),
                .product(name: "IO", package: "IO"),
            ]
        ),
    ]
)
