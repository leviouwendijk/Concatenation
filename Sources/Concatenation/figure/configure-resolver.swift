import Foundation

public struct FilteredSnippet {
    public let file: URL
    public let lines: [String]
}

public struct ConfigureResolver {
    private let root: String
    private let maxDepth: Int?
    private let includeDotfiles: Bool
    private let ignoreMap: IgnoreMap?

    public init(
        root: String,
        maxDepth: Int? = nil,
        includeDotfiles: Bool = false,
        ignoreMap: IgnoreMap? = nil
    ) {
        self.root = root
        self.maxDepth = maxDepth
        self.includeDotfiles = includeDotfiles
        self.ignoreMap = ignoreMap
    }

    public func resolve(filters: [ConfigureParser.Filter]) throws -> [FilteredSnippet] {
        var out = [FilteredSnippet]()
        for f in filters {
            let scanner = try FileScanner(
                root: root,
                maxDepth: maxDepth,
                includePatterns: [f.glob],
                excludeFilePatterns: [],
                excludeDirPatterns: [],
                includeDotfiles: includeDotfiles,
                includeEmpty: false,
                ignoreMap: ignoreMap
            )
            let matches = try scanner.scan()
            for fileURL in matches {
                let content = try String(contentsOf: fileURL, encoding: .utf8)

                let allLines = content
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)

                for (idx, line) in allLines.enumerated() where line.contains(f.anchor) {
                    let start = max(0, idx + f.offset)
                    let end   = min(allLines.count, start + f.count)
                    let snippetLines = Array(allLines[start..<end])
                    out.append(FilteredSnippet(file: fileURL, lines: snippetLines))
                }
            }
        }
        return out
    }
}
