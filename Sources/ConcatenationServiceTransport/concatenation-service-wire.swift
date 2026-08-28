import Concatenation
import Foundation

public struct ConcatenationServiceAttachRequest:
    Sendable,
    Codable,
    Hashable
{
    public let identifier: ConcatenationCorpusIdentifier
    public let configuration: URL
    public let output: String?
    public let policy: ConcatenationCorpusAttachPolicy

    public init(
        identifier: ConcatenationCorpusIdentifier,
        configuration: URL,
        output: String? = nil,
        policy: ConcatenationCorpusAttachPolicy = .reject_existing
    ) {
        self.identifier = identifier
        self.configuration = configuration.standardizedFileURL
        self.output = output
        self.policy = policy
    }
}

public struct ConcatenationServiceImportRequest:
    Sendable,
    Codable,
    Hashable
{
    public let configuration: URL
    public let prefix: String?
    public let policy: ConcatenationCorpusAttachPolicy

    public init(
        configuration: URL,
        prefix: String? = nil,
        policy: ConcatenationCorpusAttachPolicy = .reject_existing
    ) {
        self.configuration = configuration.standardizedFileURL
        self.prefix = prefix
        self.policy = policy
    }
}

public struct ConcatenationServiceCorpusRequest:
    Sendable,
    Codable,
    Hashable
{
    public let identifier: ConcatenationCorpusIdentifier

    public init(
        identifier: ConcatenationCorpusIdentifier
    ) {
        self.identifier = identifier
    }
}

public struct ConcatenationServiceMaterializeRequest:
    Sendable,
    Codable,
    Hashable
{
    public let identifier: ConcatenationCorpusIdentifier
    public let delta: ConcatenationSourceDelta?

    public init(
        identifier: ConcatenationCorpusIdentifier,
        delta: ConcatenationSourceDelta? = nil
    ) {
        self.identifier = identifier
        self.delta = delta
    }
}

public enum ConcatenationServiceRequest:
    Sendable,
    Codable
{
    public enum Operation:
        String,
        Sendable,
        Codable,
        Hashable,
        CaseIterable
    {
        case ping
        case shutdown
        case attach
        case import_corpora
        case list
        case status
        case refresh
        case snapshot
        case materialize
        case detach
    }

    case ping
    case shutdown
    case attach(ConcatenationServiceAttachRequest)
    case import_corpora(ConcatenationServiceImportRequest)
    case list
    case status(ConcatenationServiceCorpusRequest)
    case refresh(ConcatenationServiceCorpusRequest)
    case snapshot(ConcatenationServiceCorpusRequest)
    case materialize(ConcatenationServiceMaterializeRequest)
    case detach(ConcatenationServiceCorpusRequest)

    public var operation: Operation {
        switch self {
        case .ping:
            return .ping
        case .shutdown:
            return .shutdown
        case .attach:
            return .attach
        case .import_corpora:
            return .import_corpora
        case .list:
            return .list
        case .status:
            return .status
        case .refresh:
            return .refresh
        case .snapshot:
            return .snapshot
        case .materialize:
            return .materialize
        case .detach:
            return .detach
        }
    }
}

public struct ConcatenationServiceRefresh:
    Sendable,
    Codable,
    Hashable
{
    public let snapshot: ConcatenationSourceSnapshot
    public let delta: ConcatenationSourceDelta?

    public init(
        snapshot: ConcatenationSourceSnapshot,
        delta: ConcatenationSourceDelta?
    ) {
        self.snapshot = snapshot
        self.delta = delta
    }

    public var isInitial: Bool {
        delta == nil
    }
}

public enum ConcatenationServiceResponsePayload:
    Sendable,
    Codable
{
    case corpus_status(ConcatenationCorpusStatus)
    case corpus_list([ConcatenationCorpusStatus])
    case refresh(ConcatenationServiceRefresh)
    case snapshot(ConcatenationSourceSnapshot?)
    case materialization(ConcatenationCorpusMaterialization?)
}

public struct ConcatenationServiceResponse:
    Sendable,
    Codable
{
    public enum Status:
        String,
        Sendable,
        Codable,
        Hashable
    {
        case success
        case failure
    }

    public let operation: ConcatenationServiceRequest.Operation
    public let status: Status
    public let payload: ConcatenationServiceResponsePayload?
    public let message: String?

    public init(
        operation: ConcatenationServiceRequest.Operation,
        status: Status,
        payload: ConcatenationServiceResponsePayload? = nil,
        message: String? = nil
    ) {
        self.operation = operation
        self.status = status
        self.payload = payload
        self.message = message
    }

    public var isSuccess: Bool {
        status == .success
    }
}
