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
        ignoreMap: IgnoreMap? = nil
    ) throws -> [URL] {
        var results = [URL]()
        var seen    = Set<URL>()

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
            for url in try fs.scan() where seen.insert(url).inserted {
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
        for dirName in directories {
            for dirURL in try walker.findDirectories(named: dirName) {
                let subFS = try FileScanner(
                    root: dirURL.path,
                    maxDepth: maxDepth,
                    includePatterns: ["*"],
                    excludeFilePatterns: [],
                    excludeDirPatterns: [],
                    includeDotfiles: includeDotfiles,
                    includeEmpty: false,
                    ignoreMap: ignoreMap
                )
                for f in try subFS.scan() where seen.insert(f).inserted {
                    results.append(f)
                }
            }
        }

        let all = try walker.walk()
        for target in files {
            for url in all {
                guard !url.hasDirectoryPath,
                      url.lastPathComponent == target,
                      seen.insert(url).inserted
                else { continue }
                results.append(url)
            }
        }

        return results.sorted { $0.path < $1.path }
    }
}

public struct ConselectParser {
    private enum Section { case none, patterns, directories, files }

    public static func parse(_ content: String) -> Conselect {
        var patterns   = [String]()
        var directories = [String]()
        var files      = [String]()
        var section: Section = .none

        for raw in content.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            switch line {
                case "[Patterns]":    section = .patterns;    continue
                case "[Directories]": section = .directories; continue
                case "[Files]":       section = .files;       continue
                default: break
            }

            switch section {
                case .patterns:    patterns.append(line)
                case .directories: directories.append(line)
                case .files:       files.append(line)
                case .none:        continue
            }
        }

        return Conselect(
            patterns: patterns,
            directories: directories,
            files: files
        )
    }

    public static func parseFile(at url: URL) throws -> Conselect {
        let raw = try String(contentsOf: url, encoding: .utf8)
        return parse(raw)
    }
}
