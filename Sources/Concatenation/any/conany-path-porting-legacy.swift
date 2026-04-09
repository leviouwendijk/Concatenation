import Foundation
import Path
import PathParsing

enum ConAnyPathPorting {
    static func makeSpecification(
        from renderable: ConAnyRenderableObject
    ) throws -> PathScanSpecification {
        PathScanSpecification(
            includes: try renderable.include.map(PathParse.expression),
            excludes: try renderable.exclude.map(PathParse.expression),
            selections: []
        )
    }

    static func applyStaticIgnoreDefaults(
        to urls: [URL]
    ) throws -> [URL] {
        let regexes = try compilePatterns(
            StaticIgnoreDefaults.allPatterns
        )

        return urls.filter {
            !matchesAny(regexes, url: $0)
        }
    }

    static func applyIgnoreMap(
        _ ignoreMap: IgnoreMap?,
        to urls: [URL]
    ) -> [URL] {
        guard let ignoreMap else {
            return urls
        }

        return urls.filter {
            !ignoreMap.shouldIgnore($0)
        }
    }

    static func deduplicated(
        _ urls: [URL]
    ) -> [URL] {
        var out: [URL] = []
        var seen: Set<URL> = []

        for url in urls.map(\.standardizedFileURL) {
            if seen.insert(url).inserted {
                out.append(url)
            }
        }

        return out
    }

    static func outputURL(
        for output: String,
        relativeTo baseDirectory: URL
    ) -> URL {
        try! PathResolver.resolveURL(
            output,
            relativeTo: .directoryURL(baseDirectory)
        )
    }
}
