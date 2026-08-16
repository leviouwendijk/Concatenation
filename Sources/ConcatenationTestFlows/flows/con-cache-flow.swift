import Foundation
import Concatenation
import IO
import Readers
import Writers
import TestFlows

extension ConcatenationFlowSuite {
    static var conCacheFlow: TestFlow {
        TestFlow(
            "con-cache",
            tags: [
                "con",
                "cache",
                "incremental",
            ]
        ) {
            Step("render-only concatenation requires no output artifact") {
                let fixture = try ConcatenationCacheFixture(
                    "render-only"
                )

                defer {
                    fixture.remove()
                }

                try fixture.writeSource(
                    """
                    alpha
                    beta
                    gamma
                    """
                )

                let concatenator = FileConcatenator(
                    inputFiles: [
                        fixture.source,
                    ],
                    delimiterStyle: .comment,
                    trimBlankLines: true,
                    includeSourceLineNumbers: true,
                    protectSecrets: false
                )

                let rendered = try concatenator.render()

                try Expect.true(
                    rendered.text.contains(
                        "1 | alpha"
                    ),
                    "cache.render-only-line-numbers"
                )

                try Expect.true(
                    rendered.text.contains(
                        "# "
                    ),
                    "cache.render-only-comment-delimiter"
                )

                try Expect.true(
                    !FileSystem.default.exists(
                        fixture.output
                    ),
                    "cache.render-only-no-artifact"
                )
            }

            Step("memory cache reuses outputless source state") {
                let fixture = try ConcatenationCacheFixture(
                    "memory-outputless"
                )

                defer {
                    fixture.remove()
                }

                try fixture.writeSource(
                    """
                    alpha
                    beta
                    gamma
                    """
                )

                let scope =
                    fixture.root
                    .appendingPathComponent(
                        "agentic-context",
                        isDirectory: false
                    )

                let session =
                    ConcatenationSession()

                let binding =
                    session.binding(
                        for: scope
                    )

                let concatenator =
                    FileConcatenator(
                        inputFiles: [
                            fixture.source,
                        ],
                        cache:
                            binding,
                        protectSecrets:
                            false
                    )

                let first =
                    try concatenator.document()

                try Expect.equal(
                    first.statistics.cache.sourceReads,
                    1,
                    "cache.memory-first-source-read"
                )

                try Expect.equal(
                    first.statistics.cache.rebuilds,
                    1,
                    "cache.memory-first-rebuild"
                )

                let second =
                    try concatenator.document()

                try Expect.equal(
                    second.statistics.cache.sourceReads,
                    0,
                    "cache.memory-warm-zero-source-reads"
                )

                try Expect.equal(
                    second.statistics.cache.metadataHits,
                    1,
                    "cache.memory-warm-metadata-hit"
                )

                let manifest =
                    try Expect.notNil(
                        try binding.load(),
                        "cache.memory-manifest"
                    )

                _ = try Expect.notNil(
                    try binding.loadSection(
                        key:
                            manifest
                            .sources[0]
                            .sectionKey
                    ),
                    "cache.memory-section"
                )

                try fixture.writeSource(
                    """
                    alpha
                    beta
                    changed
                    """
                )

                try session.invalidate(
                    source:
                        fixture.source
                )

                let invalidated =
                    try Expect.notNil(
                        try binding.load(),
                        "cache.memory-invalidated-manifest"
                    )

                try Expect.equal(
                    invalidated.sources.count,
                    0,
                    "cache.memory-invalidated-source-removed"
                )

                let refreshed =
                    try concatenator.document()

                try Expect.equal(
                    refreshed.statistics.cache.sourceReads,
                    1,
                    "cache.memory-invalidated-source-read"
                )

                try Expect.equal(
                    refreshed.statistics.cache.rebuilds,
                    1,
                    "cache.memory-invalidated-rebuild"
                )

                let stable =
                    try concatenator.document()

                try Expect.equal(
                    stable.statistics.cache.sourceReads,
                    0,
                    "cache.memory-restabilized-zero-source-reads"
                )

                try Expect.equal(
                    stable.statistics.cache.metadataHits,
                    1,
                    "cache.memory-restabilized-hit"
                )
            }

            Step("hybrid cache promotes disk state into memory") {
                let fixture = try ConcatenationCacheFixture(
                    "hybrid-promotion"
                )

                defer {
                    fixture.remove()
                }

                try fixture.writeSource(
                    """
                    alpha
                    beta
                    gamma
                    """
                )

                _ = try fixture
                    .concatenator()
                    .document()

                let memory =
                    ConcatenationMemoryCache()

                let hybrid =
                    ConcatenationHybridCache(
                        memory:
                            memory,
                        disk:
                            fixture.store
                    )

                let binding =
                    ConcatenationCacheBinding(
                        storage:
                            hybrid,
                        scope:
                            fixture.output
                    )

                let outputless =
                    FileConcatenator(
                        inputFiles: [
                            fixture.source,
                        ],
                        cache:
                            binding,
                        protectSecrets:
                            false
                    )

                let warm =
                    try outputless.document()

                try Expect.equal(
                    warm.statistics.cache.sourceReads,
                    0,
                    "cache.hybrid-warm-zero-source-reads"
                )

                try Expect.equal(
                    warm.statistics.cache.metadataHits,
                    1,
                    "cache.hybrid-warm-metadata-hit"
                )

                let promoted =
                    try Expect.notNil(
                        try memory.load(
                            for:
                                fixture.output
                        ),
                        "cache.hybrid-promoted-manifest"
                    )

                _ = try Expect.notNil(
                    try memory.loadSection(
                        for:
                            fixture.output,
                        key:
                            promoted
                            .sources[0]
                            .sectionKey
                    ),
                    "cache.hybrid-promoted-section"
                )
            }

            Step("workspace maps internal and external cache manifests") {
                let fixture = try ConcatenationCacheFixture(
                    "workspace"
                )

                defer {
                    fixture.remove()
                }

                let nestedOutput = fixture.root
                    .appendingPathComponent(
                        "reports",
                        isDirectory: true
                    )
                    .appendingPathComponent(
                        "context.txt",
                        isDirectory: false
                    )

                let expectedInternal = fixture.workspace.cache
                    .appendingPathComponent(
                        "reports",
                        isDirectory: true
                    )
                    .appendingPathComponent(
                        "context.txt.json",
                        isDirectory: false
                    )

                try Expect.equal(
                    fixture.workspace.cacheManifest(
                        for: nestedOutput
                    ),
                    expectedInternal,
                    "cache.internal-manifest"
                )

                try Expect.equal(
                    fixture.workspace.cachedSections(
                        for: nestedOutput
                    ),
                    expectedInternal
                        .deletingLastPathComponent()
                        .appendingPathComponent(
                            "context.txt.sections",
                            isDirectory: true
                        ),
                    "cache.internal-sections"
                )

                let externalOutput = fixture.root
                    .deletingLastPathComponent()
                    .appendingPathComponent(
                        "external-\(UUID().uuidString).txt",
                        isDirectory: false
                    )

                let externalManifest = fixture.workspace.cacheManifest(
                    for: externalOutput
                )

                let expectedExternalDirectory = fixture.workspace.cache
                    .appendingPathComponent(
                        "external",
                        isDirectory: true
                    )

                try Expect.equal(
                    externalManifest.deletingLastPathComponent(),
                    expectedExternalDirectory,
                    "cache.external-directory"
                )
            }

            Step("document creates manifest and exact metadata reuses cached section") {
                let fixture = try ConcatenationCacheFixture(
                    "reuse"
                )

                defer {
                    fixture.remove()
                }

                try fixture.writeSource(
                    """
                    alpha
                    beta
                    """
                )

                let concatenator = fixture.concatenator()

                let firstDocument = try concatenator.document()

                let firstManifest = try Expect.notNil(
                    try fixture.store.load(
                        for: fixture.output
                    ),
                    "cache.initial-manifest"
                )

                try Expect.equal(
                    firstManifest.sources.count,
                    1,
                    "cache.initial-source-count"
                )

                try Expect.equal(
                    firstManifest.sources[0].file,
                    fixture.source.standardizedFileURL,
                    "cache.initial-source"
                )

                try Expect.true(
                    firstManifest.artifact == nil,
                    "cache.document-has-no-artifact"
                )

                let cached = firstManifest.sources[0]
                let section = firstDocument.sections[0]

                let sidecar = try Expect.notNil(
                    try fixture.store.loadSection(
                        for: fixture.output,
                        key: cached.sectionKey
                    ),
                    "cache.section-sidecar-roundtrip"
                )

                try Expect.equal(
                    sidecar.presentedPath,
                    section.presentedPath,
                    "cache.section-sidecar-presented-path"
                )

                try Expect.equal(
                    sidecar.selectedLineCount,
                    section.selectedLineCount,
                    "cache.section-sidecar-selected-lines"
                )

                let secondDocument = try concatenator.document()

                try Expect.equal(
                    firstDocument.sections.count,
                    secondDocument.sections.count,
                    "cache.reuse-section-count"
                )

                try Expect.equal(
                    secondDocument.sections[0].presentedPath,
                    section.presentedPath,
                    "cache.exact-metadata-reuses-sidecar"
                )

                try Expect.equal(
                    secondDocument.statistics.cache.metadataInspections,
                    1,
                    "cache.exact-metadata-inspection-count"
                )

                try Expect.equal(
                    secondDocument.statistics.cache.sourceReads,
                    0,
                    "cache.exact-metadata-zero-source-reads"
                )

                try Expect.equal(
                    secondDocument.statistics.cache.metadataHits,
                    1,
                    "cache.exact-metadata-hit-count"
                )

                try Expect.equal(
                    secondDocument.statistics.cache.rebuilds,
                    0,
                    "cache.exact-metadata-zero-rebuilds"
                )

                try FileSystem.default.remove(
                    fixture.workspace.cachedSection(
                        for: fixture.output,
                        key: cached.sectionKey
                    )
                )

                let repairedDocument = try concatenator.document()

                try Expect.equal(
                    repairedDocument.statistics.cache.metadataHits,
                    0,
                    "cache.missing-sidecar-zero-metadata-hits"
                )

                try Expect.equal(
                    repairedDocument.statistics.cache.sourceReads,
                    1,
                    "cache.missing-sidecar-source-read"
                )

                try Expect.equal(
                    repairedDocument.statistics.cache.rebuilds,
                    1,
                    "cache.missing-sidecar-rebuild"
                )

                _ = try Expect.notNil(
                    try fixture.store.loadSection(
                        for: fixture.output,
                        key: cached.sectionKey
                    ),
                    "cache.missing-sidecar-repaired"
                )

                try FileSystem.default.remove(
                    fixture.workspace.cachedSection(
                        for: fixture.output,
                        key: cached.sectionKey
                    )
                )

                let asyncRepairedDocument = try await concatenator.document(
                    concurrency: .limited(
                        4
                    )
                )

                try Expect.equal(
                    asyncRepairedDocument.statistics.cache.metadataHits,
                    0,
                    "cache.async-missing-sidecar-zero-metadata-hits"
                )

                try Expect.equal(
                    asyncRepairedDocument.statistics.cache.sourceReads,
                    1,
                    "cache.async-missing-sidecar-source-read"
                )

                try Expect.equal(
                    asyncRepairedDocument.statistics.cache.rebuilds,
                    1,
                    "cache.async-missing-sidecar-rebuild"
                )

                _ = try Expect.notNil(
                    try fixture.store.loadSection(
                        for: fixture.output,
                        key: cached.sectionKey
                    ),
                    "cache.async-missing-sidecar-repaired"
                )
            }

            Step("manifest save prunes stale section sidecars") {
                let fixture = try ConcatenationCacheFixture(
                    "section-sidecar-pruning"
                )

                defer {
                    fixture.remove()
                }

                try fixture.writeSource(
                    """
                    alpha
                    beta
                    gamma
                    """
                )

                let concatenator = fixture.concatenator()

                _ = try concatenator.document()

                let firstManifest = try Expect.notNil(
                    try fixture.store.load(
                        for: fixture.output
                    ),
                    "cache.sidecar-prune-first-manifest"
                )

                let firstKey = firstManifest.sources[0].sectionKey
                let firstSidecar = fixture.workspace.cachedSection(
                    for: fixture.output,
                    key: firstKey
                )

                try Expect.true(
                    FileSystem.default.exists(
                        firstSidecar
                    ),
                    "cache.sidecar-prune-first-exists"
                )

                try fixture.writeSource(
                    """
                    alpha
                    beta
                    gamma
                    delta
                    """
                )

                _ = try concatenator.document()

                let secondManifest = try Expect.notNil(
                    try fixture.store.load(
                        for: fixture.output
                    ),
                    "cache.sidecar-prune-second-manifest"
                )

                let secondKey = secondManifest.sources[0].sectionKey
                let secondSidecar = fixture.workspace.cachedSection(
                    for: fixture.output,
                    key: secondKey
                )

                try Expect.true(
                    firstKey != secondKey,
                    "cache.sidecar-prune-key-changed"
                )

                try Expect.true(
                    !FileSystem.default.exists(
                        firstSidecar
                    ),
                    "cache.sidecar-prune-old-removed"
                )

                try Expect.true(
                    FileSystem.default.exists(
                        secondSidecar
                    ),
                    "cache.sidecar-prune-current-kept"
                )
            }

            Step("write records stable artifact material state") {
                let fixture = try ConcatenationCacheFixture(
                    "artifact-state"
                )

                defer {
                    fixture.remove()
                }

                try fixture.writeSource(
                    """
                    alpha
                    beta
                    """
                )

                let concatenator = fixture.concatenator()

                let firstWrite = try concatenator.write()

                let firstManifest = try Expect.notNil(
                    try fixture.store.load(
                        for: fixture.output
                    ),
                    "cache.artifact-first-manifest"
                )

                let firstArtifact = try Expect.notNil(
                    firstManifest.artifact,
                    "cache.artifact-first-state"
                )

                let firstMetadata = try FileInspector(
                    fixture.output
                ).inspect()

                try Expect.true(
                    firstMetadata.existed,
                    "cache.artifact-output-exists"
                )

                try Expect.equal(
                    firstArtifact.metadata,
                    firstMetadata,
                    "cache.artifact-metadata"
                )

                try Expect.equal(
                    firstArtifact.file,
                    fixture.output.standardizedFileURL,
                    "cache.artifact-output-file"
                )

                let firstText = try Expect.notNil(
                    firstWrite.text,
                    "cache.artifact-first-rendered-text"
                )

                try Expect.equal(
                    firstArtifact.contentFingerprint,
                    ContentFingerprint.fingerprint(
                        for: Data(
                            firstText.utf8
                        )
                    ),
                    "cache.artifact-content-fingerprint"
                )

                try Expect.true(
                    firstWrite.performedRender,
                    "cache.artifact-first-rendered"
                )

                try Expect.true(
                    firstWrite.performedWrite,
                    "cache.artifact-first-written"
                )

                let secondWrite = try concatenator.write()

                let secondManifest = try Expect.notNil(
                    try fixture.store.load(
                        for: fixture.output
                    ),
                    "cache.artifact-second-manifest"
                )

                let secondArtifact = try Expect.notNil(
                    secondManifest.artifact,
                    "cache.artifact-second-state"
                )

                try Expect.equal(
                    firstArtifact.materialFingerprint,
                    secondArtifact.materialFingerprint,
                    "cache.artifact-material-stable"
                )

                try Expect.equal(
                    firstArtifact.contentFingerprint,
                    secondArtifact.contentFingerprint,
                    "cache.artifact-content-stable"
                )

                try Expect.equal(
                    firstArtifact.metadata,
                    secondArtifact.metadata,
                    "cache.artifact-metadata-preserved"
                )

                try Expect.true(
                    !secondWrite.performedRender,
                    "cache.artifact-second-skips-render"
                )

                try Expect.true(
                    !secondWrite.performedWrite,
                    "cache.artifact-second-skips-write"
                )

                try Expect.true(
                    secondWrite.text == nil,
                    "cache.artifact-second-has-no-new-text"
                )

                try Expect.equal(
                    secondWrite.documentStatistics.cache.sourceReads,
                    0,
                    "cache.artifact-second-write-zero-source-reads"
                )

                try Expect.equal(
                    secondWrite.documentStatistics.cache.metadataHits,
                    1,
                    "cache.artifact-second-write-metadata-hit"
                )
            }

            Step("artifact metadata drift with identical bytes avoids rewrite") {
                let fixture = try ConcatenationCacheFixture(
                    "artifact-metadata-drift"
                )

                defer {
                    fixture.remove()
                }

                try fixture.writeSource(
                    """
                    alpha
                    beta
                    """
                )

                let concatenator = fixture.concatenator()

                _ = try concatenator.write()

                let firstManifest = try Expect.notNil(
                    try fixture.store.load(
                        for: fixture.output
                    ),
                    "cache.artifact-drift-first-manifest"
                )

                let firstArtifact = try Expect.notNil(
                    firstManifest.artifact,
                    "cache.artifact-drift-first-state"
                )

                try fixture.setOutputModifiedAt(
                    Date(
                        timeIntervalSince1970: 1_600_000_100
                    )
                )

                let secondWrite = try concatenator.write()

                let secondManifest = try Expect.notNil(
                    try fixture.store.load(
                        for: fixture.output
                    ),
                    "cache.artifact-drift-second-manifest"
                )

                let secondArtifact = try Expect.notNil(
                    secondManifest.artifact,
                    "cache.artifact-drift-second-state"
                )

                try Expect.true(
                    firstArtifact.metadata != secondArtifact.metadata,
                    "cache.artifact-drift-metadata-refreshed"
                )

                try Expect.equal(
                    firstArtifact.contentFingerprint,
                    secondArtifact.contentFingerprint,
                    "cache.artifact-drift-content-stable"
                )

                try Expect.true(
                    !secondWrite.performedRender,
                    "cache.artifact-drift-skips-render"
                )

                try Expect.true(
                    !secondWrite.performedWrite,
                    "cache.artifact-drift-skips-write"
                )
            }

            Step("missing artifact is regenerated") {
                let fixture = try ConcatenationCacheFixture(
                    "artifact-missing"
                )

                defer {
                    fixture.remove()
                }

                try fixture.writeSource(
                    """
                    alpha
                    beta
                    """
                )

                let concatenator = fixture.concatenator()

                _ = try concatenator.write()

                try FileSystem.default.remove(
                    fixture.output
                )

                let repaired = try concatenator.write()

                try Expect.true(
                    repaired.performedRender,
                    "cache.artifact-missing-rerenders"
                )

                try Expect.true(
                    repaired.performedWrite,
                    "cache.artifact-missing-rewrites"
                )

                let repairedMetadata = try FileInspector(
                    fixture.output
                ).inspect()

                try Expect.true(
                    repairedMetadata.existed,
                    "cache.artifact-missing-restored"
                )

                let stable = try concatenator.write()

                try Expect.true(
                    !stable.performedRender,
                    "cache.artifact-restored-next-run-skips-render"
                )

                try Expect.true(
                    !stable.performedWrite,
                    "cache.artifact-restored-next-run-skips-write"
                )
            }

            Step("externally modified artifact is repaired") {
                let fixture = try ConcatenationCacheFixture(
                    "artifact-modified"
                )

                defer {
                    fixture.remove()
                }

                try fixture.writeSource(
                    """
                    alpha
                    beta
                    """
                )

                let concatenator = fixture.concatenator()

                _ = try concatenator.write()

                let externalText = "__externally_modified_artifact__"

                _ = try StandardWriter(
                    fixture.output
                ).write(
                    externalText,
                    options: .overwriteWithoutBackup
                )

                let repaired = try concatenator.write()

                try Expect.true(
                    repaired.performedRender,
                    "cache.artifact-modified-rerenders"
                )

                try Expect.true(
                    repaired.performedWrite,
                    "cache.artifact-modified-rewrites"
                )

                let repairedData = try DataFileReader(
                    fixture.output
                ).read(
                    options: .init(
                        missingFilePolicy: .throwError,
                        cachePolicy: .system
                    )
                ).data

                try Expect.true(
                    repairedData != Data(
                        externalText.utf8
                    ),
                    "cache.artifact-modified-content-repaired"
                )

                let manifest = try Expect.notNil(
                    try fixture.store.load(
                        for: fixture.output
                    ),
                    "cache.artifact-modified-manifest"
                )

                let artifact = try Expect.notNil(
                    manifest.artifact,
                    "cache.artifact-modified-state"
                )

                try Expect.equal(
                    artifact.contentFingerprint,
                    ContentFingerprint.fingerprint(
                        for: repairedData
                    ),
                    "cache.artifact-modified-fingerprint-repaired"
                )

                let stable = try concatenator.write()

                try Expect.true(
                    !stable.performedRender,
                    "cache.artifact-modified-next-run-skips-render"
                )

                try Expect.true(
                    !stable.performedWrite,
                    "cache.artifact-modified-next-run-skips-write"
                )
            }

            Step("multi-file change invalidates only changed source") {
                let fixture = try ConcatenationMultiCacheFixture(
                    "selective"
                )

                defer {
                    fixture.remove()
                }

                let a = fixture.source(
                    "a.txt"
                )

                let b = fixture.source(
                    "b.txt"
                )

                let c = fixture.source(
                    "c.txt"
                )

                try fixture.write(
                    "alpha",
                    to: a
                )

                try fixture.write(
                    "beta",
                    to: b
                )

                try fixture.write(
                    "gamma",
                    to: c
                )

                let sources = [
                    a,
                    b,
                    c,
                ]

                let concatenator = fixture.concatenator(
                    sources
                )

                _ = try concatenator.write()

                let firstManifest = try Expect.notNil(
                    try fixture.store.load(
                        for: fixture.output
                    ),
                    "cache.multi-selective-first-manifest"
                )

                let firstFingerprints = Dictionary(
                    uniqueKeysWithValues:
                        firstManifest.sources.map {
                            (
                                $0.file.lastPathComponent,
                                $0.contentFingerprint
                            )
                        }
                )

                try fixture.write(
                    """
                    beta
                    changed
                    """,
                    to: b
                )

                let changed = try concatenator.write()

                try Expect.equal(
                    changed.documentStatistics.cache
                        .metadataInspections,
                    3,
                    "cache.multi-selective-inspections"
                )

                try Expect.equal(
                    changed.documentStatistics.cache
                        .metadataHits,
                    2,
                    "cache.multi-selective-metadata-hits"
                )

                try Expect.equal(
                    changed.documentStatistics.cache
                        .sourceReads,
                    1,
                    "cache.multi-selective-source-reads"
                )

                try Expect.equal(
                    changed.documentStatistics.cache
                        .rebuilds,
                    1,
                    "cache.multi-selective-rebuilds"
                )

                try Expect.true(
                    changed.performedRender,
                    "cache.multi-selective-rerenders"
                )

                try Expect.true(
                    changed.performedWrite,
                    "cache.multi-selective-rewrites"
                )

                let secondManifest = try Expect.notNil(
                    try fixture.store.load(
                        for: fixture.output
                    ),
                    "cache.multi-selective-second-manifest"
                )

                let secondFingerprints = Dictionary(
                    uniqueKeysWithValues:
                        secondManifest.sources.map {
                            (
                                $0.file.lastPathComponent,
                                $0.contentFingerprint
                            )
                        }
                )

                try Expect.equal(
                    firstFingerprints["a.txt"],
                    secondFingerprints["a.txt"],
                    "cache.multi-selective-a-unchanged"
                )

                try Expect.true(
                    firstFingerprints["b.txt"]
                        != secondFingerprints["b.txt"],
                    "cache.multi-selective-b-changed"
                )

                try Expect.equal(
                    firstFingerprints["c.txt"],
                    secondFingerprints["c.txt"],
                    "cache.multi-selective-c-unchanged"
                )

                let stable = try concatenator.write()

                try Expect.equal(
                    stable.documentStatistics.cache
                        .sourceReads,
                    0,
                    "cache.multi-selective-stable-zero-reads"
                )

                try Expect.equal(
                    stable.documentStatistics.cache
                        .metadataHits,
                    3,
                    "cache.multi-selective-stable-hits"
                )

                try Expect.true(
                    !stable.performedRender,
                    "cache.multi-selective-stable-no-render"
                )

                try Expect.true(
                    !stable.performedWrite,
                    "cache.multi-selective-stable-no-write"
                )
            }

            Step("source additions and removals preserve reusable sections") {
                let fixture = try ConcatenationMultiCacheFixture(
                    "source-set"
                )

                defer {
                    fixture.remove()
                }

                let a = fixture.source(
                    "a.txt"
                )

                let b = fixture.source(
                    "b.txt"
                )

                let c = fixture.source(
                    "c.txt"
                )

                try fixture.write(
                    "alpha",
                    to: a
                )

                try fixture.write(
                    "beta",
                    to: b
                )

                try fixture.write(
                    "gamma",
                    to: c
                )

                _ = try fixture.concatenator(
                    [
                        a,
                        b,
                    ]
                ).write()

                let added = try fixture.concatenator(
                    [
                        a,
                        b,
                        c,
                    ]
                ).write()

                try Expect.equal(
                    added.documentStatistics.cache.metadataHits,
                    2,
                    "cache.source-addition-existing-hits"
                )

                try Expect.equal(
                    added.documentStatistics.cache.sourceReads,
                    1,
                    "cache.source-addition-one-read"
                )

                try Expect.equal(
                    added.documentStatistics.cache.rebuilds,
                    1,
                    "cache.source-addition-one-rebuild"
                )

                try Expect.true(
                    added.performedWrite,
                    "cache.source-addition-rewrites"
                )

                let removed = try fixture.concatenator(
                    [
                        b,
                        c,
                    ]
                ).write()

                try Expect.equal(
                    removed.documentStatistics.cache.metadataHits,
                    2,
                    "cache.source-removal-retained-hits"
                )

                try Expect.equal(
                    removed.documentStatistics.cache.sourceReads,
                    0,
                    "cache.source-removal-zero-reads"
                )

                try Expect.equal(
                    removed.documentStatistics.cache.rebuilds,
                    0,
                    "cache.source-removal-zero-rebuilds"
                )

                try Expect.true(
                    removed.performedRender,
                    "cache.source-removal-rerenders"
                )

                try Expect.true(
                    removed.performedWrite,
                    "cache.source-removal-rewrites"
                )

                let manifest = try Expect.notNil(
                    try fixture.store.load(
                        for: fixture.output
                    ),
                    "cache.source-removal-manifest"
                )

                try Expect.equal(
                    manifest.sources.map {
                        $0.file.lastPathComponent
                    },
                    [
                        "b.txt",
                        "c.txt",
                    ],
                    "cache.source-removal-manifest-pruned"
                )

                let stable = try fixture.concatenator(
                    [
                        b,
                        c,
                    ]
                ).write()

                try Expect.true(
                    !stable.performedRender,
                    "cache.source-removal-stable-no-render"
                )

                try Expect.true(
                    !stable.performedWrite,
                    "cache.source-removal-stable-no-write"
                )
            }

            Step("source reordering reuses sections but changes artifact order") {
                let fixture = try ConcatenationMultiCacheFixture(
                    "reorder"
                )

                defer {
                    fixture.remove()
                }

                let a = fixture.source(
                    "a.txt"
                )

                let b = fixture.source(
                    "b.txt"
                )

                let c = fixture.source(
                    "c.txt"
                )

                try fixture.write(
                    "alpha",
                    to: a
                )

                try fixture.write(
                    "beta",
                    to: b
                )

                try fixture.write(
                    "gamma",
                    to: c
                )

                _ = try fixture.concatenator(
                    [
                        a,
                        b,
                        c,
                    ]
                ).write()

                let reordered = try fixture.concatenator(
                    [
                        c,
                        a,
                        b,
                    ]
                ).write()

                try Expect.equal(
                    reordered.documentStatistics.cache.metadataHits,
                    3,
                    "cache.reorder-all-section-hits"
                )

                try Expect.equal(
                    reordered.documentStatistics.cache.sourceReads,
                    0,
                    "cache.reorder-zero-source-reads"
                )

                try Expect.equal(
                    reordered.documentStatistics.cache.rebuilds,
                    0,
                    "cache.reorder-zero-rebuilds"
                )

                let reorderedDocument = try Expect.notNil(
                    reordered.document,
                    "cache.reorder-materialized-document"
                )

                try Expect.equal(
                    reorderedDocument.sections.map {
                        $0.file.lastPathComponent
                    },
                    [
                        "c.txt",
                        "a.txt",
                        "b.txt",
                    ],
                    "cache.reorder-document-order"
                )

                try Expect.true(
                    reordered.performedRender,
                    "cache.reorder-rerenders"
                )

                try Expect.true(
                    reordered.performedWrite,
                    "cache.reorder-rewrites"
                )

                let stable = try fixture.concatenator(
                    [
                        c,
                        a,
                        b,
                    ]
                ).write()

                try Expect.true(
                    !stable.performedRender,
                    "cache.reorder-stable-no-render"
                )

                try Expect.true(
                    !stable.performedWrite,
                    "cache.reorder-stable-no-write"
                )
            }

            Step("aliases to one physical source keep separate cached sections") {
                let fixture = try ConcatenationMultiCacheFixture(
                    "aliases"
                )

                defer {
                    fixture.remove()
                }

                let physical = fixture.source(
                    "physical.txt"
                )

                let first = fixture.source(
                    "first.txt"
                )

                let second = fixture.source(
                    "second.txt"
                )

                try fixture.write(
                    """
                    alpha
                    beta
                    """,
                    to: physical
                )

                try fixture.symlink(
                    first,
                    to: physical
                )

                try fixture.symlink(
                    second,
                    to: physical
                )

                let presented = [
                    first: "first-presentation.txt",
                    second: "second-presentation.txt",
                ]

                let concatenator = fixture.concatenator(
                    [
                        first,
                        second,
                    ],
                    presentedPathByFile: presented
                )

                let firstDocument = try concatenator.document()

                try Expect.equal(
                    firstDocument.sections.map(
                        \.presentedPath
                    ),
                    [
                        "first-presentation.txt",
                        "second-presentation.txt",
                    ],
                    "cache.aliases-first-presentations"
                )

                let secondDocument = try concatenator.document()

                try Expect.equal(
                    secondDocument.statistics.cache.metadataHits,
                    2,
                    "cache.aliases-both-cache-hits"
                )

                try Expect.equal(
                    secondDocument.statistics.cache.sourceReads,
                    0,
                    "cache.aliases-zero-source-reads"
                )

                try Expect.equal(
                    secondDocument.statistics.cache.rebuilds,
                    0,
                    "cache.aliases-zero-rebuilds"
                )

                try Expect.equal(
                    secondDocument.sections.map(
                        \.presentedPath
                    ),
                    [
                        "first-presentation.txt",
                        "second-presentation.txt",
                    ],
                    "cache.aliases-presentations-preserved"
                )
            }

            Step("deep safeguard aliases share one physical inspection") {
                let fixture = try ConcatenationMultiCacheFixture(
                    "safeguard-aliases"
                )

                defer {
                    fixture.remove()
                }

                let physical = fixture.source(
                    "physical.txt"
                )

                let first = fixture.source(
                    "first.txt"
                )

                let second = fixture.source(
                    "second.txt"
                )

                try fixture.write(
                    """
                    ordinary
                    safe
                    content
                    """,
                    to: physical
                )

                try fixture.symlink(
                    first,
                    to: physical
                )

                try fixture.symlink(
                    second,
                    to: physical
                )

                let concatenator = fixture.concatenator(
                    [
                        first,
                        second,
                    ],
                    protectSecrets: true,
                    deepSecretInspection: true
                )

                let syncCold = try concatenator.document()

                try Expect.equal(
                    syncCold.statistics.cache.safeguardReads,
                    1,
                    "cache.safeguard-alias-sync-cold-one-physical-read"
                )

                try Expect.equal(
                    syncCold.statistics.cache.safeguardHits,
                    0,
                    "cache.safeguard-alias-sync-cold-zero-hits"
                )

                try Expect.equal(
                    syncCold.sections.count,
                    2,
                    "cache.safeguard-alias-sync-cold-two-sections"
                )

                let syncWarm = try concatenator.document()

                try Expect.equal(
                    syncWarm.statistics.cache.safeguardReads,
                    0,
                    "cache.safeguard-alias-sync-warm-zero-reads"
                )

                try Expect.equal(
                    syncWarm.statistics.cache.safeguardHits,
                    2,
                    "cache.safeguard-alias-sync-warm-two-hits"
                )

                try FileSystem.default.remove(
                    fixture.workspace.state
                )

                let asyncCold = try await concatenator.document(
                    concurrency: .limited(4)
                )

                try Expect.equal(
                    asyncCold.statistics.cache.safeguardReads,
                    1,
                    "cache.safeguard-alias-async-cold-one-physical-read"
                )

                try Expect.equal(
                    asyncCold.statistics.cache.safeguardHits,
                    0,
                    "cache.safeguard-alias-async-cold-zero-hits"
                )

                try Expect.equal(
                    asyncCold.sections.count,
                    2,
                    "cache.safeguard-alias-async-cold-two-sections"
                )

                let asyncWarm = try await concatenator.document(
                    concurrency: .limited(4)
                )

                try Expect.equal(
                    asyncWarm.statistics.cache.safeguardReads,
                    0,
                    "cache.safeguard-alias-async-warm-zero-reads"
                )

                try Expect.equal(
                    asyncWarm.statistics.cache.safeguardHits,
                    2,
                    "cache.safeguard-alias-async-warm-two-hits"
                )

                try Expect.equal(
                    asyncWarm.statistics.cache.metadataHits,
                    2,
                    "cache.safeguard-alias-async-warm-two-metadata-hits"
                )
            }

            Step("async bounded inspection preserves source order and cache semantics") {
                let fixture = try ConcatenationMultiCacheFixture(
                    "parallel-inspection"
                )

                defer {
                    fixture.remove()
                }

                let sources = try (0..<32).map {
                    index -> URL in

                    let source = fixture.source(
                        String(
                            format: "source-%02d.txt",
                            index
                        )
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

                let cold = try await concatenator.document(
                    concurrency: .limited(
                        4
                    )
                )

                try Expect.equal(
                    cold.sections.map {
                        $0.file.lastPathComponent
                    },
                    sources.map(
                        \.lastPathComponent
                    ),
                    "cache.parallel-inspection-cold-order"
                )

                try Expect.equal(
                    cold.statistics.cache.metadataInspections,
                    sources.count,
                    "cache.parallel-inspection-cold-inspections"
                )

                try Expect.equal(
                    cold.statistics.cache.sourceReads,
                    sources.count,
                    "cache.parallel-inspection-cold-source-reads"
                )

                try Expect.equal(
                    cold.statistics.cache.rebuilds,
                    sources.count,
                    "cache.parallel-inspection-cold-rebuilds"
                )

                let warm = try await concatenator.document(
                    concurrency: .automatic
                )

                try Expect.equal(
                    warm.sections.map {
                        $0.file.lastPathComponent
                    },
                    sources.map(
                        \.lastPathComponent
                    ),
                    "cache.parallel-inspection-warm-order"
                )

                try Expect.equal(
                    warm.statistics.cache.metadataInspections,
                    sources.count,
                    "cache.parallel-inspection-warm-inspections"
                )

                try Expect.equal(
                    warm.statistics.cache.metadataHits,
                    sources.count,
                    "cache.parallel-inspection-warm-hits"
                )

                try Expect.equal(
                    warm.statistics.cache.sourceReads,
                    0,
                    "cache.parallel-inspection-warm-zero-reads"
                )

                try Expect.equal(
                    warm.statistics.cache.rebuilds,
                    0,
                    "cache.parallel-inspection-warm-zero-rebuilds"
                )
            }

            Step("async write uses bounded inspection and preserves no-op") {
                let fixture = try ConcatenationMultiCacheFixture(
                    "async-write"
                )

                defer {
                    fixture.remove()
                }

                let sources = try (0..<24).map {
                    index -> URL in

                    let source = fixture.source(
                        String(
                            format: "source-%02d.txt",
                            index
                        )
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

                let cold = try await concatenator.write(
                    concurrency: .limited(
                        4
                    )
                )

                try Expect.true(
                    cold.performedRender,
                    "cache.async-write-cold-render"
                )

                try Expect.true(
                    cold.performedWrite,
                    "cache.async-write-cold-write"
                )

                try Expect.equal(
                    cold.documentStatistics.cache
                        .metadataInspections,
                    sources.count,
                    "cache.async-write-cold-inspections"
                )

                try Expect.equal(
                    cold.documentStatistics.cache
                        .sourceReads,
                    sources.count,
                    "cache.async-write-cold-source-reads"
                )

                try Expect.equal(
                    cold.documentStatistics.cache
                        .rebuilds,
                    sources.count,
                    "cache.async-write-cold-rebuilds"
                )

                let warm = try await concatenator.write(
                    concurrency: .automatic
                )

                try Expect.true(
                    warm.document == nil,
                    "cache.async-write-warm-skips-materialization"
                )

                try Expect.equal(
                    warm.documentStatistics.renderedSectionCount,
                    sources.count,
                    "cache.async-write-warm-section-count"
                )

                try Expect.equal(
                    warm.documentStatistics.cache
                        .metadataHits,
                    sources.count,
                    "cache.async-write-warm-metadata-hits"
                )

                try Expect.equal(
                    warm.documentStatistics.cache
                        .sourceReads,
                    0,
                    "cache.async-write-warm-zero-source-reads"
                )

                try Expect.equal(
                    warm.documentStatistics.cache
                        .rebuilds,
                    0,
                    "cache.async-write-warm-zero-rebuilds"
                )

                try Expect.true(
                    !warm.performedRender,
                    "cache.async-write-warm-no-render"
                )

                try Expect.true(
                    !warm.performedWrite,
                    "cache.async-write-warm-no-write"
                )
            }

            Step("async deep safeguards preserve cache semantics") {
                let fixture = try ConcatenationMultiCacheFixture(
                    "parallel-safeguards"
                )

                defer {
                    fixture.remove()
                }

                let sources = try (0..<24).map {
                    index -> URL in

                    let source = fixture.source(
                        String(
                            format: "safe-%02d.txt",
                            index
                        )
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

                let concatenator = FileConcatenator(
                    inputFiles: sources,
                    outputURL: fixture.output,
                    workspace: fixture.workspace,
                    trimBlankLines: true,
                    includeSourceModifiedAt: false,
                    protectSecrets: true,
                    allowSecrets: false,
                    deepSecretInspection: true
                )

                let cold = try await concatenator.document(
                    concurrency: .limited(
                        4
                    )
                )

                try Expect.equal(
                    cold.statistics.cache.safeguardReads,
                    sources.count,
                    "cache.parallel-safeguards-cold-reads"
                )

                try Expect.equal(
                    cold.statistics.cache.safeguardHits,
                    0,
                    "cache.parallel-safeguards-cold-hits"
                )

                try Expect.equal(
                    cold.statistics.blockedFileCount,
                    0,
                    "cache.parallel-safeguards-cold-unblocked"
                )

                let warm = try await concatenator.document(
                    concurrency: .automatic
                )

                try Expect.equal(
                    warm.statistics.cache.safeguardReads,
                    0,
                    "cache.parallel-safeguards-warm-zero-reads"
                )

                try Expect.equal(
                    warm.statistics.cache.safeguardHits,
                    sources.count,
                    "cache.parallel-safeguards-warm-hits"
                )

                try Expect.equal(
                    warm.statistics.cache.sourceReads,
                    0,
                    "cache.parallel-safeguards-warm-zero-source-reads"
                )

                try Expect.equal(
                    warm.statistics.cache.rebuilds,
                    0,
                    "cache.parallel-safeguards-warm-zero-rebuilds"
                )
            }

            Step("async changed-source reads are selective and ordered") {
                let fixture = try ConcatenationMultiCacheFixture(
                    "parallel-source-reads"
                )

                defer {
                    fixture.remove()
                }

                let sources = try (0..<32).map {
                    index -> URL in

                    let source = fixture.source(
                        String(
                            format: "source-%02d.txt",
                            index
                        )
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
                    concurrency: .limited(
                        4
                    )
                )

                let changedIndexes = Array(
                    stride(
                        from: 0,
                        to: sources.count,
                        by: 4
                    )
                )

                for index in changedIndexes {
                    try fixture.write(
                        """
                        source \(index)
                        changed
                        alpha
                        beta
                        gamma
                        """,
                        to: sources[index]
                    )
                }

                let changed = try await concatenator.document(
                    concurrency: .limited(
                        4
                    )
                )

                try Expect.equal(
                    changed.sections.map {
                        $0.file.lastPathComponent
                    },
                    sources.map(
                        \.lastPathComponent
                    ),
                    "cache.parallel-reads-order"
                )

                try Expect.equal(
                    changed.statistics.cache.metadataInspections,
                    sources.count,
                    "cache.parallel-reads-inspections"
                )

                try Expect.equal(
                    changed.statistics.cache.metadataHits,
                    sources.count - changedIndexes.count,
                    "cache.parallel-reads-metadata-hits"
                )

                try Expect.equal(
                    changed.statistics.cache.sourceReads,
                    changedIndexes.count,
                    "cache.parallel-reads-source-reads"
                )

                try Expect.equal(
                    changed.statistics.cache.contentHits,
                    0,
                    "cache.parallel-reads-no-content-hits"
                )

                try Expect.equal(
                    changed.statistics.cache.rebuilds,
                    changedIndexes.count,
                    "cache.parallel-reads-rebuilds"
                )

                let stable = try await concatenator.document(
                    concurrency: .automatic
                )

                try Expect.equal(
                    stable.statistics.cache.metadataHits,
                    sources.count,
                    "cache.parallel-reads-stable-hits"
                )

                try Expect.equal(
                    stable.statistics.cache.sourceReads,
                    0,
                    "cache.parallel-reads-stable-zero-reads"
                )

                try Expect.equal(
                    stable.statistics.cache.rebuilds,
                    0,
                    "cache.parallel-reads-stable-zero-rebuilds"
                )
            }

            Step("mtime-only change reuses identical content when timestamp is excluded") {
                let fixture = try ConcatenationCacheFixture(
                    "mtime-content-reuse"
                )

                defer {
                    fixture.remove()
                }

                try fixture.writeSource(
                    """
                    alpha
                    beta
                    """
                )

                let concatenator = fixture.concatenator(
                    includeSourceModifiedAt: false
                )

                _ = try concatenator.document()

                let firstManifest = try Expect.notNil(
                    try fixture.store.load(
                        for: fixture.output
                    ),
                    "cache.mtime-first-manifest"
                )

                try fixture.setSourceModifiedAt(
                    Date(
                        timeIntervalSince1970: 1_600_000_000
                    )
                )

                let secondDocument = try concatenator.document()

                let secondManifest = try Expect.notNil(
                    try fixture.store.load(
                        for: fixture.output
                    ),
                    "cache.mtime-second-manifest"
                )

                try Expect.equal(
                    firstManifest.sources[0].contentFingerprint,
                    secondManifest.sources[0].contentFingerprint,
                    "cache.mtime-content-unchanged"
                )

                try Expect.equal(
                    secondDocument.statistics.cache.sourceReads,
                    1,
                    "cache.mtime-one-source-read"
                )

                try Expect.equal(
                    secondDocument.statistics.cache.contentHits,
                    1,
                    "cache.mtime-content-hit"
                )

                try Expect.equal(
                    secondDocument.statistics.cache.rebuilds,
                    0,
                    "cache.mtime-zero-rebuilds"
                )
            }

            Step("mtime-only change rebuilds when timestamp is included") {
                let fixture = try ConcatenationCacheFixture(
                    "mtime-material-change"
                )

                defer {
                    fixture.remove()
                }

                try fixture.writeSource(
                    """
                    alpha
                    beta
                    """
                )

                let concatenator = fixture.concatenator(
                    includeSourceModifiedAt: true
                )

                let firstDocument = try concatenator.document()

                try fixture.setSourceModifiedAt(
                    Date(
                        timeIntervalSince1970: 1_600_000_000
                    )
                )

                let secondDocument = try concatenator.document()

                try Expect.equal(
                    secondDocument.statistics.cache.sourceReads,
                    1,
                    "cache.mtime-stamped-one-source-read"
                )

                try Expect.equal(
                    secondDocument.statistics.cache.contentHits,
                    0,
                    "cache.mtime-stamped-no-content-hit"
                )

                try Expect.equal(
                    secondDocument.statistics.cache.rebuilds,
                    1,
                    "cache.mtime-stamped-rebuild"
                )

                try Expect.true(
                    firstDocument.sections[0].modifiedAt
                        != secondDocument.sections[0].modifiedAt,
                    "cache.mtime-stamped-section-changed"
                )
            }

            Step("deep safeguard verdict is reused for exact metadata") {
                let fixture = try ConcatenationCacheFixture(
                    "deep-safeguard"
                )

                defer {
                    fixture.remove()
                }

                try fixture.writeSource(
                    """
                    alpha
                    beta
                    """
                )

                let concatenator = fixture.concatenator(
                    protectSecrets: true,
                    deepSecretInspection: true
                )

                let firstDocument = try concatenator.document()

                try Expect.equal(
                    firstDocument.sections.count,
                    1,
                    "cache.safeguard-first-section"
                )

                let firstManifest = try Expect.notNil(
                    try fixture.store.load(
                        for: fixture.output
                    ),
                    "cache.safeguard-first-manifest"
                )

                try Expect.equal(
                    firstManifest.safeguards.count,
                    1,
                    "cache.safeguard-count"
                )

                let cachedSafeguard = firstManifest.safeguards[0]

                try Expect.true(
                    !cachedSafeguard.matched,
                    "cache.safeguard-first-safe"
                )

                let sentinelReason =
                    "__cached_deep_safeguard_reused__"

                try fixture.store.save(
                    .init(
                        output: firstManifest.output,
                        sources: firstManifest.sources,
                        safeguards: [
                            ConcatenationCachedSafeguard(
                                metadata: cachedSafeguard.metadata,
                                policyFingerprint:
                                    cachedSafeguard.policyFingerprint,
                                matched: true,
                                reason: sentinelReason
                            ),
                        ],
                        artifact: firstManifest.artifact
                    )
                )

                let secondDocument = try concatenator.document()

                try Expect.equal(
                    secondDocument.sections.count,
                    0,
                    "cache.safeguard-reused-before-source-read"
                )

                try Expect.equal(
                    secondDocument.statistics.blockedFileCount,
                    1,
                    "cache.safeguard-reused-block-count"
                )

                let warning = try Expect.notNil(
                    secondDocument.warnings.first,
                    "cache.safeguard-reused-warning"
                )

                try Expect.equal(
                    warning.message,
                    sentinelReason,
                    "cache.safeguard-reused-reason"
                )

                try Expect.equal(
                    secondDocument.statistics.cache.safeguardReads,
                    0,
                    "cache.safeguard-zero-reads"
                )

                try Expect.equal(
                    secondDocument.statistics.cache.safeguardHits,
                    1,
                    "cache.safeguard-hit-count"
                )

                try Expect.equal(
                    secondDocument.statistics.cache.sourceReads,
                    0,
                    "cache.safeguard-zero-source-reads"
                )
            }

            Step("changed source bytes invalidate cached section") {
                let fixture = try ConcatenationCacheFixture(
                    "content-change"
                )

                defer {
                    fixture.remove()
                }

                try fixture.writeSource(
                    """
                    alpha
                    beta
                    """
                )

                let concatenator = fixture.concatenator()

                let firstDocument = try concatenator.document()

                let firstManifest = try Expect.notNil(
                    try fixture.store.load(
                        for: fixture.output
                    ),
                    "cache.content-first-manifest"
                )

                try fixture.writeSource(
                    """
                    alpha
                    beta
                    gamma
                    """
                )

                let secondDocument = try concatenator.document()

                let secondManifest = try Expect.notNil(
                    try fixture.store.load(
                        for: fixture.output
                    ),
                    "cache.content-second-manifest"
                )

                try Expect.true(
                    firstManifest.sources[0].contentFingerprint
                        != secondManifest.sources[0].contentFingerprint,
                    "cache.content-fingerprint-changed"
                )

                try Expect.true(
                    firstDocument.sections[0].totalLineCount
                        != secondDocument.sections[0].totalLineCount,
                    "cache.changed-content-rebuilt-section"
                )
            }

            Step("section transformation change invalidates cached section") {
                let fixture = try ConcatenationCacheFixture(
                    "transformation-change"
                )

                defer {
                    fixture.remove()
                }

                try fixture.writeSource(
                    "\nalpha\n\n"
                )

                let trimmed = fixture.concatenator(
                    trimBlankLines: true
                )

                let firstDocument = try trimmed.document()

                let firstManifest = try Expect.notNil(
                    try fixture.store.load(
                        for: fixture.output
                    ),
                    "cache.transform-first-manifest"
                )

                let untrimmed = fixture.concatenator(
                    trimBlankLines: false
                )

                let secondDocument = try untrimmed.document()

                let secondManifest = try Expect.notNil(
                    try fixture.store.load(
                        for: fixture.output
                    ),
                    "cache.transform-second-manifest"
                )

                try Expect.equal(
                    firstManifest.sources[0].contentFingerprint,
                    secondManifest.sources[0].contentFingerprint,
                    "cache.transform-source-bytes-unchanged"
                )

                try Expect.true(
                    firstManifest.sources[0].transformationFingerprint
                        != secondManifest.sources[0].transformationFingerprint,
                    "cache.transformation-fingerprint-changed"
                )

                try Expect.true(
                    firstDocument.sections[0].blankLineHeader
                        != secondDocument.sections[0].blankLineHeader,
                    "cache.transformation-rebuilt-section"
                )
            }

            Step("corrupt manifest degrades to miss and is replaced") {
                let fixture = try ConcatenationCacheFixture(
                    "corrupt"
                )

                defer {
                    fixture.remove()
                }

                try fixture.writeSource(
                    """
                    alpha
                    beta
                    """
                )

                let concatenator = fixture.concatenator()

                _ = try concatenator.document()

                let manifestURL = fixture.workspace.cacheManifest(
                    for: fixture.output
                )

                _ = try StandardWriter(
                    manifestURL
                ).write(
                    "{ definitely-not-valid-json",
                    options: .overwriteWithoutBackup
                )

                let corruptLoad = try fixture.store.load(
                    for: fixture.output
                )

                try Expect.true(
                    corruptLoad == nil,
                    "cache.corrupt-manifest-is-miss"
                )

                _ = try concatenator.document()

                let recovered = try fixture.store.load(
                    for: fixture.output
                )

                try Expect.true(
                    recovered != nil,
                    "cache.corrupt-manifest-replaced"
                )
            }
        }
    }
}

private struct ConcatenationMultiCacheFixture {
    let root: URL
    let output: URL

    let workspace: ConcatenationWorkspace
    let store: ConcatenationCacheStore

    init(
        _ name: String
    ) throws {
        let root = URL(
            fileURLWithPath: NSTemporaryDirectory(),
            isDirectory: true
        )
        .appendingPathComponent(
            "concatenation-cache-multi-\(name)-\(UUID().uuidString)",
            isDirectory: true
        )

        let workspace = ConcatenationWorkspace(
            root: root
        )

        self.root = root
        self.output = root.appendingPathComponent(
            "output.txt",
            isDirectory: false
        )
        self.workspace = workspace
        self.store = ConcatenationCacheStore(
            workspace: workspace
        )

        try FileSystem.default.directory.create(
            root
        )
    }

    func source(
        _ name: String
    ) -> URL {
        root.appendingPathComponent(
            name,
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

    func symlink(
        _ link: URL,
        to destination: URL
    ) throws {
        try FileManager.default.createSymbolicLink(
            at: link,
            withDestinationURL: destination
        )
    }

    func concatenator(
        _ sources: [URL],
        presentedPathByFile: [URL: String] = [:],
        protectSecrets: Bool = false,
        deepSecretInspection: Bool = false
    ) -> FileConcatenator {
        FileConcatenator(
            inputFiles: sources,
            outputURL: output,
            workspace: workspace,
            presentedPathByFile: presentedPathByFile,
            trimBlankLines: true,
            includeSourceModifiedAt: false,
            protectSecrets: protectSecrets,
            deepSecretInspection: deepSecretInspection
        )
    }

    func remove() {
        try? FileSystem.default.remove(
            root
        )
    }
}

private struct ConcatenationCacheFixture {
    let root: URL
    let source: URL
    let output: URL

    let workspace: ConcatenationWorkspace
    let store: ConcatenationCacheStore

    init(
        _ name: String
    ) throws {
        let root = URL(
            fileURLWithPath: NSTemporaryDirectory(),
            isDirectory: true
        )
        .appendingPathComponent(
            "concatenation-cache-\(name)-\(UUID().uuidString)",
            isDirectory: true
        )

        let workspace = ConcatenationWorkspace(
            root: root
        )

        self.root = root
        self.source = root.appendingPathComponent(
            "source.txt",
            isDirectory: false
        )
        self.output = root.appendingPathComponent(
            "output.txt",
            isDirectory: false
        )
        self.workspace = workspace
        self.store = ConcatenationCacheStore(
            workspace: workspace
        )

        try FileSystem.default.directory.create(
            root
        )
    }

    func writeSource(
        _ text: String
    ) throws {
        _ = try StandardWriter(
            source
        ).write(
            text,
            options: .overwriteWithoutBackup
        )
    }

    func setOutputModifiedAt(
        _ date: Date
    ) throws {
        try FileManager.default.setAttributes(
            [
                .modificationDate: date,
            ],
            ofItemAtPath: output.path
        )
    }

    func setSourceModifiedAt(
        _ date: Date
    ) throws {
        try FileManager.default.setAttributes(
            [
                .modificationDate: date,
            ],
            ofItemAtPath: source.path
        )
    }

    func concatenator(
        trimBlankLines: Bool = true,
        includeSourceModifiedAt: Bool = false,
        protectSecrets: Bool = false,
        deepSecretInspection: Bool = false
    ) -> FileConcatenator {
        FileConcatenator(
            inputFiles: [
                source,
            ],
            outputURL: output,
            workspace: workspace,
            trimBlankLines: trimBlankLines,
            includeSourceModifiedAt: includeSourceModifiedAt,
            protectSecrets: protectSecrets,
            deepSecretInspection: deepSecretInspection
        )
    }

    func remove() {
        try? FileSystem.default.remove(
            root
        )
    }
}
