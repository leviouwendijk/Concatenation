import Foundation

public enum ConcatenationWarningKind: String, Sendable, Codable {
    case blockedByPolicy
    case truncated
}

public struct ConcatenationWarning: Sendable, Codable, Equatable {
    public let kind: ConcatenationWarningKind
    public let file: URL
    public let message: String

    public init(
        kind: ConcatenationWarningKind,
        file: URL,
        message: String
    ) {
        self.kind = kind
        self.file = file.standardizedFileURL
        self.message = message
    }
}
