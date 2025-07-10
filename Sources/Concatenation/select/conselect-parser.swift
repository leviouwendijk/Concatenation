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
        var seen = Set<URL>()

        if !patterns.isEmpty {
            let scanner = try FileScanner(
                concatRoot: root,
                maxDepth: maxDepth,
                includePatterns: patterns,
                excludeFilePatterns: [],
                excludeDirPatterns: [],
                includeDotfiles: includeDotfiles,
                ignoreMap: ignoreMap
            )
            for url in try scanner.scan() {
                guard seen.insert(url).inserted else { continue }
                results.append(url)
            }
        }

        for dir in directories {
            let full = (root as NSString).appendingPathComponent(dir)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: full, isDirectory: &isDir),
                  isDir.boolValue
            else {
                print("Warning: ‘\(full)’ is not a directory, skipping")
                continue
            }
            let scanner = try FileScanner(
                concatRoot: full,
                maxDepth: maxDepth,
                includePatterns: ["*"],
                excludeFilePatterns: [],
                excludeDirPatterns: [],
                includeDotfiles: includeDotfiles,
                ignoreMap: ignoreMap
            )
            for url in try scanner.scan() {
                guard seen.insert(url).inserted else { continue }
                results.append(url)
            }
        }

        for file in files {
            let path = (root as NSString).appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: path) {
                let url = URL(fileURLWithPath: path)
                if seen.insert(url).inserted {
                    results.append(url)
                }
            } else {
                print("Warning: file ‘\(path)’ not found, skipping")
            }
        }

        // sorted & unique
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
