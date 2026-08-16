import Concatenation
import Foundation
import IO
import TestFlows
import Writers

extension ConcatenationFlowSuite {
    static var conAnyExecutionFlow: TestFlow {
        TestFlow(
            "con-any-execution",
            tags: [
                "con",
                "conany",
                "execution",
                "render",
                "cache",
            ]
        ) {
            Step(
                "typed execution resolves renders writes and reuses nested outputs"
            ) {
                let root = URL(
                    fileURLWithPath: NSTemporaryDirectory(),
                    isDirectory: true
                )
                .appendingPathComponent(
                    "concatenation-conany-execution-\(UUID().uuidString)",
                    isDirectory: true
                )

                defer {
                    try? FileSystem.default.remove(
                        root
                    )
                }

                let input = root.appendingPathComponent(
                    "input",
                    isDirectory: true
                )

                try FileSystem.default.directory.create(
                    input
                )

                let sourceA = input.appendingPathComponent(
                    "a.txt",
                    isDirectory: false
                )

                let sourceB = input.appendingPathComponent(
                    "b.txt",
                    isDirectory: false
                )

                _ = try StandardWriter(
                    sourceA
                ).write(
                    """
                    alpha
                    beta
                    """,
                    options: .overwriteWithoutBackup
                )

                _ = try StandardWriter(
                    sourceB
                ).write(
                    """
                    gamma
                    delta
                    """,
                    options: .overwriteWithoutBackup
                )

                let configURL = root.appendingPathComponent(
                    ".conany",
                    isDirectory: false
                )

                _ = try StandardWriter(
                    configURL
                ).write(
                    """
                    directory("nested") {
                        file("a-context.txt") {
                            context {
                                title = "A"
                            }

                            include(
                                from: "\(root.path)",
                                show: .relativeToBase
                            ) {
                                "input/a.txt"[2..2]
                            }
                        }
                    }

                    file("b-context.txt") {
                        include(
                            from: "\(root.path)",
                            show: .relativeToBase
                        ) {
                            "input/b.txt"
                        }
                    }
                    """,
                    options: .overwriteWithoutBackup
                )

                let execution = try ConAnyExecution(
                    configURL: configURL,
                    options: .init(
                        ignoreMap: IgnoreMap(),
                        delimiterStyle: .comment,
                        delimiterClosure: false,
                        maxLinesPerFile: nil,
                        rawOutput: false,
                        outputFormat: .text,
                        includeSourceLineNumbers: true,
                        includeSourceModifiedAt: false,
                        protectSecrets: false,
                        deepSecretInspection: false
                    )
                )

                let resolvedBatch = try execution.resolveBatch()
                let resolved = resolvedBatch.outputs

                try Expect.equal(
                    resolvedBatch.statistics.scanRequestCount,
                    2,
                    "conany.execution.resolution-scan-request-count"
                )

                try Expect.equal(
                    resolvedBatch.statistics.matchedOutputCount,
                    2,
                    "conany.execution.resolution-matched-output-count"
                )

                try Expect.equal(
                    resolvedBatch.statistics.unmatchedOutputCount,
                    0,
                    "conany.execution.resolution-unmatched-output-count"
                )

                try Expect.true(
                    resolvedBatch.statistics.plannedTraversalCount
                        >= resolvedBatch.statistics.uniqueRootCount,
                    "conany.execution.resolution-traversals-cover-roots"
                )

                try Expect.true(
                    resolvedBatch.statistics.uniqueRootCount > 0,
                    "conany.execution.resolution-has-roots"
                )

                try Expect.true(
                    resolvedBatch.statistics.physicalTraversalCount
                        <= resolvedBatch.statistics.plannedTraversalCount,
                    "conany.execution.resolution-physical-below-logical"
                )

                try Expect.true(
                    resolvedBatch.statistics.physicalTraversalCount
                        <= resolvedBatch.statistics.uniqueRootCount,
                    "conany.execution.resolution-physical-below-roots"
                )

                try Expect.true(
                    resolvedBatch.statistics.physicalTraversalCount > 0,
                    "conany.execution.resolution-has-physical-traversals"
                )

                try Expect.equal(
                    resolvedBatch.statistics.physicalTraversals.count,
                    resolvedBatch.statistics.physicalTraversalCount,
                    "conany.execution.resolution-physical-statistics-count"
                )

                try Expect.true(
                    resolvedBatch.statistics.physicalTraversals.allSatisfy {
                        $0.duration >= 0
                            && $0.entryCount >= 0
                            && $0.logicalRootCount > 0
                            && $0.directoryEnumerationDuration >= 0
                            && $0.childSortingDuration >= 0
                            && $0.metadataInspectionDuration >= 0
                            && $0.bookkeepingDuration >= 0
                            && $0.resultSortingDuration >= 0
                    },
                    "conany.execution.resolution-physical-statistics-valid"
                )

                try Expect.true(
                    resolvedBatch.statistics.resolver.totalDuration >= 0
                        && resolvedBatch.statistics.resolver.specificationDuration >= 0
                        && resolvedBatch.statistics.resolver.compilationDuration >= 0
                        && resolvedBatch.statistics.resolver.selection.path.totalDuration >= 0
                        && resolvedBatch.statistics.outputAssemblyDuration >= 0,
                    "conany.execution.resolution-stage-statistics-valid"
                )

                try Expect.true(
                    resolvedBatch.statistics.duration >= 0,
                    "conany.execution.resolution-duration"
                )

                try Expect.equal(
                    resolved.map(
                        \.name
                    ),
                    [
                        "nested/a-context.txt",
                        "b-context.txt",
                    ],
                    "conany.execution.resolved-order"
                )

                let resolvedA = try Expect.notNil(
                    resolved.first {
                        $0.name
                            == "nested/a-context.txt"
                    },
                    "conany.execution.resolved-a"
                )

                try Expect.equal(
                    resolvedA.fileCount,
                    1,
                    "conany.execution.resolved-a-file-count"
                )

                let resolvedSourceA =
                    try Expect.notNil(
                        resolvedA.sources.first {
                            $0.file
                                == sourceA
                                .standardizedFileURL
                        },
                        "conany.execution.resolved-a-source"
                    )

                try Expect.equal(
                    resolvedSourceA.presentedPath ?? "",
                    "./input/a.txt",
                    "conany.execution.presented-a"
                )

                try Expect.equal(
                    resolvedSourceA.selections.count,
                    1,
                    "conany.execution.resolved-a-selection-count"
                )

                let rendered = try await execution.render()

                try Expect.equal(
                    rendered.outputCount,
                    2,
                    "conany.execution.render-output-count"
                )

                try Expect.equal(
                    rendered.fileCount,
                    2,
                    "conany.execution.render-file-count"
                )

                try Expect.equal(
                    rendered.resolution.scanRequestCount,
                    2,
                    "conany.execution.render-resolution-scan-count"
                )

                try Expect.equal(
                    rendered.resolution.matchedOutputCount,
                    rendered.outputCount,
                    "conany.execution.render-resolution-matched-count"
                )

                try Expect.equal(
                    rendered.resolution.unmatchedOutputCount,
                    rendered.skipped.count,
                    "conany.execution.render-resolution-unmatched-count"
                )

                try Expect.equal(
                    rendered.outputs.map(
                        \.name
                    ),
                    [
                        "nested/a-context.txt",
                        "b-context.txt",
                    ],
                    "conany.execution.render-output-order"
                )

                try Expect.true(
                    rendered.combinedText.contains(
                        "===== .conany output: nested/a-context.txt ====="
                    ),
                    "conany.execution.render-a-boundary"
                )

                try Expect.true(
                    rendered.combinedText.contains(
                        "===== .conany output: b-context.txt ====="
                    ),
                    "conany.execution.render-b-boundary"
                )

                let aBoundary = try Expect.notNil(
                    rendered.combinedText.range(
                        of: "===== .conany output: nested/a-context.txt ====="
                    ),
                    "conany.execution.render-a-boundary-range"
                )

                let bBoundary = try Expect.notNil(
                    rendered.combinedText.range(
                        of: "===== .conany output: b-context.txt ====="
                    ),
                    "conany.execution.render-b-boundary-range"
                )

                try Expect.true(
                    aBoundary.lowerBound
                        < bBoundary.lowerBound,
                    "conany.execution.render-boundary-order"
                )

                try Expect.true(
                    rendered.combinedText.contains(
                        "2 | beta"
                    ),
                    "conany.execution.render-a-selected-content"
                )

                try Expect.true(
                    !rendered.combinedText.contains(
                        "1 | alpha"
                    ),
                    "conany.execution.render-a-unselected-content-absent"
                )

                try Expect.true(
                    rendered.combinedText.contains(
                        "1 | gamma"
                    ),
                    "conany.execution.render-b-content"
                )

                let outputA = root
                    .appendingPathComponent(
                        "nested",
                        isDirectory: true
                    )
                    .appendingPathComponent(
                        "a-context.txt",
                        isDirectory: false
                    )

                let outputB = root.appendingPathComponent(
                    "b-context.txt",
                    isDirectory: false
                )

                let cache = root.appendingPathComponent(
                    ".concatenation",
                    isDirectory: true
                )

                try Expect.true(
                    !FileSystem.default.exists(
                        outputA
                    ),
                    "conany.execution.render-no-output-a"
                )

                try Expect.true(
                    !FileSystem.default.exists(
                        outputB
                    ),
                    "conany.execution.render-no-output-b"
                )

                try Expect.true(
                    !FileSystem.default.exists(
                        cache
                    ),
                    "conany.execution.render-no-cache"
                )

                try Expect.true(
                    !FileSystem.default.exists(
                        root.appendingPathComponent(
                            "context_index.txt",
                            isDirectory: false
                        )
                    ),
                    "conany.execution.render-no-context-index"
                )

                let cold = try await execution.write()

                try Expect.equal(
                    cold.outputCount,
                    2,
                    "conany.execution.write-output-count"
                )

                try Expect.equal(
                    cold.resolution.scanRequestCount,
                    2,
                    "conany.execution.cold-resolution-scan-count"
                )

                try Expect.equal(
                    cold.resolution.matchedOutputCount,
                    cold.outputCount,
                    "conany.execution.cold-resolution-matched-count"
                )

                try Expect.equal(
                    cold.resolution.unmatchedOutputCount,
                    cold.skipped.count,
                    "conany.execution.cold-resolution-unmatched-count"
                )

                try Expect.true(
                    cold.performedWrite,
                    "conany.execution.cold-performed-write"
                )

                try Expect.equal(
                    cold.fileCount,
                    2,
                    "conany.execution.cold-file-count"
                )

                try Expect.equal(
                    cold.renderedOutputCount,
                    2,
                    "conany.execution.cold-rendered-output-count"
                )

                try Expect.equal(
                    cold.writtenOutputCount,
                    2,
                    "conany.execution.cold-written-output-count"
                )

                try Expect.equal(
                    cold.reusedSourceCount,
                    0,
                    "conany.execution.cold-reused-source-count"
                )

                try Expect.equal(
                    cold.cache.rebuilds,
                    2,
                    "conany.execution.cold-rebuild-count"
                )

                try Expect.equal(
                    cold.executionKind,
                    .rebuilt,
                    "conany.execution.cold-kind"
                )

                try Expect.true(
                    FileSystem.default.exists(
                        outputA
                    ),
                    "conany.execution.write-output-a"
                )

                try Expect.true(
                    FileSystem.default.exists(
                        outputB
                    ),
                    "conany.execution.write-output-b"
                )

                try Expect.true(
                    FileSystem.default.exists(
                        cache
                    ),
                    "conany.execution.write-cache"
                )

                let contextIndex = root.appendingPathComponent(
                    "context_index.txt",
                    isDirectory: false
                )

                try Expect.equal(
                    cold.contextIndexAction,
                    .written(
                        contextIndex
                    ),
                    "conany.execution.context-index-written"
                )

                try Expect.true(
                    FileSystem.default.exists(
                        contextIndex
                    ),
                    "conany.execution.context-index-exists"
                )

                let warm = try await execution.write()

                try Expect.true(
                    !warm.performedWrite,
                    "conany.execution.warm-no-write"
                )

                try Expect.equal(
                    warm.resolution.scanRequestCount,
                    2,
                    "conany.execution.warm-resolution-scan-count"
                )

                try Expect.equal(
                    warm.resolution.matchedOutputCount,
                    warm.outputCount,
                    "conany.execution.warm-resolution-matched-count"
                )

                try Expect.equal(
                    warm.resolution.unmatchedOutputCount,
                    warm.skipped.count,
                    "conany.execution.warm-resolution-unmatched-count"
                )

                try Expect.equal(
                    warm.fileCount,
                    2,
                    "conany.execution.warm-file-count"
                )

                try Expect.equal(
                    warm.renderedOutputCount,
                    0,
                    "conany.execution.warm-rendered-output-count"
                )

                try Expect.equal(
                    warm.writtenOutputCount,
                    0,
                    "conany.execution.warm-written-output-count"
                )

                try Expect.equal(
                    warm.reusedSourceCount,
                    2,
                    "conany.execution.warm-reused-source-count"
                )

                try Expect.equal(
                    warm.cache.rebuilds,
                    0,
                    "conany.execution.warm-rebuild-count"
                )

                try Expect.equal(
                    warm.executionKind,
                    .unchanged,
                    "conany.execution.warm-kind"
                )

                try Expect.true(
                    warm.outputs.allSatisfy {
                        !$0.result.performedRender
                    },
                    "conany.execution.warm-all-no-render"
                )

                try Expect.true(
                    warm.outputs.allSatisfy {
                        !$0.result.performedWrite
                    },
                    "conany.execution.warm-all-no-write"
                )

                try Expect.equal(
                    warm.contextIndexAction,
                    .unchanged(
                        contextIndex
                    ),
                    "conany.execution.context-index-unchanged"
                )
            }

            Step(
                "session render refreshes and reuses context"
            ) {
                let root = URL(
                    fileURLWithPath: NSTemporaryDirectory(),
                    isDirectory: true
                )
                .appendingPathComponent(
                    "concatenation-conany-session-\(UUID().uuidString)",
                    isDirectory: true
                )

                defer {
                    try? FileSystem.default.remove(
                        root
                    )
                }

                let input = root.appendingPathComponent(
                    "input",
                    isDirectory: true
                )

                try FileSystem.default.directory.create(
                    input
                )

                let sourceA = input.appendingPathComponent(
                    "a.txt",
                    isDirectory: false
                )

                let sourceB = input.appendingPathComponent(
                    "b.txt",
                    isDirectory: false
                )

                let configURL = root.appendingPathComponent(
                    ".conany",
                    isDirectory: false
                )

                func write(
                    _ text: String,
                    to url: URL
                ) throws {
                    _ = try StandardWriter(
                        url
                    ).write(
                        text,
                        options:
                            .overwriteWithoutBackup
                    )
                }

                func sourceReads(
                    _ result: ConAnyRenderBatchResult
                ) -> Int {
                    result.outputs.reduce(
                        0
                    ) {
                        $0
                            + $1.result
                            .document
                            .statistics
                            .cache
                            .sourceReads
                    }
                }

                func metadataHits(
                    _ result: ConAnyRenderBatchResult
                ) -> Int {
                    result.outputs.reduce(
                        0
                    ) {
                        $0
                            + $1.result
                            .document
                            .statistics
                            .cache
                            .metadataHits
                    }
                }

                try write(
                    "alpha-original",
                    to: sourceA
                )

                try write(
                    """
                    file("context.txt") {
                        include(
                            from: "\(root.path)",
                            show: .relativeToBase
                        ) {
                            "input/*.txt"
                        }
                    }
                    """,
                    to: configURL
                )

                let options = ConAnyExecutionOptions(
                    maxLinesPerFile: nil,
                    protectSecrets: false,
                    deepSecretInspection: false
                )

                let session = ConcatenationSession()

                let first = try await session.render(
                    conAnyAt: configURL,
                    options: options
                )

                try Expect.equal(
                    first.fileCount,
                    1,
                    "conany.session.first-file-count"
                )

                try Expect.equal(
                    sourceReads(first),
                    1,
                    "conany.session.first-source-read"
                )

                let warm = try await session.render(
                    conAnyAt: configURL,
                    options: options
                )

                try Expect.equal(
                    sourceReads(warm),
                    0,
                    "conany.session.warm-zero-source-reads"
                )

                try Expect.equal(
                    metadataHits(warm),
                    1,
                    "conany.session.warm-metadata-hit"
                )

                try write(
                    "alpha-changed",
                    to: sourceA
                )

                try session.invalidate(
                    source: sourceA
                )

                let invalidated = try await session.render(
                    conAnyAt: configURL,
                    options: options
                )

                try Expect.equal(
                    sourceReads(invalidated),
                    1,
                    "conany.session.invalidated-source-read"
                )

                try Expect.true(
                    invalidated
                        .combinedText
                        .contains(
                            "alpha-changed"
                        ),
                    "conany.session.invalidated-content"
                )

                try write(
                    "bravo-new",
                    to: sourceB
                )

                let membership = try await session.render(
                    conAnyAt: configURL,
                    options: options
                )

                try Expect.equal(
                    membership.fileCount,
                    2,
                    "conany.session.membership-file-count"
                )

                try Expect.equal(
                    sourceReads(membership),
                    1,
                    "conany.session.membership-new-source-read"
                )

                try Expect.equal(
                    metadataHits(membership),
                    1,
                    "conany.session.membership-existing-hit"
                )

                try write(
                    """
                    file("context.txt") {
                        include(
                            from: "\(root.path)",
                            show: .relativeToBase
                        ) {
                            "input/*.txt"
                        }
                    }

                    file("secondary.txt") {
                        include(
                            from: "\(root.path)",
                            show: .relativeToBase
                        ) {
                            "input/b.txt"
                        }
                    }
                    """,
                    to: configURL
                )

                let reparsed = try await session.render(
                    conAnyAt: configURL,
                    options: options
                )

                try Expect.equal(
                    reparsed.outputCount,
                    2,
                    "conany.session.reparsed-output-count"
                )

                try Expect.equal(
                    sourceReads(reparsed),
                    1,
                    "conany.session.reparsed-new-scope-read"
                )

                try Expect.equal(
                    metadataHits(reparsed),
                    2,
                    "conany.session.reparsed-existing-hits"
                )

                try Expect.true(
                    !FileSystem.default.exists(
                        root.appendingPathComponent(
                            "context.txt",
                            isDirectory: false
                        )
                    ),
                    "conany.session.no-primary-output-artifact"
                )

                try Expect.true(
                    !FileSystem.default.exists(
                        root.appendingPathComponent(
                            "secondary.txt",
                            isDirectory: false
                        )
                    ),
                    "conany.session.no-secondary-output-artifact"
                )
            }

            Step(
                "shared source preflight deduplicates overlapping outputs"
            ) {
                let root = URL(
                    fileURLWithPath:
                        NSTemporaryDirectory(),
                    isDirectory: true
                )
                .appendingPathComponent(
                    "concatenation-conany-shared-preflight-\(UUID().uuidString)",
                    isDirectory: true
                )

                defer {
                    try? FileSystem.default.remove(
                        root
                    )
                }

                let input = root.appendingPathComponent(
                    "input",
                    isDirectory: true
                )

                try FileSystem.default.directory.create(
                    input
                )

                let sourceA = input.appendingPathComponent(
                    "a.txt",
                    isDirectory: false
                )

                let sourceB = input.appendingPathComponent(
                    "b.txt",
                    isDirectory: false
                )

                _ = try StandardWriter(
                    sourceA
                ).write(
                    "alpha",
                    options: .overwriteWithoutBackup
                )

                _ = try StandardWriter(
                    sourceB
                ).write(
                    "bravo",
                    options: .overwriteWithoutBackup
                )

                let configURL = root.appendingPathComponent(
                    ".conany",
                    isDirectory: false
                )

                _ = try StandardWriter(
                    configURL
                ).write(
                    """
                    file("first.txt") {
                        include(
                            from: "\(root.path)",
                            show: .relativeToBase
                        ) {
                            "input/*.txt"
                        }
                    }

                    file("second.txt") {
                        include(
                            from: "\(root.path)",
                            show: .relativeToBase
                        ) {
                            "input/*.txt"
                        }
                    }
                    """,
                    options: .overwriteWithoutBackup
                )

                let execution = try ConAnyExecution(
                    configURL: configURL,
                    options: .init(
                        ignoreMap: IgnoreMap(),
                        maxLinesPerFile: nil,
                        protectSecrets: false,
                        deepSecretInspection: false
                    )
                )

                let cold = try await execution.write()

                try Expect.equal(
                    cold.sourcePreflight
                        .sourceReferenceCount,
                    4,
                    "conany.preflight.cold-reference-count"
                )

                try Expect.equal(
                    cold.sourcePreflight
                        .uniqueSourceCount,
                    2,
                    "conany.preflight.cold-unique-source-count"
                )

                try Expect.equal(
                    cold.sourcePreflight
                        .uniqueResolvedSourceCount,
                    2,
                    "conany.preflight.cold-unique-resolved-count"
                )

                try Expect.equal(
                    cold.sourcePreflight
                        .metadataInspectionCount,
                    2,
                    "conany.preflight.cold-inspection-count"
                )

                try Expect.equal(
                    cold.sourcePreflight
                        .sharedMetadataReuseCount,
                    2,
                    "conany.preflight.cold-shared-hit-count"
                )

                let warm = try await execution.write()

                try Expect.equal(
                    warm.sourcePreflight
                        .metadataInspectionCount,
                    2,
                    "conany.preflight.warm-inspection-count"
                )

                try Expect.equal(
                    warm.sourcePreflight
                        .sharedMetadataReuseCount,
                    2,
                    "conany.preflight.warm-shared-hit-count"
                )

                try Expect.equal(
                    warm.reuseProofs.lookupCount,
                    4,
                    "conany.reuse-proofs.warm-reference-count"
                )

                try Expect.equal(
                    warm.reuseProofs.uniqueProofCount,
                    2,
                    "conany.reuse-proofs.warm-unique-count"
                )

                try Expect.equal(
                    warm.reuseProofs.sharedHitCount,
                    2,
                    "conany.reuse-proofs.warm-shared-hit-count"
                )

                try Expect.equal(
                    warm.reuseProofs
                        .fingerprintComputationCount,
                    2,
                    "conany.reuse-proofs.warm-computation-count"
                )

                try Expect.equal(
                    warm.cache.sourceReads,
                    0,
                    "conany.preflight.warm-source-reads"
                )

                try Expect.equal(
                    warm.renderedOutputCount,
                    0,
                    "conany.preflight.warm-rendered-output-count"
                )

                try Expect.equal(
                    warm.writtenOutputCount,
                    0,
                    "conany.preflight.warm-written-output-count"
                )
            }

        }
    }
}
