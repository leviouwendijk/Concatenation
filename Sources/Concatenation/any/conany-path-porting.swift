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
            selections: try selectionExpressions(
                from: renderable,
                relativeTo: baseDirectory
            )
        )
    }

    static func includeExpressions(
        from renderable: ConAnyRenderableObject,
        relativeTo baseDirectory: URL
    ) throws -> [PathExpression] {
        try renderable.includeBlocks.flatMap { block in
            try block.includes.map { pattern in
                try resolvedPathExpression(
                    from: pattern,
                    base: block.base,
                    relativeTo: baseDirectory
                )
            }
        }
    }

    static func selectionExpressions(
        from renderable: ConAnyRenderableObject,
        relativeTo baseDirectory: URL
    ) throws -> [PathSelectionExpression] {
        try renderable.includeBlocks.flatMap { block in
            try block.selections.map { raw in
                let parsed = try PathParse.selectionExpression(raw)

                return try PathSelectionExpression(
                    path: resolvedPathExpression(
                        parsed.path,
                        base: block.base,
                        relativeTo: baseDirectory
                    ),
                    content: parsed.content
                )
            }
        }
    }

    static func resolvedPathExpression(
        from raw: String,
        base: String?,
        relativeTo baseDirectory: URL
    ) throws -> PathExpression {
        try resolvedPathExpression(
            PathParse.expression(raw),
            base: base,
            relativeTo: baseDirectory
        )
    }

    static func resolvedPathExpression(
        _ expression: PathExpression,
        base: String?,
        relativeTo baseDirectory: URL
    ) throws -> PathExpression {
        guard let base,
              !base.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              expression.anchor == .relative else {
            return expression
        }

        let resolvedBase = try PathResolver.resolveStandardPath(
            base,
            relativeTo: .directoryURL(baseDirectory),
            terminalHint: .directory
        )

        let baseComponents = resolvedBase.segments.map {
            PathPatternComponent.literal($0.value)
        }

        let combinedComponents =
            baseComponents + expression.pattern.components

        return PathExpression(
            anchor: .root,
            pattern: PathPattern(
                combinedComponents,
                terminalHint: expression.pattern.terminalHint
            )
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

    static func deduplicated(
        _ matches: [PathScanMatch]
    ) -> [PathScanMatch] {
        var out: [PathScanMatch] = []
        var seen: [URL: Int] = [:]

        for match in matches {
            let url = match.url.standardizedFileURL

            if let existingIndex = seen[url] {
                let existing = out[existingIndex]
                let mergedSelections = existing.contentSelections
                    + match.contentSelections.filter { selection in
                        !existing.contentSelections.contains(selection)
                    }

                out[existingIndex] = PathScanMatch(
                    url: existing.url,
                    path: existing.path,
                    contentSelections: mergedSelections
                )
            } else {
                seen[url] = out.count
                out.append(
                    PathScanMatch(
                        url: match.url,
                        path: match.path,
                        contentSelections: match.contentSelections
                    )
                )
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
