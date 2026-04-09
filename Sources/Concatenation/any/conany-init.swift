import Foundation

public enum ConAnyInitError: Error {
    case alreadyExists
}

public struct ConAnyInitializer {
    public let path: URL

    public init(
        at directory: URL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath
        )
    ) {
        self.path = directory.appendingPathComponent(".conany")
    }

    public func initialize(
        force: Bool = false,
        instructions: Bool = false
    ) throws {
        let fileManager = FileManager.default
        let exists = fileManager.fileExists(atPath: path.path)

        if exists && !force {
            throw ConAnyInitError.alreadyExists
        }

        var template = ""

        if instructions {
            template += """
            // .conany — concatenate arbitrary files anywhere on disk using Path syntax
            //
            // New syntax:
            //
            // directory("lib-context") {
            //     file("path.txt") {
            //         context {
            //             title = "Path lib"
            //
            //             details = \"\"\"
            //                 Some description
            //             \"\"\"
            //
            //             dependencies {
            //                 "Primitives"
            //                 "Something"
            //             }
            //         }
            //
            //         include(
            //             from: "~/myworkdir/programming/libraries/swift",
            //             show: .relativeToBase
            //         ) {
            //             "Path/Sources/**"
            //             "Path/Package.swift"
            //         }
            //
            //         exclude {
            //             "**/.build/**"
            //             "**/*.generated.swift"
            //         }
            //     }
            // }
            //
            // Legacy syntax is still accepted:
            //
            // render(path.txt) {
            //     include [
            //         /absolute/path/to/file.txt
            //         /absolute/path/to/dir/**
            //         ./Sources/**/*.swift
            //         ~/project/**/*.md
            //     ]
            //
            //     exclude [
            //         **/build/**
            //         **/*.log
            //     ]
            // }
            //
            """

        }

        template += """
        directory("lib-context") {
            file("any.txt") {
                context {
                    title = "Context title"

                    details = \"\"\"
                        Some description
                    \"\"\"

                    dependencies {
                        "Primitives"
                    }
                }

                include(
                    from: "$CWD",
                    show: .relativeToBase
                ) {
                    "./Sources/**/*.swift"
                    "./README.md"
                }

                exclude {
                    "**/.build/**"
                    "**/*.generated.swift"
                }
            }
        }
        """

        try template.write(
            to: path,
            atomically: true,
            encoding: .utf8
        )
    }
}
