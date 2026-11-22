import Foundation
import IO

public struct ConcatenationCacheManifest:
    Sendable,
    Codable
{
    public static let currentVersion = 6

    public let version: Int
    public let output: URL
    /// The file that declared `output`, when one did (`.conany`,
    /// `con.frame`); `con clean` uses it to find outputs it no longer declares.
    public let configuration: URL?
    public let sources: [ConcatenationCachedSource]
    public let safeguards: [ConcatenationCachedSafeguard]
    public let artifact: ConcatenationCachedArtifact?

    public init(
        version: Int = Self.currentVersion,
        output: URL,
        configuration: URL? = nil,
        sources: [ConcatenationCachedSource],
        safeguards: [ConcatenationCachedSafeguard] = [],
        artifact: ConcatenationCachedArtifact? = nil
    ) {
        self.version = version
        self.output = output.standardizedFileURL
        self.configuration = configuration?.standardizedFileURL
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
    /// Everything that shapes this source in its output, header included.
    public let transformationFingerprint: ContentFingerprint
    /// Only what shapes the section's lines; with `contentFingerprint` it
    /// names the shared section file.
    public let bodyFingerprint: ContentFingerprint

    public init(
        metadata: FileMetadataSnapshot,
        contentFingerprint: ContentFingerprint,
        transformationFingerprint: ContentFingerprint,
        bodyFingerprint: ContentFingerprint
    ) {
        self.metadata = metadata
        self.contentFingerprint = contentFingerprint
        self.transformationFingerprint = transformationFingerprint
        self.bodyFingerprint = bodyFingerprint
    }

    init(
        metadata: FileMetadataSnapshot,
        contentFingerprint: ContentFingerprint,
        transformationFingerprint fingerprint: ConcatenationSectionFingerprint
    ) {
        self.init(
            metadata: metadata,
            contentFingerprint: contentFingerprint,
            transformationFingerprint: fingerprint.transformation,
            bodyFingerprint: fingerprint.body
        )
    }

    public var file: URL {
        metadata.url
    }

    public var sectionKey: String {
        ContentFingerprint.fingerprint(
            for: [
                contentFingerprint.algorithm,
                contentFingerprint.value,
                bodyFingerprint.algorithm,
                bodyFingerprint.value,
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
    public let signal: ConcatenationSecretSignal?

    public init(
        metadata: FileMetadataSnapshot,
        policyFingerprint: ContentFingerprint,
        signal: ConcatenationSecretSignal?
    ) {
        self.metadata = metadata
        self.policyFingerprint = policyFingerprint
        self.signal = signal
    }

    public var matched: Bool {
        signal != nil
    }

    public var file: URL {
        metadata.url
    }
}

struct ConcatenationCachedDocumentSummary:
    Sendable,
    Codable,
    Equatable
{
    let sourceCount: Int
    let renderedSectionCount: Int
    let blockedFileCount: Int
    let truncatedSectionCount: Int
    let selectedLineCount: Int
    let warnings: [ConcatenationWarning]

    init(
        sourceCount: Int,
        renderedSectionCount: Int,
        blockedFileCount: Int,
        truncatedSectionCount: Int,
        selectedLineCount: Int,
        warnings: [ConcatenationWarning]
    ) {
        self.sourceCount = sourceCount
        self.renderedSectionCount = renderedSectionCount
        self.blockedFileCount = blockedFileCount
        self.truncatedSectionCount = truncatedSectionCount
        self.selectedLineCount = selectedLineCount
        self.warnings = warnings
    }
}

public struct ConcatenationCachedArtifact:
    Sendable,
    Codable
{
    public let metadata: FileMetadataSnapshot
    public let contentFingerprint: ContentFingerprint
    public let materialFingerprint: ContentFingerprint

    // Internal optional fields keep existing v3 manifests decodable. Old
    // artifacts take the materialized path once and are hydrated afterward.
    let sourceMaterialFingerprint: ContentFingerprint?
    let documentSummary: ConcatenationCachedDocumentSummary?

    public init(
        metadata: FileMetadataSnapshot,
        contentFingerprint: ContentFingerprint,
        materialFingerprint: ContentFingerprint
    ) {
        self.metadata = metadata
        self.contentFingerprint = contentFingerprint
        self.materialFingerprint = materialFingerprint
        self.sourceMaterialFingerprint = nil
        self.documentSummary = nil
    }

    init(
        metadata: FileMetadataSnapshot,
        contentFingerprint: ContentFingerprint,
        materialFingerprint: ContentFingerprint,
        sourceMaterialFingerprint: ContentFingerprint?,
        documentSummary: ConcatenationCachedDocumentSummary?
    ) {
        self.metadata = metadata
        self.contentFingerprint = contentFingerprint
        self.materialFingerprint = materialFingerprint
        self.sourceMaterialFingerprint = sourceMaterialFingerprint
        self.documentSummary = documentSummary
    }

    public var file: URL {
        metadata.url
    }
}
