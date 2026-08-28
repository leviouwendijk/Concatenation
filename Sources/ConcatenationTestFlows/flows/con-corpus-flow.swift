import Concatenation
import Foundation
import TestFlows

extension ConcatenationFlowSuite {
    static var conCorpusFlow: TestFlow {
        TestFlow(
            "con-corpus",
            tags: [
                "cache",
                "corpus",
                "delta",
                "incremental",
            ]
        ) {
            Step(
                "corpus establishes one retained location"
            ) {
                let fixture = try corpusFixture(
                    "initial"
                )

                defer {
                    try? FileManager.default.removeItem(
                        at: fixture.root
                    )
                }

                let first = try fixture.corpus.refresh()

                try Expect.true(
                    first.isInitial,
                    "first corpus refresh is initial"
                )
                try Expect.equal(
                    first.snapshot.count,
                    2,
                    "initial corpus snapshot source count"
                )

                let materialized = try Expect.notNil(
                    fixture.corpus.materialize(),
                    "initial corpus materialization"
                )

                try Expect.equal(
                    materialized.count,
                    2,
                    "initial corpus materializes retained sections"
                )
                try Expect.equal(
                    materialized.sources.map {
                        $0.section.file.lastPathComponent
                    },
                    [
                        "A.swift",
                        "B.swift",
                    ],
                    "corpus materialization preserves canonical source order"
                )
            }

            Step(
                "warm corpus refresh reuses retained sections"
            ) {
                let fixture = try corpusFixture(
                    "warm"
                )

                defer {
                    try? FileManager.default.removeItem(
                        at: fixture.root
                    )
                }

                _ = try fixture.corpus.refresh()
                let warm = try fixture.corpus.refresh()
                let delta = try Expect.notNil(
                    warm.delta,
                    "warm corpus delta"
                )

                try Expect.true(
                    delta.isEmpty,
                    "warm corpus delta is empty"
                )
                try Expect.equal(
                    delta.unchangedCount,
                    2,
                    "warm corpus keeps both sources unchanged"
                )
                try Expect.equal(
                    warm.document.statistics.cache.sourceReads,
                    0,
                    "warm corpus refresh performs zero source reads"
                )
                try Expect.equal(
                    warm.document.statistics.cache.rebuilds,
                    0,
                    "warm corpus refresh performs zero rebuilds"
                )
            }

            Step(
                "one source change refreshes and materializes selectively"
            ) {
                let fixture = try corpusFixture(
                    "changed"
                )

                defer {
                    try? FileManager.default.removeItem(
                        at: fixture.root
                    )
                }

                _ = try fixture.corpus.refresh()

                try "alpha changed\n".write(
                    to: fixture.a,
                    atomically: true,
                    encoding: .utf8
                )

                let changed = try fixture.corpus.refresh()
                let delta = try Expect.notNil(
                    changed.delta,
                    "changed corpus delta"
                )

                try Expect.equal(
                    delta.changed.map {
                        $0.current.file.lastPathComponent
                    },
                    [
                        "A.swift",
                    ],
                    "corpus delta identifies changed source"
                )
                try Expect.equal(
                    delta.unchangedCount,
                    1,
                    "corpus delta retains unchanged source"
                )
                try Expect.equal(
                    changed.document.statistics.cache.sourceReads,
                    1,
                    "one source change causes one source read"
                )
                try Expect.equal(
                    changed.document.statistics.cache.rebuilds,
                    1,
                    "one source change causes one rebuild"
                )

                let materialized = try fixture.corpus.materialize(
                    delta
                )

                try Expect.equal(
                    materialized.count,
                    1,
                    "delta materialization returns only changed and added sources"
                )
                try Expect.equal(
                    materialized.sources[0]
                        .section.file.lastPathComponent,
                    "A.swift",
                    "delta materialization returns changed source"
                )
                try Expect.true(
                    materialized.sources[0]
                        .section.slices
                        .flatMap(\.lines)
                        .contains("alpha changed"),
                    "delta materialization returns current cached content"
                )
            }

            Step(
                "corpus handles share retained session state"
            ) {
                let fixture = try corpusFixture(
                    "shared"
                )

                defer {
                    try? FileManager.default.removeItem(
                        at: fixture.root
                    )
                }

                let first = try fixture.corpus.refresh()
                let second = ConcatenationCorpus(
                    location: fixture.location,
                    plan: fixture.plan,
                    session: fixture.session
                )
                let shared = try Expect.notNil(
                    second.snapshot(),
                    "second corpus handle observes session state"
                )

                try Expect.equal(
                    shared.fingerprint,
                    first.snapshot.fingerprint,
                    "shared corpus handles resolve one retained location"
                )
            }

            Step(
                "stale delta cannot materialize against newer corpus state"
            ) {
                let fixture = try corpusFixture(
                    "stale"
                )

                defer {
                    try? FileManager.default.removeItem(
                        at: fixture.root
                    )
                }

                _ = try fixture.corpus.refresh()

                try "alpha changed\n".write(
                    to: fixture.a,
                    atomically: true,
                    encoding: .utf8
                )

                let changed = try fixture.corpus.refresh()
                let staleDelta = try Expect.notNil(
                    changed.delta,
                    "stale candidate delta"
                )

                try "beta changed\n".write(
                    to: fixture.b,
                    atomically: true,
                    encoding: .utf8
                )

                _ = try fixture.corpus.refresh()

                var rejected = false

                do {
                    _ = try fixture.corpus.materialize(
                        staleDelta
                    )
                } catch let error as ConcatenationCorpusError {
                    switch error {
                    case .staleDelta:
                        rejected = true
                    default:
                        break
                    }
                }

                try Expect.true(
                    rejected,
                    "stale corpus delta is rejected"
                )
            }
        }
    }

    private struct CorpusFixture {
        let root: URL
        let a: URL
        let b: URL
        let location: URL
        let plan: ConcatenationPlan
        let session: ConcatenationSession
        let corpus: ConcatenationCorpus
    }

    private static func corpusFixture(
        _ name: String
    ) throws -> CorpusFixture {
        let root = URL(
            fileURLWithPath: NSTemporaryDirectory(),
            isDirectory: true
        )
        .appendingPathComponent(
            "concatenation-corpus-\(name)-\(UUID().uuidString)",
            isDirectory: true
        )

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )

        let a = root.appendingPathComponent(
            "A.swift",
            isDirectory: false
        )
        let b = root.appendingPathComponent(
            "B.swift",
            isDirectory: false
        )

        try "alpha\n".write(
            to: a,
            atomically: true,
            encoding: .utf8
        )
        try "beta\n".write(
            to: b,
            atomically: true,
            encoding: .utf8
        )

        let location = root.appendingPathComponent(
            "retained-corpus",
            isDirectory: false
        )
        let plan = ConcatenationPlan(
            context: nil,
            sources: [
                ConcatenationSource(
                    file: a
                ),
                ConcatenationSource(
                    file: b
                ),
            ],
            options: ConcatenationRenderOptions()
        )
        let session = ConcatenationSession()
        let corpus = ConcatenationCorpus(
            location: location,
            plan: plan,
            session: session
        )

        return CorpusFixture(
            root: root,
            a: a,
            b: b,
            location: location,
            plan: plan,
            session: session,
            corpus: corpus
        )
    }
}
