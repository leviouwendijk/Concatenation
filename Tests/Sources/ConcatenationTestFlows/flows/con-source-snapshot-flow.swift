import Concatenation
import Foundation
import IO
import TestFlows

extension ConcatenationFlowSuite {
    static var conSourceSnapshotFlow: TestFlow {
        TestFlow(
            "con-source-snapshot",
            tags: [
                "cache",
                "delta",
                "incremental",
                "snapshot",
            ]
        ) {
            Step(
                "source snapshot is deterministic and cache-only"
            ) {
                let cache = ConcatenationMemoryCache()
                let binding = ConcatenationCacheBinding(
                    storage: cache,
                    scope: URL(
                        fileURLWithPath:
                            "/virtual/concatenation-source-snapshot"
                    )
                )
                let a = cachedSource(
                    "/virtual/A.swift",
                    content: "alpha",
                    transformation: "plain"
                )
                let b = cachedSource(
                    "/virtual/B.swift",
                    content: "beta",
                    transformation: "plain"
                )

                try binding.save(
                    sources: [
                        b,
                        a,
                    ],
                    safeguards: [],
                    artifact: nil
                )

                let first = try Expect.notNil(
                    binding.sourceSnapshot(),
                    "source snapshot exists"
                )

                try Expect.equal(
                    first.sources.map {
                        $0.file.lastPathComponent
                    },
                    [
                        "A.swift",
                        "B.swift",
                    ],
                    "source snapshot canonical order"
                )

                try binding.save(
                    sources: [
                        a,
                        b,
                    ],
                    safeguards: [],
                    artifact: nil
                )

                let second = try Expect.notNil(
                    binding.sourceSnapshot(),
                    "reordered source snapshot exists"
                )

                try Expect.equal(
                    second.fingerprint,
                    first.fingerprint,
                    "source snapshot fingerprint ignores manifest ordering"
                )

                let encoded = try JSONEncoder().encode(
                    first
                )
                let decoded = try JSONDecoder().decode(
                    ConcatenationSourceSnapshot.self,
                    from: encoded
                )

                try Expect.equal(
                    decoded,
                    first,
                    "source snapshot Codable round trip"
                )
            }

            Step(
                "source delta classifies material changes only"
            ) {
                let cache = ConcatenationMemoryCache()
                let binding = ConcatenationCacheBinding(
                    storage: cache,
                    scope: URL(
                        fileURLWithPath:
                            "/virtual/concatenation-source-delta"
                    )
                )
                let firstDate = Date(
                    timeIntervalSince1970: 1
                )
                let secondDate = Date(
                    timeIntervalSince1970: 2
                )

                try binding.save(
                    sources: [
                        cachedSource(
                            "/virtual/A.swift",
                            content: "old",
                            transformation: "plain",
                            modifiedAt: firstDate
                        ),
                        cachedSource(
                            "/virtual/B.swift",
                            content: "stable",
                            transformation: "plain",
                            modifiedAt: firstDate
                        ),
                        cachedSource(
                            "/virtual/C.swift",
                            content: "removed",
                            transformation: "plain",
                            modifiedAt: firstDate
                        ),
                    ],
                    safeguards: [],
                    artifact: nil
                )

                let previous = try Expect.notNil(
                    binding.sourceSnapshot(),
                    "previous source snapshot"
                )

                try binding.save(
                    sources: [
                        cachedSource(
                            "/virtual/A.swift",
                            content: "new",
                            transformation: "plain",
                            modifiedAt: secondDate
                        ),
                        cachedSource(
                            "/virtual/B.swift",
                            content: "stable",
                            transformation: "plain",
                            modifiedAt: secondDate
                        ),
                        cachedSource(
                            "/virtual/D.swift",
                            content: "added",
                            transformation: "plain",
                            modifiedAt: secondDate
                        ),
                    ],
                    safeguards: [],
                    artifact: nil
                )

                let current = try Expect.notNil(
                    binding.sourceSnapshot(),
                    "current source snapshot"
                )
                let delta = try previous.delta(
                    to: current
                )

                try Expect.equal(
                    delta.added.map {
                        $0.file.lastPathComponent
                    },
                    [
                        "D.swift",
                    ],
                    "source delta added"
                )
                try Expect.equal(
                    delta.changed.map {
                        $0.current.file.lastPathComponent
                    },
                    [
                        "A.swift",
                    ],
                    "source delta changed"
                )
                try Expect.equal(
                    delta.removed.map {
                        $0.file.lastPathComponent
                    },
                    [
                        "C.swift",
                    ],
                    "source delta removed"
                )
                try Expect.equal(
                    delta.unchangedCount,
                    1,
                    "metadata-only drift remains unchanged"
                )
                try Expect.equal(
                    delta.baseFingerprint,
                    previous.fingerprint,
                    "source delta base fingerprint"
                )
                try Expect.equal(
                    delta.fingerprint,
                    current.fingerprint,
                    "source delta current fingerprint"
                )
                try Expect.true(
                    previous.fingerprint != current.fingerprint,
                    "material source change advances fingerprint"
                )

                let encoded = try JSONEncoder().encode(
                    delta
                )
                let decoded = try JSONDecoder().decode(
                    ConcatenationSourceDelta.self,
                    from: encoded
                )

                try Expect.equal(
                    decoded,
                    delta,
                    "source delta Codable round trip"
                )
            }

            Step(
                "parallel transformations remain distinct source records"
            ) {
                let snapshot = ConcatenationSourceSnapshot(
                    scope: URL(
                        fileURLWithPath:
                            "/virtual/concatenation-source-transforms"
                    ),
                    sources: [
                        ConcatenationSourceRecord(
                            cachedSource(
                                "/virtual/A.swift",
                                content: "alpha",
                                transformation: "lines"
                            )
                        ),
                        ConcatenationSourceRecord(
                            cachedSource(
                                "/virtual/A.swift",
                                content: "alpha",
                                transformation: "whole"
                            )
                        ),
                    ]
                )

                try Expect.equal(
                    snapshot.count,
                    2,
                    "same file with distinct transformations remains distinct"
                )
                try Expect.equal(
                    snapshot.sources[0].file,
                    snapshot.sources[1].file,
                    "parallel transformations share one source file"
                )
                try Expect.true(
                    snapshot.sources[0].transformationFingerprint
                        != snapshot.sources[1].transformationFingerprint,
                    "parallel transformations remain distinct"
                )
                try Expect.true(
                    snapshot.sources[0].sectionKey
                        != snapshot.sources[1].sectionKey,
                    "transformation participates in cached section identity"
                )
            }

            Step(
                "source delta rejects different cache scopes"
            ) {
                let previous = ConcatenationSourceSnapshot(
                    scope: URL(
                        fileURLWithPath: "/virtual/first"
                    ),
                    sources: []
                )
                let current = ConcatenationSourceSnapshot(
                    scope: URL(
                        fileURLWithPath: "/virtual/second"
                    ),
                    sources: []
                )
                var rejected = false

                do {
                    _ = try previous.delta(
                        to: current
                    )
                } catch let error as ConcatenationSourceDeltaError {
                    switch error {
                    case .differentScopes(
                        let previousScope,
                        let currentScope
                    ):
                        rejected =
                            previousScope == previous.scope
                            && currentScope == current.scope
                    }
                }

                try Expect.true(
                    rejected,
                    "different source snapshot scopes are rejected"
                )
            }
        }
    }

    private static func cachedSource(
        _ path: String,
        content: String,
        transformation: String,
        modifiedAt: Date? = nil
    ) -> ConcatenationCachedSource {
        ConcatenationCachedSource(
            metadata: FileMetadataSnapshot(
                url: URL(
                    fileURLWithPath: path
                ),
                existed: true,
                byteCount: content.utf8.count,
                modifiedAt: modifiedAt,
                identity: nil,
                kind: .file
            ),
            contentFingerprint: .fingerprint(
                for: content
            ),
            transformationFingerprint: .fingerprint(
                for: transformation
            )
        )
    }
}
