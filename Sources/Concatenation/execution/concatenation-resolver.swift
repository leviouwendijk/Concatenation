import Foundation
import Path
import Selection

public struct ConcatenationResolverResult: Sendable {
    public let matches: [SelectionScanMatch]
    public let plannedTraversalRoots: [URL]
    public let warnings: [SelectionScanWarning]

    public init(
        matches: [SelectionScanMatch],
        plannedTraversalRoots: [URL],
        warnings: [SelectionScanWarning] = []
    ) {
        self.matches = matches
        self.warnings = warnings
        self.plannedTraversalRoots = plannedTraversalRoots.map(
            \.standardizedFileURL
        )
    }
}

public struct ConcatenationResolverStatistics:
    Sendable,
    Equatable
{
    public let totalDuration: TimeInterval
    public let compilationDuration: TimeInterval
    public let selection: SelectionScanBatchStatistics
    public let mergeDuration: TimeInterval
    public let assemblyDuration: TimeInterval

    public init(
        totalDuration: TimeInterval = 0,
        compilationDuration: TimeInterval = 0,
        selection: SelectionScanBatchStatistics = .init(),
        mergeDuration: TimeInterval = 0,
        assemblyDuration: TimeInterval = 0
    ) {
        self.totalDuration = totalDuration
        self.compilationDuration = compilationDuration
        self.selection = selection
        self.mergeDuration = mergeDuration
        self.assemblyDuration = assemblyDuration
    }
}

public struct ConcatenationResolverBatchResult: Sendable {
    public let results: [ConcatenationResolverResult]
    public let logicalTraversalCount: Int
    public let physicalTraversalCount: Int
    public let physicalTraversals: [PathScanPhysicalTraversalStatistics]
    public let statistics: ConcatenationResolverStatistics

    public init(
        results: [ConcatenationResolverResult],
        logicalTraversalCount: Int,
        physicalTraversalCount: Int,
        physicalTraversals: [PathScanPhysicalTraversalStatistics] = [],
        statistics: ConcatenationResolverStatistics = .init()
    ) {
        self.results = results
        self.logicalTraversalCount = logicalTraversalCount
        self.physicalTraversalCount = physicalTraversalCount
        self.physicalTraversals = physicalTraversals
        self.statistics = statistics
    }
}

/// Scans every output of a definition in one batch, so outputs that share
/// roots share traversals, then merges each output's matches per file.
public struct ConcatenationResolver: Sendable {
    public let anchor: URL

    public init(
        anchor: URL
    ) {
        self.anchor = anchor.standardizedFileURL
    }

    public func resolve(
        _ specifications: [SelectionScanSpecification],
        maxDepth: Int? = nil,
        includeHidden: Bool = false
    ) throws -> ConcatenationResolverBatchResult {
        let startedAt = Date()

        let compilationStartedAt = Date()

        let plans = specifications.map {
            SelectionScan.compile(
                $0,
                relativeTo: .directoryURL(
                    anchor
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
                includeHidden: includeHidden,
                followSymlinks: false,
                emitDirectories: false,
                emitFiles: true
            )
        )

        precondition(
            batch.results.count == specifications.count
        )

        let postScanStartedAt = Date()
        var mergeDuration: TimeInterval = 0
        var results: [ConcatenationResolverResult] = []

        results.reserveCapacity(
            specifications.count
        )

        for index in specifications.indices {
            let result = batch.results[index]
            let mergeStartedAt = Date()

            let matches = Self.merged(
                result.matches
            )

            mergeDuration +=
                Date().timeIntervalSince(
                    mergeStartedAt
                )

            results.append(
                .init(
                    matches: matches,
                    plannedTraversalRoots: plans[index].traversalRoots,
                    warnings: result.warnings
                )
            )
        }

        let postScanDuration =
            Date().timeIntervalSince(
                postScanStartedAt
            )

        return .init(
            results: results,
            logicalTraversalCount: batch.logicalTraversalCount,
            physicalTraversalCount: batch.physicalTraversalCount,
            physicalTraversals: batch.physicalTraversals,
            statistics: .init(
                totalDuration:
                    Date().timeIntervalSince(
                        startedAt
                    ),
                compilationDuration: compilationDuration,
                selection: batch.statistics,
                mergeDuration: mergeDuration,
                assemblyDuration: max(
                    0,
                    postScanDuration - mergeDuration
                )
            )
        )
    }

    /// One match per file, its content selections unioned in first-seen order,
    /// sorted by path.
    static func merged(
        _ input: [SelectionScanMatch]
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
            guard let existingIndex = indexByURL[match.url] else {
                indexByURL[match.url] = matches.count
                matches.append(
                    match
                )
                continue
            }

            let existing = matches[existingIndex]

            matches[existingIndex] = SelectionScanMatch(
                url: existing.url,
                path: existing.path,
                type: existing.type,
                contentSelections:
                    existing.contentSelections
                    + match.contentSelections.filter {
                        !existing.contentSelections.contains($0)
                    }
            )
        }

        return matches.sorted {
            $0.url.path < $1.url.path
        }
    }
}
