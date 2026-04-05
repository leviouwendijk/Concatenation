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
            // .conany — select arbitrary files anywhere on disk
            // Syntax:
            //   render(output.txt) {
            //       include [
            //           /absolute/path/to/file.txt,
            //           /absolute/path/to/dir/,            // recursive
            //           /Users/you/project/**/*.swift      // glob
            //       ]
            //       exclude [
            //           */build/*,
            //           *.log
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
                // /Users/you/file.txt,
                // /Users/you/project/,
                // /Users/you/project/**/*.swift
            ]

            exclude [
                // *.log
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
