import Foundation
import plate

public struct PathWalker {
    public let rootURL: URL
    public let maxDepth: Int?
    public let includeDotfiles: Bool
    public let includeEmpty: Bool
    public let ignoreMap: IgnoreMap?

    public init(
        root: String,
        maxDepth: Int? = nil,
        includeDotfiles: Bool = false,
        includeEmpty: Bool = false,
        ignoreMap: IgnoreMap? = nil
    ) {
        self.rootURL = URL(fileURLWithPath: root).standardizedFileURL
        self.maxDepth = maxDepth
        self.includeDotfiles = includeDotfiles
        self.includeEmpty = includeEmpty
        self.ignoreMap = ignoreMap
    }
    
    public func walk() throws -> [URL] {
        var results = [URL]()
        var errors = [Error]()
        func recurse(_ url: URL, depth: Int) {
            do {
                let res = try resolveSymlink(at: url)
                if !includeDotfiles, res.lastPathComponent.hasPrefix(".") { return }
                let isDir = (try res.resourceValues(forKeys:[.isDirectoryKey])).isDirectory == true
                if isDir {
                    let children = try FileManager.default.contentsOfDirectory(
                        at: res,
                        includingPropertiesForKeys:[.isDirectoryKey],
                        options:[.skipsHiddenFiles]
                    )
                    var sawChild = false
                    for child in children {
                        if let m = maxDepth, depth >= m { continue }
                        recurse(child, depth: depth + 1)
                        sawChild = true
                    }
                    if includeEmpty && !sawChild {
                        results.append(res)
                    }
                } else {
                    if !(ignoreMap.map { shouldIgnore(res, using: $0) } ?? false) {
                        results.append(res)
                    }
                }
            } catch {
                errors.append(error)
            }
        }
        recurse(rootURL, depth: 0)
        if !errors.isEmpty { throw MultiError(errors) }
        return results
    }
}

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
