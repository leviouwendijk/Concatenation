import Foundation

public enum ConignoreSection {
    case none, ignoreFiles, ignoreDirectories, obscure
}

public struct IgnoreMap {
    public let ignoreFiles: [String]
    public let ignoreDirectories: [String]
    public let obscureValues: [String: String]

    private let fileRegexes: [NSRegularExpression]
    private let dirRegexes: [NSRegularExpression]

    public init() {
        self.ignoreFiles = []
        self.ignoreDirectories = []
        self.obscureValues = [:]

        self.fileRegexes = []
        self.dirRegexes = []
    }

    public init(
        ignoreFiles: [String],
        ignoreDirectories: [String],
        obscureValues: [String: String]
    ) throws {
        self.ignoreFiles        = ignoreFiles
        self.ignoreDirectories  = ignoreDirectories
        self.obscureValues      = obscureValues

        self.fileRegexes = try compilePatterns(ignoreFiles)
        self.dirRegexes  = try compilePatterns(ignoreDirectories)
    }

    public func shouldIgnore(_ url: URL) -> Bool {
        return matchesAny(fileRegexes, url: url) || matchesAny(dirRegexes,  url: url)
    }
}
