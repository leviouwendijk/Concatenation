import Concatenation
import Foundation
import Path
import PathParsing
import Selection
import SelectionParsing
import Partition
import PartitionFrame

enum ConAnyPathPorting {
    static func makeSpecification(
        from renderable: ConAnyRenderableObject,
        relativeTo baseDirectory: URL
    ) throws -> SelectionScanSpecification {
        let parts = try specificationParts(
            from: renderable,
            relativeTo: baseDirectory
        )

        return SelectionScanSpecification(
            includes: parts.includes,
            excludes: parts.excludes,
            selections: parts.selections
        )
    }

    private static func specificationParts(
        from renderable: ConAnyRenderableObject,
        relativeTo baseDirectory: URL
    ) throws -> (
        includes: [PathExpression],
        excludes: [PathExpression],
        selections: [PathSelectionExpression]
    ) {
        (
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
                let parsed = try PathSelectionExpressionParser.parse(
                    raw
                )

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
        base: ConInclude?,
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
        base: ConInclude?,
        relativeTo baseDirectory: URL
    ) throws -> PathExpression {
        guard let base,
              expression.anchor == .relative else {
            return expression
        }

        let resolvedBase = try resolvedBaseStandardPath(
            base,
            relativeTo: baseDirectory
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

            let resolvedBase = try resolvedBaseStandardPath(
                base,
                relativeTo: baseDirectory
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
        present(
            url,
            using: block,
            options: try presentationOptions(
                for: block,
                relativeTo: baseDirectory
            )
        )
    }

    static func present(
        _ url: URL,
        using block: ConAnyIncludeBlock,
        options: PathPresentationOptions
    ) -> String {
        present(
            StandardPath(
                fileURL: url,
                terminalHint: .file,
                inferFileType: true
            ),
            url: url,
            using: block,
            options: options
        )
    }

    static func present(
        _ path: StandardPath,
        url: URL,
        using block: ConAnyIncludeBlock,
        options: PathPresentationOptions
    ) -> String {
        switch block.show {
        case .basename:
            return path.basename
                ?? url.lastPathComponent

        default:
            return path.present(
                options
            )
        }
    }

    static func resolvedBaseURL(
        for block: ConAnyIncludeBlock,
        relativeTo baseDirectory: URL
    ) throws -> URL? {
        guard let base = block.base else {
            return nil
        }

        return try resolvedBaseURL(
            base,
            relativeTo: baseDirectory
        )
    }

    static func deduplicated(
        _ matches: [SelectionScanMatch]
    ) -> [SelectionScanMatch] {
        var out: [SelectionScanMatch] = []
        var seen: [URL: Int] = [:]

        for match in matches {
            let url = match.url.standardizedFileURL

            if let existingIndex = seen[url] {
                let existing = out[existingIndex]
                let mergedSelections = existing.contentSelections
                    + match.contentSelections.filter { selection in
                        !existing.contentSelections.contains(selection)
                    }

                out[existingIndex] = SelectionScanMatch(
                    url: existing.url,
                    path: existing.path,
                    type: existing.type,
                    contentSelections: mergedSelections
                )
            } else {
                seen[url] = out.count
                out.append(
                    SelectionScanMatch(
                        url: match.url,
                        path: match.path,
                        type: match.type,
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

private extension ConAnyPathPorting {
    static func resolvedBaseStandardPath(
        _ base: ConInclude,
        relativeTo baseDirectory: URL
    ) throws -> StandardPath {
        switch base {
        case .path(let raw):
            return try resolvedConcreteBaseStandardPath(
                raw,
                relativeTo: baseDirectory
            )

        case .partition(let raw):
            // A partition key from this machine's configuration (~/.config/partition).
            return try PartitionConfiguration
                .load()
                .path(raw)
        }
    }

    static func resolvedBaseURL(
        _ base: ConInclude,
        relativeTo baseDirectory: URL
    ) throws -> URL {
        try resolvedBaseStandardPath(
            base,
            relativeTo: baseDirectory
        ).directory_url
    }
}

private extension ConAnyPathPorting {
    static func resolvedConcreteBaseStandardPath(
        _ raw: String,
        relativeTo baseDirectory: URL
    ) throws -> StandardPath {
        let direct = try PathResolver.resolveStandardPath(
            raw,
            relativeTo: .directoryURL(baseDirectory),
            terminalHint: .directory
        )

        guard !directoryExists(
            direct.directory_url
        ) else {
            return direct
        }

        guard let translated = translatedPartitionMappedPath(
            direct
        ) else {
            return direct
        }

        return translated
    }

    /// A path written under another layout (`~/.config/partition/maps/*.frame`,
    /// such as a former directory layout), ported to where it lives on this
    /// machine. Nil without partition configuration, when no other map covers
    /// the path, or when the ported directory does not exist.
    static func translatedPartitionMappedPath(
        _ source: StandardPath
    ) -> StandardPath? {
        guard let partitions = try? PartitionConfiguration.load(),
              let translated = partitions.translate(source)
        else {
            return nil
        }

        let translatedURL = translated.directory_url.standardizedFileURL

        guard directoryExists(
            translatedURL
        ) else {
            return nil
        }

        guard normalizedDirectoryPath(translatedURL.path)
            != normalizedDirectoryPath(source.directory_url.standardizedFileURL.path)
        else {
            return nil
        }

        return StandardPath(
            fileURL: translatedURL,
            terminalHint: .directory,
            inferFileType: true
        )
    }

    static func directoryExists(
        _ url: URL
    ) -> Bool {
        var isDirectory: ObjCBool = false

        let exists = FileManager.default.fileExists(
            atPath: url.standardizedFileURL.path,
            isDirectory: &isDirectory
        )

        return exists && isDirectory.boolValue
    }

    static func normalizedDirectoryPath(
        _ raw: String
    ) -> String {
        var path = URL(
            fileURLWithPath: raw,
            isDirectory: true
        )
        .standardizedFileURL
        .path

        while path.count > 1,
              path.hasSuffix("/") {
            path.removeLast()
        }

        return path
    }
}
