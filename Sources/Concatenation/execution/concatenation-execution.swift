import Foundation
import IO
import Path
import Selection

public struct ConcatenationExecutionOptions: Sendable {
    public var maxDepth: Int?
    public var includeDotfiles: Bool

    public var delimiterStyle: DelimiterStyle
    public var delimiterClosure: Bool
    public var maxLinesPerFile: Int?
    public var rawOutput: Bool
    public var outputFormat: ConcatenationOutputFormat
    public var includeSourceLineNumbers: Bool
    public var includeSourceModifiedAt: Bool
    /// Literal value → obscuring method (`redact`, `preserve`, `verbose`).
    public var obscurations: [String: String]

    public var protectSecrets: Bool
    public var allowSecrets: Bool
    public var failOnBlockedFiles: Bool
    public var deepSecretInspection: Bool

    public init(
        maxDepth: Int? = nil,
        includeDotfiles: Bool = false,
        delimiterStyle: DelimiterStyle = .boxed,
        delimiterClosure: Bool = false,
        maxLinesPerFile: Int? = 10_000,
        rawOutput: Bool = false,
        outputFormat: ConcatenationOutputFormat = .text,
        includeSourceLineNumbers: Bool = false,
        includeSourceModifiedAt: Bool = false,
        obscurations: [String: String] = [:],
        protectSecrets: Bool = true,
        allowSecrets: Bool = false,
        failOnBlockedFiles: Bool = false,
        deepSecretInspection: Bool = true
    ) {
        self.maxDepth = maxDepth
        self.includeDotfiles = includeDotfiles

        self.delimiterStyle = delimiterStyle
        self.delimiterClosure = delimiterClosure
        self.maxLinesPerFile = maxLinesPerFile
        self.rawOutput = rawOutput
        self.outputFormat = outputFormat
        self.includeSourceLineNumbers = includeSourceLineNumbers
        self.includeSourceModifiedAt = includeSourceModifiedAt
        self.obscurations = obscurations

        self.protectSecrets = protectSecrets
        self.allowSecrets = allowSecrets
        self.failOnBlockedFiles = failOnBlockedFiles
        self.deepSecretInspection = deepSecretInspection
    }
}

public struct ConcatenationResolvedOutput {
    /// The definition output this was resolved from.
    public let declaration: ConcatenationDefinition.Output

    public let plan: ConcatenationPlan

    /// What the path scan reported while resolving this output's includes.
    public let scanWarnings: [SelectionScanWarning]

    public init(
        declaration: ConcatenationDefinition.Output,
        plan: ConcatenationPlan,
        scanWarnings: [SelectionScanWarning] = []
    ) {
        self.declaration = declaration
        self.plan = plan
        self.scanWarnings = scanWarnings
    }

    public var outputURL: URL {
        declaration.destination
    }

    public var sources:
        [ConcatenationSource]
    {
        plan.sources
    }

    public var name: String {
        declaration.name
    }

    public var isEmpty: Bool {
        plan.sources.isEmpty
    }

    public var fileCount: Int {
        plan.sources.count
    }
}

public struct ConcatenationRenderedOutput {
    public let resolved: ConcatenationResolvedOutput
    public let result: ConcatenationRenderResult

    public init(
        resolved: ConcatenationResolvedOutput,
        result: ConcatenationRenderResult
    ) {
        self.resolved = resolved
        self.result = result
    }

    public var name: String {
        resolved.name
    }

    public var fileCount: Int {
        result.document.sections.count
    }
}

public struct ConcatenationWrittenOutput {
    public let resolved: ConcatenationResolvedOutput
    public let result: ConcatenationWriteResult

    public init(
        resolved: ConcatenationResolvedOutput,
        result: ConcatenationWriteResult
    ) {
        self.resolved = resolved
        self.result = result
    }

    public var name: String {
        resolved.name
    }
}

public struct ConcatenationResolutionStatistics:
    Sendable,
    Equatable
{
    public let duration: TimeInterval
    public let scanRequestCount: Int
    public let plannedTraversalCount: Int
    public let physicalTraversalCount: Int
    public let physicalTraversals:
        [PathScanPhysicalTraversalStatistics]
    public let resolver:
        ConcatenationResolverStatistics
    public let outputAssemblyDuration:
        TimeInterval
    public let uniqueRoots: [URL]
    public let matchedOutputCount: Int
    public let unmatchedOutputCount: Int

    public init(
        duration: TimeInterval = 0,
        scanRequestCount: Int = 0,
        plannedTraversalCount: Int = 0,
        physicalTraversalCount: Int = 0,
        physicalTraversals:
            [PathScanPhysicalTraversalStatistics] = [],
        resolver:
            ConcatenationResolverStatistics = .init(),
        outputAssemblyDuration:
            TimeInterval = 0,
        uniqueRoots: [URL] = [],
        matchedOutputCount: Int = 0,
        unmatchedOutputCount: Int = 0
    ) {
        self.duration = duration
        self.scanRequestCount = scanRequestCount
        self.plannedTraversalCount = plannedTraversalCount
        self.physicalTraversalCount = physicalTraversalCount
        self.physicalTraversals = physicalTraversals
        self.resolver = resolver
        self.outputAssemblyDuration =
            outputAssemblyDuration

        self.uniqueRoots = Array(
            Set(
                uniqueRoots.map(
                    \.standardizedFileURL
                )
            )
        )
        .sorted {
            $0.path < $1.path
        }

        self.matchedOutputCount = matchedOutputCount
        self.unmatchedOutputCount = unmatchedOutputCount
    }

    public var uniqueRootCount: Int {
        uniqueRoots.count
    }
}

public struct ConcatenationResolvedBatch {
    public let outputs: [ConcatenationResolvedOutput]
    public let statistics: ConcatenationResolutionStatistics

    public init(
        outputs: [ConcatenationResolvedOutput],
        statistics: ConcatenationResolutionStatistics
    ) {
        self.outputs = outputs
        self.statistics = statistics
    }
}

public struct ConcatenationRenderBatchResult {
    public let outputs: [ConcatenationRenderedOutput]
    public let skipped: [ConcatenationResolvedOutput]
    public let resolution: ConcatenationResolutionStatistics

    public init(
        outputs: [ConcatenationRenderedOutput],
        skipped: [ConcatenationResolvedOutput],
        resolution: ConcatenationResolutionStatistics = .init()
    ) {
        self.outputs = outputs
        self.skipped = skipped
        self.resolution = resolution
    }

    public var outputCount: Int {
        outputs.count
    }

    public var fileCount: Int {
        outputs.reduce(
            0
        ) {
            $0 + $1.fileCount
        }
    }

    public var warnings: [ConcatenationWarning] {
        outputs.flatMap {
            $0.result.document.warnings
        }
    }

    public var combinedText: String {
        guard outputs.count > 1 else {
            return outputs.first?.result.text ?? ""
        }

        return outputs.map { output in
            """
            ===== .conany output: \(output.name) =====

            \(output.result.text)
            """
        }
        .joined(
            separator: "\n\n"
        )
    }
}

public enum ConcatenationContextIndexAction:
    Equatable
{
    case none
    case written(URL)
    case overwritten(URL)
    case removed(URL)
    case skippedManual(URL)
    case unchanged(URL)
}

public enum ConcatenationExecutionKind:
    Sendable,
    Equatable
{
    case unchanged
    case updated
    case rebuilt
}

public struct ConcatenationSourcePreflightStatistics:
    Sendable,
    Equatable
{
    public let duration: TimeInterval
    public let sourceReferenceCount: Int
    public let uniqueSourceCount: Int
    public let uniqueResolvedSourceCount: Int
    public let metadataInspectionCount: Int
    public let sharedMetadataReuseCount: Int

    public init(
        duration: TimeInterval = 0,
        sourceReferenceCount: Int = 0,
        uniqueSourceCount: Int = 0,
        uniqueResolvedSourceCount: Int = 0,
        metadataInspectionCount: Int = 0,
        sharedMetadataReuseCount: Int = 0
    ) {
        self.duration = duration
        self.sourceReferenceCount =
            sourceReferenceCount
        self.uniqueSourceCount =
            uniqueSourceCount
        self.uniqueResolvedSourceCount =
            uniqueResolvedSourceCount
        self.metadataInspectionCount =
            metadataInspectionCount
        self.sharedMetadataReuseCount =
            sharedMetadataReuseCount
    }
}

public struct ConcatenationReuseProofStatistics:
    Sendable,
    Equatable
{
    public let lookupCount: Int
    public let uniqueProofCount: Int
    public let sharedHitCount: Int
    public let fingerprintComputationCount: Int

    public init(
        lookupCount: Int = 0,
        uniqueProofCount: Int = 0,
        sharedHitCount: Int = 0,
        fingerprintComputationCount: Int = 0
    ) {
        self.lookupCount =
            lookupCount
        self.uniqueProofCount =
            uniqueProofCount
        self.sharedHitCount =
            sharedHitCount
        self.fingerprintComputationCount =
            fingerprintComputationCount
    }
}

public struct ConcatenationWriteBatchStatistics:
    Sendable,
    Equatable
{
    public let duration: TimeInterval
    public let resolutionDuration: TimeInterval
    public let outputDuration: TimeInterval
    public let contextIndexDuration: TimeInterval

    public init(
        duration: TimeInterval = 0,
        resolutionDuration: TimeInterval = 0,
        outputDuration: TimeInterval = 0,
        contextIndexDuration: TimeInterval = 0
    ) {
        self.duration = duration
        self.resolutionDuration =
            resolutionDuration
        self.outputDuration =
            outputDuration
        self.contextIndexDuration =
            contextIndexDuration
    }

    public var measuredDuration: TimeInterval {
        resolutionDuration
            + outputDuration
            + contextIndexDuration
    }

    public var otherDuration: TimeInterval {
        max(
            0,
            duration - measuredDuration
        )
    }
}

public struct ConcatenationWriteBatchResult {
    public let outputs: [ConcatenationWrittenOutput]
    public let skipped: [ConcatenationResolvedOutput]
    public let contextIndexAction: ConcatenationContextIndexAction
    public let resolution: ConcatenationResolutionStatistics
    public let sourcePreflight:
        ConcatenationSourcePreflightStatistics
    public let reuseProofs:
        ConcatenationReuseProofStatistics
    public let statistics: ConcatenationWriteBatchStatistics

    public init(
        outputs: [ConcatenationWrittenOutput],
        skipped: [ConcatenationResolvedOutput],
        contextIndexAction: ConcatenationContextIndexAction,
        resolution: ConcatenationResolutionStatistics = .init(),
        sourcePreflight:
            ConcatenationSourcePreflightStatistics = .init(),
        reuseProofs:
            ConcatenationReuseProofStatistics = .init(),
        statistics: ConcatenationWriteBatchStatistics = .init()
    ) {
        self.outputs = outputs
        self.skipped = skipped
        self.contextIndexAction = contextIndexAction
        self.resolution = resolution
        self.sourcePreflight =
            sourcePreflight
        self.reuseProofs =
            reuseProofs
        self.statistics = statistics
    }

    public var outputCount: Int {
        outputs.count
    }

    public var fileCount: Int {
        outputs.reduce(
            0
        ) {
            $0 + $1.result.documentStatistics.sourceCount
        }
    }

    public var renderedOutputCount: Int {
        outputs.reduce(
            0
        ) {
            $0 + ($1.result.performedRender ? 1 : 0)
        }
    }

    public var writtenOutputCount: Int {
        outputs.reduce(
            0
        ) {
            $0 + ($1.result.performedWrite ? 1 : 0)
        }
    }

    public var warnings: [ConcatenationWarning] {
        outputs.flatMap {
            $0.result.warnings
        }
    }

    public var cache: ConcatenationStatistics.Cache {
        outputs.reduce(
            .init()
        ) { aggregate, output in
            let next = output.result.documentStatistics.cache

            return .init(
                metadataInspections:
                    aggregate.metadataInspections
                    + next.metadataInspections,
                safeguardReads:
                    aggregate.safeguardReads
                    + next.safeguardReads,
                safeguardHits:
                    aggregate.safeguardHits
                    + next.safeguardHits,
                sourceReads:
                    aggregate.sourceReads
                    + next.sourceReads,
                metadataHits:
                    aggregate.metadataHits
                    + next.metadataHits,
                contentHits:
                    aggregate.contentHits
                    + next.contentHits,
                sectionLoads:
                    aggregate.sectionLoads
                    + next.sectionLoads,
                rebuilds:
                    aggregate.rebuilds
                    + next.rebuilds
            )
        }
    }

    public var reusedSourceCount: Int {
        cache.metadataHits
            + cache.contentHits
    }

    public var executionKind: ConcatenationExecutionKind {
        if renderedOutputCount == 0,
           writtenOutputCount == 0 {
            return .unchanged
        }

        if fileCount > 0,
           cache.rebuilds == fileCount {
            return .rebuilt
        }

        return .updated
    }

    public var totalLineCount: Int {
        outputs.reduce(
            0
        ) {
            $0 + $1.result.renderedLineCount
        }
    }

    public var outputStatistics:
        ConcatenationWriteStatistics
    {
        outputs.reduce(
            .init()
        ) {
            $0 + $1.result.statistics
        }
    }

    public var performedWrite: Bool {
        outputs.contains {
            $0.result.performedWrite
        }
    }
}

public enum ConcatenationExecutionError:
    Error,
    LocalizedError
{
    case noOutputs
    case outputCollision(URL)

    public var errorDescription: String? {
        switch self {
        case .noOutputs:
            return "No outputs contained matching files."

        case .outputCollision(let url):
            return "Multiple outputs resolve to the same destination: \(url.path)"
        }
    }
}

public struct ConcatenationExecution: SafelyConcatenatable {
    public let definition: ConcatenationDefinition
    public let options: ConcatenationExecutionOptions

    /// Fails with `outputCollision` when two outputs share a destination.
    public init(
        definition: ConcatenationDefinition,
        options: ConcatenationExecutionOptions = .init()
    ) throws {
        var seenPaths: Set<String> = []

        for output in definition.outputs {
            guard seenPaths.insert(
                output.destination.path
            ).inserted else {
                throw ConcatenationExecutionError.outputCollision(
                    output.destination
                )
            }
        }

        self.definition = definition
        self.options = options
    }

    public func resolveBatch() throws -> ConcatenationResolvedBatch {
        let startedAt = Date()
        let outputsToResolve = definition.outputs

        let resolverBatch = try ConcatenationResolver(
            anchor: definition.anchor
        ).resolve(
            outputsToResolve.map(\.specification),
            maxDepth: options.maxDepth,
            includeHidden: options.includeDotfiles
        )

        let outputAssemblyStartedAt = Date()

        let renderOptions = ConcatenationRenderOptions(
            delimiter: .init(
                style: options.delimiterStyle,
                closure: options.delimiterClosure
            ),
            line: .init(
                filemax: options.maxLinesPerFile,
                trimblanks: true,
                numbers: options.includeSourceLineNumbers
            ),
            output: .init(
                format: options.outputFormat,
                raw: options.rawOutput,
                relativepaths: false,
                modifiedstamp: options.includeSourceModifiedAt,
                obscurations: options.obscurations
            )
        )

        var outputs: [ConcatenationResolvedOutput] = []

        outputs.reserveCapacity(
            outputsToResolve.count
        )

        for (declaration, resolved) in zip(
            outputsToResolve,
            resolverBatch.results
        ) {
            let sources = resolved.matches.map { match in
                ConcatenationSource(
                    standardizedFile: match.url,
                    presentedPath: declaration.presentedPath(
                        for: match
                    ),
                    selections: match.contentSelections
                )
            }

            outputs.append(
                ConcatenationResolvedOutput(
                    declaration: declaration,
                    plan: ConcatenationPlan(
                        context: declaration.context,
                        sources: sources,
                        options: renderOptions
                    ),
                    scanWarnings: resolved.warnings
                )
            )
        }

        let plannedTraversalRoots = resolverBatch.results.flatMap(
            \.plannedTraversalRoots
        )

        let matchedOutputCount = outputs.reduce(0) {
            $0 + ($1.isEmpty ? 0 : 1)
        }

        let outputAssemblyDuration = Date().timeIntervalSince(
            outputAssemblyStartedAt
        )

        return .init(
            outputs: outputs,
            statistics: .init(
                duration: Date().timeIntervalSince(
                    startedAt
                ),
                scanRequestCount: outputsToResolve.count,
                plannedTraversalCount: resolverBatch.logicalTraversalCount,
                physicalTraversalCount: resolverBatch.physicalTraversalCount,
                physicalTraversals: resolverBatch.physicalTraversals,
                resolver: resolverBatch.statistics,
                outputAssemblyDuration: outputAssemblyDuration,
                uniqueRoots: plannedTraversalRoots,
                matchedOutputCount: matchedOutputCount,
                unmatchedOutputCount: outputs.count - matchedOutputCount
            )
        )
    }

    public func resolve() throws -> [ConcatenationResolvedOutput] {
        try resolveBatch().outputs
    }

    public func render(
        concurrency: IOConcurrency = .automatic
    ) async throws -> ConcatenationRenderBatchResult {
        try await renderResolved(
            session: nil,
            concurrency: concurrency
        )
    }

    public func render(
        using session: ConcatenationSession,
        concurrency: IOConcurrency = .automatic
    ) async throws -> ConcatenationRenderBatchResult {
        try await renderResolved(
            session: session,
            concurrency: concurrency
        )
    }

    /// Renders every output without writing artifacts, for callers that hand
    /// the combined text elsewhere (the CLI copies it to the clipboard).
    public func renderNonEmpty(
        concurrency: IOConcurrency = .automatic
    ) async throws -> ConcatenationRenderBatchResult {
        let result = try await render(
            concurrency: concurrency
        )

        guard !result.outputs.isEmpty else {
            throw ConcatenationExecutionError.noOutputs
        }

        return result
    }

    public func write(
        concurrency: IOConcurrency = .automatic
    ) async throws -> ConcatenationWriteBatchResult {
        let startedAt =
            Date()

        let resolutionStartedAt =
            Date()

        let resolvedBatch = try resolveBatch()
        let resolved = resolvedBatch.outputs

        let resolutionDuration =
            Date().timeIntervalSince(
                resolutionStartedAt
            )

        let outputStartedAt =
            Date()

        let sourcePreflightStartedAt =
            Date()

        let sourceReferences =
            resolved.flatMap {
                $0.sources.map(
                    \.file
                )
            }
            .filter { source in
                !(options.protectSecrets
                    && !options.allowSecrets
                    && isProtectedFile(
                        source
                    ))
            }

        let sourcePreflightResult =
            try await ConcatenationSourcePreflight.inspect(
                sources:
                    sourceReferences,
                concurrency:
                    concurrency
            )

        let sourcePreflightStatistics =
            ConcatenationSourcePreflightStatistics(
                duration:
                    Date().timeIntervalSince(
                        sourcePreflightStartedAt
                    ),
                sourceReferenceCount:
                    sourcePreflightResult
                    .sourceReferenceCount,
                uniqueSourceCount:
                    sourcePreflightResult
                    .uniqueSourceCount,
                uniqueResolvedSourceCount:
                    sourcePreflightResult
                    .uniqueResolvedSourceCount,
                metadataInspectionCount:
                    sourcePreflightResult
                    .metadataInspectionCount,
                sharedMetadataReuseCount:
                    sourcePreflightResult
                    .sharedMetadataReuseCount
            )

        let reuseProofCache =
            ConcatenationReuseProofCache()

        let workspace = ConcatenationWorkspace(
            configuration: definition.configuration
        )

        var outputs: [ConcatenationWrittenOutput] = []
        var skipped: [ConcatenationResolvedOutput] = []

        var collectedContexts: [String] = []

        if definition.outputs.contains(
            where: {
                $0.context != nil
            }
        ) {
            collectedContexts.append(
                """
                // type: autogenerated
                // signature: concatenator
                """
            )
        }

        for output in resolved {
            guard !output.isEmpty else {
                skipped.append(
                    output
                )
                continue
            }

            if let context = output.declaration.context {
                collectedContexts.append(
                    context.object(
                        outputURL: output.outputURL
                    )
                )
            }

            let concatenator = makeConcatenator(
                for: output,
                outputURL: output.outputURL,
                workspace: workspace,
                sourcePreflight:
                    sourcePreflightResult.preflight,
                reuseProofCache:
                    reuseProofCache
            )

            let result = try await concatenator.write(
                concurrency: concurrency
            )

            outputs.append(
                .init(
                    resolved: output,
                    result: result
                )
            )
        }

        let reuseProofSnapshot =
            reuseProofCache.snapshot()

        let reuseProofStatistics =
            ConcatenationReuseProofStatistics(
                lookupCount:
                    reuseProofSnapshot.lookupCount,
                uniqueProofCount:
                    reuseProofSnapshot.uniqueProofCount,
                sharedHitCount:
                    reuseProofSnapshot.sharedHitCount,
                fingerprintComputationCount:
                    reuseProofSnapshot.fingerprintComputationCount
            )

        let outputDuration =
            Date().timeIntervalSince(
                outputStartedAt
            )

        let refreshContextIndex = outputs.contains {
            $0.result.performedWrite
        }

        let contextIndexStartedAt =
            Date()

        let contextIndexAction = try updateContextIndex(
            collectedContexts: collectedContexts,
            refresh: refreshContextIndex
        )

        let contextIndexDuration =
            Date().timeIntervalSince(
                contextIndexStartedAt
            )

        return .init(
            outputs: outputs,
            skipped: skipped,
            contextIndexAction: contextIndexAction,
            resolution: resolvedBatch.statistics,
            sourcePreflight:
                sourcePreflightStatistics,
            reuseProofs:
                reuseProofStatistics,
            statistics: .init(
                duration:
                    Date().timeIntervalSince(
                        startedAt
                    ),
                resolutionDuration:
                    resolutionDuration,
                outputDuration:
                    outputDuration,
                contextIndexDuration:
                    contextIndexDuration
            )
        )
    }

}

private extension ConcatenationExecution {
    var configDirectory: URL {
        definition.anchor
    }

    func renderResolved(
        session: ConcatenationSession?,
        concurrency: IOConcurrency
    ) async throws -> ConcatenationRenderBatchResult {
        let resolvedBatch = try resolveBatch()

        var outputs: [ConcatenationRenderedOutput] = []
        var skipped: [ConcatenationResolvedOutput] = []

        outputs.reserveCapacity(
            resolvedBatch.outputs.count
        )

        skipped.reserveCapacity(
            resolvedBatch.outputs.count
        )

        for output in resolvedBatch.outputs {
            guard !output.isEmpty else {
                skipped.append(
                    output
                )
                continue
            }

            let concatenator = makeConcatenator(
                for: output,
                outputURL: nil,
                workspace: nil,
                cache: session?.binding(
                    for: output.outputURL
                )
            )

            let result = try await concatenator.render(
                concurrency: concurrency
            )

            outputs.append(
                .init(
                    resolved: output,
                    result: result
                )
            )
        }

        return .init(
            outputs: outputs,
            skipped: skipped,
            resolution: resolvedBatch.statistics
        )
    }

    func makeConcatenator(
        for resolved: ConcatenationResolvedOutput,
        outputURL: URL?,
        workspace: ConcatenationWorkspace?,
        cache: ConcatenationCacheBinding? = nil,
        sourcePreflight:
            ConcatenationSourcePreflight? = nil,
        reuseProofCache:
            ConcatenationReuseProofCache? = nil
    ) -> FileConcatenator {
        FileConcatenator(
            plan:
                resolved.plan,
            outputURL:
                outputURL,
            workspace:
                workspace,
            cache:
                cache,

            protectSecrets:
                options.protectSecrets,
            allowSecrets:
                options.allowSecrets,
            failOnBlockedFiles:
                options.failOnBlockedFiles,
            deepSecretInspection:
                options.deepSecretInspection
        )
        .sharingSourcePreflight(
            sourcePreflight
        )
        .sharingReuseProofCache(
            reuseProofCache
        )
    }

    func updateContextIndex(
        collectedContexts: [String],
        refresh: Bool
    ) throws -> ConcatenationContextIndexAction {
        let contextsURL = configDirectory
            .appendingPathComponent(
                "context_index.txt",
                isDirectory: false
            )

        let exists = FileManager.default.fileExists(
            atPath: contextsURL.path
        )

        if collectedContexts.isEmpty {
            guard exists else {
                return .none
            }

            let text = try String(
                contentsOf: contextsURL,
                encoding: .utf8
            )

            guard isConcatenatorSigned(
                text
            ) else {
                return .skippedManual(
                    contextsURL
                )
            }

            try FileSystem.default.remove(
                contextsURL
            )

            return .removed(
                contextsURL
            )
        }

        let contextsJoined = collectedContexts.joined(
            separator: "\n\n"
        )

        guard exists else {
            try contextsJoined.write(
                to: contextsURL,
                atomically: true,
                encoding: .utf8
            )

            return .written(
                contextsURL
            )
        }

        let existing = try String(
            contentsOf: contextsURL,
            encoding: .utf8
        )

        guard isConcatenatorSigned(
            existing
        ) else {
            return .skippedManual(
                contextsURL
            )
        }

        let materialChanged =
            contextIndexMaterial(
                existing
            )
            != contextIndexMaterial(
                contextsJoined
            )

        guard refresh || materialChanged else {
            return .unchanged(
                contextsURL
            )
        }

        try contextsJoined.write(
            to: contextsURL,
            atomically: true,
            encoding: .utf8
        )

        return .overwritten(
            contextsURL
        )
    }

    func contextIndexMaterial(
        _ text: String
    ) -> String {
        text.replacingOccurrences(
            of: #""generated_at"\s*:\s*"[^"]*""#,
            with: #""generated_at" : "<generated_at>""#,
            options: .regularExpression
        )
    }

    func isConcatenatorSigned(
        _ text: String
    ) -> Bool {
        let firstLines = text
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .prefix(10)
            .map(
                String.init
            )

        let hasTypeMarker = firstLines.contains {
            $0.trimmingCharacters(
                in: .whitespacesAndNewlines
            ) == "// type: autogenerated"
        }

        let hasSignature = firstLines.contains {
            $0.trimmingCharacters(
                in: .whitespacesAndNewlines
            ) == "// signature: concatenator"
        }

        return hasTypeMarker
            && hasSignature
    }
}
