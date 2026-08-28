import Concatenation
import Dispatch
import Foundation

public struct ConcatenationServiceHost:
    Sendable
{
    public let endpoint: ConcatenationServiceEndpoint
    public let service: ConcatenationCorpusService

    public init(
        endpoint: ConcatenationServiceEndpoint = .default,
        service: ConcatenationCorpusService = .init()
    ) {
        self.endpoint = endpoint
        self.service = service
    }

    public func serve() async throws {
        let listener = try ConcatenationUnixSocket.listen(
            at: endpoint
        )

        defer {
            ConcatenationUnixSocket.close(
                listener
            )
            try? ConcatenationUnixSocket.removeSocket(
                endpoint
            )
        }

        while true {
            let descriptor = try await accept(
                listener
            )

            let request: ConcatenationServiceRequest

            do {
                request = try await receive(
                    descriptor
                )
            } catch {
                ConcatenationUnixSocket.close(
                    descriptor
                )
                continue
            }

            let response = await response(
                for: request
            )

            do {
                try await send(
                    response,
                    to: descriptor
                )
            } catch {
                ConcatenationUnixSocket.close(
                    descriptor
                )
                throw error
            }

            ConcatenationUnixSocket.close(
                descriptor
            )

            if request.operation == .shutdown,
               response.isSuccess
            {
                return
            }
        }
    }
}

private extension ConcatenationServiceHost {
    func response(
        for request: ConcatenationServiceRequest
    ) async -> ConcatenationServiceResponse {
        do {
            switch request {
            case .ping:
                return .init(
                    operation: .ping,
                    status: .success,
                    message: "pong"
                )

            case .shutdown:
                return .init(
                    operation: .shutdown,
                    status: .success,
                    message: "shutting_down"
                )

            case .attach(let attachment):
                let resolved = try resolve(
                    attachment
                )
                let status = try await service.attach(
                    attachment.identifier,
                    location: resolved.outputURL,
                    plan: resolved.plan,
                    policy: attachment.policy
                )

                return .init(
                    operation: .attach,
                    status: .success,
                    payload: .corpus_status(
                        status
                    )
                )

            case .import_corpora(let request):
                return .init(
                    operation: .import_corpora,
                    status: .success,
                    payload: .corpus_list(
                        try await importCorpora(
                            request
                        )
                    )
                )

            case .list:
                return .init(
                    operation: .list,
                    status: .success,
                    payload: .corpus_list(
                        try await service.list()
                    )
                )

            case .status(let corpus):
                return .init(
                    operation: .status,
                    status: .success,
                    payload: .corpus_status(
                        try await service.status(
                            corpus.identifier
                        )
                    )
                )

            case .refresh(let corpus):
                let refresh = try await service.refresh(
                    corpus.identifier
                )

                return .init(
                    operation: .refresh,
                    status: .success,
                    payload: .refresh(
                        .init(
                            snapshot: refresh.snapshot,
                            delta: refresh.delta
                        )
                    )
                )

            case .snapshot(let corpus):
                return .init(
                    operation: .snapshot,
                    status: .success,
                    payload: .snapshot(
                        try await service.snapshot(
                            corpus.identifier
                        )
                    )
                )

            case .materialize(let corpus):
                let materialization: ConcatenationCorpusMaterialization?

                if let delta = corpus.delta {
                    materialization = try await service.materialize(
                        corpus.identifier,
                        delta: delta
                    )
                } else {
                    materialization = try await service.materialize(
                        corpus.identifier
                    )
                }

                return .init(
                    operation: .materialize,
                    status: .success,
                    payload: .materialization(
                        materialization
                    )
                )

            case .detach(let corpus):
                return .init(
                    operation: .detach,
                    status: .success,
                    payload: .corpus_status(
                        try await service.detach(
                            corpus.identifier
                        )
                    )
                )
            }
        } catch {
            return .init(
                operation: request.operation,
                status: .failure,
                message: error.localizedDescription
            )
        }
    }

    func importCorpora(
        _ request: ConcatenationServiceImportRequest
    ) async throws -> [ConcatenationCorpusStatus] {
        let outputs = try ConAnyExecution(
            configURL: request.configuration
        )
        .resolve()

        let targets = outputs.map { output in
            (
                identifier: importedCorpusIdentifier(
                    output: output.name,
                    prefix: request.prefix
                ),
                output: output
            )
        }

        let current = try await service.list()
        var identifiers: Set<ConcatenationCorpusIdentifier> = []

        for target in targets {
            guard identifiers.insert(
                target.identifier
            ).inserted else {
                throw ConcatenationServiceHostError
                    .importConflict(
                        "The .conany catalog resolves duplicate corpus identifier '\(target.identifier.rawValue)'."
                    )
            }

            if request.policy == .reject_existing,
               current.contains(
                    where: {
                        $0.identifier == target.identifier
                    }
               )
            {
                throw ConcatenationServiceHostError
                    .importConflict(
                        "Corpus identifier is already attached: \(target.identifier.rawValue)"
                    )
            }

            if let existing = current.first(
                where: {
                    $0.identifier != target.identifier
                        && $0.location == target.output.outputURL
                }
            ) {
                throw ConcatenationServiceHostError
                    .importConflict(
                        "Corpus location '\(target.output.outputURL.path)' is already attached as '\(existing.identifier.rawValue)'."
                    )
            }
        }

        var statuses: [ConcatenationCorpusStatus] = []
        statuses.reserveCapacity(
            targets.count
        )

        for target in targets {
            statuses.append(
                try await service.attach(
                    target.identifier,
                    location: target.output.outputURL,
                    plan: target.output.plan,
                    policy: request.policy
                )
            )
        }

        return statuses
    }

    func importedCorpusIdentifier(
        output: String,
        prefix: String?
    ) -> ConcatenationCorpusIdentifier {
        let separators = CharacterSet(
            charactersIn: "/"
        )
        let output = output.trimmingCharacters(
            in: separators
        )
        let prefix = prefix?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .trimmingCharacters(
                in: separators
            )

        guard let prefix,
              !prefix.isEmpty
        else {
            return .init(
                rawValue: output
            )
        }

        return .init(
            rawValue: "\(prefix)/\(output)"
        )
    }

    func resolve(
        _ attachment: ConcatenationServiceAttachRequest
    ) throws -> ConAnyResolvedOutput {
        let outputs = try ConAnyExecution(
            configURL: attachment.configuration
        )
        .resolve()

        if let requested = attachment.output {
            guard let output = outputs.first(
                where: {
                    $0.name == requested
                }
            ) else {
                throw ConcatenationServiceHostError
                    .unknownOutput(
                        requested: requested,
                        available: outputs.map(\.name)
                    )
            }

            return output
        }

        guard outputs.count == 1,
              let output = outputs.first
        else {
            throw ConcatenationServiceHostError
                .outputRequired(
                    outputs.map(\.name)
                )
        }

        return output
    }

    func accept(
        _ listener: Int32
    ) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(
                qos: .utility
            ).async {
                do {
                    continuation.resume(
                        returning: try ConcatenationUnixSocket.accept(
                            listener
                        )
                    )
                } catch {
                    continuation.resume(
                        throwing: error
                    )
                }
            }
        }
    }

    func receive(
        _ descriptor: Int32
    ) async throws -> ConcatenationServiceRequest {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(
                qos: .utility
            ).async {
                do {
                    continuation.resume(
                        returning: try ConcatenationUnixSocket.receive(
                            ConcatenationServiceRequest.self,
                            from: descriptor
                        )
                    )
                } catch {
                    continuation.resume(
                        throwing: error
                    )
                }
            }
        }
    }

    func send(
        _ response: ConcatenationServiceResponse,
        to descriptor: Int32
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(
                qos: .utility
            ).async {
                do {
                    try ConcatenationUnixSocket.send(
                        response,
                        to: descriptor
                    )
                    continuation.resume()
                } catch {
                    continuation.resume(
                        throwing: error
                    )
                }
            }
        }
    }
}

private enum ConcatenationServiceHostError:
    Error,
    LocalizedError
{
    case outputRequired([String])
    case importConflict(String)
    case unknownOutput(
        requested: String,
        available: [String]
    )

    var errorDescription: String? {
        switch self {
        case .outputRequired(let available):
            return "The .conany configuration resolves multiple outputs; specify one of: \(available.joined(separator: ", "))"

        case .importConflict(let message):
            return message

        case .unknownOutput(let requested, let available):
            return "Unknown .conany output '\(requested)'; available outputs: \(available.joined(separator: ", "))"
        }
    }
}
