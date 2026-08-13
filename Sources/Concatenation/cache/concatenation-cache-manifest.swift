import Foundation
import IO

public struct ConcatenationCacheManifest:
    Sendable,
    Codable
{
    public static let currentVersion = 3

    public let version: Int
    public let output: URL
    public let sources: [ConcatenationCachedSource]
    public let safeguards: [ConcatenationCachedSafeguard]
    public let artifact: ConcatenationCachedArtifact?

    public init(
        version: Int = Self.currentVersion,
        output: URL,
        sources: [ConcatenationCachedSource],
        safeguards: [ConcatenationCachedSafeguard] = [],
        artifact: ConcatenationCachedArtifact? = nil
    ) {
        self.version = version
        self.output = output.standardizedFileURL
        self.sources = sources
        self.safeguards = safeguards
        self.artifact = artifact
    }
}

public struct ConcatenationCachedSource:
    Sendable,
    Codable
{
    public let metadata: FileMetadataSnapshot
    public let contentFingerprint: ContentFingerprint
    public let transformationFingerprint: ContentFingerprint

    public init(
        metadata: FileMetadataSnapshot,
        contentFingerprint: ContentFingerprint,
        transformationFingerprint: ContentFingerprint
    ) {
        self.metadata = metadata
        self.contentFingerprint = contentFingerprint
        self.transformationFingerprint = transformationFingerprint
    }

    public var file: URL {
        metadata.url
    }

    public var sectionKey: String {
        ContentFingerprint.fingerprint(
            for: [
                contentFingerprint.algorithm,
                contentFingerprint.value,
                transformationFingerprint.algorithm,
                transformationFingerprint.value,
            ].joined(
                separator: ":"
            )
        ).value
    }
}

public struct ConcatenationCachedSafeguard:
    Sendable,
    Codable
{
    public let metadata: FileMetadataSnapshot
    public let policyFingerprint: ContentFingerprint
    public let matched: Bool
    public let reason: String?

    public init(
        metadata: FileMetadataSnapshot,
        policyFingerprint: ContentFingerprint,
        matched: Bool,
        reason: String?
    ) {
        self.metadata = metadata
        self.policyFingerprint = policyFingerprint
        self.matched = matched
        self.reason = reason
    }

    public var file: URL {
        metadata.url
    }
}

public struct ConcatenationCachedArtifact:
    Sendable,
    Codable
{
    public let metadata: FileMetadataSnapshot
    public let contentFingerprint: ContentFingerprint
    public let materialFingerprint: ContentFingerprint

    public init(
        metadata: FileMetadataSnapshot,
        contentFingerprint: ContentFingerprint,
        materialFingerprint: ContentFingerprint
    ) {
        self.metadata = metadata
        self.contentFingerprint = contentFingerprint
        self.materialFingerprint = materialFingerprint
    }

    public var file: URL {
        metadata.url
    }
}
