import Concatenation
import Dispatch
import Foundation

public struct ConcatenationServiceClient:
    Sendable
{
    public let endpoint: ConcatenationServiceEndpoint

    public init(
        endpoint: ConcatenationServiceEndpoint = .default
    ) {
        self.endpoint = endpoint
    }

    public func send(
        _ request: ConcatenationServiceRequest
    ) async throws -> ConcatenationServiceResponse {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(
                qos: .userInitiated
            ).async {
                do {
                    let descriptor = try ConcatenationUnixSocket.connect(
                        to: endpoint
                    )

                    defer {
                        ConcatenationUnixSocket.close(
                            descriptor
                        )
                    }

                    try ConcatenationUnixSocket.send(
                        request,
                        to: descriptor
                    )

                    let response = try ConcatenationUnixSocket.receive(
                        ConcatenationServiceResponse.self,
                        from: descriptor
                    )

                    continuation.resume(
                        returning: response
                    )
                } catch {
                    continuation.resume(
                        throwing: error
                    )
                }
            }
        }
    }

    public func ping() async throws
        -> ConcatenationServiceResponse
    {
        try await successfulResponse(
            for: .ping
        )
    }

    public func shutdown() async throws
        -> ConcatenationServiceResponse
    {
        try await successfulResponse(
            for: .shutdown
        )
    }

    public func attach(
        _ identifier: ConcatenationCorpusIdentifier,
        configuration: URL,
        output: String? = nil,
        policy: ConcatenationCorpusAttachPolicy = .reject_existing
    ) async throws -> ConcatenationCorpusStatus {
        let response = try await successfulResponse(
            for: .attach(
                .init(
                    identifier: identifier,
                    configuration: configuration,
                    output: output,
                    policy: policy
                )
            )
        )

        guard case .corpus_status(let status) = response.payload else {
            throw ConcatenationServiceTransportError
                .unexpectedResponse(
                    operation: .attach
                )
        }

        return status
    }

    public func importCorpora(
        configuration: URL,
        prefix: String? = nil,
        policy: ConcatenationCorpusAttachPolicy = .reject_existing
    ) async throws -> [ConcatenationCorpusStatus] {
        let response = try await successfulResponse(
            for: .import_corpora(
                .init(
                    configuration: configuration,
                    prefix: prefix,
                    policy: policy
                )
            )
        )

        guard case .corpus_list(let statuses) = response.payload else {
            throw ConcatenationServiceTransportError
                .unexpectedResponse(
                    operation: .import_corpora
                )
        }

        return statuses
    }

    public func list() async throws
        -> [ConcatenationCorpusStatus]
    {
        let response = try await successfulResponse(
            for: .list
        )

        guard case .corpus_list(let statuses) = response.payload else {
            throw ConcatenationServiceTransportError
                .unexpectedResponse(
                    operation: .list
                )
        }

        return statuses
    }

    public func status(
        _ identifier: ConcatenationCorpusIdentifier
    ) async throws -> ConcatenationCorpusStatus {
        let response = try await successfulResponse(
            for: .status(
                .init(
                    identifier: identifier
                )
            )
        )

        guard case .corpus_status(let status) = response.payload else {
            throw ConcatenationServiceTransportError
                .unexpectedResponse(
                    operation: .status
                )
        }

        return status
    }

    public func refresh(
        _ identifier: ConcatenationCorpusIdentifier
    ) async throws -> ConcatenationServiceRefresh {
        let response = try await successfulResponse(
            for: .refresh(
                .init(
                    identifier: identifier
                )
            )
        )

        guard case .refresh(let refresh) = response.payload else {
            throw ConcatenationServiceTransportError
                .unexpectedResponse(
                    operation: .refresh
                )
        }

        return refresh
    }

    public func snapshot(
        _ identifier: ConcatenationCorpusIdentifier
    ) async throws -> ConcatenationSourceSnapshot? {
        let response = try await successfulResponse(
            for: .snapshot(
                .init(
                    identifier: identifier
                )
            )
        )

        guard case .snapshot(let snapshot) = response.payload else {
            throw ConcatenationServiceTransportError
                .unexpectedResponse(
                    operation: .snapshot
                )
        }

        return snapshot
    }

    public func materialize(
        _ identifier: ConcatenationCorpusIdentifier,
        delta: ConcatenationSourceDelta? = nil
    ) async throws -> ConcatenationCorpusMaterialization? {
        let response = try await successfulResponse(
            for: .materialize(
                .init(
                    identifier: identifier,
                    delta: delta
                )
            )
        )

        guard case .materialization(let materialization) = response.payload else {
            throw ConcatenationServiceTransportError
                .unexpectedResponse(
                    operation: .materialize
                )
        }

        return materialization
    }

    public func detach(
        _ identifier: ConcatenationCorpusIdentifier
    ) async throws -> ConcatenationCorpusStatus {
        let response = try await successfulResponse(
            for: .detach(
                .init(
                    identifier: identifier
                )
            )
        )

        guard case .corpus_status(let status) = response.payload else {
            throw ConcatenationServiceTransportError
                .unexpectedResponse(
                    operation: .detach
                )
        }

        return status
    }
}

private extension ConcatenationServiceClient {
    func successfulResponse(
        for request: ConcatenationServiceRequest
    ) async throws -> ConcatenationServiceResponse {
        let response = try await send(
            request
        )

        guard response.isSuccess else {
            throw ConcatenationServiceTransportError
                .serviceFailure(
                    response.message
                        ?? "Concatenation service operation failed: \(request.operation.rawValue)"
                )
        }

        return response
    }
}
