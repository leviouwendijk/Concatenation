import Foundation
import IO
import Terminal
import Indentation
import Primitives
import Clipboard
import Path
import Position
import Writers
import Readers
import Selection

public struct FileConcatenator: SafelyConcatenatable {
    public let plan: ConcatenationPlan
    public let outputURL: URL?
    public let workspace: ConcatenationWorkspace?
    public let cache: ConcatenationCacheBinding?

    public let copyToClipboard: Bool
    public let verbose: Bool
    public let reportWarnings: Bool

    public let location: String?

    public let protectSecrets: Bool
    public let allowSecrets: Bool
    public let failOnBlockedFiles: Bool
    public let deepSecretInspection: Bool

    public var inputFiles: [URL] {
        plan.sources.map(
            \.file
        )
    }

    public var context: ConcatenationContext? {
        plan.context
    }

    public var selectedContentByFile:
        [URL: [ContentSelection]]
    {
        var selections:
            [URL: [ContentSelection]] = [:]

        selections.reserveCapacity(
            plan.sources.count
        )

        for source in plan.sources {
            selections[source.file] =
                source.selections
        }

        return selections
    }

    public var presentedPathByFile:
        [URL: String]
    {
        var paths:
            [URL: String] = [:]

        paths.reserveCapacity(
            plan.sources.count
        )

        for source in plan.sources {
            if let presentedPath =
                source.presentedPath
            {
                paths[source.file] =
                    presentedPath
            }
        }

        return paths
    }

    public var delimiterStyle: DelimiterStyle {
        plan.options.delimiter.style
    }

    public var delimiterClosure: Bool {
        plan.options.delimiter.closure
    }

    public var maxLinesPerFile: Int? {
        plan.options.line.filemax
    }

    public var trimBlankLines: Bool {
        plan.options.line.trimblanks
    }

    public var relativePaths: Bool {
        plan.options.output.relativepaths
    }

    public var rawOutput: Bool {
        plan.options.output.raw
    }

    public var outputFormat:
        ConcatenationOutputFormat
    {
        plan.options.output.format
    }

    public var includeSourceLineNumbers: Bool {
        plan.options.line.numbers
    }

    public var includeSourceModifiedAt: Bool {
        plan.options.output.modifiedstamp
    }

    public var obscureMap:
        [String: String]
    {
        plan.options.output.obscurations
    }

    public init(
        plan: ConcatenationPlan,
        outputURL: URL? = nil,
        workspace: ConcatenationWorkspace? = nil,
        cache: ConcatenationCacheBinding? = nil,

        copyToClipboard: Bool = false,
        verbose: Bool = false,
        reportWarnings: Bool = true,

        location: String? = nil,

        protectSecrets: Bool = true,
        allowSecrets: Bool = false,
        failOnBlockedFiles: Bool = false,
        deepSecretInspection: Bool = false
    ) {
        let standardizedOutputURL =
            outputURL?
            .standardizedFileURL

        self.plan =
            plan

        self.outputURL =
            standardizedOutputURL

        self.workspace =
            workspace

        if let cache {
            self.cache =
                cache
        } else if let workspace,
                  let standardizedOutputURL {
            self.cache =
                ConcatenationCacheBinding(
                    storage:
                        ConcatenationCacheStore(
                            workspace:
                                workspace
                        ),
                    scope:
                        standardizedOutputURL
                )
        } else {
            self.cache =
                nil
        }

        self.copyToClipboard =
            copyToClipboard

        self.verbose =
            verbose

        self.reportWarnings =
            reportWarnings

        self.location =
            location

        self.protectSecrets =
            protectSecrets

        self.allowSecrets =
            allowSecrets

        self.failOnBlockedFiles =
            failOnBlockedFiles

        self.deepSecretInspection =
            deepSecretInspection
    }

    public init(
        inputFiles: [URL],
        outputURL: URL? = nil,
        context: ConcatenationContext? = nil,
        workspace: ConcatenationWorkspace? = nil,
        cache: ConcatenationCacheBinding? = nil,
        selectedContentByFile: [URL: [ContentSelection]] = [:],
        presentedPathByFile: [URL: String] = [:],

        delimiterStyle: DelimiterStyle = .boxed,
        delimiterClosure: Bool = false,
        maxLinesPerFile: Int? = 10_000,
        trimBlankLines: Bool = true,
        relativePaths: Bool = true,
        rawOutput: Bool = false,
        outputFormat: ConcatenationOutputFormat = .text,
        includeSourceLineNumbers: Bool = false,
        includeSourceModifiedAt: Bool = false,
        obscureMap: [String: String] = [:],

        copyToClipboard: Bool = false,
        verbose: Bool = false,
        reportWarnings: Bool = true,

        location: String? = nil,

        protectSecrets: Bool = true,
        allowSecrets: Bool = false,
        failOnBlockedFiles: Bool = false,
        deepSecretInspection: Bool = false
    ) {
        var standardizedSelections:
            [URL: [ContentSelection]] = [:]

        standardizedSelections.reserveCapacity(
            selectedContentByFile.count
        )

        for (
            file,
            selections
        ) in selectedContentByFile {
            standardizedSelections[
                file.standardizedFileURL
            ] = selections
        }

        var standardizedPresentedPaths:
            [URL: String] = [:]

        standardizedPresentedPaths.reserveCapacity(
            presentedPathByFile.count
        )

        for (
            file,
            presentedPath
        ) in presentedPathByFile {
            standardizedPresentedPaths[
                file.standardizedFileURL
            ] = presentedPath
        }

        var sources:
            [ConcatenationSource] = []

        sources.reserveCapacity(
            inputFiles.count
        )

        for file in inputFiles {
            let standardized =
                file.standardizedFileURL

            sources.append(
                ConcatenationSource(
                    standardizedFile:
                        standardized,
                    presentedPath:
                        standardizedPresentedPaths[
                            standardized
                        ],
                    selections:
                        standardizedSelections[
                            standardized
                        ] ?? []
                )
            )
        }

        self.init(
            plan:
                ConcatenationPlan(
                    context:
                        context,
                    sources:
                        sources,
                    options:
                        .init(
                            delimiter:
                                .init(
                                    style:
                                        delimiterStyle,
                                    closure:
                                        delimiterClosure
                                ),
                            line:
                                .init(
                                    filemax:
                                        maxLinesPerFile,
                                    trimblanks:
                                        trimBlankLines,
                                    numbers:
                                        includeSourceLineNumbers
                                ),
                            output:
                                .init(
                                    format:
                                        outputFormat,
                                    raw:
                                        rawOutput,
                                    relativepaths:
                                        relativePaths,
                                    modifiedstamp:
                                        includeSourceModifiedAt,
                                    obscurations:
                                        obscureMap
                                )
                        )
                ),
            outputURL:
                outputURL,
            workspace:
                workspace,
            cache:
                cache,
            copyToClipboard:
                copyToClipboard,
            verbose:
                verbose,
            reportWarnings:
                reportWarnings,
            location:
                location,
            protectSecrets:
                protectSecrets,
            allowSecrets:
                allowSecrets,
            failOnBlockedFiles:
                failOnBlockedFiles,
            deepSecretInspection:
                deepSecretInspection
        )
    }

    public func document() throws -> ConcatenationDocument {
        try prepareDocument(
            preinspected: [:],
            persistCache: true
        ).document
    }

    public func document(
        concurrency: IOConcurrency
    ) async throws -> ConcatenationDocument {
        try await prepareDocument(
            concurrency: concurrency,
            persistCache: true
        ).document
    }

    private func prepareDocument(
        concurrency: IOConcurrency,
        persistCache: Bool
    ) async throws -> ConcatenationPreparedDocument {
        let startedAt =
            Date()

        let cacheLoadStartedAt =
            Date()

        let cachedManifest =
            try cache?.load()

        let cacheLoadDuration =
            Date().timeIntervalSince(
                cacheLoadStartedAt
            )

        let sourceInspectionStartedAt =
            Date()

        let preinspected = try await preinspectSources(
            concurrency: concurrency
        )

        let sourceInspectionDuration =
            Date().timeIntervalSince(
                sourceInspectionStartedAt
            )

        let safeguardStartedAt =
            Date()

        let presafeguards = try await preinspectSafeguards(
            preinspected: preinspected,
            cachedManifest: cachedManifest,
            concurrency: concurrency
        )

        let safeguardDuration =
            Date().timeIntervalSince(
                safeguardStartedAt
            )

        let sectionPreloadStartedAt =
            Date()

        let preloadedSections = try await preloadCachedSections(
            preinspected: preinspected,
            presafeguards: presafeguards,
            cachedManifest: cachedManifest,
            concurrency: concurrency
        )

        let sectionPreloadDuration =
            Date().timeIntervalSince(
                sectionPreloadStartedAt
            )

        let sourcePrereadStartedAt =
            Date()

        let prereads = try await preReadSources(
            preinspected: preinspected,
            presafeguards: presafeguards,
            preloadedSections: preloadedSections,
            cachedManifest: cachedManifest,
            concurrency: concurrency
        )

        let sourcePrereadDuration =
            Date().timeIntervalSince(
                sourcePrereadStartedAt
            )

        let assemblyStartedAt =
            Date()

        let prepared = try prepareDocument(
            preinspected: preinspected,
            presafeguards: presafeguards,
            preloadedSections: preloadedSections,
            sectionsPreloaded: true,
            prereads: prereads,
            cachedManifest: cachedManifest,
            persistCache: persistCache
        )

        let assemblyDuration =
            Date().timeIntervalSince(
                assemblyStartedAt
            )

        let duration =
            Date().timeIntervalSince(
                startedAt
            )

        return ConcatenationPreparedDocument(
            document: prepared.document,
            cacheManifest: prepared.cacheManifest,
            cacheStateChanged:
                prepared.cacheStateChanged,
            sourceActivities:
                prepared.sourceActivities,
            preparationStatistics: .init(
                duration: duration,
                cacheLoadDuration:
                    cacheLoadDuration,
                sourceInspectionDuration:
                    sourceInspectionDuration,
                safeguardDuration:
                    safeguardDuration,
                sectionPreloadDuration:
                    sectionPreloadDuration,
                sourcePrereadDuration:
                    sourcePrereadDuration,
                assemblyDuration:
                    assemblyDuration
            )
        )
    }

    private func prepareDocument(
        preinspected initialPreinspections: [
            URL: [FileMetadataSnapshot]
        ],
        presafeguards initialPresafeguards: [
            URL: ConcatenationCachedSafeguard
        ] = [:],
        preloadedSections initialPreloadedSections: [
            Int: ConcatenationSection
        ] = [:],
        sectionsPreloaded: Bool = false,
        prereads initialPrereads: [
            Int: LineReadResult
        ] = [:],
        cachedManifest providedCachedManifest:
            ConcatenationCacheManifest? = nil,
        persistCache: Bool = true
    ) throws -> ConcatenationPreparedDocument {
        let fileManager = FileManager.default
        var preinspected = initialPreinspections
        let presafeguards = initialPresafeguards
        var preloadedSections = initialPreloadedSections
        var prereads = initialPrereads

        let cache =
            self.cache

        let cachedManifest: ConcatenationCacheManifest?

        if let providedCachedManifest {
            cachedManifest =
                providedCachedManifest
        } else {
            cachedManifest =
                try cache?.load()
        }

        var cachedSourcesByFile: [
            URL: [ConcatenationCachedSource]
        ] = [:]

        for cachedSource in cachedManifest?.sources ?? [] {
            cachedSourcesByFile[
                cachedSource.file.standardizedFileURL,
                default: []
            ].append(
                cachedSource
            )
        }

        var cachedSafeguardsByFile: [
            URL: ConcatenationCachedSafeguard
        ] = [:]

        for cachedSafeguard in cachedManifest?.safeguards ?? [] {
            cachedSafeguardsByFile[
                cachedSafeguard.file.standardizedFileURL
            ] = cachedSafeguard
        }

        let deepSafeguardPolicyFingerprint: ContentFingerprint?

        if protectSecrets
            && !allowSecrets
            && deepSecretInspection
        {
            deepSafeguardPolicyFingerprint = try safeguardPolicyFingerprint()
        } else {
            deepSafeguardPolicyFingerprint = nil
        }

        var sections: [ConcatenationSection] = []
        var cachedSources: [ConcatenationCachedSource] = []
        var cachedSafeguards: [ConcatenationCachedSafeguard] = []
        var evaluatedSafeguardsByFile: [
            URL: ConcatenationCachedSafeguard
        ] = [:]
        var warnings: [ConcatenationWarning] = []
        var errors: [Error] = []

        var blockedFileCount = 0

        var metadataInspections = 0
        var safeguardReads = 0
        var safeguardHits = 0
        var sourceReads = 0
        var metadataHits = 0
        var contentHits = 0
        var rebuilds = 0
        var sourceActivities:
            [ConcatenationSourceActivity] = []

        for (sourceIndex, source) in plan.sources.enumerated() {
            let fileURL = source.file

            if protectSecrets && !allowSecrets {
                if isProtectedFile(fileURL) {
                    blockedFileCount += 1

                    let reason = "Detected filename/extension matching secret patterns."

                    warnings.append(
                        .init(
                            kind: .blockedByPolicy,
                            file: fileURL,
                            message: reason
                        )
                    )

                    if failOnBlockedFiles {
                        errors.append(
                            ConcatError.fileBlockedByPolicy(
                                url: fileURL,
                                reason: reason
                            )
                        )
                    }

                    continue
                }

            }

            do {
                let resolved = try resolveSymlink(
                    at: fileURL
                )

                let metadata: FileMetadataSnapshot
                let resolvedKey = resolved.standardizedFileURL

                if var candidates = preinspected[
                    resolvedKey
                ],
                !candidates.isEmpty {
                    metadata = candidates.removeFirst()

                    if candidates.isEmpty {
                        preinspected.removeValue(
                            forKey: resolvedKey
                        )
                    } else {
                        preinspected[
                            resolvedKey
                        ] = candidates
                    }
                } else {
                    metadata = try FileInspector(
                        resolved
                    ).inspect()
                }

                metadataInspections += 1

                if let deepSafeguardPolicyFingerprint {
                    let safeguardKey = resolved.standardizedFileURL
                    let previousSafeguard = cachedSafeguardsByFile[
                        safeguardKey
                    ]

                    let previousSafeguardMatches: Bool

                    if let previousSafeguard {
                        previousSafeguardMatches =
                            previousSafeguard.metadata == metadata
                            && previousSafeguard.policyFingerprint
                                == deepSafeguardPolicyFingerprint
                    } else {
                        previousSafeguardMatches = false
                    }

                    let safeguard: ConcatenationCachedSafeguard

                    if let evaluated = evaluatedSafeguardsByFile[
                        safeguardKey
                    ],
                    evaluated.metadata == metadata,
                    evaluated.policyFingerprint
                        == deepSafeguardPolicyFingerprint {
                        if previousSafeguardMatches {
                            safeguardHits += 1
                        }

                        safeguard = evaluated
                    } else if let preinspectedSafeguard = presafeguards[
                        safeguardKey
                    ],
                    preinspectedSafeguard.metadata == metadata,
                    preinspectedSafeguard.policyFingerprint
                        == deepSafeguardPolicyFingerprint {
                        if previousSafeguardMatches {
                            safeguardHits += 1
                        } else {
                            safeguardReads += 1
                        }

                        safeguard = preinspectedSafeguard
                    } else if let previousSafeguard,
                              previousSafeguardMatches {
                        safeguardHits += 1
                        safeguard = previousSafeguard
                    } else {
                        safeguardReads += 1

                        let result = Self.deepSecretCheck(
                            resolved
                        )

                        safeguard = .init(
                            metadata: metadata,
                            policyFingerprint:
                                deepSafeguardPolicyFingerprint,
                            matched: result.matched,
                            reason: result.reason
                        )
                    }

                    evaluatedSafeguardsByFile[
                        safeguardKey
                    ] = safeguard

                    cachedSafeguards.append(
                        safeguard
                    )

                    if safeguard.matched {
                        blockedFileCount += 1

                        let reason = safeguard.reason
                            ?? "deep-secret heuristic matched"

                        warnings.append(
                            .init(
                                kind: .blockedByPolicy,
                                file: fileURL,
                                message: reason
                            )
                        )

                        if failOnBlockedFiles {
                            errors.append(
                                ConcatError.fileBlockedByPolicy(
                                    url: fileURL,
                                    reason: reason
                                )
                            )
                        }

                        continue
                    }
                }

                let transformationFingerprint = try sectionTransformationFingerprint(
                    for: source,
                    resolved: resolved,
                    metadata: metadata,
                    fileManager: fileManager
                )

                let previous = consumeCachedSource(
                    for: resolved,
                    transformationFingerprint:
                        transformationFingerprint,
                    from: &cachedSourcesByFile
                )

                let section: ConcatenationSection
                let cachedSource: ConcatenationCachedSource

                let exactCachedSection: ConcatenationSection?

                if let previous,
                   previous.metadata == metadata,
                   previous.transformationFingerprint
                        == transformationFingerprint {
                    if sectionsPreloaded {
                        exactCachedSection = preloadedSections.removeValue(
                            forKey: sourceIndex
                        )
                    } else {
                        exactCachedSection = try loadCachedSection(
                            previous,
                            from: cache
                        )
                    }
                } else {
                    exactCachedSection = nil
                }

                if let previous,
                   let exactCachedSection {
                    metadataHits += 1

                    section = exactCachedSection
                    cachedSource = previous
                } else {
                    sourceReads += 1

                    let readResult: LineReadResult

                    if let preread = prereads.removeValue(
                        forKey: sourceIndex
                    ) {
                        readResult = preread
                    } else {
                        readResult = try readSource(
                            resolved,
                            inspected: metadata
                        )
                    }

                    guard let contentFingerprint =
                        readResult
                            .fileSnapshot?
                            .contentFingerprint
                    else {
                        throw ConcatenationCacheInvariantError
                            .missingContentFingerprint(
                                resolved
                            )
                    }

                    if let previous,
                       previous.contentFingerprint == contentFingerprint,
                       previous.transformationFingerprint == transformationFingerprint,
                       let reusedSection = try loadCachedSection(
                            previous,
                            from: cache
                       ) {
                        contentHits += 1

                        sourceActivities.append(
                            .init(
                                standardizedSource:
                                    fileURL,
                                presentedPath:
                                    source.presentedPath,
                                kind:
                                    .reread
                            )
                        )

                        section = reusedSection
                        cachedSource = .init(
                            metadata: metadata,
                            contentFingerprint: contentFingerprint,
                            transformationFingerprint:
                                transformationFingerprint
                        )
                    } else {
                        rebuilds += 1

                        sourceActivities.append(
                            .init(
                                standardizedSource:
                                    fileURL,
                                presentedPath:
                                    source.presentedPath,
                                kind:
                                    .rebuilt
                            )
                        )

                        section = makeSection(
                            for: source,
                            resolved: resolved,
                            fileManager: fileManager,
                            readResult: readResult,
                            metadata: metadata
                        )

                        cachedSource = .init(
                            metadata: metadata,
                            contentFingerprint: contentFingerprint,
                            transformationFingerprint:
                                transformationFingerprint
                        )

                        try saveCachedSection(
                            section,
                            source: cachedSource,
                            to: cache
                        )
                    }
                }

                if section.wasTruncated,
                   let message = section.truncationMessage {
                    warnings.append(
                        .init(
                            kind: .truncated,
                            file: resolved,
                            message: message
                        )
                    )
                }

                sections.append(
                    section
                )

                cachedSources.append(
                    cachedSource
                )
            } catch {
                let wrapped = ConcatError.fileProcessingFailed(
                    url: fileURL,
                    stage: "document-build",
                    underlying: error
                )

                errors.append(wrapped)
            }
        }

        if !errors.isEmpty {
            throw MultiError(errors)
        }

        let cacheStateChanged = !cacheStateMatches(
            cachedManifest,
            sources: cachedSources,
            safeguards: cachedSafeguards
        )

        let preparedCacheManifest =
            cache.map {
                ConcatenationCacheManifest(
                    output:
                        $0.scope,
                    sources:
                        cachedSources,
                    safeguards:
                        cachedSafeguards,
                    artifact:
                        cachedManifest?.artifact
                )
            }

        if persistCache,
           cacheStateChanged,
           let cache,
           let preparedCacheManifest {
            try cache.save(
                sources:
                    preparedCacheManifest.sources,
                safeguards:
                    preparedCacheManifest.safeguards,
                artifact:
                    preparedCacheManifest.artifact
            )
        }

        let selectedLineCount = sections.reduce(0) { partial, section in
            partial + section.selectedLineCount
        }

        let statistics = ConcatenationStatistics(
            sourceCount: plan.sources.count,
            renderedSectionCount: sections.count,
            blockedFileCount: blockedFileCount,
            truncatedSectionCount: sections.filter(\.wasTruncated).count,
            selectedLineCount: selectedLineCount,
            cache: .init(
                metadataInspections: metadataInspections,
                safeguardReads: safeguardReads,
                safeguardHits: safeguardHits,
                sourceReads: sourceReads,
                metadataHits: metadataHits,
                contentHits: contentHits,
                rebuilds: rebuilds
            )
        )

        let sourceMaterialFingerprint = try sourceMaterialFingerprint(
            for: cachedSources
        )

        return ConcatenationPreparedDocument(
            document: ConcatenationDocument(
                context: plan.context,
                sections: sections,
                warnings: warnings,
                statistics: statistics,
                sourceMaterialFingerprint: sourceMaterialFingerprint
            ),
            cacheManifest: preparedCacheManifest,
            cacheStateChanged: cacheStateChanged,
            sourceActivities:
                sourceActivities,
            preparationStatistics: .init()
        )
    }

    public func render() throws -> ConcatenationRenderResult {
        let document = try document()

        return render(
            document
        )
    }

    public func render(
        concurrency: IOConcurrency
    ) async throws -> ConcatenationRenderResult {
        let document = try await document(
            concurrency: concurrency
        )

        return render(
            document
        )
    }

    @discardableResult
    public func copy() throws -> ConcatenationRenderResult {
        let rendered = try render()

        if reportWarnings {
            printWarnings(
                from: rendered.document
            )
        }

        return copy(
            rendered
        )
    }

    @discardableResult
    public func copy(
        concurrency: IOConcurrency
    ) async throws -> ConcatenationRenderResult {
        let rendered = try await render(
            concurrency: concurrency
        )

        if reportWarnings {
            printWarnings(
                from: rendered.document
            )
        }

        return copy(
            rendered
        )
    }

    @discardableResult
    public func write() throws -> ConcatenationWriteResult {
        guard let outputURL else {
            throw ConcatError.outputRequired
        }

        if verbose {
            if let location {
                print("Concatenation location: \(location)")
            }

            print(
                "Concatenating \(plan.sources.count) files → \(outputURL.path)"
            )
        }

        let preparedDocument: ConcatenationDocument

        do {
            preparedDocument = try self.document()
        } catch {
            printErrors(for: error)
            throw error
        }

        if reportWarnings {
            printWarnings(
                from: preparedDocument
            )
        }

        let materialFingerprint = try artifactMaterialFingerprint(
            for: preparedDocument
        )

        if !copyToClipboard,
           try validatedCachedArtifact(
                materialFingerprint: materialFingerprint
           ) != nil {
            if verbose {
                print(
                    "Unchanged: \(outputURL.path)"
                )
            }

            return ConcatenationWriteResult(
                document: preparedDocument,
                renderResult: nil,
                writeResult: nil,
                renderedLineCount:
                    preparedDocument.statistics.selectedLineCount
            )
        }

        let rendered = render(
            preparedDocument
        )

        let writeResult = try ConcatenationWriter(
            outputURL
        ).write(rendered.text)

        try recordArtifact(
            renderedText: rendered.text,
            materialFingerprint: materialFingerprint
        )

        if copyToClipboard {
            copy(
                rendered
            )
        }

        if verbose {
            print(
                "Done: \(preparedDocument.statistics.selectedLineCount) lines written"
            )
        }

        return ConcatenationWriteResult(
            document: preparedDocument,
            renderResult: rendered,
            writeResult: writeResult,
            renderedLineCount:
                preparedDocument.statistics.selectedLineCount
        )
    }

    @discardableResult
    public func write(
        concurrency: IOConcurrency
    ) async throws -> ConcatenationWriteResult {
        guard let outputURL else {
            throw ConcatError.outputRequired
        }

        let startedAt =
            Date()

        if verbose {
            if let location {
                print("Concatenation location: \(location)")
            }

            print(
                "Concatenating \(plan.sources.count) files → \(outputURL.path)"
            )
        }

        let preparation: ConcatenationPreparedDocument

        do {
            preparation = try await prepareDocument(
                concurrency: concurrency,
                persistCache: false
            )
        } catch {
            printErrors(for: error)
            throw error
        }

        let preparedDocument = preparation.document

        if reportWarnings {
            printWarnings(
                from: preparedDocument
            )
        }

        let artifactFingerprintStartedAt =
            Date()

        let materialFingerprint = try artifactMaterialFingerprint(
            for: preparedDocument
        )

        let artifactFingerprintDuration =
            Date().timeIntervalSince(
                artifactFingerprintStartedAt
            )

        let artifactValidationStartedAt =
            Date()

        let cachedArtifact: ConcatenationCachedArtifact?

        if copyToClipboard {
            cachedArtifact = nil
        } else {
            cachedArtifact = try validatedCachedArtifact(
                materialFingerprint:
                    materialFingerprint,
                manifest:
                    preparation.cacheManifest
            )
        }

        let artifactValidationDuration =
            Date().timeIntervalSince(
                artifactValidationStartedAt
            )

        if let artifact = cachedArtifact {
            let cachePersistenceStartedAt =
                Date()

            try persistCachedState(
                preparation,
                artifact: artifact
            )

            let cachePersistenceDuration =
                Date().timeIntervalSince(
                    cachePersistenceStartedAt
                )

            if verbose {
                print(
                    "Unchanged: \(outputURL.path)"
                )
            }

            return ConcatenationWriteResult(
                document: preparedDocument,
                renderResult: nil,
                writeResult: nil,
                renderedLineCount:
                    preparedDocument.statistics.selectedLineCount,
                sourceActivities:
                    preparation.sourceActivities,
                statistics: .init(
                    duration:
                        Date().timeIntervalSince(
                            startedAt
                        ),
                    preparation:
                        preparation
                        .preparationStatistics,
                    artifactFingerprintDuration:
                        artifactFingerprintDuration,
                    artifactValidationDuration:
                        artifactValidationDuration,
                    cachePersistenceDuration:
                        cachePersistenceDuration
                )
            )
        }

        let renderStartedAt =
            Date()

        let rendered = render(
            preparedDocument
        )

        let renderDuration =
            Date().timeIntervalSince(
                renderStartedAt
            )

        let outputWriteStartedAt =
            Date()

        let writeResult = try ConcatenationWriter(
            outputURL
        ).write(
            rendered.text
        )

        let outputWriteDuration =
            Date().timeIntervalSince(
                outputWriteStartedAt
            )

        let artifactCreationStartedAt =
            Date()

        let artifact = try makeCachedArtifact(
            renderedText: rendered.text,
            materialFingerprint: materialFingerprint
        )

        let artifactCreationDuration =
            Date().timeIntervalSince(
                artifactCreationStartedAt
            )

        let cachePersistenceStartedAt =
            Date()

        try persistCachedState(
            preparation,
            artifact: artifact
        )

        let cachePersistenceDuration =
            Date().timeIntervalSince(
                cachePersistenceStartedAt
            )

        var clipboardDuration:
            TimeInterval = 0

        if copyToClipboard {
            let clipboardStartedAt =
                Date()

            copy(
                rendered
            )

            clipboardDuration =
                Date().timeIntervalSince(
                    clipboardStartedAt
                )
        }

        if verbose {
            print(
                "Done: \(preparedDocument.statistics.selectedLineCount) lines written"
            )
        }

        return ConcatenationWriteResult(
            document: preparedDocument,
            renderResult: rendered,
            writeResult: writeResult,
            renderedLineCount:
                preparedDocument.statistics.selectedLineCount,
            sourceActivities:
                preparation.sourceActivities,
            statistics: .init(
                duration:
                    Date().timeIntervalSince(
                        startedAt
                    ),
                preparation:
                    preparation
                    .preparationStatistics,
                artifactFingerprintDuration:
                    artifactFingerprintDuration,
                artifactValidationDuration:
                    artifactValidationDuration,
                renderDuration:
                    renderDuration,
                outputWriteDuration:
                    outputWriteDuration,
                artifactCreationDuration:
                    artifactCreationDuration,
                cachePersistenceDuration:
                    cachePersistenceDuration,
                clipboardDuration:
                    clipboardDuration
            )
        )
    }

    public func run() throws -> Int {
        try write().renderedLineCount
    }

    public func run(
        concurrency: IOConcurrency
    ) async throws -> Int {
        try await write(
            concurrency: concurrency
        ).renderedLineCount
    }
}

private struct ConcatenationPreparedDocument:
    Sendable
{
    let document: ConcatenationDocument
    let cacheManifest: ConcatenationCacheManifest?
    let cacheStateChanged: Bool
    let sourceActivities:
        [ConcatenationSourceActivity]
    let preparationStatistics:
        ConcatenationPreparationStatistics
}

private struct ConcatenationPreinspection:
    Sendable
{
    let resolved: URL
    let metadata: FileMetadataSnapshot?
}


private struct ConcatenationSectionPreloadJob:
    Sendable
{
    let sourceIndex: Int
    let source: ConcatenationCachedSource
}

private struct ConcatenationSectionPreload:
    Sendable
{
    let sourceIndex: Int
    let section: ConcatenationSection?
}

private struct ConcatenationSourceReadJob:
    Sendable
{
    let sourceIndex: Int
    let metadata: FileMetadataSnapshot
}

private struct ConcatenationSourcePreread:
    Sendable
{
    let sourceIndex: Int
    let result: LineReadResult?
}

private struct ConcatenationArtifactMaterial:
    Encodable
{
    let version: Int
    let output: String
    let format: String
    let delimiterStyle: String
    let delimiterClosure: Bool
    let maxLinesPerFile: Int?
    let trimBlankLines: Bool
    let lineNumbers: Bool
    let raw: Bool
    let relativePaths: Bool
    let includeSourceModifiedAt: Bool
    let obscurations: [String: String]
    let context: ConcatenationContext?
    let warnings: [ConcatenationArtifactWarning]
    let statistics: ConcatenationArtifactStatistics
    let sourceMaterialFingerprint: ContentFingerprint
}

private struct ConcatenationSourceMaterial:
    Encodable
{
    let version: Int
    let sources: [ConcatenationSourceMaterialIdentity]
}

private struct ConcatenationSourceMaterialIdentity:
    Encodable
{
    let contentFingerprint: ContentFingerprint
    let transformationFingerprint: ContentFingerprint
}

private struct ConcatenationArtifactWarning:
    Encodable
{
    let kind: String
    let file: String
    let message: String
}

private struct ConcatenationArtifactStatistics:
    Encodable
{
    let sourceCount: Int
    let renderedSectionCount: Int
    let blockedFileCount: Int
    let truncatedSectionCount: Int
    let selectedLineCount: Int
}

private struct ConcatenationDeepSafeguardPolicy:
    Encodable
{
    let version: Int
    let maxPeekBytes: Int
    let protectedExtensions: [String]
    let pemMarkers: [String]
    let privateKeyJSONTokens: [String]
    let treatNullByteAsBinary: Bool
}

private struct ConcatenationSectionTransformation:
    Encodable
{
    let version: Int
    let presentedPath: String
    let selections: [ContentSelection]
    let trimBlankLines: Bool
    let maxLinesPerFile: Int?
    let obscurations: [String: String]
    let modifiedAt: Date?
}

private enum ConcatenationCacheInvariantError:
    Error,
    LocalizedError
{
    case missingContentFingerprint(URL)
    case missingSourceMaterialFingerprint
    case missingArtifactContentFingerprint(URL)
    case missingWrittenArtifact(URL)

    var errorDescription: String? {
        switch self {
        case .missingContentFingerprint(let url):
            return "Missing content fingerprint after reading \(url.path)"

        case .missingSourceMaterialFingerprint:
            return "Missing source material fingerprint for concatenation document"

        case .missingArtifactContentFingerprint(let url):
            return "Missing content fingerprint after reading artifact \(url.path)"

        case .missingWrittenArtifact(let url):
            return "Written concatenation artifact does not exist at \(url.path)"
        }
    }
}

private extension FileConcatenator {
    var options: ConcatenationRenderOptions {
        plan.options
    }

    func render(
        _ document: ConcatenationDocument
    ) -> ConcatenationRenderResult {
        let text: String

        switch options.output.format {
        case .text:
            text = ConcatenationRenderer(
                outputURL: outputURL,
                options: options
            ).render(document)

        case .xml:
            text = ConcatenationXMLRenderer(
                outputURL: outputURL,
                options: options
            ).render(document)
        }

        return .init(
            document: document,
            text: text
        )
    }

    @discardableResult
    func copy(
        _ rendered: ConcatenationRenderResult
    ) -> ConcatenationRenderResult {
        rendered.text.clipboard()

        if verbose {
            print(
                "Copied output to clipboard"
            )
        }

        return rendered
    }

    func readSource(
        _ resolved: URL,
        inspected metadata: FileMetadataSnapshot
    ) throws -> LineReadResult {
        try LineReader(
            resolved
        ).read(
            inspected: metadata,
            options: sourceReadOptions
        )
    }

    var sourceReadOptions: LineReadOptions {
        .init(
            text: .init(
                decoding: .commonTextFallbacks,
                missingFilePolicy: .throwError,
                newlineNormalization: .unix
            )
        )
    }

    func makeSection(
        for source: ConcatenationSource,
        resolved: URL,
        fileManager: FileManager,
        readResult: LineReadResult,
        metadata: FileMetadataSnapshot
    ) -> ConcatenationSection {
        let (processedLines, blankWarnings) = processBlankLines(
            readResult.lines,
            trim: options.line.trimblanks
        )

        let totalLineCount = processedLines.count

        let keptLines: [String]
        let wasTruncated: Bool

        if let limit = options.line.filemax,
           processedLines.count > limit {
            keptLines = Array(
                processedLines.prefix(limit)
            )
            wasTruncated = true
        } else {
            keptLines = processedLines
            wasTruncated = false
        }

        let obscuredLines = applyObscuring(
            to: keptLines,
            obscurations: options.output.obscurations
        )

        let slices = resolvedSlices(
            for: resolved,
            selections: source.selections,
            lines: obscuredLines,
            encodingUsed: readResult.encodingUsed,
            byteCount: readResult.byteCount,
            existed: readResult.existed
        )

        return ConcatenationSection(
            file: resolved,
            presentedPath: sectionPresentedPath(
                for: source,
                resolved: resolved,
                fileManager: fileManager
            ),
            modifiedAt: options.output.modifiedstamp
                ? sourceModifiedAtString(
                    metadata.modifiedAt
                )
                : nil,
            slices: slices,
            blankLineHeader: blankWarnings.header,
            blankLineFooter: blankWarnings.footer,
            totalLineCount: totalLineCount,
            keptLineCount: keptLines.count,
            wasTruncated: wasTruncated
        )
    }

    func resolvedSlices(
        for file: URL,
        selections: [ContentSelection],
        lines: [String],
        encodingUsed: TextEncoding?,
        byteCount: Int,
        existed: Bool
    ) -> [FileLineSlice] {
        let readResult = LineReadResult(
            url: file,
            lines: lines,
            encodingUsed: encodingUsed,
            byteCount: byteCount,
            existed: existed
        )

        return SelectionResolver.resolve(
            file: file,
            readResult: readResult,
            selections: selections
        ).slices
    }

    func printWarnings(
        from document: ConcatenationDocument
    ) {
        let blockedWarnings = document.warnings.filter {
            $0.kind == .blockedByPolicy
        }

        if !blockedWarnings.isEmpty {
            for warning in blockedWarnings {
                printProtectionNotifier(
                    file: warning.file.path,
                    reason: warning.message
                )
            }

            print("Use --allow-secrets to override".indent())
            print()
        }

        let truncatedWarnings = document.warnings.filter {
            $0.kind == .truncated
        }

        for warning in truncatedWarnings {
            print(
                warning.message.ansi(.yellow)
            )
        }
    }

    func printErrors(
        for error: Error
    ) {
        let errors: [Error]

        if let multi = error as? Errors {
            errors = multi.errors
        } else {
            errors = [error]
        }

        guard !errors.isEmpty else {
            return
        }

        print(
            "\nErrors encountered during concatenation"
                + (location.map { " — \($0)" } ?? "")
        )

        for error in errors {
            if let concatError = error as? ConcatError {
                print(" • \(concatError.localizedDescription)")
            } else {
                print(" • \(error.localizedDescription)")
            }
        }
    }

    func preinspectSafeguards(
        preinspected: [
            URL: [FileMetadataSnapshot]
        ],
        cachedManifest: ConcatenationCacheManifest?,
        concurrency: IOConcurrency
    ) async throws -> [
        URL: ConcatenationCachedSafeguard
    ] {
        guard protectSecrets,
              !allowSecrets,
              deepSecretInspection else {
            return [:]
        }

        let policyFingerprint = try safeguardPolicyFingerprint()

        var cachedByFile: [
            URL: ConcatenationCachedSafeguard
        ] = [:]

        for safeguard in cachedManifest?.safeguards ?? [] {
            cachedByFile[
                safeguard.file.standardizedFileURL
            ] = safeguard
        }

        var reused: [
            URL: ConcatenationCachedSafeguard
        ] = [:]

        var jobs: [
            FileMetadataSnapshot
        ] = []

        var scheduled: Set<URL> = []

        for source in plan.sources {
            let file = source.file

            if isProtectedFile(
                file
            ) {
                continue
            }

            guard let resolved = try? resolveSymlink(
                at: file
            ) else {
                continue
            }

            let key = resolved.standardizedFileURL

            guard !scheduled.contains(
                key
            ) else {
                continue
            }

            guard let metadata = preinspected[
                key
            ]?.first else {
                continue
            }

            scheduled.insert(
                key
            )

            if let cached = cachedByFile[key],
               cached.metadata == metadata,
               cached.policyFingerprint == policyFingerprint {
                reused[
                    key
                ] = cached

                continue
            }

            jobs.append(
                metadata
            )
        }

        let checked = try await IOExecutor(
            concurrency: concurrency
        ).map(
            jobs
        ) { metadata in
            let result = Self.deepSecretCheck(
                metadata.url
            )

            return ConcatenationCachedSafeguard(
                metadata: metadata,
                policyFingerprint: policyFingerprint,
                matched: result.matched,
                reason: result.reason
            )
        }

        for safeguard in checked {
            reused[
                safeguard.file.standardizedFileURL
            ] = safeguard
        }

        return reused
    }

    func preloadCachedSections(
        preinspected: [
            URL: [FileMetadataSnapshot]
        ],
        presafeguards: [
            URL: ConcatenationCachedSafeguard
        ],
        cachedManifest: ConcatenationCacheManifest?,
        concurrency: IOConcurrency
    ) async throws -> [
        Int: ConcatenationSection
    ] {
        guard let cache,
              let cachedManifest else {
            return [:]
        }

        let fileManager = FileManager.default

        var remainingMetadata = preinspected
        var cachedSourcesByFile: [
            URL: [ConcatenationCachedSource]
        ] = [:]

        for cachedSource in cachedManifest.sources {
            cachedSourcesByFile[
                cachedSource.file.standardizedFileURL,
                default: []
            ].append(
                cachedSource
            )
        }

        var jobs: [ConcatenationSectionPreloadJob] = []

        for (sourceIndex, source) in plan.sources.enumerated() {
            let file = source.file

            if protectSecrets
                && !allowSecrets
                && isProtectedFile(
                    file
                )
            {
                continue
            }

            guard let resolved = try? resolveSymlink(
                at: file
            ) else {
                continue
            }

            let key = resolved.standardizedFileURL

            guard var metadataCandidates = remainingMetadata[
                key
            ],
            !metadataCandidates.isEmpty else {
                continue
            }

            let metadata = metadataCandidates.removeFirst()

            if metadataCandidates.isEmpty {
                remainingMetadata.removeValue(
                    forKey: key
                )
            } else {
                remainingMetadata[
                    key
                ] = metadataCandidates
            }

            if protectSecrets
                && !allowSecrets
                && deepSecretInspection
            {
                guard let safeguard = presafeguards[
                    key
                ],
                !safeguard.matched else {
                    continue
                }
            }

            guard let transformationFingerprint =
                try? sectionTransformationFingerprint(
                    for: source,
                    resolved: resolved,
                    metadata: metadata,
                    fileManager: fileManager
                )
            else {
                continue
            }

            guard
                let previous = consumeCachedSource(
                    for: resolved,
                    transformationFingerprint:
                        transformationFingerprint,
                    from: &cachedSourcesByFile
                ),
                previous.metadata == metadata,
                previous.transformationFingerprint
                    == transformationFingerprint
            else {
                continue
            }

            jobs.append(
                .init(
                    sourceIndex: sourceIndex,
                    source: previous
                )
            )
        }

        let completed = try await IOExecutor(
            concurrency: concurrency
        ).map(
            jobs
        ) { job in
            ConcatenationSectionPreload(
                sourceIndex: job.sourceIndex,
                section: try? cache.loadSection(
                    key:
                        job.source.sectionKey
                )
            )
        }

        return Dictionary(
            uniqueKeysWithValues: completed.compactMap { preload in
                guard let section = preload.section else {
                    return nil
                }

                return (
                    preload.sourceIndex,
                    section
                )
            }
        )
    }

    func preReadSources(
        preinspected: [
            URL: [FileMetadataSnapshot]
        ],
        presafeguards: [
            URL: ConcatenationCachedSafeguard
        ],
        preloadedSections: [
            Int: ConcatenationSection
        ],
        cachedManifest: ConcatenationCacheManifest?,
        concurrency: IOConcurrency
    ) async throws -> [
        Int: LineReadResult
    ] {
        let fileManager = FileManager.default

        var remainingMetadata = preinspected
        var cachedSourcesByFile: [
            URL: [ConcatenationCachedSource]
        ] = [:]

        for cachedSource in cachedManifest?.sources ?? [] {
            cachedSourcesByFile[
                cachedSource.file.standardizedFileURL,
                default: []
            ].append(
                cachedSource
            )
        }

        var jobs: [ConcatenationSourceReadJob] = []

        for (sourceIndex, source) in plan.sources.enumerated() {
            let file = source.file

            if protectSecrets
                && !allowSecrets
                && isProtectedFile(
                    file
                )
            {
                continue
            }

            guard let resolved = try? resolveSymlink(
                at: file
            ) else {
                continue
            }

            let key = resolved.standardizedFileURL

            guard var metadataCandidates = remainingMetadata[
                key
            ],
            !metadataCandidates.isEmpty else {
                continue
            }

            let metadata = metadataCandidates.removeFirst()

            if metadataCandidates.isEmpty {
                remainingMetadata.removeValue(
                    forKey: key
                )
            } else {
                remainingMetadata[
                    key
                ] = metadataCandidates
            }

            if protectSecrets
                && !allowSecrets
                && deepSecretInspection
            {
                guard let safeguard = presafeguards[
                    key
                ] else {
                    continue
                }

                if safeguard.matched {
                    continue
                }
            }

            guard let transformationFingerprint =
                try? sectionTransformationFingerprint(
                    for: source,
                    resolved: resolved,
                    metadata: metadata,
                    fileManager: fileManager
                )
            else {
                continue
            }

            let previous = consumeCachedSource(
                for: resolved,
                transformationFingerprint:
                    transformationFingerprint,
                from: &cachedSourcesByFile
            )

            if let previous,
               previous.metadata == metadata,
               previous.transformationFingerprint
                    == transformationFingerprint,
               preloadedSections[
                    sourceIndex
               ] != nil {
                continue
            }

            jobs.append(
                .init(
                    sourceIndex: sourceIndex,
                    metadata: metadata
                )
            )
        }

        let readOptions = sourceReadOptions

        let completed = try await IOExecutor(
            concurrency: concurrency
        ).map(
            jobs
        ) { job in
            ConcatenationSourcePreread(
                sourceIndex: job.sourceIndex,
                result: try? LineReader(
                    job.metadata.url
                ).read(
                    inspected: job.metadata,
                    options: readOptions
                )
            )
        }

        return Dictionary(
            uniqueKeysWithValues: completed.compactMap { preread in
                guard let result = preread.result else {
                    return nil
                }

                return (
                    preread.sourceIndex,
                    result
                )
            }
        )
    }

    func preinspectSources(
        concurrency: IOConcurrency
    ) async throws -> [
        URL: [FileMetadataSnapshot]
    ] {
        let resolvedSources = plan.sources.compactMap {
            source -> URL? in

            let file = source.file

            if protectSecrets
                && !allowSecrets
                && isProtectedFile(
                    file
                )
            {
                return nil
            }

            return try? resolveSymlink(
                at: file
            )
        }

        let inspections = try await IOExecutor(
            concurrency: concurrency
        ).map(
            resolvedSources
        ) { resolved in
            ConcatenationPreinspection(
                resolved: resolved,
                metadata: try? FileInspector(
                    resolved
                ).inspect()
            )
        }

        var result: [
            URL: [FileMetadataSnapshot]
        ] = [:]

        for inspection in inspections {
            guard let metadata = inspection.metadata else {
                continue
            }

            result[
                inspection.resolved.standardizedFileURL,
                default: []
            ].append(
                metadata
            )
        }

        return result
    }

    func cacheStateMatches(
        _ manifest: ConcatenationCacheManifest?,
        sources: [ConcatenationCachedSource],
        safeguards: [ConcatenationCachedSafeguard]
    ) -> Bool {
        guard let manifest,
              manifest.sources.count == sources.count,
              manifest.safeguards.count == safeguards.count else {
            return false
        }

        for (previous, current) in zip(
            manifest.sources,
            sources
        ) {
            guard previous.metadata == current.metadata,
                  previous.contentFingerprint
                    == current.contentFingerprint,
                  previous.transformationFingerprint
                    == current.transformationFingerprint else {
                return false
            }
        }

        for (previous, current) in zip(
            manifest.safeguards,
            safeguards
        ) {
            guard previous.metadata == current.metadata,
                  previous.policyFingerprint
                    == current.policyFingerprint,
                  previous.matched == current.matched,
                  previous.reason == current.reason else {
                return false
            }
        }

        return true
    }

    func consumeCachedSource(
        for resolved: URL,
        transformationFingerprint: ContentFingerprint,
        from sourcesByFile: inout [
            URL: [ConcatenationCachedSource]
        ]
    ) -> ConcatenationCachedSource? {
        let key = resolved.standardizedFileURL

        guard var candidates = sourcesByFile[key],
              !candidates.isEmpty else {
            return nil
        }

        let index = candidates.firstIndex {
            $0.transformationFingerprint
                == transformationFingerprint
        } ?? candidates.startIndex

        let source = candidates.remove(
            at: index
        )

        if candidates.isEmpty {
            sourcesByFile.removeValue(
                forKey: key
            )
        } else {
            sourcesByFile[key] = candidates
        }

        return source
    }

    func loadCachedSection(
        _ source: ConcatenationCachedSource,
        from cache: ConcatenationCacheBinding?
    ) throws -> ConcatenationSection? {
        try cache?.loadSection(
            key:
                source.sectionKey
        )
    }

    func saveCachedSection(
        _ section: ConcatenationSection,
        source: ConcatenationCachedSource,
        to cache: ConcatenationCacheBinding?
    ) throws {
        try cache?.saveSection(
            section,
            key:
                source.sectionKey
        )
    }

    func sourceMaterialFingerprint(
        for sources: [ConcatenationCachedSource]
    ) throws -> ContentFingerprint {
        let material = ConcatenationSourceMaterial(
            version: 1,
            sources: sources.map {
                .init(
                    contentFingerprint: $0.contentFingerprint,
                    transformationFingerprint:
                        $0.transformationFingerprint
                )
            }
        )

        let encoder = JSONEncoder()

        encoder.outputFormatting = [
            .sortedKeys,
        ]

        return .fingerprint(
            for: try encoder.encode(
                material
            )
        )
    }

    func artifactMaterialFingerprint(
        for document: ConcatenationDocument
    ) throws -> ContentFingerprint {
        guard let outputURL else {
            throw ConcatError.outputRequired
        }

        guard let sourceMaterialFingerprint =
            document.sourceMaterialFingerprint
        else {
            throw ConcatenationCacheInvariantError
                .missingSourceMaterialFingerprint
        }

        let material = ConcatenationArtifactMaterial(
            version: 2,
            output: outputURL.standardizedFileURL.path,
            format: options.output.format.rawValue,
            delimiterStyle: options.delimiter.style.rawValue,
            delimiterClosure: options.delimiter.closure,
            maxLinesPerFile: options.line.filemax,
            trimBlankLines: options.line.trimblanks,
            lineNumbers: options.line.numbers,
            raw: options.output.raw,
            relativePaths: options.output.relativepaths,
            includeSourceModifiedAt: options.output.modifiedstamp,
            obscurations: options.output.obscurations,
            context: document.context,
            warnings: document.warnings.map {
                .init(
                    kind: $0.kind.rawValue,
                    file: $0.file.standardizedFileURL.path,
                    message: $0.message
                )
            },
            statistics: .init(
                sourceCount: document.statistics.sourceCount,
                renderedSectionCount:
                    document.statistics.renderedSectionCount,
                blockedFileCount:
                    document.statistics.blockedFileCount,
                truncatedSectionCount:
                    document.statistics.truncatedSectionCount,
                selectedLineCount:
                    document.statistics.selectedLineCount
            ),
            sourceMaterialFingerprint: sourceMaterialFingerprint
        )

        let encoder = JSONEncoder()

        encoder.outputFormatting = [
            .sortedKeys,
        ]

        return .fingerprint(
            for: try encoder.encode(
                material
            )
        )
    }

    func validatedCachedArtifact(
        materialFingerprint: ContentFingerprint
    ) throws -> ConcatenationCachedArtifact? {
        guard let cache,
              outputURL != nil,
              let manifest = try cache.load()
        else {
            return nil
        }

        guard let artifact = try validatedCachedArtifact(
            materialFingerprint: materialFingerprint,
            manifest: manifest
        ) else {
            return nil
        }

        if !cachedArtifactStateMatches(
            manifest.artifact,
            artifact
        ) {
            try cache.save(
                sources:
                    manifest.sources,
                safeguards:
                    manifest.safeguards,
                artifact:
                    artifact
            )
        }

        return artifact
    }

    func validatedCachedArtifact(
        materialFingerprint: ContentFingerprint,
        manifest: ConcatenationCacheManifest?
    ) throws -> ConcatenationCachedArtifact? {
        guard let outputURL else {
            return nil
        }

        guard let artifact = manifest?.artifact,
              artifact.materialFingerprint == materialFingerprint else {
            return nil
        }

        let metadata = try FileInspector(
            outputURL
        ).inspect()

        guard metadata.existed else {
            return nil
        }

        if artifact.metadata == metadata {
            return artifact
        }

        let readResult = try DataFileReader(
            outputURL
        ).read(
            inspected: metadata,
            options: .init(
                missingFilePolicy: .throwError,
                cachePolicy: .system
            )
        )

        guard let contentFingerprint =
            readResult
                .fileSnapshot?
                .contentFingerprint
        else {
            throw ConcatenationCacheInvariantError
                .missingArtifactContentFingerprint(
                    outputURL
                )
        }

        guard contentFingerprint == artifact.contentFingerprint else {
            return nil
        }

        return ConcatenationCachedArtifact(
            metadata: metadata,
            contentFingerprint: artifact.contentFingerprint,
            materialFingerprint: artifact.materialFingerprint
        )
    }

    func recordArtifact(
        renderedText: String,
        materialFingerprint: ContentFingerprint
    ) throws {
        guard let cache,
              outputURL != nil,
              let manifest = try cache.load()
        else {
            return
        }

        let artifact = try makeCachedArtifact(
            renderedText: renderedText,
            materialFingerprint: materialFingerprint
        )

        try cache.save(
            sources:
                manifest.sources,
            safeguards:
                manifest.safeguards,
            artifact:
                artifact
        )
    }

    func makeCachedArtifact(
        renderedText: String,
        materialFingerprint: ContentFingerprint
    ) throws -> ConcatenationCachedArtifact {
        guard let outputURL else {
            throw ConcatError.outputRequired
        }

        let metadata = try FileInspector(
            outputURL
        ).inspect()

        guard metadata.existed else {
            throw ConcatenationCacheInvariantError
                .missingWrittenArtifact(
                    outputURL
                )
        }

        return .init(
            metadata: metadata,
            contentFingerprint: .fingerprint(
                for: Data(
                    renderedText.utf8
                )
            ),
            materialFingerprint: materialFingerprint
        )
    }

    func persistCachedState(
        _ preparation: ConcatenationPreparedDocument,
        artifact: ConcatenationCachedArtifact
    ) throws {
        guard let cache,
              let manifest = preparation.cacheManifest else {
            return
        }

        if !preparation.cacheStateChanged,
           cachedArtifactStateMatches(
                manifest.artifact,
                artifact
           ) {
            return
        }

        try cache.save(
            sources:
                manifest.sources,
            safeguards:
                manifest.safeguards,
            artifact:
                artifact
        )
    }

    func cachedArtifactStateMatches(
        _ previous: ConcatenationCachedArtifact?,
        _ current: ConcatenationCachedArtifact
    ) -> Bool {
        guard let previous else {
            return false
        }

        return previous.metadata == current.metadata
            && previous.contentFingerprint
                == current.contentFingerprint
            && previous.materialFingerprint
                == current.materialFingerprint
    }

    func safeguardPolicyFingerprint() throws -> ContentFingerprint {
        let policy = ConcatenationDeepSafeguardPolicy(
            version: 1,
            maxPeekBytes: ConSafeguard.deepPeekBytes,
            protectedExtensions: ConSafeguard
                .protectedExtensions
                .sorted(),
            pemMarkers: ConSafeguard.pemMarkers,
            privateKeyJSONTokens: ConSafeguard.privateKeyJsonTokens,
            treatNullByteAsBinary: ConSafeguard.treatNullByteAsBinary
        )

        let encoder = JSONEncoder()

        encoder.outputFormatting = [
            .sortedKeys,
        ]

        return .fingerprint(
            for: try encoder.encode(
                policy
            )
        )
    }

    func sectionTransformationFingerprint(
        for source: ConcatenationSource,
        resolved: URL,
        metadata: FileMetadataSnapshot,
        fileManager: FileManager
    ) throws -> ContentFingerprint {
        let transformation = ConcatenationSectionTransformation(
            version: 1,
            presentedPath: sectionPresentedPath(
                for: source,
                resolved: resolved,
                fileManager: fileManager
            ),
            selections:
                source.selections,
            trimBlankLines: options.line.trimblanks,
            maxLinesPerFile: options.line.filemax,
            obscurations: options.output.obscurations,
            modifiedAt: options.output.modifiedstamp
                ? metadata.modifiedAt
                : nil
        )

        let encoder = JSONEncoder()

        encoder.outputFormatting = [
            .sortedKeys,
        ]

        let data = try encoder.encode(
            transformation
        )

        return .fingerprint(
            for: data
        )
    }

    func sectionPresentedPath(
        for source: ConcatenationSource,
        resolved: URL,
        fileManager: FileManager
    ) -> String {
        source.presentedPath
            ?? displayPath(
                for: resolved,
                fileManager: fileManager
            )
    }

    private func displayPath(
        for resolved: URL,
        fileManager: FileManager
    ) -> String {
        if options.output.relativepaths {
            return resolved.path.replacingOccurrences(
                of: fileManager.currentDirectoryPath + "/",
                with: ""
            )
        }

        return resolved.path
    }

    private func sourceModifiedAtString(
        _ date: Date?
    ) -> String? {
        guard let date else {
            return nil
        }

        let formatter = ISO8601DateFormatter()

        return formatter.string(
            from: date
        )
    }

    private func applyObscuring(
        to lines: [String],
        obscurations: [String: String]
    ) -> [String] {
        guard !obscurations.isEmpty else {
            return lines
        }

        var content = lines.joined(separator: "\n")

        for (value, method) in obscurations {
            content = content.replacingOccurrences(
                of: value,
                with: obscureValue(value, method: method)
            )
        }

        return content
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map(String.init)
    }
}

// public struct FileConcatenator: SafelyConcatenatable {
//     public let inputFiles: [URL]
//     public let outputURL: URL
//     public let context: ConcatenationContext?

//     public let selectedContentByFile: [URL: [ContentSelection]]

//     public let delimiterStyle: DelimiterStyle
//     public let delimiterClosure: Bool
//     public let maxLinesPerFile: Int?
//     public let trimBlankLines: Bool
//     public let relativePaths: Bool
//     public let rawOutput: Bool
//     public let includeSourceLineNumbers: Bool
//     public let includeSourceModifiedAt: Bool

//     public let obscureMap: [String: String]
//     public let copyToClipboard: Bool
//     public let verbose: Bool

//     public let location: String?

//     public let protectSecrets: Bool
//     public let allowSecrets: Bool
//     public let failOnBlockedFiles: Bool
//     public let deepSecretInspection: Bool

//     public init(
//         inputFiles: [URL],
//         outputURL: URL,
//         context: ConcatenationContext? = nil,
//         selectedContentByFile: [URL: [ContentSelection]] = [:],

//         delimiterStyle: DelimiterStyle = .boxed,
//         delimiterClosure: Bool = false,
//         maxLinesPerFile: Int? = 10_000,
//         trimBlankLines: Bool = true,
//         relativePaths: Bool = true,
//         rawOutput: Bool = false,
//         includeSourceLineNumbers: Bool = false,
//         includeSourceModifiedAt: Bool = false,
//         obscureMap: [String: String] = [:],

//         copyToClipboard: Bool = false,
//         verbose: Bool = false,

//         location: String? = nil,

//         protectSecrets: Bool = true,
//         allowSecrets: Bool = false,
//         failOnBlockedFiles: Bool = false,
//         deepSecretInspection: Bool = false
//     ) {
//         self.inputFiles = inputFiles
//         self.outputURL = outputURL
//         self.context = context
//         self.selectedContentByFile = selectedContentByFile

//         self.delimiterStyle = delimiterStyle
//         self.delimiterClosure = delimiterClosure
//         self.maxLinesPerFile = maxLinesPerFile
//         self.trimBlankLines = trimBlankLines
//         self.relativePaths = relativePaths
//         self.rawOutput = rawOutput
//         self.includeSourceLineNumbers = includeSourceLineNumbers
//         self.includeSourceModifiedAt = includeSourceModifiedAt
//         self.obscureMap = obscureMap

//         self.copyToClipboard = copyToClipboard
//         self.verbose = verbose

//         self.location = location

//         self.protectSecrets = protectSecrets
//         self.allowSecrets = allowSecrets
//         self.failOnBlockedFiles = failOnBlockedFiles
//         self.deepSecretInspection = deepSecretInspection
//     }

//     public func run() throws -> Int {
//         let fileManager = FileManager.default
//         let writer = StandardWriter(outputURL)

//         let bootstrapContent: String = {
//             guard !rawOutput, let context else {
//                 return ""
//             }

//             let header = context.header(outputURL: outputURL)

//             guard !header.isEmpty else {
//                 return ""
//             }

//             return header + "\n\n"
//         }()

//         try writer.write(
//             bootstrapContent,
//             options: .init(
//                 existingFilePolicy: .overwrite,
//                 makeBackupOnOverride: true,
//                 whitespaceOnlyIsBlank: true,
//                 createIntermediateDirectories: true,
//                 atomic: true,
//                 maxBackupSets: 5
//             )
//         )

//         let handle = try FileHandle(forWritingTo: outputURL)
//         defer { handle.closeFile() }
//         handle.seekToEndOfFile()

//         if verbose {
//             if let location {
//                 print("Concatenation location: \(location)")
//             }
//             print("Concatenating \(inputFiles.count) files → \(outputURL.path)")
//         }

//         var totalLines = 0
//         var errors: [Error] = []

//         var filesAutoProtected = false
//         let override = "Use --allow-secrets to override"

//         for fileURL in inputFiles {
//             if protectSecrets && !allowSecrets {
//                 if isProtectedFile(fileURL) {
//                     filesAutoProtected = true
//                     let reason = "Detected filename/extension matching secret patterns."
//                     printProtectionNotifier(
//                         file: fileURL.path,
//                         reason: reason
//                     )

//                     if failOnBlockedFiles {
//                         errors.append(
//                             ConcatError.fileBlockedByPolicy(
//                                 url: fileURL,
//                                 reason: reason
//                             )
//                         )
//                     }

//                     continue
//                 }

//                 if deepSecretInspection {
//                     let (deepMatched, deepReason) = deepSecretCheck(fileURL)

//                     if deepMatched {
//                         filesAutoProtected = true
//                         let reason = deepReason ?? "deep-secret heuristic matched"

//                         printProtectionNotifier(
//                             file: fileURL.path,
//                             reason: reason
//                         )

//                         if failOnBlockedFiles {
//                             errors.append(
//                                 ConcatError.fileBlockedByPolicy(
//                                     url: fileURL,
//                                     reason: reason
//                                 )
//                             )
//                         }

//                         continue
//                     }
//                 }
//             }

//             do {
//                 let resolved = try resolveSymlink(at: fileURL)
//                 var lines = try readLines(from: resolved)

//                 let (processedLines, blankWarnings) = processBlankLines(
//                     lines,
//                     trim: trimBlankLines
//                 )
//                 lines = processedLines

//                 let writeLines: [String]
//                 let wasTruncated: Bool

//                 if let limit = maxLinesPerFile, lines.count > limit {
//                     writeLines = Array(lines.prefix(limit))
//                     wasTruncated = true
//                 } else {
//                     writeLines = lines
//                     wasTruncated = false
//                 }

//                 let selections = selectedContentByFile[resolved.standardizedFileURL] ?? []
//                 let obscuredContent = applyObscuring(
//                     to: writeLines
//                 ).joined(separator: "\n")

//                 let slices = ContentSelectionSlicer.slice(
//                     content: obscuredContent,
//                     file: resolved,
//                     selections: selections
//                 )

//                 if !rawOutput {
//                     let headerLabel = makeHeaderLabel(
//                         for: resolved,
//                         fileManager: fileManager
//                     )

//                     let header = delimiterStyle.header(for: headerLabel) + "\n"
//                     handle.write(Data(header.utf8))
//                     handle.write(Data(blankWarnings.header.utf8))
//                 }

//                 for (index, slice) in slices.enumerated() {
//                     let bodyLines = renderedBodyLines(from: slice)

//                     for line in bodyLines {
//                         handle.write(Data((line + "\n").utf8))
//                     }

//                     totalLines += bodyLines.count

//                     if index < slices.count - 1 {
//                         handle.write(Data("\n".utf8))
//                     }
//                 }

//                 if wasTruncated {
//                     let message = "(!): truncated — file exceeded max line limit (\(writeLines.count)/\(lines.count) lines)\n"
//                     handle.write(Data(message.utf8))
//                     print(
//                         "(!): truncated — file exceeded max line limit (\(writeLines.count)/\(lines.count) lines)"
//                             .ansi(.yellow)
//                     )
//                 }

//                 if !rawOutput {
//                     let footerLabel = makeHeaderLabel(
//                         for: resolved,
//                         fileManager: fileManager
//                     )

//                     handle.write(Data(blankWarnings.footer.utf8))

//                     if delimiterClosure {
//                         handle.write(
//                             Data((delimiterStyle.footer(for: footerLabel) + "\n").utf8)
//                         )
//                     }
//                 }

//                 if fileURL != inputFiles.last {
//                     handle.write(Data("\n\n".utf8))
//                 }
//             } catch {
//                 let wrapped = ConcatError.fileProcessingFailed(
//                     url: fileURL,
//                     stage: "run-loop",
//                     underlying: error
//                 )
//                 errors.append(wrapped)
//             }
//         }

//         if filesAutoProtected {
//             print(override.indent())
//             print()
//         }

//         if !errors.isEmpty {
//             print(
//                 "\nErrors encountered during concatenation"
//                     + (location.map { " — \($0)" } ?? "")
//             )

//             for error in errors {
//                 if let concatError = error as? ConcatError {
//                     print(" • \(concatError.localizedDescription)")
//                 } else {
//                     print(" • \(error.localizedDescription)")
//                 }
//             }

//             throw MultiError(errors)
//         }

//         if copyToClipboard, let full = try? String(contentsOf: outputURL) {
//             full.clipboard()

//             if verbose {
//                 print("Copied output to clipboard")
//             }
//         }

//         if verbose {
//             print("Done: \(totalLines) lines written")
//         }

//         return totalLines
//     }

//     private func displayPath(
//         for resolved: URL,
//         fileManager: FileManager
//     ) -> String {
//         if relativePaths {
//             return resolved.path.replacingOccurrences(
//                 of: fileManager.currentDirectoryPath + "/",
//                 with: ""
//             )
//         }

//         return resolved.path
//     }

//     private func makeHeaderLabel(
//         for resolved: URL,
//         fileManager: FileManager
//     ) -> String {
//         let path = displayPath(
//             for: resolved,
//             fileManager: fileManager
//         )

//         guard includeSourceModifiedAt,
//               let modifiedAt = sourceModifiedAtString(for: resolved)
//         else {
//             return path
//         }

//         return "\(path) [modified_at: \(modifiedAt)]"
//     }

//     private func sourceModifiedAtString(
//         for url: URL
//     ) -> String? {
//         guard let values = try? url.resourceValues(
//             forKeys: [.contentModificationDateKey]
//         ), let date = values.contentModificationDate else {
//             return nil
//         }

//         let formatter = ISO8601DateFormatter()
//         return formatter.string(from: date)
//     }

//     private func applyObscuring(
//         to lines: [String]
//     ) -> [String] {
//         guard !obscureMap.isEmpty else {
//             return lines
//         }

//         var content = lines.joined(separator: "\n")

//         for (value, method) in obscureMap {
//             content = content.replacingOccurrences(
//                 of: value,
//                 with: obscureValue(value, method: method)
//             )
//         }

//         return content
//             .split(separator: "\n", omittingEmptySubsequences: false)
//             .map(String.init)
//     }

//     private func renderedBodyLines(
//         from slice: FileLineSlice
//     ) -> [String] {
//         guard includeSourceLineNumbers else {
//             return slice.lines
//         }

//         let width = String(max(1, slice.endLine)).count

//         return slice.numberedLines().map { numbered in
//             let label = String(
//                 format: "%\(width)d",
//                 numbered.line
//             )

//             return "\(label) | \(numbered.text)"
//         }
//     }
// }
