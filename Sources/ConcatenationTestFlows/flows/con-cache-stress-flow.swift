import Foundation
import Concatenation
import IO
import Readers
import Writers
import TestFlows

extension ConcatenationFlowSuite {
    static var conCacheStressFlow: TestFlow {
        TestFlow(
            "con-cache-stress",
            tags: [
                "con",
                "cache",
                "stress",
                "incremental",
            ]
        ) {
            Step("renderer-only changes reuse cached sections") {
                let fixture = try ConcatenationStressFixture(
                    "renderer-invalidation"
                )

                defer {
                    fixture.remove()
                }

                let source = fixture.source(
                    0
                )

                try fixture.write(
                    """
                    alpha
                    beta
                    gamma
                    delta
                    """,
                    to: source
                )

                let sources = [
                    source,
                ]

                let boxed = fixture.concatenator(
                    sources,
                    delimiterStyle: .boxed
                )

                let first = try await boxed.write(
                    concurrency: .automatic
                )

                try Expect.true(
                    first.performedWrite,
                    "cache-stress.renderer-first-write"
                )

                let classic = fixture.concatenator(
                    sources,
                    delimiterStyle: .classic
                )

                let delimiterChanged = try await classic.write(
                    concurrency: .automatic
                )

                try expectRendererOnlyInvalidation(
                    delimiterChanged,
                    sourceCount: 1,
                    label: "delimiter"
                )

                let classicStable = try await classic.write(
                    concurrency: .automatic
                )

                try Expect.true(
                    !classicStable.performedRender,
                    "cache-stress.renderer-delimiter-stable-no-render"
                )

                try Expect.true(
                    !classicStable.performedWrite,
                    "cache-stress.renderer-delimiter-stable-no-write"
                )

                let numbered = fixture.concatenator(
                    sources,
                    delimiterStyle: .classic,
                    includeSourceLineNumbers: true
                )

                let numbersChanged = try await numbered.write(
                    concurrency: .automatic
                )

                try expectRendererOnlyInvalidation(
                    numbersChanged,
                    sourceCount: 1,
                    label: "numbers"
                )

                let xml = fixture.concatenator(
                    sources,
                    delimiterStyle: .classic,
                    outputFormat: .xml,
                    includeSourceLineNumbers: true
                )

                let xmlChanged = try await xml.write(
                    concurrency: .automatic
                )

                try expectRendererOnlyInvalidation(
                    xmlChanged,
                    sourceCount: 1,
                    label: "xml"
                )

                let xmlText = try Expect.notNil(
                    xmlChanged.text,
                    "cache-stress.renderer-xml-text"
                )

                try Expect.true(
                    xmlText.hasPrefix(
                        "<?xml"
                    ),
                    "cache-stress.renderer-xml-format"
                )

                let raw = fixture.concatenator(
                    sources,
                    delimiterStyle: .classic,
                    rawOutput: true,
                    outputFormat: .text,
                    includeSourceLineNumbers: true
                )

                let rawChanged = try await raw.write(
                    concurrency: .automatic
                )

                try expectRendererOnlyInvalidation(
                    rawChanged,
                    sourceCount: 1,
                    label: "raw"
                )

                let rawText = try Expect.notNil(
                    rawChanged.text,
                    "cache-stress.renderer-raw-text"
                )

                try Expect.true(
                    !rawText.contains(
                        "=== Contents of"
                    ),
                    "cache-stress.renderer-raw-no-delimiter"
                )

                let rawStable = try await raw.write(
                    concurrency: .automatic
                )

                try Expect.true(
                    !rawStable.performedRender,
                    "cache-stress.renderer-raw-stable-no-render"
                )

                try Expect.true(
                    !rawStable.performedWrite,
                    "cache-stress.renderer-raw-stable-no-write"
                )
            }

            Step("cached parallel document matches uncached serial document") {
                let fixture = try ConcatenationStressFixture(
                    "semantic-equivalence"
                )

                defer {
                    fixture.remove()
                }

                let sourceCount = 128
                let linesPerSource = 40

                let sources = try (0..<sourceCount).map {
                    index -> URL in

                    let source = fixture.source(
                        index
                    )

                    let content = (0..<linesPerSource)
                        .map {
                            line in

                            if line % 11 == 0 {
                                return ""
                            }

                            return "source-\(index)-line-\(line) TOKEN"
                        }
                        .joined(
                            separator: "\n"
                        )

                    try fixture.write(
                        content,
                        to: source
                    )

                    return source
                }

                let cached = fixture.concatenator(
                    sources,
                    maxLinesPerFile: 31,
                    obscureMap: [
                        "TOKEN": "redact",
                    ]
                )

                let coldCached = try await cached.document(
                    concurrency: .limited(
                        8
                    )
                )

                try Expect.equal(
                    coldCached.statistics.cache.metadataInspections,
                    sourceCount,
                    "cache-stress.equivalence-cold-inspections"
                )

                try Expect.equal(
                    coldCached.statistics.cache.sourceReads,
                    sourceCount,
                    "cache-stress.equivalence-cold-reads"
                )

                try Expect.equal(
                    coldCached.statistics.cache.rebuilds,
                    sourceCount,
                    "cache-stress.equivalence-cold-rebuilds"
                )

                let warmCached = try await cached.document(
                    concurrency: .automatic
                )

                try Expect.equal(
                    warmCached.statistics.cache.metadataHits,
                    sourceCount,
                    "cache-stress.equivalence-warm-hits"
                )

                try Expect.equal(
                    warmCached.statistics.cache.sourceReads,
                    0,
                    "cache-stress.equivalence-warm-zero-reads"
                )

                try Expect.equal(
                    warmCached.statistics.cache.rebuilds,
                    0,
                    "cache-stress.equivalence-warm-zero-rebuilds"
                )

                let uncached = fixture.concatenator(
                    sources,
                    cached: false,
                    maxLinesPerFile: 31,
                    obscureMap: [
                        "TOKEN": "redact",
                    ]
                )

                let serialReference = try await uncached.document(
                    concurrency: .serial
                )

                try Expect.equal(
                    serialReference.statistics.cache.sourceReads,
                    sourceCount,
                    "cache-stress.equivalence-reference-reads"
                )

                try Expect.equal(
                    stableSectionEncoding(
                        warmCached.sections
                    ),
                    stableSectionEncoding(
                        serialReference.sections
                    ),
                    "cache-stress.equivalence-sections"
                )

                try Expect.equal(
                    warmCached.statistics.sourceCount,
                    serialReference.statistics.sourceCount,
                    "cache-stress.equivalence-source-count"
                )

                try Expect.equal(
                    warmCached.statistics.renderedSectionCount,
                    serialReference.statistics.renderedSectionCount,
                    "cache-stress.equivalence-rendered-count"
                )

                try Expect.equal(
                    warmCached.statistics.blockedFileCount,
                    serialReference.statistics.blockedFileCount,
                    "cache-stress.equivalence-blocked-count"
                )

                try Expect.equal(
                    warmCached.statistics.truncatedSectionCount,
                    serialReference.statistics.truncatedSectionCount,
                    "cache-stress.equivalence-truncated-count"
                )

                try Expect.equal(
                    warmCached.statistics.selectedLineCount,
                    serialReference.statistics.selectedLineCount,
                    "cache-stress.equivalence-line-count"
                )
            }

            Step("section transformations invalidate without stale reuse") {
                let fixture = try ConcatenationStressFixture(
                    "transform-invalidation"
                )

                defer {
                    fixture.remove()
                }

                let source = fixture.source(
                    0
                )

                let content = (0..<12)
                    .map {
                        "line-\($0) TOKEN"
                    }
                    .joined(
                        separator: "\n"
                    )

                try fixture.write(
                    content,
                    to: source
                )

                let sources = [
                    source,
                ]

                let baseline = fixture.concatenator(
                    sources,
                    maxLinesPerFile: 8
                )

                _ = try await baseline.document(
                    concurrency: .automatic
                )

                let truncated = fixture.concatenator(
                    sources,
                    maxLinesPerFile: 4
                )

                let truncatedDocument = try await truncated.document(
                    concurrency: .automatic
                )

                try expectCacheExecution(
                    truncatedDocument,
                    metadataHits: 0,
                    sourceReads: 1,
                    rebuilds: 1,
                    label: "transform-truncation"
                )

                let truncatedReference = try await fixture.concatenator(
                    sources,
                    cached: false,
                    maxLinesPerFile: 4
                ).document(
                    concurrency: .serial
                )

                try Expect.equal(
                    stableSectionEncoding(
                        truncatedDocument.sections
                    ),
                    stableSectionEncoding(
                        truncatedReference.sections
                    ),
                    "cache-stress.transform-truncation-equivalence"
                )

                let obscured = fixture.concatenator(
                    sources,
                    maxLinesPerFile: 4,
                    obscureMap: [
                        "TOKEN": "MASKED",
                    ]
                )

                let obscuredDocument = try await obscured.document(
                    concurrency: .automatic
                )

                try expectCacheExecution(
                    obscuredDocument,
                    metadataHits: 0,
                    sourceReads: 1,
                    rebuilds: 1,
                    label: "transform-obscuration"
                )

                let obscuredReference = try await fixture.concatenator(
                    sources,
                    cached: false,
                    maxLinesPerFile: 4,
                    obscureMap: [
                        "TOKEN": "MASKED",
                    ]
                ).document(
                    concurrency: .serial
                )

                try Expect.equal(
                    stableSectionEncoding(
                        obscuredDocument.sections
                    ),
                    stableSectionEncoding(
                        obscuredReference.sections
                    ),
                    "cache-stress.transform-obscuration-equivalence"
                )

                let presented = [
                    source: "virtual/source.swift",
                ]

                let presentedConcatenator = fixture.concatenator(
                    sources,
                    maxLinesPerFile: 4,
                    obscureMap: [
                        "TOKEN": "MASKED",
                    ],
                    presentedPathByFile: presented
                )

                let presentedDocument = try await presentedConcatenator.document(
                    concurrency: .automatic
                )

                try expectCacheExecution(
                    presentedDocument,
                    metadataHits: 0,
                    sourceReads: 1,
                    rebuilds: 1,
                    label: "transform-presentation"
                )

                try Expect.equal(
                    presentedDocument.sections[0].presentedPath,
                    "virtual/source.swift",
                    "cache-stress.transform-presented-path"
                )

                let presentedReference = try await fixture.concatenator(
                    sources,
                    cached: false,
                    maxLinesPerFile: 4,
                    obscureMap: [
                        "TOKEN": "MASKED",
                    ],
                    presentedPathByFile: presented
                ).document(
                    concurrency: .serial
                )

                try Expect.equal(
                    stableSectionEncoding(
                        presentedDocument.sections
                    ),
                    stableSectionEncoding(
                        presentedReference.sections
                    ),
                    "cache-stress.transform-presentation-equivalence"
                )

                let stable = try await presentedConcatenator.document(
                    concurrency: .automatic
                )

                try expectCacheExecution(
                    stable,
                    metadataHits: 1,
                    sourceReads: 0,
                    rebuilds: 0,
                    label: "transform-stable"
                )
            }

            Step("partial manifest repairs only missing cached sources") {
                let fixture = try ConcatenationStressFixture(
                    "partial-manifest"
                )

                defer {
                    fixture.remove()
                }

                let sourceCount = 64

                let sources = try (0..<sourceCount).map {
                    index -> URL in

                    let source = fixture.source(
                        index
                    )

                    try fixture.write(
                        """
                        source \(index)
                        alpha
                        beta
                        gamma
                        """,
                        to: source
                    )

                    return source
                }

                let concatenator = fixture.concatenator(
                    sources
                )

                _ = try await concatenator.document(
                    concurrency: .automatic
                )

                let store = ConcatenationCacheStore(
                    workspace: fixture.workspace
                )

                let manifest = try Expect.notNil(
                    try store.load(
                        for: fixture.output
                    ),
                    "cache-stress.partial-manifest-initial"
                )

                let missingIndexes = Set(
                    stride(
                        from: 0,
                        to: sourceCount,
                        by: 5
                    )
                )

                let retainedSources = manifest.sources
                    .enumerated()
                    .compactMap {
                        entry -> ConcatenationCachedSource? in

                        missingIndexes.contains(
                            entry.offset
                        )
                            ? nil
                            : entry.element
                    }

                try store.save(
                    .init(
                        output: manifest.output,
                        sources: retainedSources,
                        safeguards: manifest.safeguards,
                        artifact: manifest.artifact
                    )
                )

                let repaired = try await concatenator.document(
                    concurrency: .limited(
                        8
                    )
                )

                try expectCacheExecution(
                    repaired,
                    metadataHits: retainedSources.count,
                    sourceReads: missingIndexes.count,
                    rebuilds: missingIndexes.count,
                    label: "partial-manifest-repair"
                )

                let reference = try await fixture.concatenator(
                    sources,
                    cached: false
                ).document(
                    concurrency: .serial
                )

                try Expect.equal(
                    stableSectionEncoding(
                        repaired.sections
                    ),
                    stableSectionEncoding(
                        reference.sections
                    ),
                    "cache-stress.partial-manifest-equivalence"
                )

                let stable = try await concatenator.document(
                    concurrency: .automatic
                )

                try expectCacheExecution(
                    stable,
                    metadataHits: sourceCount,
                    sourceReads: 0,
                    rebuilds: 0,
                    label: "partial-manifest-stable"
                )
            }

            Step("stale manifest version is rejected and rebuilt") {
                let fixture = try ConcatenationStressFixture(
                    "manifest-version"
                )

                defer {
                    fixture.remove()
                }

                let sourceCount = 8

                let sources = try (0..<sourceCount).map {
                    index -> URL in

                    let source = fixture.source(
                        index
                    )

                    try fixture.write(
                        "source-\(index)",
                        to: source
                    )

                    return source
                }

                let concatenator = fixture.concatenator(
                    sources
                )

                _ = try await concatenator.document(
                    concurrency: .automatic
                )

                let store = ConcatenationCacheStore(
                    workspace: fixture.workspace
                )

                let current = try Expect.notNil(
                    try store.load(
                        for: fixture.output
                    ),
                    "cache-stress.version-current"
                )

                try store.save(
                    .init(
                        version:
                            ConcatenationCacheManifest.currentVersion + 1,
                        output: current.output,
                        sources: current.sources,
                        safeguards: current.safeguards,
                        artifact: current.artifact
                    )
                )

                let rejected = try store.load(
                    for: fixture.output
                )

                try Expect.true(
                    rejected == nil,
                    "cache-stress.version-rejected"
                )

                let rebuilt = try await concatenator.document(
                    concurrency: .automatic
                )

                try expectCacheExecution(
                    rebuilt,
                    metadataHits: 0,
                    sourceReads: sourceCount,
                    rebuilds: sourceCount,
                    label: "version-rebuild"
                )

                let recovered = try Expect.notNil(
                    try store.load(
                        for: fixture.output
                    ),
                    "cache-stress.version-recovered"
                )

                try Expect.equal(
                    recovered.version,
                    ConcatenationCacheManifest.currentVersion,
                    "cache-stress.version-restored-current"
                )
            }

            Step("repeated partial mutations remain equivalent to cold serial") {
                let fixture = try ConcatenationStressFixture(
                    "mutation-cycles"
                )

                defer {
                    fixture.remove()
                }

                let sourceCount = 96
                let cycleCount = 8

                let sources = try (0..<sourceCount).map {
                    index -> URL in

                    let source = fixture.source(
                        index
                    )

                    let content = (0..<24)
                        .map {
                            line in

                            "source-\(index)-line-\(line)"
                        }
                        .joined(
                            separator: "\n"
                        )

                    try fixture.write(
                        content,
                        to: source
                    )

                    return source
                }

                let cached = fixture.concatenator(
                    sources
                )

                _ = try await cached.document(
                    concurrency: .limited(
                        8
                    )
                )

                let initialWarm = try await cached.document(
                    concurrency: .automatic
                )

                try expectCacheExecution(
                    initialWarm,
                    metadataHits: sourceCount,
                    sourceReads: 0,
                    rebuilds: 0,
                    label: "mutation-initial-warm"
                )

                for cycle in 0..<cycleCount {
                    let changedIndexes = sources.indices.filter {
                        $0 % 12 == cycle
                    }

                    for index in changedIndexes {
                        let mutation = String(
                            repeating: "x",
                            count: cycle + index % 7 + 1
                        )

                        try fixture.write(
                            """
                            source \(index)
                            cycle \(cycle)
                            mutation \(mutation)
                            alpha
                            beta
                            gamma
                            delta
                            """,
                            to: sources[index]
                        )
                    }

                    let incremental = try await cached.document(
                        concurrency: .limited(
                            8
                        )
                    )

                    try expectCacheExecution(
                        incremental,
                        metadataHits:
                            sourceCount - changedIndexes.count,
                        sourceReads: changedIndexes.count,
                        rebuilds: changedIndexes.count,
                        label: "mutation-cycle-\(cycle)"
                    )

                    let reference = try await fixture.concatenator(
                        sources,
                        cached: false
                    ).document(
                        concurrency: .serial
                    )

                    try Expect.equal(
                        stableSectionEncoding(
                            incremental.sections
                        ),
                        stableSectionEncoding(
                            reference.sections
                        ),
                        "cache-stress.mutation-cycle-\(cycle)-equivalence"
                    )
                }

                let finalWarm = try await cached.document(
                    concurrency: .automatic
                )

                try expectCacheExecution(
                    finalWarm,
                    metadataHits: sourceCount,
                    sourceReads: 0,
                    rebuilds: 0,
                    label: "mutation-final-warm"
                )
            }
        }
    }
}

private func expectRendererOnlyInvalidation(
    _ result: ConcatenationWriteResult,
    sourceCount: Int,
    label: String
) throws {
    try Expect.equal(
        result.document.statistics.cache.metadataHits,
        sourceCount,
        "cache-stress.renderer-\(label)-metadata-hits"
    )

    try Expect.equal(
        result.document.statistics.cache.sourceReads,
        0,
        "cache-stress.renderer-\(label)-zero-reads"
    )

    try Expect.equal(
        result.document.statistics.cache.rebuilds,
        0,
        "cache-stress.renderer-\(label)-zero-rebuilds"
    )

    try Expect.true(
        result.performedRender,
        "cache-stress.renderer-\(label)-render"
    )

    try Expect.true(
        result.performedWrite,
        "cache-stress.renderer-\(label)-write"
    )
}

private func expectCacheExecution(
    _ document: ConcatenationDocument,
    metadataHits: Int,
    sourceReads: Int,
    rebuilds: Int,
    label: String
) throws {
    try Expect.equal(
        document.statistics.cache.metadataHits,
        metadataHits,
        "cache-stress.\(label)-metadata-hits"
    )

    try Expect.equal(
        document.statistics.cache.sourceReads,
        sourceReads,
        "cache-stress.\(label)-source-reads"
    )

    try Expect.equal(
        document.statistics.cache.rebuilds,
        rebuilds,
        "cache-stress.\(label)-rebuilds"
    )
}

private func stableSectionEncoding(
    _ sections: [ConcatenationSection]
) throws -> Data {
    let encoder = JSONEncoder()

    encoder.outputFormatting = [
        .sortedKeys,
    ]

    return try encoder.encode(
        sections
    )
}

private struct ConcatenationStressFixture {
    let root: URL
    let output: URL
    let workspace: ConcatenationWorkspace

    init(
        _ name: String
    ) throws {
        let root = URL(
            fileURLWithPath: NSTemporaryDirectory(),
            isDirectory: true
        )
        .appendingPathComponent(
            "concatenation-stress-\(name)-\(UUID().uuidString)",
            isDirectory: true
        )

        self.root = root
        self.output = root.appendingPathComponent(
            "output.txt",
            isDirectory: false
        )
        self.workspace = ConcatenationWorkspace(
            root: root
        )

        try FileSystem.default.directory.create(
            root
        )
    }

    func source(
        _ index: Int
    ) -> URL {
        root.appendingPathComponent(
            String(
                format: "source-%03d.txt",
                index
            ),
            isDirectory: false
        )
    }

    func write(
        _ text: String,
        to source: URL
    ) throws {
        _ = try StandardWriter(
            source
        ).write(
            text,
            options: .overwriteWithoutBackup
        )
    }

    func concatenator(
        _ sources: [URL],
        cached: Bool = true,
        delimiterStyle: DelimiterStyle = .boxed,
        maxLinesPerFile: Int? = nil,
        rawOutput: Bool = false,
        outputFormat: ConcatenationOutputFormat = .text,
        includeSourceLineNumbers: Bool = false,
        obscureMap: [String: String] = [:],
        presentedPathByFile: [URL: String] = [:]
    ) -> FileConcatenator {
        FileConcatenator(
            inputFiles: sources,
            outputURL: output,
            workspace: cached
                ? workspace
                : nil,
            presentedPathByFile: presentedPathByFile,
            delimiterStyle: delimiterStyle,
            delimiterClosure: false,
            maxLinesPerFile: maxLinesPerFile,
            trimBlankLines: true,
            relativePaths: false,
            rawOutput: rawOutput,
            outputFormat: outputFormat,
            includeSourceLineNumbers: includeSourceLineNumbers,
            includeSourceModifiedAt: false,
            obscureMap: obscureMap,
            protectSecrets: false
        )
    }

    func remove() {
        try? FileSystem.default.remove(
            root
        )
    }
}
