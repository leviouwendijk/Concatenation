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

public struct ConAnyResolver {
    private let baseDir: String

    public init(
        baseDir: String
    ) {
        self.baseDir = URL(
            fileURLWithPath: baseDir,
            isDirectory: true
        )
        .standardizedFileURL
        .path
    }

    public func resolveResults(
        _ renderables: [ConAnyRenderableObject],
        maxDepth: Int? = nil,
        includeDotfiles: Bool = false,
        ignoreMap: IgnoreMap? = nil,
        verbose: Bool = false
    ) throws -> ConAnyResolverBatchResult {
        let baseDirectory = URL(
            fileURLWithPath: baseDir,
            isDirectory: true
        )
        .standardizedFileURL

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

            let matches = try filteredMatches(
                result.matches,
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
        ignoreMap: IgnoreMap?
    ) throws -> [SelectionScanMatch] {
        var matches = input

        let filteredURLs =
            try ConAnyPathPorting
            .applyStaticIgnoreDefaults(
                to: matches.map(
                    \.url
                )
            )

        let ignoreFilteredURLs =
            ConAnyPathPorting
            .applyIgnoreMap(
                ignoreMap,
                to: filteredURLs
            )

        let allowed = Set(
            ignoreFilteredURLs.map(
                \.standardizedFileURL
            )
        )

        matches = matches.filter {
            allowed.contains(
                $0.url.standardizedFileURL
            )
        }

        matches = ConAnyPathPorting.deduplicated(
            matches
        )

        return matches.sorted {
            $0.url.path < $1.url.path
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
            relativeTo: URL(
                fileURLWithPath: baseDir,
                isDirectory: true
            )
            .standardizedFileURL
        )
    }

    public func presentedPath(
        for url: URL,
        in renderable: ConAnyRenderableObject
    ) -> String {
        let baseDirectory = URL(
            fileURLWithPath: baseDir,
            isDirectory: true
        )
        .standardizedFileURL

        guard let block = bestIncludeBlock(
            for: url,
            in: renderable,
            relativeTo: baseDirectory
        ) else {
            return url.path
        }

        return (try? ConAnyPathPorting.present(
            url.standardizedFileURL,
            using: block,
            relativeTo: baseDirectory
        )) ?? url.path
    }
}

private extension ConAnyResolver {
    func bestIncludeBlock(
        for url: URL,
        in renderable: ConAnyRenderableObject,
        relativeTo baseDirectory: URL
    ) -> ConAnyIncludeBlock? {
        let standardizedURL = url.standardizedFileURL

        let candidates = renderable.includeBlocks.compactMap {
            block -> (ConAnyIncludeBlock, Int)? in
            if let baseURL = try? ConAnyPathPorting.resolvedBaseURL(
                for: block,
                relativeTo: baseDirectory
            ) {
                let basePath = baseURL.standardizedFileURL.path
                let targetPath = standardizedURL.path

                guard targetPath == basePath
                    || targetPath.hasPrefix(basePath + "/") else {
                    return nil
                }

                return (block, basePath.count)
            }

            return (block, -1)
        }

        return candidates
            .sorted { $0.1 > $1.1 }
            .first?
            .0
    }
}
