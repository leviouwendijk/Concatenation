import Foundation
import IO

public struct ConcatenationCorpusStatus:
    Sendable,
    Codable,
    Hashable
{
    public let identifier: ConcatenationCorpusIdentifier
    public let location: URL
    public let fingerprint: ContentFingerprint?
    public let sourceCount: Int

    public init(
        identifier: ConcatenationCorpusIdentifier,
        location: URL,
        fingerprint: ContentFingerprint?,
        sourceCount: Int
    ) {
        self.identifier = identifier
        self.location = location.standardizedFileURL
        self.fingerprint = fingerprint
        self.sourceCount = sourceCount
    }

    public var hasSnapshot: Bool {
        fingerprint != nil
    }
}

public enum ConcatenationCorpusAttachPolicy:
    String,
    Sendable,
    Codable,
    Hashable
{
    case reject_existing
    case replace_existing
}

public enum ConcatenationCorpusServiceError:
    Error,
    Sendable,
    Hashable
{
    case duplicateIdentifier(
        ConcatenationCorpusIdentifier
    )
    case locationAlreadyAttached(
        location: URL,
        identifier: ConcatenationCorpusIdentifier
    )
    case unknownCorpus(
        ConcatenationCorpusIdentifier
    )
    case definitionUnavailable(
        ConcatenationCorpusIdentifier
    )
}
