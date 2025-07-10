import Foundation

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

    public func resolve(filters: [ConfigureParser.Filter]) throws -> [(file: URL, snippet: [String])] {
        var out = [(URL, [String])]()
        for f in filters {
            let fs = try FileScanner(
                root: root,
                maxDepth: maxDepth,
                includePatterns: [f.glob],
                excludeFilePatterns: [],
                excludeDirPatterns: [],
                includeDotfiles: includeDotfiles,
                includeEmpty: false,
                ignoreMap: ignoreMap
            )
            let matches = try fs.scan()
            for fileURL in matches {
                let lines = try String(contentsOf: fileURL).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                for (i, line) in lines.enumerated() where line.contains(f.anchor) {
                    let start = min(lines.count, i + f.offset)
                    let end = min(lines.count, start + f.count)
                    let snippet = Array(lines[start..<end])
                    out.append((fileURL, snippet))
                }
            }
        }
        return out
    }
}
