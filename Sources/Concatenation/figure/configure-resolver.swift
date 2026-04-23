import Foundation
import Path
import PathParsing

public struct FilteredSnippet {
    public let file: URL
    public let lines: [String]
}

public struct ConfigureResolver {
    private let rootURL: URL
    private let maxDepth: Int?
    private let includeDotfiles: Bool
    private let ignoreMap: IgnoreMap?

    public init(
        root: String,
        maxDepth: Int? = nil,
        includeDotfiles: Bool = false,
        ignoreMap: IgnoreMap? = nil
    ) {
        self.rootURL = URL(
            fileURLWithPath: root,
            isDirectory: true
        )
        .standardizedFileURL

        self.maxDepth = maxDepth
        self.includeDotfiles = includeDotfiles
        self.ignoreMap = ignoreMap
    }

    public func resolve(
        filters: [ConfigureParser.Filter]
    ) throws -> [FilteredSnippet] {
        var out: [FilteredSnippet] = []

        for filter in filters {
            let includeExpression = try PathParse.expression(
                filter.glob
            )

            let result = try PathScan.scan(
                PathScanSpecification(
                    includes: [includeExpression],
                    excludes: [],
                ),
                relativeTo: .directoryURL(rootURL),
                configuration: .init(
                    maxDepth: maxDepth,
                    includeHidden: includeDotfiles,
                    followSymlinks: false,
                    emitDirectories: false,
                    emitFiles: true
                )
            )

            var matches: [URL] = result.matches.map { $0.url }
            matches = try ConAnyPathPorting
                .applyStaticIgnoreDefaults(to: matches)
            matches = ConAnyPathPorting
                .applyIgnoreMap(ignoreMap, to: matches)

            for fileURL in matches.sorted(by: { $0.path < $1.path }) {
                let content = try String(
                    contentsOf: fileURL,
                    encoding: .utf8
                )

                let allLines = content
                    .split(
                        separator: "\n",
                        omittingEmptySubsequences: false
                    )
                    .map(String.init)

                for (index, line) in allLines.enumerated()
                    where line.contains(filter.anchor)
                {
                    let start = max(
                        0,
                        index + filter.offset
                    )

                    let end = min(
                        allLines.count,
                        start + filter.count
                    )

                    out.append(
                        FilteredSnippet(
                            file: fileURL,
                            lines: Array(allLines[start..<end])
                        )
                    )
                }
            }
        }

        return out
    }
}
