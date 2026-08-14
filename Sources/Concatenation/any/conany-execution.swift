import Clipboard
import Foundation
import IO
import Path
import Selection

public struct ConAnyExecutionOptions {
    public let maxDepth: Int?
    public let includeDotfiles: Bool
    public let ignoreMap: IgnoreMap

    public let delimiterStyle: DelimiterStyle
    public let delimiterClosure: Bool
    public let maxLinesPerFile: Int?
    public let rawOutput: Bool
    public let outputFormat: ConcatenationOutputFormat
    public let includeSourceLineNumbers: Bool
    public let includeSourceModifiedAt: Bool

    public let verboseResolution: Bool
    public let verboseOutput: Bool

    public let protectSecrets: Bool
    public let allowSecrets: Bool
    public let failOnBlockedFiles: Bool
    public let deepSecretInspection: Bool

    public init(
        maxDepth: Int? = nil,
        includeDotfiles: Bool = false,
        ignoreMap: IgnoreMap = .init(),
        delimiterStyle: DelimiterStyle = .boxed,
        delimiterClosure: Bool = false,
        maxLinesPerFile: Int? = 10_000,
        rawOutput: Bool = false,
        outputFormat: ConcatenationOutputFormat = .text,
        includeSourceLineNumbers: Bool = false,
        includeSourceModifiedAt: Bool = false,
        verboseResolution: Bool = false,
        verboseOutput: Bool = false,
        protectSecrets: Bool = true,
        allowSecrets: Bool = false,
        failOnBlockedFiles: Bool = false,
        deepSecretInspection: Bool = true
    ) {
        self.maxDepth = maxDepth
        self.includeDotfiles = includeDotfiles
        self.ignoreMap = ignoreMap

        self.delimiterStyle = delimiterStyle
        self.delimiterClosure = delimiterClosure
        self.maxLinesPerFile = maxLinesPerFile
        self.rawOutput = rawOutput
        self.outputFormat = outputFormat
        self.includeSourceLineNumbers = includeSourceLineNumbers
        self.includeSourceModifiedAt = includeSourceModifiedAt

        self.verboseResolution = verboseResolution
        self.verboseOutput = verboseOutput

        self.protectSecrets = protectSecrets
        self.allowSecrets = allowSecrets
        self.failOnBlockedFiles = failOnBlockedFiles
        self.deepSecretInspection = deepSecretInspection
    }
}

public struct ConAnyResolvedOutput {
    public let renderable: ConAnyRenderableObject
    public let outputURL: URL
    public let files: [URL]
    public let selectedContentByFile: [URL: [ContentSelection]]
    public let presentedPathByFile: [URL: String]

    public init(
        renderable: ConAnyRenderableObject,
        outputURL: URL,
        files: [URL],
        selectedContentByFile: [URL: [ContentSelection]],
        presentedPathByFile: [URL: String]
    ) {
        self.renderable = renderable
        self.outputURL = outputURL.standardizedFileURL
        self.files = files.map(
            \.standardizedFileURL
        )
        self.selectedContentByFile = selectedContentByFile
        self.presentedPathByFile = presentedPathByFile
    }

    public var name: String {
        renderable.output
    }

    public var isEmpty: Bool {
        files.isEmpty
    }

    public var fileCount: Int {
        files.count
    }
}

public struct ConAnyRenderedOutput {
    public let resolved: ConAnyResolvedOutput
    public let result: ConcatenationRenderResult

    public init(
        resolved: ConAnyResolvedOutput,
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

public struct ConAnyWrittenOutput {
    public let resolved: ConAnyResolvedOutput
    public let result: ConcatenationWriteResult

    public init(
        resolved: ConAnyResolvedOutput,
        result: ConcatenationWriteResult
    ) {
        self.resolved = resolved
        self.result = result
    }

    public var name: String {
        resolved.name
    }
}

public struct ConAnyResolutionStatistics:
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
        ConAnyResolverStatistics
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
            ConAnyResolverStatistics = .init(),
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

public struct ConAnyResolvedBatch {
    public let outputs: [ConAnyResolvedOutput]
    public let statistics: ConAnyResolutionStatistics

    public init(
        outputs: [ConAnyResolvedOutput],
        statistics: ConAnyResolutionStatistics
    ) {
        self.outputs = outputs
        self.statistics = statistics
    }
}

public struct ConAnyRenderBatchResult {
    public let outputs: [ConAnyRenderedOutput]
    public let skipped: [ConAnyResolvedOutput]
    public let resolution: ConAnyResolutionStatistics

    public init(
        outputs: [ConAnyRenderedOutput],
        skipped: [ConAnyResolvedOutput],
        resolution: ConAnyResolutionStatistics = .init()
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

public enum ConAnyContextIndexAction:
    Equatable
{
    case none
    case written(URL)
    case overwritten(URL)
    case removed(URL)
    case skippedManual(URL)
    case unchanged(URL)
}

public enum ConAnyExecutionKind:
    Sendable,
    Equatable
{
    case unchanged
    case updated
    case rebuilt
}

public struct ConAnyWriteBatchResult {
    public let outputs: [ConAnyWrittenOutput]
    public let skipped: [ConAnyResolvedOutput]
    public let contextIndexAction: ConAnyContextIndexAction
    public let resolution: ConAnyResolutionStatistics

    public init(
        outputs: [ConAnyWrittenOutput],
        skipped: [ConAnyResolvedOutput],
        contextIndexAction: ConAnyContextIndexAction,
        resolution: ConAnyResolutionStatistics = .init()
    ) {
        self.outputs = outputs
        self.skipped = skipped
        self.contextIndexAction = contextIndexAction
        self.resolution = resolution
    }

    public var outputCount: Int {
        outputs.count
    }

    public var fileCount: Int {
        outputs.reduce(
            0
        ) {
            $0 + $1.result.document.statistics.sourceCount
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
            $0.result.document.warnings
        }
    }

    public var cache: ConcatenationStatistics.Cache {
        outputs.reduce(
            .init()
        ) { aggregate, output in
            let next = output.result.document.statistics.cache

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

    public var executionKind: ConAnyExecutionKind {
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

    public var performedWrite: Bool {
        outputs.contains {
            $0.result.performedWrite
        }
    }
}

public enum ConAnyExecutionError:
    Error,
    LocalizedError
{
    case noOutputs

    public var errorDescription: String? {
        switch self {
        case .noOutputs:
            return "No .conany outputs contained matching files."
        }
    }
}

public struct ConAnyExecution {
    public let configURL: URL
    public let configuration: ConAnyConfig
    public let options: ConAnyExecutionOptions

    public init(
        configURL: URL,
        configuration: ConAnyConfig,
        options: ConAnyExecutionOptions = .init()
    ) {
        self.configURL = configURL.standardizedFileURL
        self.configuration = configuration
        self.options = options
    }

    public init(
        configURL: URL,
        options: ConAnyExecutionOptions = .init()
    ) throws {
        let standardized = configURL.standardizedFileURL

        self.configURL = standardized
        self.configuration = try ConAnyParser.parseFile(
            at: standardized
        )
        self.options = options
    }

    public func resolveBatch() throws -> ConAnyResolvedBatch {
        let startedAt = Date()

        let resolver = ConAnyResolver(
            baseDir: configDirectory.path
        )

        let resolverBatch = try resolver.resolveResults(
            configuration.renderables,
            maxDepth: options.maxDepth,
            includeDotfiles: options.includeDotfiles,
            ignoreMap: options.ignoreMap,
            verbose: options.verboseResolution
        )

        precondition(
            resolverBatch.results.count
                == configuration.renderables.count
        )

        let outputAssemblyStartedAt =
            Date()

        var outputs: [ConAnyResolvedOutput] = []

        outputs.reserveCapacity(
            configuration.renderables.count
        )

        for index in configuration.renderables.indices {
            let renderable =
                configuration.renderables[index]

            let resolved =
                resolverBatch.results[index]

            let matches =
                resolved.matches

            let files = matches.map {
                $0.url.standardizedFileURL
            }

            let selectedContentByFile = Dictionary(
                uniqueKeysWithValues: matches.map {
                    match in

                    (
                        match.url.standardizedFileURL,
                        match.contentSelections
                    )
                }
            )

            let presentedPathByFile = Dictionary(
                uniqueKeysWithValues: matches.map {
                    match in

                    (
                        match.url.standardizedFileURL,
                        resolver.presentedPath(
                            for: match.url,
                            in: renderable
                        )
                    )
                }
            )

            outputs.append(
                ConAnyResolvedOutput(
                    renderable: renderable,
                    outputURL: resolver.outputURL(
                        for: renderable
                    ),
                    files: files,
                    selectedContentByFile:
                        selectedContentByFile,
                    presentedPathByFile:
                        presentedPathByFile
                )
            )
        }

        let plannedTraversalRoots =
            resolverBatch
            .results
            .flatMap(
                \.plannedTraversalRoots
            )

        let matchedOutputCount = outputs.reduce(
            0
        ) {
            $0 + ($1.isEmpty ? 0 : 1)
        }

        let outputAssemblyDuration =
            Date().timeIntervalSince(
                outputAssemblyStartedAt
            )

        let duration = Date().timeIntervalSince(
            startedAt
        )

        return .init(
            outputs: outputs,
            statistics: .init(
                duration: duration,
                scanRequestCount:
                    configuration.renderables.count,
                plannedTraversalCount:
                    resolverBatch.logicalTraversalCount,
                physicalTraversalCount:
                    resolverBatch.physicalTraversalCount,
                physicalTraversals:
                    resolverBatch.physicalTraversals,
                resolver:
                    resolverBatch.statistics,
                outputAssemblyDuration:
                    outputAssemblyDuration,
                uniqueRoots:
                    plannedTraversalRoots,
                matchedOutputCount:
                    matchedOutputCount,
                unmatchedOutputCount:
                    outputs.count
                    - matchedOutputCount
            )
        )
    }

    public func resolve() throws -> [ConAnyResolvedOutput] {
        try resolveBatch().outputs
    }

    public func render(
        concurrency: IOConcurrency = .automatic
    ) async throws -> ConAnyRenderBatchResult {
        let resolvedBatch = try resolveBatch()
        let resolved = resolvedBatch.outputs

        var outputs: [ConAnyRenderedOutput] = []
        var skipped: [ConAnyResolvedOutput] = []

        for output in resolved {
            guard !output.isEmpty else {
                skipped.append(
                    output
                )
                continue
            }

            let concatenator = makeConcatenator(
                for: output,
                outputURL: nil,
                workspace: nil
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

    @discardableResult
    public func copy(
        concurrency: IOConcurrency = .automatic
    ) async throws -> ConAnyRenderBatchResult {
        let result = try await render(
            concurrency: concurrency
        )

        guard !result.outputs.isEmpty else {
            throw ConAnyExecutionError.noOutputs
        }

        result.combinedText.clipboard()

        return result
    }

    public func write(
        concurrency: IOConcurrency = .automatic
    ) async throws -> ConAnyWriteBatchResult {
        let resolvedBatch = try resolveBatch()
        let resolved = resolvedBatch.outputs

        let workspace = ConcatenationWorkspace(
            configuration: configURL
        )

        var outputs: [ConAnyWrittenOutput] = []
        var skipped: [ConAnyResolvedOutput] = []

        var collectedContexts: [String] = []

        if configuration.renderables.contains(
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

            if let context = output.renderable.context {
                collectedContexts.append(
                    context.object(
                        outputURL: output.outputURL
                    )
                )
            }

            let concatenator = makeConcatenator(
                for: output,
                outputURL: output.outputURL,
                workspace: workspace
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

        let refreshContextIndex = outputs.contains {
            $0.result.performedWrite
        }

        let contextIndexAction = try updateContextIndex(
            collectedContexts: collectedContexts,
            refresh: refreshContextIndex
        )

        return .init(
            outputs: outputs,
            skipped: skipped,
            contextIndexAction: contextIndexAction,
            resolution: resolvedBatch.statistics
        )
    }
}

private extension ConAnyExecution {
    var configDirectory: URL {
        configURL
            .deletingLastPathComponent()
            .standardizedFileURL
    }

    func makeConcatenator(
        for resolved: ConAnyResolvedOutput,
        outputURL: URL?,
        workspace: ConcatenationWorkspace?
    ) -> FileConcatenator {
        FileConcatenator(
            inputFiles: resolved.files,
            outputURL: outputURL,
            context: resolved.renderable.context,
            workspace: workspace,
            selectedContentByFile: resolved.selectedContentByFile,
            presentedPathByFile: resolved.presentedPathByFile,

            delimiterStyle: options.delimiterStyle,
            delimiterClosure: options.delimiterClosure,
            maxLinesPerFile: options.maxLinesPerFile,
            trimBlankLines: true,
            relativePaths: false,
            rawOutput: options.rawOutput,
            outputFormat: options.outputFormat,
            includeSourceLineNumbers: options.includeSourceLineNumbers,
            includeSourceModifiedAt: options.includeSourceModifiedAt,
            obscureMap: options.ignoreMap.obscureValues,

            verbose: options.verboseOutput,
            reportWarnings: false,

            location: outputURL.map {
                "con any block '\(resolved.name)' → \($0.path)"
            },

            protectSecrets: options.protectSecrets,
            allowSecrets: options.allowSecrets,
            failOnBlockedFiles: options.failOnBlockedFiles,
            deepSecretInspection: options.deepSecretInspection
        )
    }

    func updateContextIndex(
        collectedContexts: [String],
        refresh: Bool
    ) throws -> ConAnyContextIndexAction {
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
