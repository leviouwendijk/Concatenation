import Foundation

public enum ConselectError: Error {
    case alreadyExists
}

public struct ConselectInitializer {
    public let path: URL

    public init(
        at directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) {
        self.path = directory.appendingPathComponent(".conselect")
    }

    public func initialize(force: Bool = false) throws {
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: path.path)
        if exists && !force {
            throw ConselectError.alreadyExists
        }
        try Self.defaultTemplate.write(
            to: path,
            atomically: true,
            encoding: .utf8
        )
    }

    public static let defaultTemplate = """
    [Patterns]
    # Add glob patterns, e.g. *.swift

    [Directories]
    # Add directories, e.g. Sources/

    [Files]
    # Add specific file paths, e.g. README.md
    """
}
