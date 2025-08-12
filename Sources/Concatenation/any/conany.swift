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

    public func resolve(
        _ cfg: ConAnyConfig,
        maxDepth: Int? = nil,
        includeDotfiles: Bool = false,
        ignoreMap: IgnoreMap? = nil,
        verbose: Bool = false
    ) throws -> [URL] {
        var out: [URL] = []
        var seen = Set<URL>()

        // 1) Expand includes
        for token in cfg.include {
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
                // directory → walk recursively
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
                // file
                let u = URL(fileURLWithPath: abs).standardizedFileURL
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: u.path, isDirectory: &isDir), !isDir.boolValue else {
                    throw ConAnyResolveError.notFound(abs)
                }
                if seen.insert(u).inserted { out.append(u) }
            }
        }

        // 2) Apply excludes (as globs, absolute-anchored)
        let excludePatterns = cfg.exclude.map { absolutize($0) }
        let excludeRegexes = try compilePatterns(excludePatterns) // reuses your helpers
        if !excludeRegexes.isEmpty {
            out.removeAll { matchesAny(excludeRegexes, url: $0) }
        }

        // Stable order
        out.sort { $0.path < $1.path }
        return out
    }

    public func outputURL(for cfg: ConAnyConfig) -> URL {
        let raw = cfg.output ?? "any.txt"
        let abs = absolutize(raw, allowTrailingSlash: false)
        return URL(fileURLWithPath: abs).standardizedFileURL
    }

    // MARK: - helpers

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
        return s.contains("*") || s.contains("?")
    }

    // Extract directory prefix before first wildcard; fallback nil if none
    private func staticPrefixDir(ofPattern pattern: String) -> String? {
        guard let idx = pattern.firstIndex(where: { $0 == "*" || $0 == "?" }) else {
            // No wildcard → treat as file/dir outside
            return nil
        }
        let prefix = pattern[..<idx]
        // trim to last slash
        guard let lastSlash = prefix.lastIndex(of: "/") else { return "/" }
        let dir = String(prefix[..<lastSlash])
        return dir.isEmpty ? "/" : dir
    }
}
