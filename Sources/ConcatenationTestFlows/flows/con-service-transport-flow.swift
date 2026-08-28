import ConcatenationServiceTransport
import Darwin
import Foundation
import TestFlows

extension ConcatenationFlowSuite {
    static var conServiceTransportFlow: TestFlow {
        TestFlow(
            "con-service-transport",
            tags: [
                "corpus",
                "ipc",
                "service",
                "transport",
            ]
        ) {
            Step(
                "service host and client round trip across Unix socket"
            ) {
                let fixture = serviceTransportFixture(
                    "roundtrip"
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

                let ping = try await pingEventually(
                    client
                )

                try Expect.true(
                    ping.isSuccess,
                    "service ping succeeds"
                )
                try Expect.equal(
                    ping.message,
                    "pong",
                    "service ping response"
                )

                let shutdown = try await client.shutdown()

                try Expect.true(
                    shutdown.isSuccess,
                    "service shutdown succeeds"
                )
                try Expect.equal(
                    shutdown.message,
                    "shutting_down",
                    "service shutdown response"
                )

                try await task.value

                try Expect.false(
                    FileManager.default.fileExists(
                        atPath: fixture.endpoint.path
                    ),
                    "clean host shutdown removes socket endpoint"
                )
            }

            Step(
                "service endpoint can be rebound after shutdown"
            ) {
                let fixture = serviceTransportFixture(
                    "rebind"
                )

                for _ in 0..<2 {
                    let host = ConcatenationServiceHost(
                        endpoint: fixture.endpoint
                    )
                    let client = ConcatenationServiceClient(
                        endpoint: fixture.endpoint
                    )
                    let task = Task {
                        try await host.serve()
                    }

                    _ = try await pingEventually(
                        client
                    )
                    _ = try await client.shutdown()
                    try await task.value
                }

                try Expect.false(
                    FileManager.default.fileExists(
                        atPath: fixture.endpoint.path
                    ),
                    "rebound service leaves no stale endpoint"
                )
            }

            Step(
                "active service endpoint cannot be replaced"
            ) {
                let fixture = serviceTransportFixture(
                    "active"
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

                _ = try await pingEventually(
                    client
                )

                var rejected = false

                do {
                    try await ConcatenationServiceHost(
                        endpoint: fixture.endpoint
                    ).serve()
                } catch let error as ConcatenationServiceTransportError {
                    if case .endpointActive = error {
                        rejected = true
                    }
                }

                try Expect.true(
                    rejected,
                    "second host rejects active endpoint"
                )

                let stillAlive = try await client.ping()

                try Expect.true(
                    stillAlive.isSuccess,
                    "first host remains reachable after rejected second host"
                )

                _ = try await client.shutdown()
                try await task.value

                try? FileManager.default.removeItem(
                    at: fixture.root
                )
            }

            Step(
                "stale socket endpoint is reclaimed"
            ) {
                let fixture = serviceTransportFixture(
                    "stale"
                )

                try createStaleSocket(
                    at: fixture.endpoint
                )

                try Expect.true(
                    FileManager.default.fileExists(
                        atPath: fixture.endpoint.path
                    ),
                    "stale fixture leaves socket path behind"
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

                let ping = try await pingEventually(
                    client
                )

                try Expect.true(
                    ping.isSuccess,
                    "host reclaims stale socket and becomes reachable"
                )

                _ = try await client.shutdown()
                try await task.value

                try Expect.false(
                    FileManager.default.fileExists(
                        atPath: fixture.endpoint.path
                    ),
                    "reclaimed endpoint is removed on clean shutdown"
                )

                try? FileManager.default.removeItem(
                    at: fixture.root
                )
            }

            Step(
                "service never replaces a non-socket endpoint"
            ) {
                let fixture = serviceTransportFixture(
                    "occupied"
                )

                try FileManager.default.createDirectory(
                    at: fixture.endpoint.url
                        .deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                try "occupied".write(
                    to: fixture.endpoint.url,
                    atomically: true,
                    encoding: .utf8
                )

                var rejected = false

                do {
                    try await ConcatenationServiceHost(
                        endpoint: fixture.endpoint
                    ).serve()
                } catch let error as ConcatenationServiceTransportError {
                    if case .endpointOccupied = error {
                        rejected = true
                    }
                }

                try Expect.true(
                    rejected,
                    "non-socket service endpoint is rejected"
                )

                try Expect.equal(
                    try String(
                        contentsOf: fixture.endpoint.url,
                        encoding: .utf8
                    ),
                    "occupied",
                    "occupied endpoint remains untouched"
                )

                try? FileManager.default.removeItem(
                    at: fixture.root
                )
            }
        }
    }

    private struct ServiceTransportFixture {
        let root: URL
        let endpoint: ConcatenationServiceEndpoint
    }

    private static func serviceTransportFixture(
        _ name: String
    ) -> ServiceTransportFixture {
        let suffix = UUID()
            .uuidString
            .prefix(8)
        let root = URL(
            fileURLWithPath: "/tmp",
            isDirectory: true
        )
        .appendingPathComponent(
            "con-\(name.prefix(8))-\(suffix)",
            isDirectory: true
        )

        return ServiceTransportFixture(
            root: root,
            endpoint: ConcatenationServiceEndpoint(
                url: root.appendingPathComponent(
                    "service.sock",
                    isDirectory: false
                )
            )
        )
    }

    private static func createStaleSocket(
        at endpoint: ConcatenationServiceEndpoint
    ) throws {
        try FileManager.default.createDirectory(
            at: endpoint.url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let descriptor = Darwin.socket(
            AF_UNIX,
            SOCK_STREAM,
            0
        )

        guard descriptor >= 0 else {
            throw ConcatenationServiceTransportError.system(
                operation: "test_socket",
                code: errno
            )
        }

        defer {
            Darwin.close(
                descriptor
            )
        }

        var address = try staleSocketAddress(
            endpoint.path
        )

        let result = withUnsafePointer(
            to: &address
        ) { pointer in
            pointer.withMemoryRebound(
                to: sockaddr.self,
                capacity: 1
            ) { socketAddress in
                Darwin.bind(
                    descriptor,
                    socketAddress,
                    socklen_t(
                        MemoryLayout<sockaddr_un>.size
                    )
                )
            }
        }

        guard result == 0 else {
            throw ConcatenationServiceTransportError.system(
                operation: "test_bind",
                code: errno
            )
        }
    }

    private static func staleSocketAddress(
        _ path: String
    ) throws -> sockaddr_un {
        var address = sockaddr_un()
        let bytes = path.utf8CString
        let capacity = MemoryLayout.size(
            ofValue: address.sun_path
        )

        guard bytes.count <= capacity else {
            throw ConcatenationServiceTransportError
                .endpointPathTooLong(
                    bytes.count
                )
        }

        address.sun_family = sa_family_t(
            AF_UNIX
        )
        address.sun_len = UInt8(
            MemoryLayout<sockaddr_un>.size
        )

        withUnsafeMutablePointer(
            to: &address.sun_path
        ) { pointer in
            pointer.withMemoryRebound(
                to: CChar.self,
                capacity: capacity
            ) { destination in
                bytes.withUnsafeBufferPointer { source in
                    guard let base = source.baseAddress else {
                        return
                    }

                    destination.initialize(
                        from: base,
                        count: bytes.count
                    )
                }
            }
        }

        return address
    }

    private static func pingEventually(
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
