import Foundation

public struct Conselect {
    public let patterns:    [String]
    public let directories: [String]
    public let files:       [String]

    public init(
        patterns: [String],
        directories: [String],
        files: [String]
    ) {
        self.patterns = patterns
        self.directories = directories
        self.files = files
    }

    public func resolve(
        root: String,
        maxDepth: Int? = nil,
        includeDotfiles: Bool = false,
        ignoreMap: IgnoreMap? = nil,
        verbose: Bool = false
    ) throws -> [URL] {
        var results = [URL]()
        var seen    = Set<URL>()

        if verbose {
            print("Conselect resolving in “\(root)”")
            print("   patterns: \(patterns)")
            print("   directories: \(directories)")
            print("   files: \(files)")
        }

        if !patterns.isEmpty {
            let fs = try FileScanner(
                root: root,
                maxDepth: maxDepth,
                includePatterns: patterns,
                excludeFilePatterns: [],
                excludeDirPatterns: [],
                includeDotfiles: includeDotfiles,
                includeEmpty: false,
                ignoreMap: ignoreMap
            )

            if verbose { print(" • pattern scan →") }
            for url in try fs.scan() where seen.insert(url).inserted {
                if verbose { print("    ✓ \(url.path)") }
                results.append(url)
            }
        }

        let walker = PathWalker(
            root: root,
            maxDepth: maxDepth,
            includeDotfiles: includeDotfiles,
            includeEmpty: false,
            ignoreMap: ignoreMap
        )

        let all = try walker.walk()
        if verbose { print(" • walker.walk() found \(all.count) entries") }

        for url in all where !url.hasDirectoryPath {
            if verbose { print(" • directory‐based include") }

            let relComponents = url
            .path
            .replacingOccurrences(of: root + "/", with: "")
            .split(separator: "/")
            .map(String.init)

            if relComponents.contains(where: { directories.contains($0) }) && seen.insert(url).inserted {
                if verbose { print("    ✓ in dir match: \(url.path)") }
                results.append(url)
            }
        }
        
        if !files.isEmpty {
            if verbose { print(" • file‐name–based include") }
            for target in files {
                for url in all where !url.hasDirectoryPath && url.lastPathComponent == target {
                    guard seen.insert(url).inserted else { continue }
                    if verbose { print("    ✓ file match: \(url.path)") }
                    results.append(url)
                }
            }
        }

        return results.sorted { $0.path < $1.path }
    }
}

