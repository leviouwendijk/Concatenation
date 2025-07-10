import Foundation

public enum ConfigureError: Error {
    case alreadyExists
}

public struct ConfigureInitializer {
    private let path: URL

    public init(at directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) {
        self.path = directory.appendingPathComponent(".con-figure")
    }

    public func initialize(force: Bool = false) throws {
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: path.path)
        if exists && !force {
            throw ConfigureError.alreadyExists
        }
        let template = """
        # .con-figure — define which snippets to extract
        [Filters]
        # pattern = anchor [+offset][:count]
        # e.g.:
        # Sources/**/*.swift = TODO:+0:5
        """
        try template.write(to: path, atomically: true, encoding: .utf8)
    }
}
