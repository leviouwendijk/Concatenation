import Concatenation
import ConcatenationServiceTransport
import Foundation
import TestFlows

extension ConcatenationFlowSuite {
    static var conServiceCorpusRPCFlow: TestFlow {
        TestFlow(
            "con-service-corpus-rpc",
            tags: [
                "corpus",
                "incremental",
                "ipc",
                "service",
                "transport",
            ]
        ) {
            Step(
                "persistent service carries corpus lifecycle across client calls"
            ) {
                let fixture = try serviceCorpusRPCFixture(
                    "lifecycle"
                )

                defer {
                    try? FileManager.default.removeItem(
                        at: fixture.root
                    )
                }

                let host = ConcatenationServiceHost(
                    endpoint: fixture.endpoint
                )
                let client = ConcatenationServiceClient(
                    endpoint: fixture.endpoint
                )
                let task = Task {
                    try await host.serve()
                }

                _ = try await rpcPingEventually(
                    client
                )

                let attached = try await client.attach(
                    "primary",
                    configuration: fixture.configuration
                )

                try Expect.false(
                    attached.hasSnapshot,
                    "remote attach remains lazy"
                )
                try Expect.equal(
                    attached.sourceCount,
                    0,
                    "remote attach does not refresh corpus"
                )

                let listed = try await client.list()

                try Expect.equal(
                    listed.map(\.identifier.rawValue),
                    [
                        "primary",
                    ],
                    "remote list returns attached corpus"
                )

                let before = try await client.status(
                    "primary"
                )

                try Expect.false(
                    before.hasSnapshot,
                    "remote status observes lazy attachment"
                )

                try Expect.isNil(
                    try await client.snapshot(
                        "primary"
                    ),
                    "remote snapshot is nil before refresh"
                )

                let initial = try await client.refresh(
                    "primary"
                )

                try Expect.true(
                    initial.isInitial,
                    "first remote refresh is initial"
                )
                try Expect.equal(
                    initial.snapshot.count,
                    2,
                    "first remote refresh retains both sources"
                )

                let snapshot = try Expect.notNil(
                    try await client.snapshot(
                        "primary"
                    ),
                    "remote snapshot exists after refresh"
                )

                try Expect.equal(
                    snapshot.fingerprint,
                    initial.snapshot.fingerprint,
                    "remote snapshot retains refresh revision"
                )

                let full = try Expect.notNil(
                    try await client.materialize(
                        "primary"
                    ),
                    "remote materialization exists after refresh"
                )

                try Expect.equal(
                    full.count,
                    2,
                    "remote full materialization transfers retained sections"
                )

                try "alpha changed\n".write(
                    to: fixture.a,
                    atomically: true,
                    encoding: .utf8
                )

                let changed = try await client.refresh(
                    "primary"
                )
                let delta = try Expect.notNil(
                    changed.delta,
                    "second remote refresh returns revision delta"
                )

                try Expect.equal(
                    delta.baseFingerprint,
                    initial.snapshot.fingerprint,
                    "remote delta begins at previous revision"
                )
                try Expect.equal(
                    delta.fingerprint,
                    changed.snapshot.fingerprint,
                    "remote delta ends at current revision"
                )
                try Expect.equal(
                    delta.changed.count,
                    1,
                    "remote delta contains changed source only"
                )
                try Expect.equal(
                    delta.unchangedCount,
                    1,
                    "remote delta preserves unchanged source count"
                )

                let selective = try Expect.notNil(
                    try await client.materialize(
                        "primary",
                        delta: delta
                    ),
                    "remote changed-only materialization exists"
                )

                try Expect.equal(
                    selective.count,
                    1,
                    "remote changed-only materialization transfers one source"
                )
                try Expect.equal(
                    selective.sources[0].record.file.lastPathComponent,
                    "A.swift",
                    "remote changed-only materialization identifies changed source"
                )

                let detached = try await client.detach(
                    "primary"
                )

                try Expect.equal(
                    detached.fingerprint,
                    changed.snapshot.fingerprint,
                    "remote detach returns final retained status"
                )
                try Expect.true(
                    try await client.list().isEmpty,
                    "remote detach removes corpus from service registry"
                )

                _ = try await client.shutdown()
                try await task.value
            }

            Step(
                "remote attach resolves named conany outputs on host"
            ) {
                let fixture = try serviceCorpusRPCFixture(
                    "outputs",
                    multipleOutputs: true
                )

                defer {
                    try? FileManager.default.removeItem(
                        at: fixture.root
                    )
                }

                let host = ConcatenationServiceHost(
                    endpoint: fixture.endpoint
                )
                let client = ConcatenationServiceClient(
                    endpoint: fixture.endpoint
                )
                let task = Task {
                    try await host.serve()
                }

                _ = try await rpcPingEventually(
                    client
                )

                var requiresOutput = false

                do {
                    _ = try await client.attach(
                        "ambiguous",
                        configuration: fixture.configuration
                    )
                } catch let error as ConcatenationServiceTransportError {
                    if case .serviceFailure(let message) = error {
                        requiresOutput = message.contains(
                            "specify one of"
                        )
                    }
                }

                try Expect.true(
                    requiresOutput,
                    "multi-output remote attachment requires explicit output identity"
                )

                let attached = try await client.attach(
                    "primary",
                    configuration: fixture.configuration,
                    output: "first.txt"
                )

                try Expect.equal(
                    attached.location.lastPathComponent,
                    "first.txt",
                    "host resolves selected conany output into corpus location"
                )

                _ = try await client.shutdown()
                try await task.value
            }

            Step(
                "catalog import preserves independent corpora and explicitly re-resolves membership"
            ) {
                let fixture = try serviceCorpusRPCFixture(
                    "catalog",
                    multipleOutputs: true
                )

                defer {
                    try? FileManager.default.removeItem(
                        at: fixture.root
                    )
                }

                let wildcardConfiguration = """
                file("first.txt") {
                    include(from: "\(fixture.root.path)", show: .relativeToBase) {
                        "*.swift"
                    }
                }

                file("second.txt") {
                    include(from: "\(fixture.root.path)", show: .relativeToBase) {
                        "B.swift"
                    }
                }
                """

                try wildcardConfiguration.write(
                    to: fixture.configuration,
                    atomically: true,
                    encoding: .utf8
                )

                let host = ConcatenationServiceHost(
                    endpoint: fixture.endpoint
                )
                let client = ConcatenationServiceClient(
                    endpoint: fixture.endpoint
                )
                let task = Task {
                    try await host.serve()
                }

                _ = try await rpcPingEventually(
                    client
                )

                let imported = try await client.importCorpora(
                    configuration: fixture.configuration,
                    prefix: "spec"
                )

                try Expect.equal(
                    imported.map(\.identifier.rawValue),
                    [
                        "spec/first.txt",
                        "spec/second.txt",
                    ],
                    "catalog output names become prefixed corpus identities"
                )

                let firstInitial = try await client.refresh(
                    "spec/first.txt"
                )

                try Expect.equal(
                    firstInitial.snapshot.count,
                    2,
                    "first imported corpus resolves both initial Swift sources"
                )

                let secondBeforeRefresh = try await client.status(
                    "spec/second.txt"
                )

                try Expect.equal(
                    secondBeforeRefresh.sourceCount,
                    0,
                    "imported outputs remain independently lazy"
                )

                let c = fixture.root.appendingPathComponent(
                    "C.swift",
                    isDirectory: false
                )

                try "gamma\n".write(
                    to: c,
                    atomically: true,
                    encoding: .utf8
                )

                let staticRefresh = try await client.refresh(
                    "spec/first.txt"
                )

                try Expect.equal(
                    staticRefresh.snapshot.count,
                    2,
                    "ordinary refresh preserves already-resolved corpus membership"
                )

                _ = try await client.importCorpora(
                    configuration: fixture.configuration,
                    prefix: "spec",
                    policy: .replace_existing
                )

                let resolvedRefresh = try await client.refresh(
                    "spec/first.txt"
                )

                try Expect.equal(
                    resolvedRefresh.snapshot.count,
                    3,
                    "catalog replace re-runs conany discovery and admits newly matching source"
                )

                _ = try await client.shutdown()
                try await task.value
            }
        }
    }

    private struct ServiceCorpusRPCFixture {
        let root: URL
        let a: URL
        let configuration: URL
        let endpoint: ConcatenationServiceEndpoint
    }

    private static func serviceCorpusRPCFixture(
        _ name: String,
        multipleOutputs: Bool = false
    ) throws -> ServiceCorpusRPCFixture {
        let suffix = UUID()
            .uuidString
            .prefix(8)
        let root = URL(
            fileURLWithPath: "/tmp",
            isDirectory: true
        )
        .appendingPathComponent(
            "con-rpc-\(name.prefix(6))-\(suffix)",
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

        let configuration = root.appendingPathComponent(
            ".conany",
            isDirectory: false
        )

        var text = """
        file("first.txt") {
            include(from: "\(root.path)", show: .relativeToBase) {
                "A.swift"
                "B.swift"
            }
        }
        """

        if multipleOutputs {
            text += """


            file("second.txt") {
                include(from: "\(root.path)", show: .relativeToBase) {
                    "B.swift"
                }
            }
            """
        }

        try text.write(
            to: configuration,
            atomically: true,
            encoding: .utf8
        )

        return .init(
            root: root,
            a: a,
            configuration: configuration,
            endpoint: .init(
                url: root.appendingPathComponent(
                    "service.sock",
                    isDirectory: false
                )
            )
        )
    }

    private static func rpcPingEventually(
        _ client: ConcatenationServiceClient
    ) async throws -> ConcatenationServiceResponse {
        var lastError: Error?

        for _ in 0..<100 {
            do {
                return try await client.ping()
            } catch {
                lastError = error

                try await Task<Never, Never>.sleep(
                    nanoseconds: 10_000_000
                )
            }
        }

        throw lastError
            ?? ConcatenationServiceTransportError.connectionClosed
    }
}
