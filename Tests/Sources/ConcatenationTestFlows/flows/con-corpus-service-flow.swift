import Concatenation
import Foundation
import TestFlows

extension ConcatenationFlowSuite {
    static var conCorpusServiceFlow: TestFlow {
        TestFlow(
            "con-corpus-service",
            tags: [
                "cache",
                "corpus",
                "service",
                "session",
            ]
        ) {
            Step(
                "service attachment is lazy"
            ) {
                let fixture = try serviceFixture(
                    "lazy"
                )

                defer {
                    try? FileManager.default.removeItem(
                        at: fixture.root
                    )
                }

                let service = ConcatenationCorpusService()
                let attached = try await service.attach(
                    "primary",
                    location: fixture.location,
                    plan: fixture.plan
                )

                try Expect.false(
                    attached.hasSnapshot,
                    "attach does not eagerly create retained source state"
                )
                try Expect.equal(
                    attached.sourceCount,
                    0,
                    "attach performs no corpus refresh"
                )
                try Expect.isNil(
                    try await service.snapshot(
                        "primary"
                    ),
                    "attached corpus has no snapshot before refresh"
                )
            }

            Step(
                "service lists and refreshes named corpora"
            ) {
                let first = try serviceFixture(
                    "list-a"
                )
                let second = try serviceFixture(
                    "list-b"
                )

                defer {
                    try? FileManager.default.removeItem(
                        at: first.root
                    )
                    try? FileManager.default.removeItem(
                        at: second.root
                    )
                }

                let service = ConcatenationCorpusService()

                _ = try await service.attach(
                    "zeta",
                    location: first.location,
                    plan: first.plan
                )
                _ = try await service.attach(
                    "alpha",
                    location: second.location,
                    plan: second.plan
                )

                let before = try await service.list()

                try Expect.equal(
                    before.map(\.identifier.rawValue),
                    [
                        "alpha",
                        "zeta",
                    ],
                    "service listing is identifier ordered"
                )

                let refreshed = try await service.refresh(
                    "zeta"
                )
                let status = try await service.status(
                    "zeta"
                )

                try Expect.equal(
                    status.fingerprint,
                    refreshed.snapshot.fingerprint,
                    "service status exposes retained snapshot fingerprint"
                )
                try Expect.equal(
                    status.sourceCount,
                    2,
                    "service status exposes retained source count"
                )
            }

            Step(
                "service retains warm corpus state"
            ) {
                let fixture = try serviceFixture(
                    "warm"
                )

                defer {
                    try? FileManager.default.removeItem(
                        at: fixture.root
                    )
                }

                let service = ConcatenationCorpusService()

                _ = try await service.attach(
                    "warm",
                    location: fixture.location,
                    plan: fixture.plan
                )
                _ = try await service.refresh(
                    "warm"
                )

                let second = try await service.refresh(
                    "warm"
                )
                let delta = try Expect.notNil(
                    second.delta,
                    "service warm refresh delta"
                )

                try Expect.true(
                    delta.isEmpty,
                    "service warm refresh is unchanged"
                )
                try Expect.equal(
                    second.document.statistics.cache.sourceReads,
                    0,
                    "service warm refresh performs zero source reads"
                )
                try Expect.equal(
                    second.document.statistics.cache.rebuilds,
                    0,
                    "service warm refresh performs zero rebuilds"
                )
            }

            Step(
                "service rejects ambiguous registry identity"
            ) {
                let first = try serviceFixture(
                    "duplicate-a"
                )
                let second = try serviceFixture(
                    "duplicate-b"
                )

                defer {
                    try? FileManager.default.removeItem(
                        at: first.root
                    )
                    try? FileManager.default.removeItem(
                        at: second.root
                    )
                }

                let service = ConcatenationCorpusService()

                _ = try await service.attach(
                    "primary",
                    location: first.location,
                    plan: first.plan
                )

                var duplicateIdentifierRejected = false
                var duplicateLocationRejected = false

                do {
                    _ = try await service.attach(
                        "primary",
                        location: second.location,
                        plan: second.plan
                    )
                } catch let error as ConcatenationCorpusServiceError {
                    if case .duplicateIdentifier = error {
                        duplicateIdentifierRejected = true
                    }
                }

                do {
                    _ = try await service.attach(
                        "alias",
                        location: first.location,
                        plan: first.plan
                    )
                } catch let error as ConcatenationCorpusServiceError {
                    if case .locationAlreadyAttached = error {
                        duplicateLocationRejected = true
                    }
                }

                try Expect.true(
                    duplicateIdentifierRejected,
                    "duplicate corpus identifier rejected"
                )
                try Expect.true(
                    duplicateLocationRejected,
                    "duplicate corpus location rejected"
                )
            }

            Step(
                "service detaches corpus without invalidating retained cache"
            ) {
                let fixture = try serviceFixture(
                    "detach"
                )

                defer {
                    try? FileManager.default.removeItem(
                        at: fixture.root
                    )
                }

                let session = ConcatenationSession()
                let service = ConcatenationCorpusService(
                    session: session
                )

                _ = try await service.attach(
                    "detachable",
                    location: fixture.location,
                    plan: fixture.plan
                )
                let refreshed = try await service.refresh(
                    "detachable"
                )
                let detached = try await service.detach(
                    "detachable"
                )

                try Expect.equal(
                    detached.fingerprint,
                    refreshed.snapshot.fingerprint,
                    "detach reports last retained snapshot"
                )
                try Expect.false(
                    await service.contains(
                        "detachable"
                    ),
                    "detached corpus leaves registry"
                )

                let rebound = ConcatenationCorpus(
                    location: fixture.location,
                    plan: fixture.plan,
                    session: session
                )
                let retained = try Expect.notNil(
                    rebound.snapshot(),
                    "detach does not invalidate retained cache"
                )

                try Expect.equal(
                    retained.fingerprint,
                    refreshed.snapshot.fingerprint,
                    "retained cache survives registry detach"
                )
            }
        }
    }

    private struct ServiceFixture {
        let root: URL
        let location: URL
        let plan: ConcatenationPlan
    }

    private static func serviceFixture(
        _ name: String
    ) throws -> ServiceFixture {
        let root = URL(
            fileURLWithPath: NSTemporaryDirectory(),
            isDirectory: true
        )
        .appendingPathComponent(
            "concatenation-service-\(name)-\(UUID().uuidString)",
            isDirectory: true
        )

        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )

        let a = root.appendingPathComponent(
            "A.swift"
        )
        let b = root.appendingPathComponent(
            "B.swift"
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
            "retained-corpus"
        )

        return ServiceFixture(
            root: root,
            location: location,
            plan: ConcatenationPlan(
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
        )
    }
}
