import Foundation
import plate

public struct FileScanner {
    private let rootURL: URL
    private let maxDepth: Int?
    private let includeRegexes: [NSRegularExpression]
    private let excludeFileRegexes: [NSRegularExpression]
    private let excludeDirRegexes:  [NSRegularExpression]
    private let includeDotfiles: Bool
    private let includeEmpty: Bool
    private let ignoreMap: IgnoreMap?
    private let walker: PathWalker

    public init(
        root: String,
        maxDepth: Int? = nil,
        includePatterns: [String] = ["*"],
        excludeFilePatterns: [String],
        excludeDirPatterns: [String] = [],
        includeDotfiles: Bool = false,
        includeEmpty: Bool = false,
        ignoreMap: IgnoreMap? = nil,
        ignoreStaticDefaults: Bool = true
    ) throws {
        let staticIgnore = StaticIgnoreDefaults.allPatterns
        let finalExcludeFilePatterns = ignoreStaticDefaults ? (staticIgnore + excludeFilePatterns) : excludeFilePatterns
        self.rootURL            = normalize(path: root)
        self.maxDepth           = maxDepth
        self.includeRegexes     = try compilePatterns(includePatterns)
        self.excludeFileRegexes = try compilePatterns(finalExcludeFilePatterns)
        self.excludeDirRegexes  = try compilePatterns(excludeDirPatterns)
        self.includeDotfiles    = includeDotfiles
        self.includeEmpty       = includeEmpty
        self.ignoreMap          = ignoreMap

        self.walker = PathWalker(
            root: root,
            maxDepth: maxDepth,
            includeDotfiles: includeDotfiles,
            includeEmpty: includeEmpty,
            ignoreMap: ignoreMap
        )
    }

    public init(
        concatRoot: String,
        maxDepth: Int? = nil,
        includePatterns: [String] = ["*"],
        excludeFilePatterns: [String],
        excludeDirPatterns: [String] = [],
        includeDotfiles: Bool = false,
        includeEmpty: Bool = false,
        ignoreMap: IgnoreMap? = nil,
        ignoreStaticDefaults: Bool = true
    ) throws {
        try self.init(
            root: concatRoot,
            maxDepth: maxDepth,
            includePatterns: includePatterns,
            excludeFilePatterns: excludeFilePatterns,
            excludeDirPatterns: excludeDirPatterns,
            includeDotfiles: includeDotfiles,
            includeEmpty: false,
            ignoreMap: ignoreMap,
            ignoreStaticDefaults: ignoreStaticDefaults
        )
    }

    public init(
        treeRoot: String,
        maxDepth: Int? = nil,
        includePatterns: [String] = ["*"],
        excludeFilePatterns: [String],
        excludeDirPatterns: [String] = [],
        includeDotfiles: Bool = false,
        includeEmpty: Bool = false,
        ignoreMap: IgnoreMap? = nil,
        ignoreStaticDefaults: Bool = true
    ) throws {
        try self.init(
            root: treeRoot,
            maxDepth: maxDepth,
            includePatterns: includePatterns,
            excludeFilePatterns: excludeFilePatterns,
            excludeDirPatterns: [],
            includeDotfiles: includeDotfiles,
            includeEmpty: includeEmpty,
            ignoreMap: ignoreMap,
            ignoreStaticDefaults: ignoreStaticDefaults
        )
    }

    public func scan() throws -> [URL] {
        let all = try walker.walk()
        return all.filter { url in
            let isDir = (try? url.resourceValues(forKeys:[.isDirectoryKey]).isDirectory) == true
            if isDir {
                return !matchesAny(excludeDirRegexes, url: url)
            } else {
                return matchesAny(includeRegexes, url: url) && !matchesAny(excludeFileRegexes, url: url)
            }
        }
    }
}
