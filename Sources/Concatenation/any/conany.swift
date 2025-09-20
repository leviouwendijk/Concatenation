import Foundation

public enum ConAnyResolveError: Error, LocalizedError {
    case notFound(String)
    public var errorDescription: String? {
        switch self {
        case .notFound(let p): return "Path does not exist: \(p)"
        }
    }
}

public struct ConAnyResolver {
    private let baseDir: String   // directory containing .conany

    public init(baseDir: String) {
        self.baseDir = URL(fileURLWithPath: baseDir).standardizedFileURL.path
    }

    // Resolve ONE renderable
    public func resolve(
        _ r: ConAnyRenderableObject,
        maxDepth: Int? = nil,
        includeDotfiles: Bool = false,
        ignoreMap: IgnoreMap? = nil,
        verbose: Bool = false
    ) throws -> [URL] {
        var out: [URL] = []
        var seen = Set<URL>()

        // includes
        for token in r.include {
            if verbose { print("include token: \(token)") }
            let abs = absolutize(token)
            if isGlob(abs) {
                let scanRoot = staticPrefixDir(ofPattern: abs) ?? "/"
                if verbose { print("  glob root: \(scanRoot)  pattern: \(abs)") }
                let scanner = try FileScanner(
                    root: scanRoot,
                    maxDepth: maxDepth,
                    includePatterns: [abs],
                    excludeFilePatterns: [],
                    excludeDirPatterns: [],
                    includeDotfiles: includeDotfiles,
                    includeEmpty: false,
                    ignoreMap: ignoreMap
                )
                for url in try scanner.scan() where seen.insert(url.standardizedFileURL).inserted {
                    out.append(url.standardizedFileURL)
                }
            } else if abs.hasSuffix("/") {
                let dir = String(abs.dropLast())
                if verbose { print("  dir walk: \(dir)") }
                let walker = PathWalker(
                    root: dir,
                    maxDepth: maxDepth,
                    includeDotfiles: includeDotfiles,
                    includeEmpty: false,
                    ignoreMap: ignoreMap
                )
                for url in try walker.walk() where !url.hasDirectoryPath {
                    let std = url.standardizedFileURL
                    if seen.insert(std).inserted { out.append(std) }
                }
            } else {
                let u = URL(fileURLWithPath: abs).standardizedFileURL
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: u.path, isDirectory: &isDir), !isDir.boolValue else {
                    throw ConAnyResolveError.notFound(abs)
                }
                if seen.insert(u).inserted { out.append(u) }
            }
        }

        // excludes
        let excludePatterns = r.exclude.map { absolutize($0, allowTrailingSlash: false) }
        let excludeRegexes = try compilePatterns(excludePatterns)
        if !excludeRegexes.isEmpty {
            out.removeAll { matchesAny(excludeRegexes, url: $0) }
        }

        out.sort { $0.path < $1.path }
        return out
    }

    public func outputURL(for r: ConAnyRenderableObject) -> URL {
        // let raw = r.output ?? "any.txt"
        let raw = r.output
        let abs = absolutize(raw, allowTrailingSlash: false)
        return URL(fileURLWithPath: abs).standardizedFileURL
    }

    private func absolutize(_ token: String, allowTrailingSlash: Bool = true) -> String {
        let expanded = (token as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return expanded
        } else {
            let joined = URL(fileURLWithPath: baseDir)
                .appendingPathComponent(expanded).standardizedFileURL.path
            if allowTrailingSlash, token.hasSuffix("/"), !joined.hasSuffix("/") {
                return joined + "/"
            }
            return joined
        }
    }

    private func isGlob(_ s: String) -> Bool {
        s.contains("*") || s.contains("?")
    }

    private func staticPrefixDir(ofPattern pattern: String) -> String? {
        guard let idx = pattern.firstIndex(where: { $0 == "*" || $0 == "?" }) else { return nil }
        let prefix = pattern[..<idx]
        guard let lastSlash = prefix.lastIndex(of: "/") else { return "/" }
        let dir = String(prefix[..<lastSlash])
        return dir.isEmpty ? "/" : dir
    }
}
