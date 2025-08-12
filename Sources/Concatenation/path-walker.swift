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
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: includeDotfiles ? [] : [.skipsHiddenFiles]
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

    public func findDirectories(named name: String) throws -> [URL] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey]
        let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        )!

        var matches = [URL]()
        for case let url as URL in enumerator {
            let rv = try url.resourceValues(forKeys: Set(keys))
            if rv.isDirectory == true, url.lastPathComponent == name {
                matches.append(url)
            }
        }
        return matches
    }
}
