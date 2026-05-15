import Foundation
import Path
import PathParsing
import Selection
import SelectionParsing
import Partition

enum ConAnyPathPorting {
    static func makeSpecification(
        from renderable: ConAnyRenderableObject,
        relativeTo baseDirectory: URL
    ) throws -> SelectionScanSpecification {
        SelectionScanSpecification(
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
        guard let base = block.base else {
            return nil
        }

        return try resolvedBaseURL(
            base,
            relativeTo: baseDirectory
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

private enum ConPartitionResolutionError: Error, LocalizedError {
    case unknownAddress(String)

    var errorDescription: String? {
        switch self {
        case .unknownAddress(let raw):
            return "Unknown partition address in .conany include base: \(raw)"
        }
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
            guard let address = DevelopmentPartitionAddress(
                rawValue: raw
            ) else {
                throw ConPartitionResolutionError.unknownAddress(
                    raw
                )
            }

            let resolver = currentPartitionResolver(
                relativeTo: baseDirectory
            )

            return try resolver.resolve(
                address
            )
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

private struct PartitionTranslationCandidate {
    let address: DevelopmentPartitionAddress
    let sourceRootLength: Int
    let translatedURL: URL
    let reason: String
}

private struct LegacyPartitionAlias {
    let legacyRoot: String
    let currentRoot: URL
    let address: DevelopmentPartitionAddress
    let reason: String
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

        guard let translated = try translatedPartitionMappedPath(
            direct,
            relativeTo: baseDirectory
        ) else {
            return direct
        }

        return translated
    }

    static func translatedPartitionMappedPath(
        _ source: StandardPath,
        relativeTo baseDirectory: URL
    ) throws -> StandardPath? {
        let sourceURL = source.directory_url.standardizedFileURL
        let sourcePath = normalizedDirectoryPath(
            sourceURL.path
        )

        let currentResolver = currentPartitionResolver(
            relativeTo: baseDirectory
        )

        let candidates = partitionTranslationCandidates(
            for: sourcePath,
            currentResolver: currentResolver
        )

        guard let candidate = candidates.first else {
            return nil
        }

        guard directoryExists(
            candidate.translatedURL
        ) else {
            return nil
        }

        guard normalizedDirectoryPath(candidate.translatedURL.path) != sourcePath else {
            return nil
        }

        return StandardPath(
            fileURL: candidate.translatedURL,
            terminalHint: .directory,
            inferFileType: true
        )
    }

    static func partitionTranslationCandidates(
        for sourcePath: String,
        currentResolver: PartitionResolver<DevelopmentPartitionAddress>
    ) -> [PartitionTranslationCandidate] {
        var out: [PartitionTranslationCandidate] = []

        out.append(
            contentsOf: legacyPartitionTranslationCandidates(
                for: sourcePath,
                currentResolver: currentResolver
            )
        )

        for layout in DevelopmentPartitionLayout.all {
            let sourceResolver = PartitionResolver(
                schema: .development,
                layoutIdentifier: layout.id
            )

            for address in DevelopmentPartitionAddress.allCases {
                guard let sourceRoot = try? sourceResolver.resolve(address),
                      let currentRoot = try? currentResolver.resolve(address)
                else {
                    continue
                }

                let sourceRootURL = sourceRoot.directory_url.standardizedFileURL
                let sourceRootPath = normalizedDirectoryPath(
                    sourceRootURL.path
                )

                guard sourcePath == sourceRootPath
                    || sourcePath.hasPrefix(sourceRootPath + "/")
                else {
                    continue
                }

                let suffix = relativeSuffix(
                    path: sourcePath,
                    after: sourceRootPath
                )

                let translatedURL = appendingRelativeSuffix(
                    suffix,
                    to: currentRoot.directory_url.standardizedFileURL
                )

                out.append(
                    .init(
                        address: address,
                        sourceRootLength: sourceRootPath.count,
                        translatedURL: translatedURL.standardizedFileURL,
                        reason: "partition-root"
                    )
                )
            }
        }

        return out.sorted {
            if $0.sourceRootLength != $1.sourceRootLength {
                return $0.sourceRootLength > $1.sourceRootLength
            }

            return $0.reason < $1.reason
        }
    }

    static func legacyPartitionTranslationCandidates(
        for sourcePath: String,
        currentResolver: PartitionResolver<DevelopmentPartitionAddress>
    ) -> [PartitionTranslationCandidate] {
        var out: [PartitionTranslationCandidate] = []

        for layout in DevelopmentPartitionLayout.all {
            let sourceResolver = PartitionResolver(
                schema: .development,
                layoutIdentifier: layout.id
            )

            for alias in legacyPartitionAliases(
                sourceResolver: sourceResolver,
                currentResolver: currentResolver
            ) {
                guard sourcePath == alias.legacyRoot
                    || sourcePath.hasPrefix(alias.legacyRoot + "/")
                else {
                    continue
                }

                let suffix = relativeSuffix(
                    path: sourcePath,
                    after: alias.legacyRoot
                )

                let translatedURL = appendingRelativeSuffix(
                    suffix,
                    to: alias.currentRoot
                )

                out.append(
                    .init(
                        address: alias.address,
                        sourceRootLength: alias.legacyRoot.count,
                        translatedURL: translatedURL.standardizedFileURL,
                        reason: alias.reason
                    )
                )
            }
        }

        return out
    }

    static func legacyPartitionAliases(
        sourceResolver: PartitionResolver<DevelopmentPartitionAddress>,
        currentResolver: PartitionResolver<DevelopmentPartitionAddress>
    ) -> [LegacyPartitionAlias] {
        var aliases: [LegacyPartitionAlias] = []

        if let sourceLibraries = try? sourceResolver.resolve(.libraries),
           let currentSwiftLibraries = try? currentResolver.resolve(.swift_libraries) {
            let legacyURL = appendingRelativeSuffix(
                "swift",
                to: sourceLibraries.directory_url.standardizedFileURL
            )

            aliases.append(
                .init(
                    legacyRoot: normalizedDirectoryPath(
                        legacyURL.path
                    ),
                    currentRoot: currentSwiftLibraries.directory_url.standardizedFileURL,
                    address: .swift_libraries,
                    reason: "legacy-libraries-swift-to-swift-libraries"
                )
            )
        }

        if let sourceBinaries = try? sourceResolver.resolve(.binaries),
           let currentSwiftBinaries = try? currentResolver.resolve(.swift_binaries) {
            aliases.append(
                .init(
                    legacyRoot: normalizedDirectoryPath(
                        sourceBinaries.directory_url.standardizedFileURL.path
                    ),
                    currentRoot: currentSwiftBinaries.directory_url.standardizedFileURL,
                    address: .swift_binaries,
                    reason: "legacy-binaries-to-swift-binaries"
                )
            )
        }

        return aliases
    }

    static func currentPartitionResolver(
        relativeTo baseDirectory: URL
    ) -> PartitionResolver<DevelopmentPartitionAddress> {
        if let explicit = PartitionEnvironment.layout() {
            return PartitionResolver(
                schema: .development,
                layoutIdentifier: explicit
            )
        }

        if let inferred = inferredPartitionLayout(
            containing: baseDirectory
        ) {
            return PartitionResolver(
                schema: .development,
                layoutIdentifier: inferred
            )
        }

        return PartitionEnvironment.resolver(
            fallback: DevelopmentPartitionLayout.main
        )
    }

    static func inferredPartitionLayout(
        containing directory: URL
    ) -> PartitionLayoutIdentifier? {
        let directoryPath = normalizedDirectoryPath(
            directory.standardizedFileURL.path
        )

        let candidates: [(id: PartitionLayoutIdentifier, length: Int)] =
            DevelopmentPartitionLayout.all.compactMap { layout in
                let resolver = PartitionResolver(
                    schema: .development,
                    layoutIdentifier: layout.id
                )

                guard let root = try? resolver.resolve(.main) else {
                    return nil
                }

                let rootPath = normalizedDirectoryPath(
                    root.directory_url.standardizedFileURL.path
                )

                guard directoryPath == rootPath
                    || directoryPath.hasPrefix(rootPath + "/")
                else {
                    return nil
                }

                return (
                    id: layout.id,
                    length: rootPath.count
                )
            }

        return candidates
            .sorted { $0.length > $1.length }
            .first?
            .id
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

    static func relativeSuffix(
        path: String,
        after root: String
    ) -> String {
        guard path.count > root.count else {
            return ""
        }

        let index = path.index(
            path.startIndex,
            offsetBy: root.count
        )

        var suffix = String(
            path[index...]
        )

        while suffix.hasPrefix("/") {
            suffix.removeFirst()
        }

        return suffix
    }

    static func appendingRelativeSuffix(
        _ suffix: String,
        to root: URL
    ) -> URL {
        guard !suffix.isEmpty else {
            return root
        }

        return suffix
            .split(separator: "/", omittingEmptySubsequences: true)
            .reduce(root) { url, component in
                url.appendingPathComponent(
                    String(component),
                    isDirectory: true
                )
            }
    }
}
