import Foundation
import Path
import PathParsing

enum ConAnyPathPorting {
    static func makeSpecification(
        from renderable: ConAnyRenderableObject,
        relativeTo baseDirectory: URL
    ) throws -> PathScanSpecification {
        PathScanSpecification(
            includes: try includeExpressions(
                from: renderable,
                relativeTo: baseDirectory
            ),
            excludes: try renderable.exclude.map {
                try PathParse.expression($0)
            },
            selections: []
        )
    }

    static func includeExpressions(
        from renderable: ConAnyRenderableObject,
        relativeTo baseDirectory: URL
    ) throws -> [PathExpression] {
        try renderable.includeBlocks.flatMap { block in
            try block.patterns.map { pattern in
                try PathParse.expression(
                    resolvedIncludePattern(
                        pattern,
                        base: block.base,
                        relativeTo: baseDirectory
                    )
                )
            }
        }
    }

    static func resolvedIncludePattern(
        _ pattern: String,
        base: String?,
        relativeTo baseDirectory: URL
    ) throws -> String {
        let trimmed = pattern.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            return trimmed
        }

        guard let base,
              !base.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !looksAnchored(trimmed) else {
            return trimmed
        }

        let resolvedBase = try PathResolver.resolveString(
            base,
            relativeTo: .directoryURL(baseDirectory),
            terminalHint: .directory
        )

        return joinedPath(
            lhs: resolvedBase,
            rhs: trimmed
        )
    }

    static func presentationOptions(
        for block: ConAnyIncludeBlock,
        relativeTo baseDirectory: URL
    ) throws -> PathPresentationOptions {
        switch block.show {
        case .full:
            return .init(
                style: .full
            )

        case .relativeToBase:
            guard let base = block.base else {
                return .init(
                    style: .full
                )
            }

            let resolvedBase = try PathResolver.resolveStandardPath(
                base,
                relativeTo: .directoryURL(baseDirectory),
                terminalHint: .directory
            )

            return .init(
                style: .relative(
                    to: resolvedBase,
                    marker: "."
                )
            )

        case .relativeToCWD:
            return .init(
                style: .relative(
                    to: .cwd,
                    marker: "."
                )
            )

        case .basename:
            return .init(
                style: .full
            )

        case .middleEllipsis(let keepFirst, let keepLast):
            return .init(
                style: .middleEllipsis(
                    keepFirst: keepFirst,
                    keepLast: keepLast
                )
            )

        case .dropFirst(let count):
            return .init(
                style: .dropFirst(count)
            )
        }
    }

    static func present(
        _ url: URL,
        using block: ConAnyIncludeBlock,
        relativeTo baseDirectory: URL
    ) throws -> String {
        let path = StandardPath(
            fileURL: url,
            terminalHint: .file,
            inferFileType: true
        )

        switch block.show {
        case .basename:
            return path.basename ?? url.lastPathComponent

        default:
            return path.present(
                try presentationOptions(
                    for: block,
                    relativeTo: baseDirectory
                )
            )
        }
    }

    static func resolvedBaseURL(
        for block: ConAnyIncludeBlock,
        relativeTo baseDirectory: URL
    ) throws -> URL? {
        guard let base = block.base,
              !base.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return try PathResolver.resolveURL(
            base,
            relativeTo: .directoryURL(baseDirectory),
            terminalHint: .directory
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

    private static func looksAnchored(
        _ raw: String
    ) -> Bool {
        raw.hasPrefix("/")
            || raw.hasPrefix("~")
            || raw.hasPrefix("$HOME")
            || raw.hasPrefix("$CWD")
    }

    private static func joinedPath(
        lhs: String,
        rhs: String
    ) -> String {
        let left = lhs.hasSuffix("/")
            ? String(lhs.dropLast())
            : lhs
        let right = rhs.hasPrefix("/")
            ? String(rhs.dropFirst())
            : rhs

        return left + "/" + right
    }
}
