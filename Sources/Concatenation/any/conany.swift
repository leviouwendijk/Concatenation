import Foundation
import Path
import PathParsing
import Selection

public enum ConAnyResolveError: Error, LocalizedError {
    case notFound(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let path):
            return "Path does not exist: \(path)"
        }
    }
}

public struct ConAnyResolverResult: Sendable {
    public let matches: [SelectionScanMatch]
    public let plannedTraversalRoots: [URL]

    public init(
        matches: [SelectionScanMatch],
        plannedTraversalRoots: [URL]
    ) {
        self.matches = matches
        self.plannedTraversalRoots = plannedTraversalRoots.map(
            \.standardizedFileURL
        )
    }
}

public struct ConAnyResolverStatistics:
    Sendable,
    Equatable
{
    public let totalDuration: TimeInterval
    public let specificationDuration:
        TimeInterval
    public let compilationDuration:
        TimeInterval
    public let selection:
        SelectionScanBatchStatistics
    public let filteringDuration:
        TimeInterval
    public let assemblyDuration:
        TimeInterval

    public init(
        totalDuration: TimeInterval = 0,
        specificationDuration:
            TimeInterval = 0,
        compilationDuration:
            TimeInterval = 0,
        selection:
            SelectionScanBatchStatistics = .init(),
        filteringDuration:
            TimeInterval = 0,
        assemblyDuration:
            TimeInterval = 0
    ) {
        self.totalDuration = totalDuration
        self.specificationDuration =
            specificationDuration
        self.compilationDuration =
            compilationDuration
        self.selection = selection
        self.filteringDuration =
            filteringDuration
        self.assemblyDuration =
            assemblyDuration
    }
}

public struct ConAnyResolverBatchResult: Sendable {
    public let results: [ConAnyResolverResult]
    public let logicalTraversalCount: Int
    public let physicalTraversalCount: Int
    public let physicalTraversals:
        [PathScanPhysicalTraversalStatistics]
    public let statistics:
        ConAnyResolverStatistics

    public init(
        results: [ConAnyResolverResult],
        logicalTraversalCount: Int,
        physicalTraversalCount: Int,
        physicalTraversals:
            [PathScanPhysicalTraversalStatistics] = [],
        statistics:
            ConAnyResolverStatistics = .init()
    ) {
        self.results = results
        self.logicalTraversalCount = logicalTraversalCount
        self.physicalTraversalCount = physicalTraversalCount
        self.physicalTraversals = physicalTraversals
        self.statistics = statistics
    }
}

struct ConAnyPresentationPlan {
    let candidates: [ConAnyPresentationCandidate]
}

struct ConAnyPresentationCandidate {
    let block: ConAnyIncludeBlock
    let basePath: String?
    let options: PathPresentationOptions?

    var rank: Int {
        basePath?.count ?? -1
    }
}

public struct ConAnyResolver {
    private let baseDirectory: URL

    public init(
        baseDir: String
    ) {
        self.baseDirectory = URL(
            fileURLWithPath: baseDir,
            isDirectory: true
        )
        .standardizedFileURL
    }

    public func resolveResults(
        _ renderables: [ConAnyRenderableObject],
        maxDepth: Int? = nil,
        includeDotfiles: Bool = false,
        ignoreMap: IgnoreMap? = nil,
        verbose: Bool = false
    ) throws -> ConAnyResolverBatchResult {
        if verbose {
            print(
                "ConAny resolving \(renderables.count) outputs in \(baseDirectory.path)"
            )
        }

        let startedAt = Date()

        let specificationStartedAt = Date()

        let specifications = try renderables.map {
            try ConAnyPathPorting.makeSpecification(
                from: $0,
                relativeTo: baseDirectory
            )
        }

        let specificationDuration =
            Date().timeIntervalSince(
                specificationStartedAt
            )

        let compilationStartedAt = Date()

        let plans = specifications.map {
            SelectionScan.compile(
                $0,
                relativeTo: .directoryURL(
                    baseDirectory
                )
            )
        }

        let compilationDuration =
            Date().timeIntervalSince(
                compilationStartedAt
            )

        let batch = try SelectionScan.scan(
            plans,
            configuration: .init(
                maxDepth: maxDepth,
                includeHidden: includeDotfiles,
                followSymlinks: false,
                emitDirectories: false,
                emitFiles: true
            )
        )

        precondition(
            batch.results.count
                == renderables.count
        )

        let postScanStartedAt = Date()

        var filteringDuration:
            TimeInterval = 0

        let filteringPreparationStartedAt =
            Date()

        let staticIgnoreRegexes =
            try compilePatterns(
                StaticIgnoreDefaults.allPatterns
            )

        filteringDuration +=
            Date().timeIntervalSince(
                filteringPreparationStartedAt
            )

        var results: [ConAnyResolverResult] = []

        results.reserveCapacity(
            renderables.count
        )

        for index in renderables.indices {
            let renderable = renderables[index]
            let result = batch.results[index]

            if verbose {
                print(
                    "output: \(renderable.output)"
                )

                for match in result.matches {
                    print(
                        "match: \(match.url.path)"
                    )

                    print(
                        "  selections: \(match.contentSelections)"
                    )
                }
            }

            if verbose,
               !result.warnings.isEmpty {
                print(
                    "SelectionScan warnings: \(result.warnings)"
                )
            }

            let filteringStartedAt = Date()

            let matches = filteredMatches(
                result.matches,
                staticIgnoreRegexes:
                    staticIgnoreRegexes,
                ignoreMap: ignoreMap
            )

            filteringDuration +=
                Date().timeIntervalSince(
                    filteringStartedAt
                )

            results.append(
                .init(
                    matches: matches,
                    plannedTraversalRoots:
                        plans[index]
                        .traversalRoots
                )
            )
        }

        let postScanDuration =
            Date().timeIntervalSince(
                postScanStartedAt
            )

        let assemblyDuration =
            max(
                0,
                postScanDuration
                    - filteringDuration
            )

        return .init(
            results: results,
            logicalTraversalCount:
                batch.logicalTraversalCount,
            physicalTraversalCount:
                batch.physicalTraversalCount,
            physicalTraversals:
                batch.physicalTraversals,
            statistics: .init(
                totalDuration:
                    Date().timeIntervalSince(
                        startedAt
                    ),
                specificationDuration:
                    specificationDuration,
                compilationDuration:
                    compilationDuration,
                selection:
                    batch.statistics,
                filteringDuration:
                    filteringDuration,
                assemblyDuration:
                    assemblyDuration
            )
        )
    }

    public func resolveResult(
        _ renderable: ConAnyRenderableObject,
        maxDepth: Int? = nil,
        includeDotfiles: Bool = false,
        ignoreMap: IgnoreMap? = nil,
        verbose: Bool = false
    ) throws -> ConAnyResolverResult {
        let batch = try resolveResults(
            [renderable],
            maxDepth: maxDepth,
            includeDotfiles: includeDotfiles,
            ignoreMap: ignoreMap,
            verbose: verbose
        )

        return batch.results[0]
    }

    private func filteredMatches(
        _ input: [SelectionScanMatch],
        staticIgnoreRegexes:
            [NSRegularExpression],
        ignoreMap: IgnoreMap?
    ) -> [SelectionScanMatch] {
        var matches: [SelectionScanMatch] = []
        var indexByURL: [URL: Int] = [:]

        matches.reserveCapacity(
            input.count
        )

        indexByURL.reserveCapacity(
            input.count
        )

        for match in input {
            let url =
                match.url

            if matchesAny(
                staticIgnoreRegexes,
                url: url
            ) {
                continue
            }

            if ignoreMap?.shouldIgnore(
                url
            ) == true {
                continue
            }

            if let existingIndex =
                indexByURL[url]
            {
                let existing =
                    matches[existingIndex]

                let mergedSelections =
                    existing
                    .contentSelections
                    + match
                    .contentSelections
                    .filter {
                        selection in

                        !existing
                            .contentSelections
                            .contains(
                                selection
                            )
                    }

                matches[existingIndex] =
                    SelectionScanMatch(
                        url: existing.url,
                        path: existing.path,
                        type: existing.type,
                        contentSelections:
                            mergedSelections
                    )
            } else {
                indexByURL[url] =
                    matches.count

                matches.append(
                    match
                )
            }
        }

        return matches.sorted {
            $0.url.path
                < $1.url.path
        }
    }

    public func resolveMatches(
        _ renderable: ConAnyRenderableObject,
        maxDepth: Int? = nil,
        includeDotfiles: Bool = false,
        ignoreMap: IgnoreMap? = nil,
        verbose: Bool = false
    ) throws -> [SelectionScanMatch] {
        try resolveResult(
            renderable,
            maxDepth: maxDepth,
            includeDotfiles: includeDotfiles,
            ignoreMap: ignoreMap,
            verbose: verbose
        ).matches
    }

    public func resolve(
        _ renderable: ConAnyRenderableObject,
        maxDepth: Int? = nil,
        includeDotfiles: Bool = false,
        ignoreMap: IgnoreMap? = nil,
        verbose: Bool = false
    ) throws -> [URL] {
        try resolveMatches(
            renderable,
            maxDepth: maxDepth,
            includeDotfiles: includeDotfiles,
            ignoreMap: ignoreMap,
            verbose: verbose
        ).map(\.url)
    }

    public func outputURL(
        for renderable: ConAnyRenderableObject
    ) -> URL {
        ConAnyPathPorting.outputURL(
            for: renderable.output,
            relativeTo: baseDirectory
        )
    }

    func presentationPlan(
        for renderable: ConAnyRenderableObject
    ) -> ConAnyPresentationPlan {
        let candidates = renderable.includeBlocks.map {
            block in

            let resolvedBaseURL =
                try? ConAnyPathPorting.resolvedBaseURL(
                    for: block,
                    relativeTo: baseDirectory
                )

            let basePath =
                resolvedBaseURL?.standardizedFileURL.path

            let options =
                try? ConAnyPathPorting.presentationOptions(
                    for: block,
                    relativeTo: baseDirectory
                )

            return ConAnyPresentationCandidate(
                block: block,
                basePath: basePath,
                options: options
            )
        }
        .sorted {
            $0.rank > $1.rank
        }

        return .init(
            candidates: candidates
        )
    }

    func presentedPath(
        for url: URL,
        using plan: ConAnyPresentationPlan
    ) -> String {
        let standardizedURL =
            url.standardizedFileURL

        let targetPath = standardizedURL.path

        guard let candidate = plan.candidates.first(
            where: {
                candidate in

                guard let basePath = candidate.basePath else {
                    return true
                }

                return targetPath == basePath
                    || targetPath.hasPrefix(
                        basePath + "/"
                    )
            }
        ),
              let options = candidate.options else {
            return url.path
        }

        return ConAnyPathPorting.present(
            standardizedURL,
            using: candidate.block,
            options: options
        )
    }

    func presentedPath(
        for match: SelectionScanMatch,
        using plan: ConAnyPresentationPlan
    ) -> String {
        let url =
            match.url

        let targetPath =
            url.path

        guard let candidate =
            plan.candidates.first(
                where: {
                    candidate in

                    guard let basePath =
                        candidate.basePath
                    else {
                        return true
                    }

                    return targetPath
                        == basePath
                        || targetPath.hasPrefix(
                            basePath + "/"
                        )
                }
            ),
              let options =
                candidate.options
        else {
            return targetPath
        }

        return ConAnyPathPorting.present(
            match.path,
            url: url,
            using: candidate.block,
            options: options
        )
    }

    public func presentedPath(
        for url: URL,
        in renderable: ConAnyRenderableObject
    ) -> String {
        presentedPath(
            for: url,
            using: presentationPlan(
                for: renderable
            )
        )
    }
}
