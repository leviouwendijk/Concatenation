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
            // .conany — select arbitrary files anywhere on disk using Path syntax
            // Syntax:
            //   render(output.txt) {
            //       include [
            //           /absolute/path/to/file.txt,
            //           /absolute/path/to/dir/**,
            //           ./Sources/**/*.swift,
            //           ~/project/**/*.md
            //       ]
            //       exclude [
            //           **/build/**,
            //           **/*.log
            //       ]
            //   }

            """
        }

        template += """
        render(any.txt) {
            context {
                title = _

                details {
                    _
                }

                dependencies [
                    _
                ]
            }

            include [
                // ./Sources/**/*.swift
                // ./README.md
                // ~/project/**/*.md
            ]

            exclude [
                // **/.build/**
                // **/*.generated.swift
            ]
        }
        """

        try template.write(
            to: path,
            atomically: true,
            encoding: .utf8
        )
    }
}
