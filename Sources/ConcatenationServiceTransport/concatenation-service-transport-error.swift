import Foundation

public enum ConcatenationServiceTransportError:
    Error,
    Sendable,
    LocalizedError
{
    case endpointOccupied(URL)
    case endpointActive(URL)
    case endpointPathTooLong(Int)
    case messageTooLarge(Int)
    case connectionClosed
    case serviceFailure(String)
    case unexpectedResponse(
        operation: ConcatenationServiceRequest.Operation
    )
    case system(
        operation: String,
        code: Int32
    )

    public var errorDescription: String? {
        switch self {
        case .endpointOccupied(let url):
            return "Concatenation service endpoint is occupied by a non-socket resource: \(url.path)"

        case .endpointActive(let url):
            return "Concatenation service endpoint is already owned by an active service: \(url.path)"

        case .endpointPathTooLong(let count):
            return "Concatenation service Unix socket path is too long: \(count) bytes."

        case .messageTooLarge(let count):
            return "Concatenation service message exceeds the transport limit: \(count) bytes."

        case .connectionClosed:
            return "Concatenation service connection closed before the framed message completed."

        case .serviceFailure(let message):
            return message

        case .unexpectedResponse(let operation):
            return "Concatenation service returned an unexpected payload for operation: \(operation.rawValue)"

        case .system(let operation, let code):
            return "Concatenation service \(operation) failed with errno \(code)."
        }
    }
}
